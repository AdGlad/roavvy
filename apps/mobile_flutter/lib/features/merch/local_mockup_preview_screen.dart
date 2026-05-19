import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../core/providers.dart';
import '../cards/artwork_confirmation_service.dart';
import '../cards/card_image_renderer.dart';
import 'local_mockup_image_cache.dart';
import 'local_mockup_painter.dart';
import 'merch_customisation_sheet.dart';
import 'merch_order_confirmation_screen.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_share_exporter.dart';
import 'merch_preset.dart';
import 'merch_stamp_color.dart';
import 'merch_variant_lookup.dart';
import 'mockup_approval_service.dart';
import 'printful_placement_mapper.dart';
import 'product_mockup_specs.dart';

// ── State enum ────────────────────────────────────────────────────────────────

enum _MockupState { configuring, rerendering, approving, ready }

// ── Colour swatch constants (M58-04) ─────────────────────────────────────────

const _kSwatchColours = <String, Color>{
  'Black': Color(0xFF1A1A1A),
  'White': Color(0xFFF5F5F5),
  'Blue':  Color(0xFF1A2C5B),
  'Grey':  Color(0xFFB0B0B0),
  'Red':   Color(0xFFCC1717),
};

// ── Screen ────────────────────────────────────────────────────────────────────

/// Unified commerce screen: local product mockup, product configuration, and
/// checkout in a single screen (ADR-107 / M55 / M58).
///
/// M58 changes:
///   - Mockup fills ~80 % of screen; options live in a DraggableScrollableSheet.
///   - T-shirt front/back flip uses [_ShirtFlipView] (Matrix4.rotationY, 350 ms).
///   - Colour picker uses circle swatches instead of ChoiceChips.
///   - Mockup wrapped in InteractiveViewer for pinch-to-zoom.
///
/// Flow:
///   [configuring] — user configures product options; local mockup shown.
///   [rerendering] — card template changed; re-render in progress.
///   [approving]   — user approved; writing Firestore records + calling
///                   createMerchCart Firebase Function.
///   [ready]       — Printful photorealistic mockup loaded; checkout available.
class LocalMockupPreviewScreen extends ConsumerStatefulWidget {
  const LocalMockupPreviewScreen({
    super.key,
    required this.selectedCodes,
    required this.allCodes,
    required this.trips,
    // nullable: if null and initialPreset is provided, artwork is generated
    // automatically from the preset on mount (ADR-147).
    this.artworkImageBytes,
    this.initialPreset,
    this.artworkConfirmationId,
    this.initialTemplate = CardTemplateType.grid,
    this.confirmedAspectRatio = 3.0 / 2.0,
    this.confirmedEntryOnly = false,
    this.cardId,
    this.titleOverride,
    this.stampColor,
    this.dateColor,
    this.transparentBackground = false,
    // Passport layout params (ADR-133): stamp colour variants re-render using
    // the same size/scatter/seed so the merch image matches the editor design.
    this.stampSizeMultiplier = 1.0,
    this.stampJitterFactor = 0.4,
    this.stampLayoutSeed,
    this.initialColour,
    this.subtitleOverride,
  });

  final List<String> selectedCodes;

  /// All-time country codes (not year-filtered). Used when the front ribbon
  /// mode is set to 'all countries' so the ribbon shows the user's full
  /// collection regardless of the card's year filter.
  final List<String> allCodes;

  final List<TripRecord> trips;

  /// Pre-rendered artwork bytes. If `null`, artwork is generated from
  /// [initialPreset] on mount (ADR-147). Existing callers that pass bytes
  /// continue to work unchanged.
  final Uint8List? artworkImageBytes;

  /// Preset to use for auto-generating artwork when [artworkImageBytes] is
  /// null. Ignored if [artworkImageBytes] is provided.
  final MerchPreset? initialPreset;
  final String? artworkConfirmationId;
  final CardTemplateType initialTemplate;

  /// Aspect ratio of the confirmed artwork (ADR-112). Used when re-rendering
  /// after a template change so the new render matches the original dimensions.
  final double confirmedAspectRatio;

  /// Whether entry-only mode was active when artwork was confirmed (ADR-112).
  final bool confirmedEntryOnly;

  /// Optional TravelCard ID — threaded through to createMerchCart for order
  /// traceability (ADR-093).
  final String? cardId;

  /// User customization fields (ADR-117)
  final String? titleOverride;
  final Color? stampColor;
  final Color? dateColor;
  final bool transparentBackground;

  /// Structured branding subtitle for the artwork (ADR-157).
  /// When non-null, shown in the bottom branding zone of the card.
  final String? subtitleOverride;

  /// Passport layout params (ADR-133). Forwarded to CardImageRenderer so
  /// stamp-colour re-renders preserve the user's size/scatter/seed design.
  final double stampSizeMultiplier;
  final double stampJitterFactor;
  final int? stampLayoutSeed;

  /// Pre-selected shirt colour from [PulseMerchOption.suggestedShirtColor]
  /// (ADR-153). When null, the first available colour is used.
  final String? initialColour;

  @override
  ConsumerState<LocalMockupPreviewScreen> createState() =>
      _LocalMockupPreviewScreenState();
}

