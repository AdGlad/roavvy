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
import 'merch_order_confirmation_screen.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_stamp_color.dart';
import 'merch_variant_lookup.dart';
import 'mockup_approval_service.dart';
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
    required this.artworkImageBytes,
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
  });

  final List<String> selectedCodes;

  /// All-time country codes (not year-filtered). Used when the front ribbon
  /// mode is set to 'all countries' so the ribbon shows the user's full
  /// collection regardless of the card's year filter.
  final List<String> allCodes;

  final List<TripRecord> trips;
  final Uint8List artworkImageBytes;
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

  /// Passport layout params (ADR-133). Forwarded to CardImageRenderer so
  /// stamp-colour re-renders preserve the user's size/scatter/seed design.
  final double stampSizeMultiplier;
  final double stampJitterFactor;
  final int? stampLayoutSeed;

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
  late Uint8List _artworkBytes;
  String? _artworkConfirmationId;
  String? _mockupApprovalId;

  // ── Decoded images ─────────────────────────────────────────────────────────

  ui.Image? _artworkImage;
  ui.Image? _frontShirtImage;
  ui.Image? _backShirtImage;
  ui.Image? _frontRibbonImage;
  Uint8List? _frontRibbonBytes;

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

  // ── Poll parameters ────────────────────────────────────────────────────────

  static const int _pollIntervalSeconds = 3;
  static const int _pollMaxAttempts = 10;

  // ── Mockup generation parameters ───────────────────────────────────────────

  static const int _kMaxRetries = 1;
  // 30 s — function now returns after cart creation (~5–10 s); mockup is async.
  static const Duration _kCallTimeout = Duration(seconds: 30);
  // Mockup URL is written to Firestore by the server after cart creation.
  static const int _kMockupPollIntervalSeconds = 3;
  static const int _kMockupPollMaxAttempts = 20; // up to 60 s

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

  /// Suggests a timeline text colour based on shirt colour luminance.
  /// Dark shirts → white text; light shirts → black text.
  Color _suggestTimelineTextColor(String shirtColour) => switch (shirtColour) {
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
    _artworkBytes = widget.artworkImageBytes;
    _artworkConfirmationId = widget.artworkConfirmationId;
    _artworkVariants[0] = widget.artworkImageBytes;
    // T-shirts always composite artwork transparently onto fabric. If the
    // confirmed artwork was rendered with a background (transparentBackground=false),
    // the multicolor variant must be re-rendered with transparency. Clearing
    // slot 0 here forces _renderVariant(0) when the user picks multicolor,
    // which sets transparentBg = _isTshirt || ... = true.
    if (_isTshirt && !widget.transparentBackground) {
      _artworkVariants[0] = null;
    }
    _passportColorMode = _suggestStampColor(_colour);
    _timelineTextColor = _suggestTimelineTextColor(_colour);

    WidgetsBinding.instance.addObserver(this);

    _decodeArtwork(_artworkBytes);
    _loadShirtImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFrontRibbonImage();
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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cache owns frontShirtImage/backShirtImage — let it dispose them.
    LocalMockupImageCache.instance.dispose();
    // Artwork image is decoded directly from bytes (not cached) — screen owns it.
    _artworkImage?.dispose();
    _frontRibbonImage?.dispose();
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
    // For timeline cards use the user-selected text color so the front ribbon
    // matches the back card. For other templates auto-calculate from shirt color.
    final Color textColor;
    if (_template == CardTemplateType.timeline && _timelineTextColor != null) {
      textColor = _timelineTextColor!;
    } else {
      final isDark = _colour == 'Black' || _colour == 'Navy' || _colour == 'Red';
      textColor = isDark ? Colors.white : Colors.black;
    }
    // Use all-time codes when the user has selected 'all' ribbon mode.
    final ribbonCodes = _frontRibbonMode == 'all'
        ? widget.allCodes
        : widget.selectedCodes;

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

  // ── Mockup URL polling (post-approve) ─────────────────────────────────────

  /// Polls Firestore for front and back mockup URLs after [_onApprove] returns.
  /// The server generates mockups in the background and writes the URLs to the
  /// MerchConfig document once Printful completes — typically 10–30 s.
  Future<void> _startMockupPolling(String configId, String uid) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('merch_configs')
        .doc(configId);

    for (int attempt = 0; attempt < _kMockupPollMaxAttempts; attempt++) {
      await Future<void>.delayed(
          const Duration(seconds: _kMockupPollIntervalSeconds));
      if (!mounted) return;
      try {
        final snap = await docRef.get();
        final data = snap.data();
        final frontUrl = data?['frontMockupUrl'] as String?;
        final backUrl  = data?['backMockupUrl']  as String?;
        if (frontUrl != null && frontUrl.isNotEmpty) {
          debugPrint('[mockup] poll: mockups arrived on attempt $attempt (front=✓ back=${backUrl != null ? "✓" : "null"})');
          setState(() {
            _mockupUrl     = frontUrl;
            _backMockupUrl = backUrl;
          });
          return;
        }
      } catch (_) {
        // Network error — continue polling.
      }
    }
    debugPrint('[mockup] poll: mockupUrl did not arrive within ${_kMockupPollMaxAttempts * _kMockupPollIntervalSeconds}s');
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
      final (Color? stampColor, bool transparentBg) = switch (index) {
        1 => (const Color(0xFF000000), true),            // black stamps
        2 => (Colors.white, true),                       // white stamps (explicit)
        _ => (widget.stampColor, _isTshirt || widget.transparentBackground),  // multicolor
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
        cardAspectRatio: widget.confirmedAspectRatio,
        titleOverride: widget.titleOverride,
        stampColor: stampColor,
        dateColor: widget.dateColor,
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
        cardAspectRatio: widget.confirmedAspectRatio,
        titleOverride: widget.titleOverride,
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
  }

  // ── Upload helpers ─────────────────────────────────────────────────────────

  /// Downscales [pngBytes] to [maxWidth] pixels wide before upload.
  ///
  /// The server resizes to print dimensions (4500×5400) regardless, so sending
  /// full device-resolution PNG wastes bandwidth. Transparent PNG is preserved —
  /// no JPEG conversion. Reduces the back-artwork payload from ~1.7 MB base64
  /// to ~400 KB.
  static const int _kUploadMaxWidth = 600;

  Future<Uint8List> _resizeForUpload(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(
      pngBytes,
      targetWidth: _kUploadMaxWidth,
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
    debugPrint('[mockup]   artworkBytes=${_artworkBytes.length}B');
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
        final imageHash = sha256.convert(_artworkBytes).toString();
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
      final sendFrontImage = _isTshirt && _frontPosition != 'none' && _frontRibbonBytes != null;
      final sendBackImage  = _backPosition != 'none';
      // Resize images for upload — the server upscales to print dimensions anyway.
      // Reduces the back-artwork payload from ~1.7 MB to ~400 KB (transparent PNG preserved).
      final encSw = Stopwatch()..start();
      final uploadBackBytes  = sendBackImage  ? await _resizeForUpload(_artworkBytes)       : null;
      final uploadFrontBytes = sendFrontImage ? await _resizeForUpload(_frontRibbonBytes!)  : null;
      final backImageBase64  = uploadBackBytes  != null ? base64Encode(uploadBackBytes)  : null;
      final frontImageBase64 = uploadFrontBytes != null ? base64Encode(uploadFrontBytes) : null;
      encSw.stop();
      debugPrint('[mockup] step 3: calling createMerchCart (max retries: $_kMaxRetries)');
      debugPrint('[mockup]   resize+encode took ${encSw.elapsedMilliseconds}ms');
      debugPrint('[mockup]   sendFrontImage=$sendFrontImage raw=${_frontRibbonBytes?.length ?? 0}B → upload=${uploadFrontBytes?.length ?? 0}B b64=${frontImageBase64?.length ?? 0}B');
      debugPrint('[mockup]   sendBackImage=$sendBackImage raw=${_artworkBytes.length}B → upload=${uploadBackBytes?.length ?? 0}B b64=${backImageBase64?.length ?? 0}B');
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
                if (_isTshirt) 'frontPosition': _frontPosition,
                if (_isTshirt) 'backPosition':  _backPosition,
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
            unawaited(_startMockupPolling(merchConfigId, uid));
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

  void _openConfirmationScreen() {
    final url = _checkoutUrl;
    if (url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchOrderConfirmationScreen(
          frontMockupUrl:    _mockupUrl,
          backMockupUrl:     _backMockupUrl,
          frontArtworkBytes: _frontRibbonBytes,
          artworkBytes:      _artworkBytes,
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
      appBar: AppBar(
        title: Text('Design your ${_isTshirt ? 'T-Shirt' : 'Poster'}'),
      ),
      body: Column(
        children: [
          // ── Mockup canvas (fills available space) ────────────────────────
          Expanded(
            child: _buildMockupArea(theme),
          ),

          // ── Inline config panel (M75) ─────────────────────────────────
          if (_state != _MockupState.ready && _isTshirt)
            _buildInlineConfigPanel(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildBottomBar(),
        ),
      ),
    ),   // end Scaffold
    );   // end PopScope
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
      final frontUrl = _mockupUrl;
      final backUrl  = _backMockupUrl;
      if (frontUrl != null || backUrl != null) {
        // Show separate front / back Printful mockups with swipe navigation.
        // If only one side is available, show it without the page indicator.
        final urls = [
          if (frontUrl != null) frontUrl,
          if (backUrl  != null) backUrl,
        ];
        final labels = [
          if (frontUrl != null) 'Front',
          if (backUrl  != null) 'Back',
        ];
        return _MockupPageView(urls: urls, labels: labels, fallback: _buildLocalMockupArea(theme));
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
      area = _ShirtFlipView(
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
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Passport: stamp colour is the only adjustable image param ─
            // T-shirt colour/size/placement controls are still shown so the
            // user can choose the garment they want; only card re-renders are
            // locked to the original design (ADR-133).
            if (_template == CardTemplateType.passport) ...[
              _buildStampColorPicker(),
              const SizedBox(height: 12),
            ],

            // ── Colour + Flip ─────────────────────────────────────────────
            Row(
              children: [
                Text('Colour', style: theme.textTheme.labelLarge),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showingFront = !_showingFront;
                    _flipViewKey++;
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flip,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _showingFront ? 'View back' : 'View front',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ColourSwatchRow(
              selected: _colour,
              onChanged: (c) => _onVariantOptionChanged(colour: c),
            ),
            // Non-passport stamp/timeline colour pickers
            if (_template != CardTemplateType.passport &&
                _template == CardTemplateType.timeline)
              _buildTimelineColorPicker(),
            const SizedBox(height: 12),

            // ── Size ──────────────────────────────────────────────────────
            const _SectionLabel('Size'),
            _SegmentedPicker(
              options: tshirtSizes,
              selected: _tshirtSize,
              onChanged: (v) => setState(() => _tshirtSize = v),
            ),
            const SizedBox(height: 12),

            // ── Front design ──────────────────────────────────────────────
            const _SectionLabel('Front design'),
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
              const SizedBox(height: 12),
              const _SectionLabel('Ribbon countries'),
              _SegmentedPicker(
                options: const ['Year selection', 'All time'],
                selected:
                    _frontRibbonMode == 'all' ? 'All time' : 'Year selection',
                onChanged: (v) {
                  setState(() =>
                      _frontRibbonMode = v == 'All time' ? 'all' : 'selected');
                  _loadFrontRibbonImage();
                },
              ),
            ],

            const SizedBox(height: 12),
            // ── Back design ───────────────────────────────────────────────
            const _SectionLabel('Back design'),
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
    if (_state == _MockupState.ready) {
      final mockupReady = _mockupUrl != null;
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: mockupReady ? _openConfirmationScreen : null,
              child: Text(mockupReady ? 'Review & Checkout' : 'Loading preview…'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Edit card design'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _state == _MockupState.configuring ? _onApprove : null,
            child: Text(
              _state == _MockupState.approving
                  ? 'Preparing your order\u2026'
                  : 'Approve this order',
            ),
          ),
        ),
      ],
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
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
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

// ── Segmented picker ──────────────────────────────────────────────────────────

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (_) => onChanged(opt),
          selectedColor: theme.colorScheme.primaryContainer,
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
