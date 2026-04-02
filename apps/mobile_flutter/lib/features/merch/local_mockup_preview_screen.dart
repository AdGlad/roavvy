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

// ── Screen ────────────────────────────────────────────────────────────────────

/// Unified commerce screen: local product mockup, product configuration, and
/// checkout in a single screen (ADR-107 / M55).
///
/// Replaces the [MerchProductBrowserScreen] → [MerchVariantScreen] →
/// [MockupApprovalScreen] sequence.
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
  /// Forwarded to re-renders only when the template does not change; a template
  /// change always resets to entry+exit (false).
  final bool confirmedEntryOnly;

  /// Optional TravelCard ID — threaded through to createMerchCart for order
  /// traceability (ADR-093).
  final String? cardId;

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
  ui.Image? _productImage;

  // ── Screen state machine ───────────────────────────────────────────────────

  _MockupState _state = _MockupState.configuring;

  // ── Ready-state checkout data ──────────────────────────────────────────────

  String? _checkoutUrl;
  String? _mockupUrl;
  String? _merchConfigId;
  bool _checkoutLaunched = false;

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

    // Decode artwork bytes and pre-load the initial product image.
    _decodeArtwork(_artworkBytes);
    _loadProductImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalMockupImageCache.instance.dispose();
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

  Future<void> _loadProductImage() async {
    if (_product == MerchProduct.poster) {
      // Poster uses null productImage (edge-to-edge artwork).
      if (mounted) setState(() => _productImage = null);
      return;
    }
    final spec = ProductMockupSpecs.specsFor(
      _product,
      colour: _colour,
      placement: _placement,
    );
    try {
      final img = await LocalMockupImageCache.instance.load(spec.assetPath);
      if (mounted) setState(() => _productImage = img);
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
      // ADR-112: Pass forPrint for passport and preserve the confirmed aspect
      // ratio so the re-render dimensions match the originally approved image.
      // entryOnly is reset to false — a template change starts fresh.
      final result = await CardImageRenderer.render(
        context,
        newTemplate,
        codes: widget.selectedCodes,
        trips: widget.trips,
        forPrint: newTemplate == CardTemplateType.passport,
        entryOnly: false,
        cardAspectRatio: widget.confirmedAspectRatio,
      );
      if (!mounted) return;
      final newBytes = result.bytes;
      await _decodeArtwork(newBytes);
      if (!mounted) return;
      setState(() {
        _template = newTemplate;
        _artworkBytes = newBytes;
        _artworkConfirmationId = null; // stale — new confirmation needed
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
    setState(() {
      if (product != null) _product = product;
      if (colour != null) _colour = colour;
      if (placement != null) _placement = placement;
    });
    _loadProductImage();
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
      // If template changed inside this screen, create a new ArtworkConfirmation
      // (the prior one was for a different template — ADR-107 Decision 3).
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

        // Archive the original confirmation (fire-and-forget, ADR-106).
        // widget.artworkConfirmationId is the ID that was valid when the screen
        // opened; it has since been superseded by the template change.
        unawaited(ArtworkConfirmationService(FirebaseFirestore.instance)
            .archive(uid, widget.artworkConfirmationId));

        // Blocking write — must succeed before calling createMerchCart.
        confirmationId = await ArtworkConfirmationService(
                FirebaseFirestore.instance)
            .create(newConfirmation);

        if (!mounted) return;
        setState(() => _artworkConfirmationId = confirmationId);
      }

      // Write MockupApproval.
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

      // Call createMerchCart Firebase Function (one call per approval — ADR-107).
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
    final spec = _isTshirt
        ? ProductMockupSpecs.specsFor(_product,
            colour: _colour, placement: _placement)
        : ProductMockupSpecs.specsFor(_product);

    return Scaffold(
      appBar: AppBar(
        title: Text('Design your ${_isTshirt ? 'T-Shirt' : 'Poster'}'),
      ),
      body: Column(
        children: [
          // ── Mockup canvas ────────────────────────────────────────────────
          Expanded(
            child: _buildMockupCanvas(spec, theme),
          ),

          // ── Inline re-confirmation banner ────────────────────────────────
          if (_templateChanged && _state == _MockupState.configuring)
            _InlineReconfirmationBanner(),

          // ── Options panel ────────────────────────────────────────────────
          if (_state != _MockupState.ready)
            _buildOptionsPanel(theme)
          else
            const SizedBox.shrink(),
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

  Widget _buildMockupCanvas(ProductMockupSpec spec, ThemeData theme) {
    final artworkImage = _artworkImage;
    final isReady = _state == _MockupState.ready;

    if (isReady && _mockupUrl != null) {
      // ready state: Printful photorealistic mockup with local fallback.
      return Image.network(
        _mockupUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLocalMockup(artworkImage, spec, theme);
        },
        errorBuilder: (context, error, stack) =>
            _buildLocalMockup(artworkImage, spec, theme),
      );
    }

    return _buildLocalMockup(artworkImage, spec, theme);
  }

  Widget _buildLocalMockup(
      ui.Image? artworkImage, ProductMockupSpec spec, ThemeData theme) {
    if (artworkImage == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final painter = LocalMockupPainter(
      artworkImage: artworkImage,
      productImage: _isTshirt ? _productImage : null,
      spec: spec,
    );

    Widget canvas = CustomPaint(
      painter: painter,
      child: const SizedBox.expand(),
    );

    // Rerendering overlay.
    if (_state == _MockupState.rerendering) {
      canvas = Stack(
        fit: StackFit.expand,
        children: [
          canvas,
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return canvas;
  }

  Widget _buildOptionsPanel(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        shrinkWrap: true,
        children: [
          _SectionLabel('Product'),
          _SegmentedPicker(
            options: const ['T-Shirt', 'Poster'],
            selected: _isTshirt ? 'T-Shirt' : 'Poster',
            onChanged: (v) => _onVariantOptionChanged(
              product: v == 'T-Shirt' ? MerchProduct.tshirt : MerchProduct.poster,
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel('Card design'),
          _SegmentedPicker(
            options: const ['Grid', 'Heart', 'Passport', 'Timeline'],
            selected: _templateLabel(_template),
            onChanged: (v) => _onTemplateChanged(_templateFromLabel(v)),
          ),
          if (_isTshirt) ...[
            const SizedBox(height: 12),
            _SectionLabel('Colour'),
            _SegmentedPicker(
              options: tshirtColors,
              selected: _colour,
              onChanged: (v) => _onVariantOptionChanged(colour: v),
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
              onChanged: (v) =>
                  _onVariantOptionChanged(placement: v.toLowerCase()),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

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

// ── Segmented picker (same as MerchVariantScreen) ────────────────────────────

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
