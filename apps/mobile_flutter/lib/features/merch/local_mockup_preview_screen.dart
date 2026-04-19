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
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../cards/artwork_confirmation_service.dart';
import '../cards/card_image_renderer.dart';
import 'local_mockup_image_cache.dart';
import 'local_mockup_painter.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_stamp_color.dart';
import 'merch_variant_lookup.dart';
import 'mockup_approval_service.dart';
import 'product_mockup_specs.dart';

// ── State enum ────────────────────────────────────────────────────────────────

enum _MockupState { configuring, rerendering, approving, ready }

/// Which Printful mockup URLs are available after generation completes.
enum _PrintfulMockupStatus { pending, frontOnly, backOnly, both, neither }

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
  });

  final List<String> selectedCodes;
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
  String _placement = 'front';

  // ── Card / artwork state ───────────────────────────────────────────────────

  late CardTemplateType _template;
  late Uint8List _artworkBytes;
  String? _artworkConfirmationId;
  bool _templateChanged = false;

  // ── Decoded images ─────────────────────────────────────────────────────────

  ui.Image? _artworkImage;
  ui.Image? _frontShirtImage;
  ui.Image? _backShirtImage;
  ui.Image? _frontRibbonImage;
  Uint8List? _frontRibbonBytes;

  // ── Screen state machine ───────────────────────────────────────────────────

  _MockupState _state = _MockupState.configuring;

  // ── Ready-state checkout data ──────────────────────────────────────────────

  String? _checkoutUrl;
  String? _frontMockupUrl;
  String? _backMockupUrl;
  bool _showingFront = true;
  String? _merchConfigId;
  bool _checkoutLaunched = false;

  // ── Flip view key — replaced to reset zoom when colour/placement changes ──

  int _flipViewKey = 0;

  // ── Passport stamp colour mode (M64) ──────────────────────────────────────

  PassportColorMode _passportColorMode = PassportColorMode.black;

  // ── Artwork stamp variants ─────────────────────────────────────────────────
  // 0 = original (widget.stampColor), 1 = black stamps, 2 = white/transparent

  final List<Uint8List?> _artworkVariants = List.filled(3, null);
  int _artworkVariantIndex = 0;
  bool _variantLoading = false;

  // ── Poll parameters ────────────────────────────────────────────────────────

  static const int _pollIntervalSeconds = 3;
  static const int _pollMaxAttempts = 10;

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
    _passportColorMode = _suggestStampColor(_colour);

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
    final isDark = _colour == 'Black' || _colour == 'Navy' || _colour == 'Red';
    final textColor = isDark ? Colors.white : Colors.black;

    try {
      final result = await CardImageRenderer.render(
        context,
        CardTemplateType.frontRibbon,
        codes: widget.selectedCodes,
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

  // ── Template change handler ────────────────────────────────────────────────

  Future<void> _onTemplateChanged(CardTemplateType newTemplate) async {
    if (newTemplate == _template) return;
    setState(() {
      _state = _MockupState.rerendering;
      _templateChanged = true;
    });

    try {
      if (!context.mounted) return;
      final result = await CardImageRenderer.render(
        context,
        newTemplate,
        codes: widget.selectedCodes,
        trips: widget.trips,
        forPrint: newTemplate == CardTemplateType.passport,
        entryOnly: widget.confirmedEntryOnly,
        cardAspectRatio: widget.confirmedAspectRatio,
        titleOverride: widget.titleOverride,
        stampColor: widget.stampColor,
        dateColor: widget.dateColor,
        transparentBackground: widget.transparentBackground,
      );
      if (!mounted) return;
      final newBytes = result.bytes;
      await _decodeArtwork(newBytes);
      if (!mounted) return;
      setState(() {
        _template = newTemplate;
        _artworkBytes = newBytes;
        _artworkConfirmationId = null;
        _state = _MockupState.configuring;
        // Reset artwork variants — new template needs fresh renders.
        _artworkVariants[0] = newBytes;
        _artworkVariants[1] = null;
        _artworkVariants[2] = null;
        _artworkVariantIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Couldn't re-render design, using previous version")),
      );
      setState(() {
        _template = newTemplate;
        _state = _MockupState.configuring;
      });
    }
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
        forPrint: _template == CardTemplateType.passport,
        // T-shirts always show entry + exit stamps regardless of card-editor setting.
        entryOnly: _isTshirt ? false : widget.confirmedEntryOnly,
        cardAspectRatio: widget.confirmedAspectRatio,
        titleOverride: widget.titleOverride,
        stampColor: stampColor,
        dateColor: widget.dateColor,
        transparentBackground: transparentBg,
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

  // ── Colour / placement change handler ─────────────────────────────────────

  void _onVariantOptionChanged({
    String? colour,
    String? placement,
    MerchProduct? product,
  }) {
    final colourChanged = colour != null && colour != _colour;
    final placementChanged = placement != null && placement != _placement;
    final productChanged = product != null && product != _product;
    setState(() {
      if (product != null) _product = product;
      if (colour != null) _colour = colour;
      if (placement != null) _placement = placement;
      // Reset flip view whenever shirt variant or placement changes.
      if (colourChanged || productChanged || placementChanged) _flipViewKey++;
    });
    if (colourChanged || productChanged) {
      _loadShirtImages();
      _loadFrontRibbonImage();
    }
    if (colourChanged && _isTshirt && _template == CardTemplateType.passport) {
      // colour is non-null: colourChanged = colour != null && colour != _colour
      unawaited(_setPassportColorMode(_suggestStampColor(colour)));
    }
  }

  void _onFlipped(bool showFront) {
    setState(() => _showingFront = showFront);
  }

  // ── Approval handler ───────────────────────────────────────────────────────

  Future<void> _onApprove() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue')),
      );
      return;
    }

    setState(() => _state = _MockupState.approving);

    try {
      String? confirmationId = _artworkConfirmationId;
      if (confirmationId == null) {
        final imageHash = sha256.convert(_artworkBytes).toString();
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
          unawaited(ArtworkConfirmationService(FirebaseFirestore.instance)
              .archive(uid, priorConfirmationId));
        }

        confirmationId = await ArtworkConfirmationService(
                FirebaseFirestore.instance)
            .create(newConfirmation);

        if (!mounted) return;
        setState(() => _artworkConfirmationId = confirmationId);
      }

      final approvalId = 'ma-${DateTime.now().microsecondsSinceEpoch}';
      final approval = MockupApproval(
        mockupApprovalId: approvalId,
        userId: uid,
        artworkConfirmationId: confirmationId,
        templateType: _template,
        variantId: _resolvedVariantGid,
        placementType: _isTshirt ? _placement : null,
        confirmedAt: DateTime.now().toUtc(),
      );
      await MockupApprovalService(FirebaseFirestore.instance).create(approval);

      if (!mounted) return;

      final callable =
          FirebaseFunctions.instance.httpsCallable('createMerchCart');
      final result = await callable.call<Map<String, dynamic>>({
        'variantId': _resolvedVariantGid,
        'selectedCountryCodes': widget.selectedCodes,
        'quantity': 1,
        if (widget.cardId != null) 'cardId': widget.cardId,
        'artworkConfirmationId': confirmationId,
        'mockupApprovalId': approvalId,
        'backImageBase64': base64Encode(_artworkBytes),
        if (_isTshirt && _frontRibbonBytes != null)
          'frontImageBase64': base64Encode(_frontRibbonBytes!),
      });

      final checkoutUrl = result.data['checkoutUrl'] as String?;
      final frontMockupUrl = result.data['frontMockupUrl'] as String?;
      final backMockupUrl = result.data['backMockupUrl'] as String?;
      final merchConfigId = result.data['merchConfigId'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      if (!mounted) return;
      setState(() {
        _state = _MockupState.ready;
        _frontMockupUrl = frontMockupUrl;
        _backMockupUrl = backMockupUrl;
        _checkoutUrl = checkoutUrl;
        _merchConfigId = merchConfigId;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'unavailable'
                ? 'An internet connection is required.'
                : e.message ?? 'An error occurred. Please try again.',
          ),
        ),
      );
      setState(() => _state = _MockupState.configuring);
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      setState(() => _state = _MockupState.configuring);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
      setState(() => _state = _MockupState.configuring);
    }
  }

  Future<void> _completeCheckout() async {
    final url = _checkoutUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open checkout')),
      );
      return;
    }
    _checkoutLaunched = true;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Design your ${_isTshirt ? 'T-Shirt' : 'Poster'}'),
      ),
      body: Column(
        children: [
          // ── Mockup canvas (fills available space) ────────────────────────
          Expanded(
            child: _buildMockupArea(theme),
          ),

          // ── Inline re-confirmation banner ────────────────────────────────
          if (_templateChanged && _state == _MockupState.configuring)
            _InlineReconfirmationBanner(),

          // ── Compact bottom strip (M58-02) ────────────────────────────────
          if (_state != _MockupState.ready && _isTshirt)
            _buildCompactStrip(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildBottomBar(),
        ),
      ),
    );
  }

  // ── Printful mockup status ─────────────────────────────────────────────────

  _PrintfulMockupStatus get _printfulStatus {
    if (_state != _MockupState.ready) return _PrintfulMockupStatus.pending;
    final hasFront = _frontMockupUrl != null;
    final hasBack = _backMockupUrl != null;
    if (hasFront && hasBack) return _PrintfulMockupStatus.both;
    if (hasFront) return _PrintfulMockupStatus.frontOnly;
    if (hasBack) return _PrintfulMockupStatus.backOnly;
    return _PrintfulMockupStatus.neither;
  }

  // ── Mockup area ────────────────────────────────────────────────────────────

  Widget _buildMockupArea(ThemeData theme) {
    // During approving: show the animated "preparing" overlay over the shirt.
    if (_state == _MockupState.approving) {
      return _ApprovingView(shirt: _buildLocalMockupArea(theme));
    }

    final isReady = _state == _MockupState.ready;
    final activeMockupUrl = _showingFront ? _frontMockupUrl : _backMockupUrl;

    if (isReady && activeMockupUrl != null) {
      // ready state: Printful photorealistic mockup.
      return Image.network(
        activeMockupUrl,
        key: ValueKey(activeMockupUrl),
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLocalMockupArea(theme);
        },
        errorBuilder: (context, error, stack) =>
            _buildLocalMockupArea(theme),
      );
    }

    final status = _printfulStatus;
    if (status != _PrintfulMockupStatus.pending) {
      final url = _showingFront ? _frontMockupUrl : _backMockupUrl;

      if (url != null) {
        // Printful mockup available for this face — show with pinch-to-zoom.
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildLocalMockupArea(theme,
                  showFrontOverride: _showingFront);
            },
            errorBuilder: (context, error, stack) =>
                _buildPrintfulUnavailableBanner(_showingFront),
          ),
        );
      }

      // Printful generation completed but this face's URL is missing.
      return _buildPrintfulUnavailableBanner(_showingFront);
    }

    // Pre-generation: local mockup is the preview.
    return _buildLocalMockupArea(theme);
  }

  /// Shown when Printful generation completed but the URL for [isFront] is null
  /// or failed to load. Explicit signal — never silently shows local mockup.
  Widget _buildPrintfulUnavailableBanner(bool isFront) {
    final face = isFront ? 'Front' : 'Back';
    return Container(
      color: const Color(0xFFF2F2F2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 40, color: Color(0xFF9E9E9E)),
            const SizedBox(height: 12),
            Text(
              '$face mockup unavailable',
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
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
      final showFront = showFrontOverride ?? (_placement == 'front');
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

      // _ShirtFlipView owns AnimationController + GestureDetector + zoom (M58-03/05).
      area = _ShirtFlipView(
        key: ValueKey('${_flipViewKey}_$showFront'),
        frontArtwork: _frontRibbonImage,
        backArtwork: artworkImage,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  // ── Compact strip (M58-02) ─────────────────────────────────────────────────

  /// Compact bottom strip with colour swatches + More options handle.
  Widget _buildCompactStrip(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Front/Back toggle chips (moved from options panel)
              _PlacementToggle(
                placement: _placement,
                onFront: () => _onVariantOptionChanged(placement: 'front'),
                onBack: () => _onVariantOptionChanged(placement: 'back'),
              ),
              const SizedBox(width: 12),
              // Colour swatches (M58-04)
              Expanded(
                child: _ColourSwatchRow(
                  selected: _colour,
                  onChanged: (c) => _onVariantOptionChanged(colour: c),
                ),
              ),
              const SizedBox(width: 8),
              // More options drag handle
              GestureDetector(
                onTap: () => _showOptionsSheet(theme),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                      Text(
                        'More',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isTshirt && _template == CardTemplateType.passport) ...[
            const SizedBox(height: 4),
            _buildStampColorPicker(),
          ],
        ],
      ),
    );
  }

  // ── Options bottom sheet (M58-02) ──────────────────────────────────────────

  void _showOptionsSheet(ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _SectionLabel('Product'),
            _SegmentedPicker(
              options: const ['T-Shirt', 'Poster'],
              selected: _isTshirt ? 'T-Shirt' : 'Poster',
              onChanged: (v) {
                Navigator.of(ctx).pop();
                _onVariantOptionChanged(
                  product:
                      v == 'T-Shirt' ? MerchProduct.tshirt : MerchProduct.poster,
                );
              },
            ),
            const SizedBox(height: 12),
            _SectionLabel('Card design'),
            _SegmentedPicker(
              options: const ['Grid', 'Heart', 'Passport', 'Timeline'],
              selected: _templateLabel(_template),
              onChanged: (v) {
                Navigator.of(ctx).pop();
                _onTemplateChanged(_templateFromLabel(v));
              },
            ),
            if (_isTshirt) ...[
              const SizedBox(height: 12),
              _SectionLabel('Colour'),
              _ColourSwatchRow(
                selected: _colour,
                onChanged: (c) => setState(() {
                  final changed = c != _colour;
                  _colour = c;
                  if (changed) {
                    _flipViewKey++;
                    _loadShirtImages();
                  }
                }),
              ),
              const SizedBox(height: 12),
              _SectionLabel('Size'),
              _SegmentedPicker(
                options: tshirtSizes,
                selected: _tshirtSize,
                onChanged: (v) => setState(() => _tshirtSize = v),
              ),
              const SizedBox(height: 12),
              _SectionLabel('Placement'),
              _SegmentedPicker(
                options: const ['Front', 'Back'],
                selected: _placement == 'front' ? 'Front' : 'Back',
                onChanged: (v) {
                  Navigator.of(ctx).pop();
                  _onVariantOptionChanged(placement: v.toLowerCase());
                },
              ),
            ] else ...[
              const SizedBox(height: 12),
              _SectionLabel('Paper'),
              _SegmentedPicker(
                options: posterPapers,
                selected: _posterPaper,
                onChanged: (v) => setState(() => _posterPaper = v),
              ),
              const SizedBox(height: 12),
              _SectionLabel('Size'),
              _SegmentedPicker(
                options: posterSizes,
                selected: _posterSize,
                onChanged: (v) => setState(() => _posterSize = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    if (_state == _MockupState.ready) {
      // Show toggle whenever we have a front Printful mockup — back uses the
      // local flip-view (Printful back URL is a front-facing image, design invisible).
      final hasBothMockups = _isTshirt && _frontMockupUrl != null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBothMockups) ...[
            _PlacementToggle(
              placement: _showingFront ? 'front' : 'back',
              onFront: () => setState(() => _showingFront = true),
              onBack: () => setState(() => _showingFront = false),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _completeCheckout,
                  child: const Text('Complete order →'),
                ),
              ),
            ],
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
                  : (_templateChanged
                      ? 'Confirm updated design'
                      : 'Approve this order'),
            ),
          ),
        ),
      ],
    );
  }

  static String _templateLabel(CardTemplateType t) => switch (t) {
        CardTemplateType.grid => 'Grid',
        CardTemplateType.heart => 'Heart',
        CardTemplateType.passport => 'Passport',
        CardTemplateType.timeline => 'Timeline',
        CardTemplateType.frontRibbon => 'Front Ribbon',
      };

  static CardTemplateType _templateFromLabel(String label) => switch (label) {
        'Heart' => CardTemplateType.heart,
        'Passport' => CardTemplateType.passport,
        'Timeline' => CardTemplateType.timeline,
        _ => CardTemplateType.grid,
      };
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
  const _ApprovingView({required this.shirt});
  final Widget shirt;

  @override
  State<_ApprovingView> createState() => _ApprovingViewState();
}

class _ApprovingViewState extends State<_ApprovingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _swing;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Swing the hanger ±12° like it's sliding on a rail.
    _swing = Tween<double>(begin: -0.033, end: 0.033).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
                'Nearly there\u2026',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your t\u2011shirt design will be\nconfirmed shortly.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Placement toggle ──────────────────────────────────────────────────────────

class _PlacementToggle extends StatelessWidget {
  const _PlacementToggle({
    required this.placement,
    required this.onFront,
    required this.onBack,
  });

  final String placement;
  final VoidCallback onFront;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            label: 'Front',
            selected: placement == 'front',
            onTap: onFront,
          ),
          _ToggleOption(
            label: 'Back',
            selected: placement == 'back',
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
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

// ── Inline re-confirmation banner ─────────────────────────────────────────────

class _InlineReconfirmationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Design changed — please confirm this is correct before ordering',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