class _LocalMockupPreviewScreenState
    extends ConsumerState<LocalMockupPreviewScreen>
    with WidgetsBindingObserver {
  // ── Product state ──────────────────────────────────────────────────────────

  MerchProduct _product = MerchProduct.tshirt;
  String _colour = tshirtColors.first; // 'Black'
  String _tshirtSize = tshirtSizes[2]; // 'L'
  String _posterPaper = posterPapers.first; // 'Enhanced Matte'
  String _posterSize = posterSizes.first; // '12x18in'
  // 'left_chest' | 'center' | 'right_chest' | 'none'
  // Default 'center' → Printful placement 'front' (confirmed working for product 12).
  // 'left_chest'/'right_chest' → 'front_left'/'front_right' — validity unconfirmed.
  String _frontPosition = 'center';
  // 'center' | 'none'
  String _backPosition = 'center';

  // ── Card / artwork state ───────────────────────────────────────────────────

  late CardTemplateType _template;

  // nullable until first generation (ADR-147: preset-driven entry).
  Uint8List? _artworkBytes;

  /// True after the first successful artwork render. Prevents silent
  /// re-generation on navigation events or unrelated state changes.
  bool _artworkLocked = false;

  /// Current active preset config (may be updated by Layer 2 customisation).
  MerchPresetConfig? _presetConfig;

  /// True when all Printful mockup retries are exhausted. Shows fallback
  /// warning and re-enables the checkout button.
  bool _mockupFailed = false;

  String? _artworkConfirmationId;
  String? _mockupApprovalId;

  // ── Decoded images ─────────────────────────────────────────────────────────

  ui.Image? _artworkImage;
  ui.Image? _frontShirtImage;
  ui.Image? _backShirtImage;
  ui.Image? _frontRibbonImage;
  Uint8List? _frontRibbonBytes;
  // Ribbon rendered with ALL codes — for mini preview tiles.
  ui.Image? _frontRibbonAllImage;

  // ── Screen state machine ───────────────────────────────────────────────────

  _MockupState _state = _MockupState.configuring;

  /// Non-null during a retry attempt; displayed in [_ApprovingView].
  String? _retryMessage;

  // ── Ready-state checkout data ──────────────────────────────────────────────

  String? _checkoutUrl;
  /// Front mockup URL from Printful (front or chest placement view).
  String? _mockupUrl;
  /// Back mockup URL from Printful (back placement view — separate from front).
  String? _backMockupUrl;
  String? _merchConfigId;
  bool _checkoutLaunched = false;

  // ── Mockup realtime listener (post-approve) ────────────────────────────────

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _mockupSubscription;
  Timer? _mockupListenerTimer;

  // ── Flip view key — replaced to reset zoom when colour/placement changes ──

  int _flipViewKey = 0;

  // ── Which face is visible in the local mockup (configuring state only) ────
  // Driven by _onFlipped; reset when placement options change.
  bool _showingFront = true;

  // ── Passport stamp colour mode (M64) ──────────────────────────────────────

  PassportColorMode _passportColorMode = PassportColorMode.black;

  // ── Timeline text colour (M86) ─────────────────────────────────────────────
  // null = not yet resolved; set in initState from _suggestTimelineTextColor.

  Color? _timelineTextColor;

  // ── Grid text colour (M107) ────────────────────────────────────────────────
  // Auto-derived from shirt colour; dark text on light shirts, light on dark.

  Color? _gridTextColor;

  // ── Word cloud text colour ─────────────────────────────────────────────────
  // Auto-derived from shirt colour; dark text on light shirts, light on dark.

  Color? _wordCloudTextColor;

  // ── Front ribbon mode (M74) ───────────────────────────────────────────────
  // 'all'      → ribbon uses all-time countries (widget.allCodes)
  // 'selected' → ribbon uses year-filtered selection (widget.selectedCodes)
  // Only visible when allCodes differs from selectedCodes.
  String _frontRibbonMode = 'selected';

  // ── Artwork stamp variants ─────────────────────────────────────────────────
  // 0 = original (widget.stampColor), 1 = black stamps, 2 = white/transparent

  final List<Uint8List?> _artworkVariants = List.filled(3, null);
  int _artworkVariantIndex = 0;
  bool _variantLoading = false;

  // ── Post-checkout order poll parameters ────────────────────────────────────

  static const int _pollIntervalSeconds = 3;
  static const int _pollMaxAttempts = 10;

  // ── Mockup generation parameters ───────────────────────────────────────────

  static const int _kMaxRetries = 2;
  // 30 s — function now returns after cart creation (~5–10 s); mockup is async.
  static const Duration _kCallTimeout = Duration(seconds: 30);
  // Realtime listener timeout: Printful can take up to ~75 s (25 polls × 3 s).
  // 120 s gives comfortable headroom.
  static const Duration _kMockupListenerTimeout = Duration(seconds: 120);

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isTshirt => _product == MerchProduct.tshirt;

  /// True when the current artwork variant uses a transparent background,
  /// requiring [BlendMode.srcOver] in [LocalMockupPainter].
  ///
  /// For t-shirts all variants are always transparent (no parchment border
  /// visible on fabric). For posters, only variants 1 & 2 are transparent.
  bool get _variantIsTransparent {
    if (_isTshirt) return true;
    if (_artworkVariantIndex == 1) return true;
    if (_artworkVariantIndex == 2) return true;
    if (_artworkVariantIndex == 0 && widget.transparentBackground) return true;
    return false;
  }

  String get _resolvedVariantGid => resolveVariantGid(
        product: _product,
        colour: _colour,
        size: _isTshirt ? _tshirtSize : _posterSize,
        paper: _posterPaper,
      );

  // ── Stamp colour helpers (M64) ─────────────────────────────────────────────

  PassportColorMode _suggestStampColor(String shirtColour) => switch (shirtColour) {
    'Black'        => PassportColorMode.white,
    'White'        => PassportColorMode.black,
    'Navy'         => PassportColorMode.white,
    'Heather Grey' => PassportColorMode.black,
    'Red'          => PassportColorMode.white,
    _              => PassportColorMode.black,
  };

  /// Suggests a timeline/grid text colour based on shirt colour luminance.
  /// Dark shirts → white text; light shirts → black text.
  Color _suggestTimelineTextColor(String shirtColour) => switch (shirtColour) {
    'White' => Colors.black,
    'Grey'  => Colors.black,
    _       => Colors.white, // Black, Blue, Red → white
  };

  Color _suggestGridTextColor(String shirtColour) => switch (shirtColour) {
    'White' => Colors.black,
    'Grey'  => Colors.black,
    _       => Colors.white, // Black, Blue, Red → white
  };

  Color _suggestWordCloudTextColor(String shirtColour) => switch (shirtColour) {
    'White' => Colors.black,
    'Grey'  => Colors.black,
    _       => Colors.white, // Black, Blue, Red → white
  };

  Set<PassportColorMode> _disabledStampColors(String shirtColour) => switch (shirtColour) {
    'Black'        => {PassportColorMode.black, PassportColorMode.multicolor},
    'White'        => {PassportColorMode.white},
    'Navy'         => {PassportColorMode.black, PassportColorMode.multicolor},
    'Red'          => {PassportColorMode.multicolor},
    _              => {},
  };

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _artworkConfirmationId = widget.artworkConfirmationId;
    if (widget.initialColour != null &&
        tshirtColors.contains(widget.initialColour)) {
      _colour = widget.initialColour!;
    }
    final providedBytes = widget.artworkImageBytes;
    if (providedBytes != null) {
      // Existing path: caller supplied pre-rendered artwork bytes (ADR-147).
      _artworkBytes = providedBytes;
      _artworkLocked = true;
      _artworkVariants[0] = providedBytes;
      // T-shirts always composite artwork transparently onto fabric. If the
      // confirmed artwork was rendered with a background (transparentBackground=false),
      // the multicolor variant must be re-rendered with transparency. Clearing
      // slot 0 here forces _renderVariant(0) when the user picks multicolor,
      // which sets transparentBg = _isTshirt || ... = true.
      if (_isTshirt && !widget.transparentBackground) {
        _artworkVariants[0] = null;
      }
    } else if (widget.initialPreset != null) {
      // Preset-driven path: no artwork yet. Will be generated in postFrameCallback.
      _presetConfig = widget.initialPreset!.config;
      _template = _presetConfig!.layout;
    }

    _passportColorMode = _suggestStampColor(_colour);
    _timelineTextColor = _suggestTimelineTextColor(_colour);
    _gridTextColor = _suggestGridTextColor(_colour);
    _wordCloudTextColor = _suggestWordCloudTextColor(_colour);

    WidgetsBinding.instance.addObserver(this);

    if (_artworkBytes != null) {
      _decodeArtwork(_artworkBytes!);
    }
    _loadShirtImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFrontRibbonImage();

      if (_artworkBytes != null) {
        // Immediately render the suggested stamp color for the initial shirt
        // colour so the user sees the correct variant on first entry (e.g. white
        // stamps on a black shirt) without having to tap a color chip manually.
        if (_isTshirt && _template == CardTemplateType.passport) {
          unawaited(_setPassportColorMode(_passportColorMode));
        }
        // Immediately render with the suggested text colour for timeline cards
        // so the artwork bytes are fresh + transparent on first entry.
        if (_isTshirt && _template == CardTemplateType.timeline) {
          unawaited(_setTimelineTextColor(_timelineTextColor ?? Colors.white));
        }
        // Same for grid cards.
        if (_isTshirt && _template == CardTemplateType.grid) {
          unawaited(_setGridTextColor(_gridTextColor ?? Colors.white));
        }
        // Same for word cloud cards.
        if (_isTshirt && _template == CardTemplateType.wordCloud) {
          unawaited(_setWordCloudTextColor(_wordCloudTextColor ?? Colors.white));
        }
      } else if (_presetConfig != null) {
        // Preset-driven: auto-generate artwork on first frame.
        unawaited(_generateFromPreset(_presetConfig!));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mockupListenerTimer?.cancel();
    _mockupSubscription?.cancel();
    // Cache owns frontShirtImage/backShirtImage — let it dispose them.
    LocalMockupImageCache.instance.dispose();
    // Artwork image is decoded directly from bytes (not cached) — screen owns it.
    _artworkImage?.dispose();
    _frontRibbonImage?.dispose();
    _frontRibbonAllImage?.dispose();
    super.dispose();
  }

  // ── Image loading ──────────────────────────────────────────────────────────

  Future<void> _decodeArtwork(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _artworkImage?.dispose();
      _artworkImage = frame.image;
    });
  }

  /// Loads the shirt mockup image (M59: single JPG shared for front and back).
  ///
  /// All colour variants use the same asset; colour swatch selection affects
  /// the Printful order colour but not the in-app preview (ADR-115 Decision 3).
  Future<void> _loadShirtImages() async {
    if (_product == MerchProduct.poster) {
      if (mounted) {
        setState(() {
          _frontShirtImage = null;
          _backShirtImage = null;
        });
      }
      return;
    }

    final frontSpec = ProductMockupSpecs.specsFor(
      _product,
      colour: _colour,
      placement: 'front',
    );
    final backSpec = ProductMockupSpecs.specsFor(
      _product,
      colour: _colour,
      placement: 'back',
    );

    try {
      final frontImage = await LocalMockupImageCache.instance.load(frontSpec.assetPath);
      final backImage = await LocalMockupImageCache.instance.load(backSpec.assetPath);
      if (!mounted) return;
      setState(() {
        _frontShirtImage = frontImage;
        _backShirtImage = backImage;
      });
    } catch (_) {
      // Non-fatal — painter handles null productImage gracefully.
    }
  }

  Future<void> _loadFrontRibbonImage() async {
    if (!_isTshirt || !mounted) return;

    final levelLabel = ref.read(xpNotifierProvider).levelLabel;
    final Color textColor;
    if (_template == CardTemplateType.timeline && _timelineTextColor != null) {
      textColor = _timelineTextColor!;
    } else {
      final isDark = _colour == 'Black' || _colour == 'Blue' || _colour == 'Navy' || _colour == 'Red';
      textColor = isDark ? Colors.white : Colors.black;
    }
    final ribbonCodes = _frontRibbonMode == 'all'
        ? widget.allCodes
        : widget.selectedCodes;

    // Render the active ribbon (used for the shirt mockup).
    try {
      final result = await CardImageRenderer.render(
        context,
        CardTemplateType.frontRibbon,
        codes: ribbonCodes,
        travelerLevel: levelLabel,
        textColor: textColor,
        pixelRatio: 4.0,
      );

      final codec = await ui.instantiateImageCodec(result.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }

      setState(() {
        _frontRibbonBytes = result.bytes;
        _frontRibbonImage?.dispose();
        _frontRibbonImage = frame.image;
      });
    } catch (_) {}

    // Also render the "all codes" version for mini preview tiles
    // (only needed when there is a difference between selected and all).
    if (!mounted) return;
    if (widget.allCodes.length != widget.selectedCodes.length) {
      try {
        final allResult = await CardImageRenderer.render(
          context,
          CardTemplateType.frontRibbon,
          codes: widget.allCodes,
          travelerLevel: levelLabel,
          textColor: textColor,
          pixelRatio: 2.0,
        );
        final codec2 = await ui.instantiateImageCodec(allResult.bytes);
        final frame2 = await codec2.getNextFrame();
        if (!mounted) {
          frame2.image.dispose();
          return;
        }
        setState(() {
          _frontRibbonAllImage?.dispose();
          _frontRibbonAllImage = frame2.image;
        });
      } catch (_) {}
    }
  }

  // ── Preset-driven artwork generation (ADR-147) ────────────────────────────

  /// Generates artwork from [config] using [CardImageRenderer] and locks it.
  ///
  /// Shows a rerendering overlay while generating. Called on first mount when
  /// [widget.initialPreset] is set, and again when the user applies Layer 2
  /// customisation changes.
  Future<void> _generateFromPreset(MerchPresetConfig config) async {
    if (!mounted) return;
    setState(() => _state = _MockupState.rerendering);
    try {
      final result = await CardImageRenderer.render(
        context,
        config.layout,
        codes: widget.selectedCodes,
        trips: widget.trips,
        forPrint: false,
        entryOnly: config.entryOnly,
        cardAspectRatio: _isTshirt ? 4.0 / 5.0 : widget.confirmedAspectRatio,
        pixelRatio: _isTshirt ? 7.0 : 3.0,
        topPaddingFraction: _isTshirt ? 1.0 / 16.0 : 0.0,
        transparentBackground: _isTshirt,
        stampJitterFactor: config.stampJitterFactor,
        stampSizeMultiplier: config.stampSizeMultiplier,
      );
      if (!mounted) return;
      _artworkVariants[0] = result.bytes;
      await _decodeArtwork(result.bytes);
      if (!mounted) return;
      setState(() {
        _artworkBytes = result.bytes;
        _artworkLocked = true;
        _artworkConfirmationId = null; // reset — new image, no confirmation yet
        _state = _MockupState.configuring;
      });
      // Apply suggested stamp/text colour for the newly generated image.
      if (_isTshirt && config.layout == CardTemplateType.passport) {
        unawaited(_setPassportColorMode(_passportColorMode));
      }
      if (_isTshirt && config.layout == CardTemplateType.timeline) {
        unawaited(_setTimelineTextColor(_timelineTextColor ?? Colors.white));
      }
      if (_isTshirt && config.layout == CardTemplateType.grid) {
        unawaited(_setGridTextColor(_gridTextColor ?? Colors.white));
      }
      if (_isTshirt && config.layout == CardTemplateType.wordCloud) {
        unawaited(_setWordCloudTextColor(_wordCloudTextColor ?? Colors.white));
      }
    } catch (e) {
      debugPrint('[merch] preset generation failed: $e');
      if (!mounted) return;
      setState(() => _state = _MockupState.configuring);
    }
  }

  /// Opens the Layer 2 customisation sheet and regenerates artwork if the
  /// user applies changes (ADR-147).
  Future<void> _openCustomisationSheet() async {
    final current = _presetConfig ??
        MerchPresetConfig(
          layout:    _template,
          source:    MerchCountrySource.allTime,
          jitter:    widget.stampJitterFactor,
          density:   MerchDensity.balanced,
          stampMode: widget.confirmedEntryOnly
              ? MerchStampMode.entryOnly
              : MerchStampMode.entryExit,
        );

    final updated = await showMerchCustomisationSheet(
      context,
      config: current,
    );
    if (updated == null || !mounted) return;

    setState(() {
      _presetConfig = updated;
      _template = updated.layout;
      _artworkLocked = false; // allow regeneration
    });
    await _generateFromPreset(updated);
  }

  // ── App lifecycle (post-checkout poll) ────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutLaunched) {
      _checkoutLaunched = false;
      if (!mounted) return;
      _pollForOrderConfirmation();
    }
  }

  Future<void> _pollForOrderConfirmation() async {
    final configId = _merchConfigId;
    final uid = ref.read(currentUidProvider);
    if (configId == null || uid == null) {
      if (!mounted) return;
      _showOrderProcessingFallback();
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('merch_configs')
        .doc(configId);

    for (int attempt = 0; attempt < _pollMaxAttempts; attempt++) {
      await Future<void>.delayed(
          const Duration(seconds: _pollIntervalSeconds));
      if (!mounted) return;
      try {
        final snap = await docRef.get();
        if (snap.data()?['status'] == 'ordered') {
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MerchPostPurchaseScreen(
                product: _product,
                countryCount: widget.selectedCodes.length,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Network error mid-poll — continue.
      }
    }

    if (!mounted) return;
    _showOrderProcessingFallback();
  }

  // ── Mockup realtime listener (post-approve) ───────────────────────────────

  /// Attaches a Firestore realtime listener on the MerchConfig document after
  /// [_onApprove] returns. Reacts to [mockupStatus] field updates written by
  /// the Cloud Function background task (typically within 20–75 s).
  ///
  /// Cancels itself when status is terminal ('ready', 'timeout', 'failed') or
  /// after [_kMockupListenerTimeout] elapses without a terminal state.
  void _startMockupListener(String configId, String uid) {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('merch_configs')
        .doc(configId);

    // Hard timeout — cancel and surface the amber fallback if Firestore never
    // delivers a terminal status within the window.
    _mockupListenerTimer = Timer(_kMockupListenerTimeout, () {
      _mockupSubscription?.cancel();
      _mockupSubscription = null;
      debugPrint('[mockup] listener: timed out after ${_kMockupListenerTimeout.inSeconds}s');
      if (mounted) setState(() => _mockupFailed = true);
    });

    _mockupSubscription = docRef.snapshots().listen(
      (snap) {
        final data      = snap.data();
        final status    = data?['mockupStatus'] as String?;
        final frontUrl  = data?['frontMockupUrl'] as String?;
        final backUrl   = data?['backMockupUrl']  as String?;

        debugPrint('[mockup] listener update: status=$status front=${frontUrl != null ? "✓" : "null"} back=${backUrl != null ? "✓" : "null"}');

        // Terminal when server has written a definitive status, or (backwards
        // compat) when a URL is present on a doc that predates mockupStatus.
        final isTerminal = status == 'ready' || status == 'timeout' ||
            status == 'failed' ||
            (status == null && frontUrl != null && frontUrl.isNotEmpty);

        if (!isTerminal) return;

        _mockupListenerTimer?.cancel();
        _mockupListenerTimer = null;
        _mockupSubscription?.cancel();
        _mockupSubscription = null;

        if (!mounted) return;
        setState(() {
          _mockupUrl     = frontUrl;
          _backMockupUrl = backUrl;
          // Show amber fallback when server explicitly timed out or failed and
          // we have no URLs to display.
          if ((status == 'timeout' || status == 'failed') &&
              (frontUrl == null || frontUrl.isEmpty)) {
            _mockupFailed = true;
          }
        });
      },
      onError: (Object e) {
        debugPrint('[mockup] listener error: $e');
        _mockupListenerTimer?.cancel();
        _mockupListenerTimer = null;
        if (mounted) setState(() => _mockupFailed = true);
      },
    );
  }

  void _showOrderProcessingFallback() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("We're processing your order"),
        content: const Text(
          "If you completed payment, you'll receive a confirmation email "
          'shortly. Your order will appear in your order history once confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to map'),
          ),
        ],
      ),
    );
  }

  // ── Artwork stamp variant cycling (swipe up) ───────────────────────────────

  /// Labels shown briefly when the user swipes up to change stamp variant.
  static const List<String> _kVariantLabels = [
    'Original stamps',
    'Black stamps',
    'White stamps',
  ];

  Future<void> _renderVariant(int index) async {
    setState(() => _variantLoading = true);
    try {
      if (!context.mounted) return;
      // For t-shirts all variants are transparent (no parchment border on fabric).
      // Index 2 (white) must pass Colors.white explicitly — null falls back to
      // the original stamp colours, not white.
      final (Color? stampColor, Color? stampTextColor, bool transparentBg) = switch (index) {
        1 => (const Color(0xFF000000), const Color(0xFF000000), true),  // black stamps + black text
        2 => (Colors.white, Colors.white, true),                         // white stamps + white text
        _ => (widget.stampColor, null, _isTshirt || widget.transparentBackground),  // multicolor/default
      };
      final result = await CardImageRenderer.render(
        context,
        _template,
        codes: widget.selectedCodes,
        trips: widget.trips,
        // Passport uses forPrint=false so re-renders for stamp colour changes
        // use the same screen-layout (margins, sizeMultiplier, jitter) as the
        // card the user designed. forPrint=true would change margins and ignore
        // sizeMultiplier, producing a different layout (ADR-133).
        forPrint: false,
        // T-shirts always show entry + exit stamps regardless of card-editor setting.
        entryOnly: _isTshirt ? false : widget.confirmedEntryOnly,
        cardAspectRatio: _isTshirt ? 4.0 / 5.0 : widget.confirmedAspectRatio,
        pixelRatio: _isTshirt ? 7.0 : 3.0,
        topPaddingFraction: _isTshirt ? 1.0 / 16.0 : 0.0,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
        stampColor: stampColor,
        dateColor: widget.dateColor,
        textColor: stampTextColor,
        transparentBackground: transparentBg,
        // Preserve the exact layout the user designed (ADR-133).
        stampSeed: widget.stampLayoutSeed,
        stampSizeMultiplier: widget.stampSizeMultiplier,
        stampJitterFactor: widget.stampJitterFactor,
      );
      if (!mounted) return;
      _artworkVariants[index] = result.bytes;
      await _switchToVariant(index);
    } finally {
      if (mounted) setState(() => _variantLoading = false);
    }
  }

  Future<void> _switchToVariant(int index) async {
    final bytes = _artworkVariants[index]!;
    await _decodeArtwork(bytes);
    if (!mounted) return;
    setState(() {
      _artworkVariantIndex = index;
      _artworkBytes = bytes;
    });
  }

  // ── Passport stamp colour selection (M64) ──────────────────────────────────

  Future<void> _setPassportColorMode(PassportColorMode mode) async {
    setState(() => _passportColorMode = mode);
    final idx = switch (mode) {
      PassportColorMode.multicolor => 0,
      PassportColorMode.black      => 1,
      PassportColorMode.white      => 2,
    };
    if (_artworkVariants[idx] != null) {
      await _switchToVariant(idx);
    } else {
      await _renderVariant(idx);
    }
  }

  // ── Timeline text colour selection (M86) ───────────────────────────────────

  Future<void> _setTimelineTextColor(Color textColor) async {
    setState(() {
      _timelineTextColor = textColor;
      _variantLoading = true;
    });
    try {
      if (!context.mounted) return;
      final result = await CardImageRenderer.render(
        context,
        _template,
        codes: widget.selectedCodes,
        trips: widget.trips,
        cardAspectRatio: _isTshirt ? 4.0 / 5.0 : widget.confirmedAspectRatio,
        pixelRatio: _isTshirt ? 7.0 : 3.0,
        topPaddingFraction: _isTshirt ? 1.0 / 16.0 : 0.0,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
        transparentBackground: true,
        textColor: textColor,
      );
      if (!mounted) return;
      await _decodeArtwork(result.bytes);
      if (!mounted) return;
      setState(() => _artworkBytes = result.bytes);
      // Re-render front ribbon to match the chosen text color.
      await _loadFrontRibbonImage();
    } finally {
      if (mounted) setState(() => _variantLoading = false);
    }
  }

  // ── Grid text colour selection (M107) ─────────────────────────────────────

  Future<void> _setGridTextColor(Color textColor) async {
    setState(() {
      _gridTextColor = textColor;
      _variantLoading = true;
    });
    try {
      if (!context.mounted) return;
      final result = await CardImageRenderer.render(
        context,
        _template,
        codes: widget.selectedCodes,
        trips: widget.trips,
        cardAspectRatio: _isTshirt ? 4.0 / 5.0 : widget.confirmedAspectRatio,
        pixelRatio: _isTshirt ? 7.0 : 3.0,
        topPaddingFraction: _isTshirt ? 1.0 / 16.0 : 0.0,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
        transparentBackground: true,
        textColor: textColor,
      );
      if (!mounted) return;
      await _decodeArtwork(result.bytes);
      if (!mounted) return;
      setState(() => _artworkBytes = result.bytes);
    } finally {
      if (mounted) setState(() => _variantLoading = false);
    }
  }

  // ── Word cloud text colour selection ──────────────────────────────────────

  Future<void> _setWordCloudTextColor(Color textColor) async {
    setState(() {
      _wordCloudTextColor = textColor;
      _variantLoading = true;
    });
    try {
      if (!context.mounted) return;
      final result = await CardImageRenderer.render(
        context,
        _template,
        codes: widget.selectedCodes,
        trips: widget.trips,
        cardAspectRatio: _isTshirt ? 4.0 / 5.0 : widget.confirmedAspectRatio,
        pixelRatio: _isTshirt ? 7.0 : 3.0,
        topPaddingFraction: _isTshirt ? 1.0 / 16.0 : 0.0,
        titleOverride: widget.titleOverride,
        subtitleOverride: widget.subtitleOverride,
        transparentBackground: true,
        textColor: textColor,
      );
      if (!mounted) return;
      await _decodeArtwork(result.bytes);
      if (!mounted) return;
      setState(() => _artworkBytes = result.bytes);
    } finally {
      if (mounted) setState(() => _variantLoading = false);
    }
  }

  // ── Colour / placement change handler ─────────────────────────────────────

  void _onVariantOptionChanged({
    String? colour,
    String? frontPosition,
    String? backPosition,
    MerchProduct? product,
  }) {
    final colourChanged = colour != null && colour != _colour;
    final frontChanged = frontPosition != null && frontPosition != _frontPosition;
    final backChanged = backPosition != null && backPosition != _backPosition;
    final productChanged = product != null && product != _product;
    setState(() {
      if (product != null) _product = product;
      if (colour != null) _colour = colour;
      if (frontPosition != null) _frontPosition = frontPosition;
      if (backPosition != null) _backPosition = backPosition;
      if (colourChanged || productChanged || frontChanged || backChanged) _flipViewKey++;
      // Sync the visible face when placement changes.
      if (frontChanged) _showingFront = _frontPosition != 'none';
    });
    if (colourChanged || productChanged) {
      _loadShirtImages();
      _loadFrontRibbonImage();
    }
    if (colourChanged && _isTshirt && _template == CardTemplateType.passport) {
      unawaited(_setPassportColorMode(_suggestStampColor(colour)));
    }
    if (colourChanged && _isTshirt && _template == CardTemplateType.timeline) {
      unawaited(_setTimelineTextColor(_suggestTimelineTextColor(colour)));
    }
    if (colourChanged && _isTshirt && _template == CardTemplateType.grid) {
      unawaited(_setGridTextColor(_suggestGridTextColor(colour)));
    }
    if (colourChanged && _isTshirt && _template == CardTemplateType.wordCloud) {
      unawaited(_setWordCloudTextColor(_suggestWordCloudTextColor(colour)));
    }
  }

  // ── Upload helpers ─────────────────────────────────────────────────────────

  /// Downscales [pngBytes] to [maxWidth] pixels wide before upload.
  ///
  /// Max upload width for front/chest artwork (small print area, 600 px is enough).
  static const int _kUploadMaxWidth = 600;

  /// Max upload width for back artwork. At 12 in × 150 DPI the print requires
  /// 1800 px; rendering at 7× logical (340 px) gives 2380 px (~198 DPI).
  /// Cap at 2400 so the full render is sent with no downscaling.
  static const int _kBackUploadMaxWidth = 2400;

  Future<Uint8List> _resizeForUpload(Uint8List pngBytes,
      {int maxWidth = _kUploadMaxWidth}) async {
    final codec = await ui.instantiateImageCodec(
      pngBytes,
      targetWidth: maxWidth,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return byteData!.buffer.asUint8List();
  }

  void _onFlipped(bool showFront) {
    // Tracks which face is visible in the local mockup so _buildCurrentFace
    // can supply the correct artwork (back artwork when showFront=false).
    setState(() => _showingFront = showFront);
  }

  // ── Approval handler ───────────────────────────────────────────────────────

  Future<void> _onApprove() async {
    // Artwork must be locked before approval (ADR-147).
    final artworkBytes = _artworkBytes;
    if (artworkBytes == null) {
      debugPrint('[mockup] approve blocked — artwork not yet generated');
      return;
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      debugPrint('[mockup] ❌ approve blocked — user not signed in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue')),
      );
      return;
    }

    debugPrint('[mockup] ── approve started ──────────────────────────────');
    debugPrint('[mockup]   uid=$uid');
    debugPrint('[mockup]   product=${_product.name}  colour=$_colour  size=$_tshirtSize');
    debugPrint('[mockup]   frontPosition=$_frontPosition  backPosition=$_backPosition');
    debugPrint('[mockup]   variant=$_resolvedVariantGid');
    debugPrint('[mockup]   artworkBytes=${artworkBytes.length}B');
    debugPrint('[mockup]   frontRibbonBytes=${_frontRibbonBytes?.length ?? 0}B');
    debugPrint('[mockup]   countries=${widget.selectedCodes.length}: ${widget.selectedCodes.take(5).join(",")}${widget.selectedCodes.length > 5 ? "…" : ""}');

    setState(() {
      _state = _MockupState.approving;
      _retryMessage = null;
    });

    try {
      // ── Step 1: artwork confirmation ────────────────────────────────────────
      String? confirmationId = _artworkConfirmationId;
      if (confirmationId == null) {
        debugPrint('[mockup] step 1: creating artwork confirmation');
        final imageHash = sha256.convert(artworkBytes).toString();
        debugPrint('[mockup]   imageHash=$imageHash');
        final newConfirmation = ArtworkConfirmation(
          confirmationId: 'ac-${DateTime.now().microsecondsSinceEpoch}',
          userId: uid,
          templateType: _template,
          aspectRatio: 1.5,
          countryCodes: widget.selectedCodes,
          countryCount: widget.selectedCodes.length,
          dateLabel: '',
          entryOnly: false,
          imageHash: imageHash,
          renderSchemaVersion: 'v1',
          confirmedAt: DateTime.now().toUtc(),
          status: ArtworkConfirmationStatus.confirmed,
        );

        final priorConfirmationId = widget.artworkConfirmationId;
        if (priorConfirmationId != null) {
          debugPrint('[mockup]   archiving prior confirmation: $priorConfirmationId');
          unawaited(ArtworkConfirmationService(FirebaseFirestore.instance)
              .archive(uid, priorConfirmationId));
        }

        confirmationId = await ArtworkConfirmationService(
                FirebaseFirestore.instance)
            .create(newConfirmation);
        debugPrint('[mockup]   confirmationId=$confirmationId ✓');

        if (!mounted) return;
        setState(() => _artworkConfirmationId = confirmationId);
      } else {
        debugPrint('[mockup] step 1: reusing existing confirmationId=$confirmationId');
      }

      // ── Step 2: mockup approval record ─────────────────────────────────────
      // Cached so re-taps after an error reuse the same record rather than
      // creating duplicates.
      debugPrint('[mockup] step 2: mockup approval');
      if (_mockupApprovalId == null) {
        final newApprovalId = 'ma-${DateTime.now().microsecondsSinceEpoch}';
        final approval = MockupApproval(
          mockupApprovalId: newApprovalId,
          userId: uid,
          artworkConfirmationId: confirmationId,
          templateType: _template,
          variantId: _resolvedVariantGid,
          placementType: _isTshirt ? 'front:$_frontPosition,back:$_backPosition' : null,
          confirmedAt: DateTime.now().toUtc(),
        );
        await MockupApprovalService(FirebaseFirestore.instance).create(approval);
        if (!mounted) return;
        setState(() => _mockupApprovalId = newApprovalId);
        debugPrint('[mockup]   approvalId=$newApprovalId ✓ (created)');
      } else {
        debugPrint('[mockup]   approvalId=$_mockupApprovalId ✓ (reused)');
      }
      final approvalId = _mockupApprovalId!;

      if (!mounted) return;

      // ── Step 3: call createMerchCart (with retry) ──────────────────────────
      final sendFrontImage = _isTshirt &&
          PrintfulPlacementMapper.sendsArtwork(_frontPosition) &&
          _frontRibbonBytes != null;
      final sendBackImage = PrintfulPlacementMapper.sendsArtwork(_backPosition);
      // Resize images for upload — the server upscales to print dimensions anyway.
      // Reduces the back-artwork payload from ~1.7 MB to ~400 KB (transparent PNG preserved).
      final encSw = Stopwatch()..start();
      final uploadBackBytes  = sendBackImage  ? await _resizeForUpload(artworkBytes, maxWidth: _kBackUploadMaxWidth) : null;
      final uploadFrontBytes = sendFrontImage ? await _resizeForUpload(_frontRibbonBytes!)                           : null;
      final backImageBase64  = uploadBackBytes  != null ? base64Encode(uploadBackBytes)  : null;
      final frontImageBase64 = uploadFrontBytes != null ? base64Encode(uploadFrontBytes) : null;
      encSw.stop();
      debugPrint('[mockup] step 3: calling createMerchCart (max retries: $_kMaxRetries)');
      debugPrint('[mockup]   resize+encode took ${encSw.elapsedMilliseconds}ms');
      debugPrint('[mockup]   sendFrontImage=$sendFrontImage raw=${_frontRibbonBytes?.length ?? 0}B → upload=${uploadFrontBytes?.length ?? 0}B b64=${frontImageBase64?.length ?? 0}B');
      debugPrint('[mockup]   sendBackImage=$sendBackImage raw=${artworkBytes.length}B → upload=${uploadBackBytes?.length ?? 0}B b64=${backImageBase64?.length ?? 0}B');
      debugPrint('[mockup]   total payload ~${((frontImageBase64?.length ?? 0) + (backImageBase64?.length ?? 0)) ~/ 1024}KB');
      debugPrint('[mockup]   frontPosition=$_frontPosition  backPosition=$_backPosition');
      debugPrint('[mockup]   cardId=${widget.cardId}  artworkConfirmationId=$confirmationId  mockupApprovalId=$approvalId');

      Object? lastCallError;
      bool callSucceeded = false;

      for (var attempt = 0; attempt <= _kMaxRetries; attempt++) {
        if (attempt > 0) {
          debugPrint('[mockup]   retry attempt $attempt/$_kMaxRetries after error: $lastCallError');
          if (!mounted) return;
          setState(() => _retryMessage = 'Having trouble generating your mockup. Retrying\u2026');
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }

        try {
          final callable =
              FirebaseFunctions.instance.httpsCallable('createMerchCart');
          final sw = Stopwatch()..start();
          final result = await callable
              .call<Map<String, dynamic>>({
                'variantId': _resolvedVariantGid,
                'selectedCountryCodes': widget.selectedCodes,
                'quantity': 1,
                if (widget.cardId != null) 'cardId': widget.cardId,
                'artworkConfirmationId': confirmationId,
                'mockupApprovalId': approvalId,
                if (backImageBase64  != null) 'backImageBase64':  backImageBase64,
                if (frontImageBase64 != null) 'frontImageBase64': frontImageBase64,
                if (_isTshirt) 'frontPosition': PrintfulPlacementMapper.mapFront(_frontPosition),
                if (_isTshirt) 'backPosition':  PrintfulPlacementMapper.mapBack(_backPosition),
              })
              .timeout(_kCallTimeout);
          sw.stop();
          debugPrint('[mockup]   call completed in ${sw.elapsedMilliseconds}ms (attempt $attempt)');

          // ── Step 4: parse response ────────────────────────────────────────
          final checkoutUrl   = result.data['checkoutUrl']   as String?;
          final mockupUrl     = result.data['frontMockupUrl'] as String?;
          final backMockupUrl = result.data['backMockupUrl']  as String?;
          final merchConfigId = result.data['merchConfigId']  as String?;
          debugPrint('[mockup] step 4: response received');
          debugPrint('[mockup]   checkoutUrl=${checkoutUrl != null ? "✓ present" : "✗ null"}');
          debugPrint('[mockup]   frontMockupUrl=${mockupUrl != null ? "✓ $mockupUrl" : "✗ null"}');
          debugPrint('[mockup]   backMockupUrl=${backMockupUrl != null ? "✓ $backMockupUrl" : "✗ null (expected for collage style)"}');
          debugPrint('[mockup]   merchConfigId=$merchConfigId');

          if (checkoutUrl == null || checkoutUrl.isEmpty) {
            debugPrint('[mockup] ❌ no checkoutUrl in response — retrying');
            lastCallError = Exception('No checkout URL returned.');
            continue;
          }

          // mockupUrl may be null — the server generates it in the background.
          // We poll Firestore for it after transitioning to ready state.
          debugPrint('[mockup] ✓ ready — checkoutUrl present${mockupUrl != null ? ", mockupUrl present" : ", mockupUrl pending (will poll)"}');
          if (!mounted) return;
          setState(() {
            _state         = _MockupState.ready;
            _retryMessage  = null;
            _mockupUrl     = mockupUrl;
            _backMockupUrl = backMockupUrl;
            _checkoutUrl   = checkoutUrl;
            _merchConfigId = merchConfigId;
          });
          if ((mockupUrl == null || mockupUrl.isEmpty) && merchConfigId != null) {
            _startMockupListener(merchConfigId, uid);
          }
          callSucceeded = true;
          break;

        } on TimeoutException catch (e) {
          debugPrint('[mockup] ❌ TimeoutException on attempt $attempt: $e');
          lastCallError = e;
          // retryable — continue loop
        } on FirebaseFunctionsException catch (e) {
          debugPrint('[mockup] ❌ FirebaseFunctionsException on attempt $attempt: code=${e.code} msg=${e.message}');
          if (e.code == 'unavailable' ||
              e.code == 'internal' ||
              e.code == 'deadline-exceeded') {
            lastCallError = e;
            // retryable — continue loop
          } else {
            // Non-retryable (invalid-argument, not-found, etc.) — fail immediately.
            rethrow;
          }
        } on SocketException catch (e) {
          debugPrint('[mockup] ❌ SocketException on attempt $attempt: $e');
          lastCallError = e;
          // retryable — continue loop
        }
      }

      // If the loop completed without success, surface the last error.
      if (!callSucceeded) {
        final err = lastCallError;
        if (err is FirebaseFunctionsException) throw err;
        if (err is SocketException) throw err;
        // Default: treat as timeout.
        throw TimeoutException(
            'Mockup generation did not complete after retries.', _kCallTimeout);
      }

    } on FirebaseFunctionsException catch (e) {
      debugPrint('[mockup] ❌ FirebaseFunctionsException (final)');
      debugPrint('[mockup]   code=${e.code}');
      debugPrint('[mockup]   message=${e.message}');
      debugPrint('[mockup]   details=${e.details}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'unavailable'
                ? 'We couldn\'t generate your mockup. Please check your connection and try again.'
                : e.message ?? 'An error occurred. Please try again.',
          ),
        ),
      );
      setState(() { _state = _MockupState.configuring; _retryMessage = null; });
    } on SocketException catch (e) {
      debugPrint('[mockup] ❌ SocketException (final): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
      setState(() { _state = _MockupState.configuring; _retryMessage = null; });
    } on TimeoutException catch (e) {
      debugPrint('[mockup] ❌ TimeoutException (final): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'We couldn\'t generate your mockup right now. This may be due to a poor connection. Please try again later.'),
        ),
      );
      setState(() { _state = _MockupState.configuring; _retryMessage = null; });
    } catch (e, stack) {
      debugPrint('[mockup] ❌ unexpected error: $e');
      debugPrint('[mockup]   $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'We couldn\'t generate your mockup right now. Please try again later.'),
        ),
      );
      setState(() { _state = _MockupState.configuring; _retryMessage = null; });
    }
  }

  Future<void> _shareDesign() async {
    final bytes = _artworkBytes;
    if (bytes == null) return;
    await MerchShareExporter.share(bytes, title: 'My Travel Design');
  }

  void _openConfirmationScreen() {
    final url = _checkoutUrl;
    if (url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchOrderConfirmationScreen(
          frontMockupUrl:    _mockupUrl,
          backMockupUrl:     _backMockupUrl,
          frontArtworkBytes: _frontRibbonBytes,
          artworkBytes:      _artworkBytes!,
          size:              _isTshirt ? _tshirtSize : _posterSize,
          colour:            _colour,
          frontPosition:     _frontPosition,
          backPosition:      _backPosition,
          templateType:      _template,
          checkoutUrl:       url,
          isTshirt:          _isTshirt,
          onCheckoutLaunched: () { _checkoutLaunched = true; },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // Block system back while the cloud function is in flight so the user
      // cannot abandon a request that may still complete and charge them.
      canPop: _state != _MockupState.approving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please stay on this screen while your mockup is being prepared.'),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text('${_isTshirt ? 'T-Shirt' : 'Poster'} Design'),
          actions: [
            if (_artworkBytes != null)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Design',
                onPressed: _shareDesign,
              ),
          ],
        ),
        body: Stack(
          children: [
            // ── Background Mockup Canvas (Full Screen) ──────────────────────
            Positioned.fill(
              bottom: 80, // Leave some space for the floating bottom bar
              child: _buildMockupArea(theme),
            ),

            // ── Immersive Config Tray (Draggable) ───────────────────────────
            if (_state != _MockupState.ready && _isTshirt)
              _buildDraggableConfigTray(theme),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildBottomBar(),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableConfigTray(ThemeData theme) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.08,
      maxChildSize: 0.85,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _buildCompactConfigContent(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactConfigContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header row ───────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Design',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _showingFront = !_showingFront;
                _flipViewKey++;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip, size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      _showingFront ? 'See Back' : 'See Front',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Colour + Size (one row) ──────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MiniLabel('Colour'),
                  const SizedBox(height: 4),
                  _ColourSwatchRow(
                    selected: _colour,
                    onChanged: (c) => _onVariantOptionChanged(colour: c),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _MiniLabel('Size'),
                      Text(
                        _tshirtSize,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: theme.colorScheme.outline.withValues(alpha: 0.25),
                      thumbColor: theme.colorScheme.primary,
                    ),
                    child: Slider(
                      value: tshirtSizes.indexOf(_tshirtSize).toDouble(),
                      min: 0,
                      max: (tshirtSizes.length - 1).toDouble(),
                      divisions: tshirtSizes.length - 1,
                      onChanged: (v) =>
                          setState(() => _tshirtSize = tshirtSizes[v.round()]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final s in tshirtSizes)
                        Expanded(
                          child: Text(
                            s,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: s == _tshirtSize
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: s == _tshirtSize
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Front placement ──────────────────────────────────────────────
        const _MiniLabel('Front'),
        const SizedBox(height: 6),
        _PlacementSelector(
          options: const [
            _PlacementOptionData('left_chest',  'Left'),
            _PlacementOptionData('center',       'Centre'),
            _PlacementOptionData('right_chest', 'Right'),
            _PlacementOptionData('none',         'None'),
          ],
          selected: _frontPosition,
          isFront: true,
          colour: _colour,
          product: _product,
          shirtImage: _frontShirtImage,
          artworkImage: _frontRibbonImage,
          onChanged: (v) => _onVariantOptionChanged(frontPosition: v),
        ),
        const SizedBox(height: 10),

        // ── Back placement ───────────────────────────────────────────────
        const _MiniLabel('Back'),
        const SizedBox(height: 6),
        _PlacementSelector(
          options: const [
            _PlacementOptionData('center', 'Centre'),
            _PlacementOptionData('none',   'None'),
          ],
          selected: _backPosition,
          isFront: false,
          colour: _colour,
          product: _product,
          shirtImage: _backShirtImage,
          artworkImage: _artworkImage,
          onChanged: (v) => _onVariantOptionChanged(backPosition: v),
        ),

        // ── Advanced styling (conditional) ──────────────────────────────
        if (_template == CardTemplateType.passport ||
            _template == CardTemplateType.timeline ||
            widget.allCodes.length != widget.selectedCodes.length) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          if (_template == CardTemplateType.passport) ...[
            const _MiniLabel('Stamp Style'),
            const SizedBox(height: 6),
            _buildStampColorPicker(),
          ],
          if (_template == CardTemplateType.timeline) ...[
            if (_template == CardTemplateType.passport) const SizedBox(height: 10),
            const _MiniLabel('Text Colour'),
            const SizedBox(height: 6),
            _buildTimelineColorPicker(),
          ],
          if (widget.allCodes.length != widget.selectedCodes.length) ...[
            const SizedBox(height: 10),
            const _MiniLabel('Ribbon Countries'),
            const SizedBox(height: 6),
            _MiniRibbonSelector(
              selectedImage: _frontRibbonMode == 'selected'
                  ? _frontRibbonImage
                  : _frontRibbonAllImage,
              allImage: _frontRibbonMode == 'all'
                  ? _frontRibbonImage
                  : _frontRibbonAllImage,
              selectedCount: widget.selectedCodes.length,
              allCount: widget.allCodes.length,
              mode: _frontRibbonMode,
              onChanged: (v) {
                setState(() => _frontRibbonMode = v);
                _loadFrontRibbonImage();
              },
            ),
          ],
        ],
      ],
    );
  }

  // ── Mockup area ────────────────────────────────────────────────────────────

  Widget _buildMockupArea(ThemeData theme) {
    // During approving: show the animated "preparing" overlay over the shirt.
    if (_state == _MockupState.approving) {
      return _ApprovingView(
        shirt: _buildLocalMockupArea(theme),
        retryMessage: _retryMessage,
        isTshirt: _isTshirt,
      );
    }

    if (_state == _MockupState.ready) {
      final collageUrl = _mockupUrl;
      if (collageUrl != null) {
        // Show the Printful collage mockup (front + back in one image).
        return _MockupPageView(urls: [collageUrl], labels: const [], fallback: _buildLocalMockupArea(theme));
      }
      // Mockup not yet available — show local preview with a loading overlay
      // while Firestore polling waits for the server to complete generation.
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildLocalMockupArea(theme),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Generating photorealistic preview\u2026',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Pre-generation: local mockup is the preview.
    return _buildLocalMockupArea(theme);
  }

  Widget _buildLocalMockupArea(ThemeData theme, {bool? showFrontOverride}) {
    final artworkImage = _artworkImage;

    if (artworkImage == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget area;

    if (_isTshirt) {
      final showFront = showFrontOverride ?? _showingFront;
      final frontSpec = ProductMockupSpecs.specsFor(
        _product,
        colour: _colour,
        placement: 'front',
        frontPosition: _frontPosition,
      );
      final backSpec = ProductMockupSpecs.specsFor(
        _product,
        colour: _colour,
        placement: 'back',
      );

      // _ShirtFlipView owns AnimationController + GestureDetector + zoom (M58-03/05).
      // Colour change → wipe right-to-left (new shirt slides in from the right).
      area = AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, if (currentChild != null) currentChild],
        ),
        child: SizedBox.expand(
          key: ValueKey(_colour),
          child: _ShirtFlipView(
        key: ValueKey('${_flipViewKey}_$showFront'),
        frontArtwork: _frontPosition != 'none' ? _frontRibbonImage : null,
        backArtwork: _backPosition != 'none' ? artworkImage : null,
        frontShirt: _frontShirtImage,
        backShirt: _backShirtImage,
        frontSpec: frontSpec,
        backSpec: backSpec,
        showFront: showFront,
        onFlipped: _onFlipped,
        artworkBlendMode: _variantIsTransparent
            ? ui.BlendMode.srcOver
            : ui.BlendMode.multiply,
        onNextColour: () {
          final idx =
              (tshirtColors.indexOf(_colour) + 1) % tshirtColors.length;
          _onVariantOptionChanged(colour: tshirtColors[idx]);
        },
        onSwipeUp: null,
          ),
        ),
      );
    } else {
      // Poster: simple InteractiveViewer with edge-to-edge artwork.
      final spec = ProductMockupSpecs.specsFor(_product);
      area = InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: CustomPaint(
          painter: LocalMockupPainter(
            artworkImage: artworkImage,
            productImage: null,
            spec: spec,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    // Stamp variant loading / indicator overlay.
    if (_isTshirt && (_variantLoading || _artworkVariantIndex > 0)) {
      area = Stack(
        fit: StackFit.expand,
        children: [
          area,
          if (_variantLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _kVariantLabels[_artworkVariantIndex],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Rerendering overlay.
    if (_state == _MockupState.rerendering) {
      area = Stack(
        fit: StackFit.expand,
        children: [
          area,
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return area;
  }

  // ── Stamp colour picker (M64) ──────────────────────────────────────────────

  Widget _buildStampColorPicker() {
    final disabled = _disabledStampColors(_colour);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Widget chip(PassportColorMode mode, String label, Color? swatch) {
      final isSelected = _passportColorMode == mode;
      final isDisabled = disabled.contains(mode);
      return GestureDetector(
        onTap: isDisabled ? null : () => unawaited(_setPassportColorMode(mode)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDisabled
                  ? onSurface.withValues(alpha: 0.1)
                  : isSelected
                      ? onSurface.withValues(alpha: 0.7)
                      : onSurface.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isSelected
                ? onSurface.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatch ?? Colors.transparent,
                  border: Border.all(
                    color: onSurface.withValues(alpha: isDisabled ? 0.15 : 0.3),
                  ),
                ),
                child: swatch == null
                    ? Icon(Icons.palette_outlined,
                        size: 8,
                        color: isDisabled
                            ? Colors.white24
                            : Colors.white70)
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDisabled
                      ? onSurface.withValues(alpha: 0.25)
                      : isSelected
                          ? onSurface.withValues(alpha: 0.9)
                          : onSurface.withValues(alpha: 0.55),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          chip(PassportColorMode.multicolor, 'Multicolor', null),
          const SizedBox(width: 8),
          chip(PassportColorMode.black, 'Black', const Color(0xFF1A1A1A)),
          const SizedBox(width: 8),
          chip(PassportColorMode.white, 'White', Colors.white),
        ],
      ),
    );
  }

  // ── Timeline text colour picker (M86) ─────────────────────────────────────

  Widget _buildTimelineColorPicker() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final currentColor = _timelineTextColor ?? Colors.white;

    Widget chip(Color color, String label) {
      final isSelected = currentColor == color;
      return GestureDetector(
        onTap: () => unawaited(_setTimelineTextColor(color)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? onSurface.withValues(alpha: 0.7)
                  : onSurface.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isSelected
                ? onSurface.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? onSurface.withValues(alpha: 0.9)
                      : onSurface.withValues(alpha: 0.55),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          chip(Colors.black, 'Black text'),
          const SizedBox(width: 8),
          chip(Colors.white, 'White text'),
        ],
      ),
    );
  }

  // ── Inline config panel (ADR-127 / M75) ────────────────────────────────────

  /// Always-visible t-shirt configuration panel below the mockup.
  ///
  /// Replaces _buildCompactStrip + _showOptionsSheet. All t-shirt options are
  /// inline — no modals, no hidden navigation, no duplicate controls.
  Widget _buildInlineConfigPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 380),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── View Front/Back Toggle ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('Product Options'),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showingFront = !_showingFront;
                    _flipViewKey++;
                  }),
                  icon: const Icon(Icons.flip, size: 18),
                  label: Text(_showingFront ? 'See Back' : 'See Front'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Colour ───────────────────────────────────────────────────
            const _SectionLabel('Colour'),
            const SizedBox(height: 4),
            _ColourSwatchRow(
              selected: _colour,
              onChanged: (c) => _onVariantOptionChanged(colour: c),
            ),
            
            // Passport/Timeline specific colour pickers
            if (_template == CardTemplateType.passport) ...[
              const SizedBox(height: 12),
              const _SectionLabel('Stamp Style'),
              _buildStampColorPicker(),
            ],
            if (_template == CardTemplateType.timeline) ...[
              const SizedBox(height: 12),
              const _SectionLabel('Text Colour'),
              _buildTimelineColorPicker(),
            ],

            const SizedBox(height: 16),

            // ── Size ──────────────────────────────────────────────────────
            const _SectionLabel('Size'),
            const SizedBox(height: 4),
            _SegmentedPicker(
              options: tshirtSizes,
              selected: _tshirtSize,
              onChanged: (v) => setState(() => _tshirtSize = v),
            ),
            const SizedBox(height: 16),

            // ── Front design ──────────────────────────────────────────────
            const _SectionLabel('Front Placement'),
            const SizedBox(height: 4),
            _SegmentedPicker(
              options: const ['Left', 'Center', 'Right', 'None'],
              selected: switch (_frontPosition) {
                'center'      => 'Center',
                'right_chest' => 'Right',
                'none'        => 'None',
                _             => 'Left',
              },
              onChanged: (v) => _onVariantOptionChanged(
                frontPosition: switch (v) {
                  'Center' => 'center',
                  'Right'  => 'right_chest',
                  'None'   => 'none',
                  _        => 'left_chest',
                },
              ),
            ),

            // ── Ribbon countries (conditional) ────────────────────────────
            if (widget.allCodes.length != widget.selectedCodes.length) ...[
              const SizedBox(height: 16),
              const _SectionLabel('Ribbon Countries'),
              const SizedBox(height: 4),
              _SegmentedPicker(
                options: const ['Selected', 'All'],
                selected:
                    _frontRibbonMode == 'all' ? 'All' : 'Selected',
                onChanged: (v) {
                  setState(() =>
                      _frontRibbonMode = v == 'All' ? 'all' : 'selected');
                  _loadFrontRibbonImage();
                },
              ),
            ],

            const SizedBox(height: 16),
            // ── Back design ───────────────────────────────────────────────
            const _SectionLabel('Back Placement'),
            const SizedBox(height: 4),
            _SegmentedPicker(
              options: const ['Center', 'None'],
              selected: _backPosition == 'none' ? 'None' : 'Center',
              onChanged: (v) => _onVariantOptionChanged(
                  backPosition: v == 'None' ? 'none' : 'center'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final theme = Theme.of(context);

    if (_state == _MockupState.ready) {
      final mockupReady = _mockupUrl != null || _mockupFailed;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mockupFailed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preview skipped due to connection \u2014 you can still proceed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: mockupReady ? _openConfirmationScreen : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                mockupReady ? 'Review & Checkout' : 'Loading Preview\u2026',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    final artworkReady = _artworkBytes != null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: artworkReady && _state == _MockupState.configuring
            ? _onApprove
            : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          _state == _MockupState.approving
              ? 'Preparing\u2026'
              : !artworkReady
                  ? 'Generating\u2026'
                  : 'Approve & Preview',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

}

// ── _ShirtFlipView (M58-03 / M58-05) ─────────────────────────────────────────

/// Displays the shirt mockup with a 2.5D card-flip animation.
///
/// Owns an [AnimationController] (350 ms, easeInOut) driven by horizontal
/// swipe or tap. The [Matrix4.rotationY] transform with a small perspective
/// entry produces a convincing card-flip. The displayed face swaps at the
/// 90° midpoint so the reverse side appears naturally as the shirt comes around.
///
/// Also owns a [TransformationController] for pinch-to-zoom (M58-05). Zoom
/// is reset whenever [key] changes (parent bumps [ValueKey(_flipViewKey)]).
class _ShirtFlipView extends StatefulWidget {
  const _ShirtFlipView({
    super.key,
    required this.frontArtwork,
    required this.backArtwork,
    required this.frontShirt,
    required this.backShirt,
    required this.frontSpec,
    required this.backSpec,
    required this.showFront,
    required this.onFlipped,
    required this.artworkBlendMode,
    this.onNextColour,
    this.onSwipeUp,
  });

  final ui.Image? frontArtwork;
  final ui.Image? backArtwork;
  final ui.Image? frontShirt;
  final ui.Image? backShirt;
  final ProductMockupSpec frontSpec;
  final ProductMockupSpec backSpec;
  final bool showFront;
  final ValueChanged<bool> onFlipped;

  /// Blend mode for the artwork layer (multiply for opaque, srcOver for
  /// transparent-background renders).
  final ui.BlendMode artworkBlendMode;

  /// Called when the user swipes right-to-left to advance to the next colour.
  final VoidCallback? onNextColour;

  /// Called when the user swipes up to cycle stamp colour variants.
  final VoidCallback? onSwipeUp;

  @override
  State<_ShirtFlipView> createState() => _ShirtFlipViewState();
}

class _ShirtFlipViewState extends State<_ShirtFlipView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final TransformationController _transformationController;

  // true = showing front face; flips at the 90° midpoint.
  late bool _showingFront;

  // Accumulates drag distance to determine gesture direction.
  double _dragStart = 0;
  double _verticalDragStart = 0;

  static const double _kSwipeThreshold = 40.0;
  static const Duration _kFlipDuration = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _showingFront = widget.showFront;
    _controller = AnimationController(vsync: this, duration: _kFlipDuration);
    _transformationController = TransformationController();
    _controller.addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    // Swap the displayed face at the 90° midpoint.
    final atMidpoint = _controller.value >= 0.5;
    final wantFront = _flipDirection > 0
        ? !atMidpoint  // swiping to back: start front, flip to back
        : atMidpoint;  // swiping to front: start back, flip to front
    if (wantFront != _showingFront) {
      setState(() => _showingFront = wantFront);
    }
  }

  // +1 = flipping front→back (swipe left), -1 = flipping back→front (swipe right)
  int _flipDirection = 1;

  void _flipTo(bool goToFront) {
    if (_controller.isAnimating) return;
    _flipDirection = goToFront ? -1 : 1;
    _controller.forward(from: 0).then((_) {
      if (!mounted) return;
      // Do NOT reset _controller.value here. Resetting to 0 would re-trigger
      // _onAnimationTick at value=0, which snaps _showingFront back to the
      // pre-flip state. The controller stays at 1.0; the next forward(from: 0)
      // restarts cleanly from 0 with the new _flipDirection already set.
      widget.onFlipped(_showingFront);
    });
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    _dragStart = d.localPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final delta = d.localPosition.dx - _dragStart;
    if (delta.abs() < _kSwipeThreshold) return;
    if (delta < 0) {
      // Right-to-left swipe: advance to next t-shirt colour.
      widget.onNextColour?.call();
    } else {
      // Left-to-right swipe: flip to show the front.
      if (_showingFront) return;
      _flipTo(true);
    }
  }

  void _onVerticalDragStart(DragStartDetails d) {
    _verticalDragStart = d.localPosition.dy;
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final delta = d.localPosition.dy - _verticalDragStart;
    if (delta < -_kSwipeThreshold) {
      // Upward swipe: cycle stamp colour variant.
      widget.onSwipeUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragEnd: _onVerticalDragEnd,
      onDoubleTap: () => _transformationController.value = Matrix4.identity(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 3.14159265358979;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle * _flipDirection);
          return Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          child: _buildCurrentFace(),
        ),
      ),
    );
  }

  Widget _buildCurrentFace() {
    final shirt = _showingFront ? widget.frontShirt : widget.backShirt;
    final spec = _showingFront ? widget.frontSpec : widget.backSpec;
    // Artwork is only shown on the face that matches the placement button.
    // Swiping to peek at the other side shows a blank shirt (no artwork pasted
    // on whichever face happens to be animating).
    final artwork = (_showingFront == widget.showFront)
        ? (widget.showFront ? widget.frontArtwork : widget.backArtwork)
        : null;

    // The front ribbon is always rendered on a transparent canvas (no
    // background fill in _RibbonPainter), so it must always composite with
    // srcOver. The back card varies — use the caller-supplied blend mode.
    final blendMode = _showingFront
        ? ui.BlendMode.srcOver
        : widget.artworkBlendMode;

    return CustomPaint(
      painter: LocalMockupPainter(
        artworkImage: artwork,
        productImage: shirt,
        spec: spec,
        artworkBlendMode: blendMode,
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ── Approving overlay ─────────────────────────────────────────────────────────

/// Full-area overlay shown while the Firebase Function processes the order.
/// Keeps the local shirt visible at low opacity so the user retains context of
/// what they approved, while a pulsing animation + copy reassures them.
class _ApprovingView extends StatefulWidget {
  const _ApprovingView({
    required this.shirt,
    required this.isTshirt,
    this.retryMessage,
  });
  final Widget shirt;
  final bool isTshirt;

  /// Non-null when a retry is in progress; overrides the subtitle copy.
  final String? retryMessage;

  @override
  State<_ApprovingView> createState() => _ApprovingViewState();
}

class _ApprovingViewState extends State<_ApprovingView>
    with TickerProviderStateMixin {
  late final AnimationController _swingCtrl;
  late final Animation<double> _swing;

  // Simulated progress: 0 → 0.9 over 25 s (easeOut), stalls at 90 % until the
  // API responds and the overlay is removed. Resets to 0 on each retry.
  late AnimationController _progressCtrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _swingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _swing = Tween<double>(begin: -0.033, end: 0.033).animate(
      CurvedAnimation(parent: _swingCtrl, curve: Curves.easeInOut),
    );
    _startProgress();
  }

  void _startProgress() {
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    );
    _progress = Tween<double>(begin: 0.0, end: 0.9).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut),
    );
    _progressCtrl.forward();
  }

  @override
  void didUpdateWidget(_ApprovingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the progress bar at the start of each retry attempt.
    if (oldWidget.retryMessage == null && widget.retryMessage != null) {
      _progressCtrl.dispose();
      _startProgress();
    }
  }

  @override
  void dispose() {
    _swingCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dimmed shirt — keeps context of what was approved.
        Opacity(opacity: 0.3, child: widget.shirt),
        // Steady semi-transparent scrim.
        ColoredBox(
          color: theme.colorScheme.surface.withValues(alpha: 0.60),
        ),
        // Icon + copy centred over the shirt.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coat-hanger icon swinging on a rail.
              RotationTransition(
                turns: _swing,
                child: Icon(
                  Icons.checkroom_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Creating your mockup\u2026',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Simulated progress bar — fills to ~90 % over 25 s, then stalls
              // until the API responds. Resets to 0 on each retry.
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => LinearProgressIndicator(
                  value: _progress.value,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.retryMessage != null)
                Text(
                  widget.retryMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    height: 1.5,
                  ),
                )
              else ...[
                Text(
                  'This usually takes about 20 seconds.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please stay on this screen while\nwe prepare your preview.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Colour swatch row (M58-04) ────────────────────────────────────────────────

class _ColourSwatchRow extends StatelessWidget {
  const _ColourSwatchRow({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kSwatchColours.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.value,
                  border: isSelected
                      ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                      : Border.all(
                          color: Colors.transparent,
                          width: 2,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entry.value.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white70,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

// ── Mini label (compact section header) ──────────────────────────────────────

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── Segmented picker ──────────────────────────────────────────────────────────

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 6 : 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(opt, style: TextStyle(fontSize: compact ? 12 : 14)),
          selected: isSelected,
          onSelected: (_) => onChanged(opt),
          selectedColor: theme.colorScheme.primaryContainer,
          padding: compact ? const EdgeInsets.symmetric(horizontal: 4) : null,
          visualDensity: compact ? VisualDensity.compact : null,
        );
      }).toList(),
    );
  }
}

/// Swipeable front/back Printful mockup viewer.
/// Shows [urls] as pages with a label pill (e.g. "Front" / "Back") and dot
/// indicators. Pinch-to-zoom works per page.
class _MockupPageView extends StatefulWidget {
  const _MockupPageView({
    required this.urls,
    required this.labels,
    required this.fallback,
  });

  final List<String> urls;
  final List<String> labels;
  final Widget fallback;

  @override
  State<_MockupPageView> createState() => _MockupPageViewState();
}

class _MockupPageViewState extends State<_MockupPageView> {
  int _page = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Image.network(
                widget.urls[i],
                key: ValueKey(widget.urls[i]),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return widget.fallback;
                },
                errorBuilder: (context, error, stack) => widget.fallback,
              ),
            );
          },
        ),
        // Label pill (e.g. "Front" / "Back")
        if (widget.labels.isNotEmpty)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.labels[_page],
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        // Dot indicators (only when more than one page)
        if (widget.urls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 8 : 6,
                  height: _page == i ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _page == i ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ── Visual placement selector ─────────────────────────────────────────────────

/// Immutable data for a single placement option.
@immutable

class _PlacementOptionData {
  const _PlacementOptionData(this.value, this.label);
  final String value;
  final String label;
}

/// A row of mini actual shirt mockups, each showing the ribbon at a placement.
///
/// Passes [shirtImage] + [artworkImage] + per-placement [ProductMockupSpec]
/// to [LocalMockupPainter] so the tiles are pixel-accurate mini previews.
class _PlacementSelector extends StatelessWidget {
  const _PlacementSelector({
    required this.options,
    required this.selected,
    required this.isFront,
    required this.colour,
    required this.product,
    required this.onChanged,
    this.shirtImage,
    this.artworkImage,
  });

  final List<_PlacementOptionData> options;
  final String selected;
  final bool isFront;
  final String colour;
  final MerchProduct product;
  final ui.Image? shirtImage;
  final ui.Image? artworkImage;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _PlacementTile(
              option: options[i],
              isSelected: options[i].value == selected,
              isFront: isFront,
              colour: colour,
              product: product,
              shirtImage: shirtImage,
              artworkImage: options[i].value == 'none' ? null : artworkImage,
              onTap: () => onChanged(options[i].value),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _PlacementTile extends StatelessWidget {
  const _PlacementTile({
    required this.option,
    required this.isSelected,
    required this.isFront,
    required this.colour,
    required this.product,
    required this.onTap,
    this.shirtImage,
    this.artworkImage,
  });

  final _PlacementOptionData option;
  final bool isSelected;
  final bool isFront;
  final String colour;
  final MerchProduct product;
  final ui.Image? shirtImage;
  final ui.Image? artworkImage;
  final VoidCallback onTap;

  ProductMockupSpec _spec() {
    if (isFront) {
      return ProductMockupSpecs.specsFor(
        product,
        colour: colour,
        placement: 'front',
        frontPosition: option.value == 'none' ? 'left_chest' : option.value,
      );
    }
    return ProductMockupSpecs.specsFor(product, colour: colour, placement: 'back');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _spec();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: CustomPaint(
                  painter: LocalMockupPainter(
                    artworkImage: artworkImage,
                    productImage: shirtImage,
                    spec: spec,
                    artworkBlendMode: ui.BlendMode.srcOver,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
              fontSize: 9,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
            child: Text(option.label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ── Mini ribbon country selector ───────────────────────────────────────────────

/// Shows two tappable mini ribbon card previews for the "Ribbon Countries"
/// option — one for selected codes, one for all codes.
///
/// Each tile renders the [ui.Image] (already-rendered FrontRibbonCard PNG)
/// cropped to show just the ribbon artwork.
class _MiniRibbonSelector extends StatelessWidget {
  const _MiniRibbonSelector({
    required this.selectedImage,
    required this.allImage,
    required this.selectedCount,
    required this.allCount,
    required this.mode,
    required this.onChanged,
  });

  final ui.Image? selectedImage;
  final ui.Image? allImage;
  final int selectedCount;
  final int allCount;
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniRibbonTile(
            image: selectedImage,
            label: '$selectedCount countries',
            sublabel: 'Selected',
            isSelected: mode == 'selected',
            onTap: () => onChanged('selected'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniRibbonTile(
            image: allImage,
            label: '$allCount countries',
            sublabel: 'All',
            isSelected: mode == 'all',
            onTap: () => onChanged('all'),
          ),
        ),
      ],
    );
  }
}

class _MiniRibbonTile extends StatelessWidget {
  const _MiniRibbonTile({
    required this.image,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  final ui.Image? image;
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.07)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ribbon artwork preview (show the card image directly).
            SizedBox(
              height: 40,
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: RawImage(
                        image: image,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
