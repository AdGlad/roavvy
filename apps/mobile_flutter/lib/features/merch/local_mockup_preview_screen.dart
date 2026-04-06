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
import 'merch_variant_lookup.dart';
import 'mockup_approval_service.dart';
import 'product_mockup_specs.dart';

// ── State enum ────────────────────────────────────────────────────────────────

enum _MockupState { configuring, rerendering, approving, ready }

// ── Colour swatch constants (M58-04) ─────────────────────────────────────────

const _kSwatchColours = <String, Color>{
  'Black':        Color(0xFF1A1A1A),
  'White':        Color(0xFFF5F5F5),
  'Navy':         Color(0xFF1A2C5B),
  'Heather Grey': Color(0xFFB0B0B0),
  'Red':          Color(0xFFCC1717),
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
    required this.artworkConfirmationId,
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
  final String artworkConfirmationId;
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

  // ── Screen state machine ───────────────────────────────────────────────────

  _MockupState _state = _MockupState.configuring;

  // ── Ready-state checkout data ──────────────────────────────────────────────

  String? _checkoutUrl;
  String? _mockupUrl;
  String? _merchConfigId;
  bool _checkoutLaunched = false;

  // ── Flip view key — replaced to reset zoom when colour/placement changes ──

  int _flipViewKey = 0;

  // ── Poll parameters ────────────────────────────────────────────────────────

  static const int _pollIntervalSeconds = 3;
  static const int _pollMaxAttempts = 10;

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isTshirt => _product == MerchProduct.tshirt;

  String get _resolvedVariantGid => resolveVariantGid(
        product: _product,
        colour: _colour,
        size: _isTshirt ? _tshirtSize : _posterSize,
        paper: _posterPaper,
      );

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _artworkBytes = widget.artworkImageBytes;
    _artworkConfirmationId = widget.artworkConfirmationId;

    WidgetsBinding.instance.addObserver(this);

    _decodeArtwork(_artworkBytes);
    _loadShirtImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cache owns frontShirtImage/backShirtImage — let it dispose them.
    LocalMockupImageCache.instance.dispose();
    // Artwork image is decoded directly from bytes (not cached) — screen owns it.
    _artworkImage?.dispose();
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

    // Front and back specs share the same asset path for t-shirts (ADR-115).
    final spec = ProductMockupSpecs.specsFor(
      _product,
      colour: _colour,
      placement: 'front',
    );

    try {
      final image = await LocalMockupImageCache.instance.load(spec.assetPath);
      if (!mounted) return;
      setState(() {
        // Cache owns this image; both fields reference the same ui.Image.
        _frontShirtImage = image;
        _backShirtImage = image;
      });
    } catch (_) {
      // Non-fatal — painter handles null productImage gracefully.
    }
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
    if (colourChanged || productChanged) _loadShirtImages();
  }

  void _onFlipped(bool showFront) {
    setState(() {
      _placement = showFront ? 'front' : 'back';
      _flipViewKey++;
    });
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

        unawaited(ArtworkConfirmationService(FirebaseFirestore.instance)
            .archive(uid, widget.artworkConfirmationId));

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
        'clientCardBase64': base64Encode(_artworkBytes),
        if (_isTshirt) 'placement': _placement,
      });

      final checkoutUrl = result.data['checkoutUrl'] as String?;
      final mockupUrl = result.data['mockupUrl'] as String?;
      final merchConfigId = result.data['merchConfigId'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      if (!mounted) return;
      setState(() {
        _state = _MockupState.ready;
        _checkoutUrl = checkoutUrl;
        _mockupUrl = mockupUrl;
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

  // ── Mockup area ────────────────────────────────────────────────────────────

  Widget _buildMockupArea(ThemeData theme) {
    final isReady = _state == _MockupState.ready;

    if (isReady && _mockupUrl != null) {
      // ready state: Printful photorealistic mockup.
      return Image.network(
        _mockupUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLocalMockupArea(theme);
        },
        errorBuilder: (context, error, stack) =>
            _buildLocalMockupArea(theme),
      );
    }

    return _buildLocalMockupArea(theme);
  }

  Widget _buildLocalMockupArea(ThemeData theme) {
    final artworkImage = _artworkImage;

    if (artworkImage == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget area;

    if (_isTshirt) {
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
        key: ValueKey(_flipViewKey),
        frontArtwork: artworkImage,
        backArtwork: artworkImage,
        frontShirt: _frontShirtImage,
        backShirt: _backShirtImage,
        frontSpec: frontSpec,
        backSpec: backSpec,
        showFront: _placement == 'front',
        onFlipped: _onFlipped,
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
      child: Row(
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
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _completeCheckout,
              child: const Text('Complete order →'),
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
            child: _state == _MockupState.approving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _templateChanged
                        ? 'Confirm updated design'
                        : 'Approve this order',
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
  });

  final ui.Image? frontArtwork;
  final ui.Image? backArtwork;
  final ui.Image? frontShirt;
  final ui.Image? backShirt;
  final ProductMockupSpec frontSpec;
  final ProductMockupSpec backSpec;
  final bool showFront;
  final ValueChanged<bool> onFlipped;

  @override
  State<_ShirtFlipView> createState() => _ShirtFlipViewState();
}

class _ShirtFlipViewState extends State<_ShirtFlipView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final TransformationController _transformationController;

  // true = showing front face; flips at the 90° midpoint.
  late bool _showingFront;

  // Accumulates horizontal drag distance to determine flip direction.
  double _dragStart = 0;

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
      _controller.value = 0;
      widget.onFlipped(_showingFront);
    });
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    _dragStart = d.localPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final delta = d.localPosition.dx - _dragStart;
    if (delta.abs() < _kSwipeThreshold) return;
    // swipe right (delta > 0) → flip to back; swipe left → flip to front
    final goToFront = delta < 0;
    if (goToFront == _showingFront) return; // already on that face
    _flipTo(goToFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragEnd: _onHorizontalDragEnd,
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
    final artwork = _showingFront ? widget.frontArtwork : widget.backArtwork;
    final shirt = _showingFront ? widget.frontShirt : widget.backShirt;
    final spec = _showingFront ? widget.frontSpec : widget.backSpec;

    if (artwork == null) {
      return const SizedBox.expand();
    }

    return CustomPaint(
      painter: LocalMockupPainter(
        artworkImage: artwork,
        productImage: shirt,
        spec: spec,
      ),
      child: const SizedBox.expand(),
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
