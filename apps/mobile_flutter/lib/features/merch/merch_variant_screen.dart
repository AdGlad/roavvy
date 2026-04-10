import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cards/card_image_renderer.dart';
import 'flag_grid_preview.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_variant_lookup.dart';
import 'mockup_approval_screen.dart';

// ── Variant lookup tables (sourced from docs/engineering/commerce_api_contracts.md) ──

const _tshirtColors = ['Black', 'White', 'Navy', 'Heather Grey', 'Red'];
const _tshirtSizes = ['S', 'M', 'L', 'XL', '2XL'];
const _posterPapers = ['Enhanced Matte', 'Luster', 'Fine Art'];
const _posterSizes = ['12x18in', '18x24in', '24x36in', 'A3', 'A4'];

/// Maps (color, size) → Shopify ProductVariant GID for the T-shirt.
const Map<(String, String), String> _tshirtGids = {
  ('Black', 'S'): 'gid://shopify/ProductVariant/47577103466683',
  ('Black', 'M'): 'gid://shopify/ProductVariant/47577103499451',
  ('Black', 'L'): 'gid://shopify/ProductVariant/47577103532219',
  ('Black', 'XL'): 'gid://shopify/ProductVariant/47577103564987',
  ('Black', '2XL'): 'gid://shopify/ProductVariant/47577103597755',
  ('White', 'S'): 'gid://shopify/ProductVariant/47577103630523',
  ('White', 'M'): 'gid://shopify/ProductVariant/47577103663291',
  ('White', 'L'): 'gid://shopify/ProductVariant/47577103696059',
  ('White', 'XL'): 'gid://shopify/ProductVariant/47577103728827',
  ('White', '2XL'): 'gid://shopify/ProductVariant/47577103761595',
  ('Navy', 'S'): 'gid://shopify/ProductVariant/47577103794363',
  ('Navy', 'M'): 'gid://shopify/ProductVariant/47577103827131',
  ('Navy', 'L'): 'gid://shopify/ProductVariant/47577103859899',
  ('Navy', 'XL'): 'gid://shopify/ProductVariant/47577103892667',
  ('Navy', '2XL'): 'gid://shopify/ProductVariant/47577103925435',
  ('Heather Grey', 'S'): 'gid://shopify/ProductVariant/47577103958203',
  ('Heather Grey', 'M'): 'gid://shopify/ProductVariant/47577103990971',
  ('Heather Grey', 'L'): 'gid://shopify/ProductVariant/47577104023739',
  ('Heather Grey', 'XL'): 'gid://shopify/ProductVariant/47577104056507',
  ('Heather Grey', '2XL'): 'gid://shopify/ProductVariant/47577104089275',
  ('Red', 'S'): 'gid://shopify/ProductVariant/47577104122043',
  ('Red', 'M'): 'gid://shopify/ProductVariant/47577104154811',
  ('Red', 'L'): 'gid://shopify/ProductVariant/47577104187579',
  ('Red', 'XL'): 'gid://shopify/ProductVariant/47577104220347',
  ('Red', '2XL'): 'gid://shopify/ProductVariant/47577104253115',
};

/// Maps (paper, size) → Shopify ProductVariant GID for the Poster.
const Map<(String, String), String> _posterGids = {
  ('Enhanced Matte', '12x18in'): 'gid://shopify/ProductVariant/47577104318651',
  ('Enhanced Matte', '18x24in'): 'gid://shopify/ProductVariant/47577104351419',
  ('Enhanced Matte', '24x36in'): 'gid://shopify/ProductVariant/47577104384187',
  ('Enhanced Matte', 'A3'): 'gid://shopify/ProductVariant/47577104416955',
  ('Enhanced Matte', 'A4'): 'gid://shopify/ProductVariant/47577104449723',
  ('Luster', '12x18in'): 'gid://shopify/ProductVariant/47577104482491',
  ('Luster', '18x24in'): 'gid://shopify/ProductVariant/47577104515259',
  ('Luster', '24x36in'): 'gid://shopify/ProductVariant/47577104548027',
  ('Luster', 'A3'): 'gid://shopify/ProductVariant/47577104580795',
  ('Luster', 'A4'): 'gid://shopify/ProductVariant/47577104613563',
  ('Fine Art', '12x18in'): 'gid://shopify/ProductVariant/47577104646331',
  ('Fine Art', '18x24in'): 'gid://shopify/ProductVariant/47577104679099',
  ('Fine Art', '24x36in'): 'gid://shopify/ProductVariant/47577104711867',
  ('Fine Art', 'A3'): 'gid://shopify/ProductVariant/47577104744635',
  ('Fine Art', 'A4'): 'gid://shopify/ProductVariant/47577104777403',
};

/// Internal preview state for the two-stage checkout flow (ADR-073).
enum _PreviewState { initial, loading, ready }

// DEPRECATED(M55): No longer in the primary commerce navigation path.
// Use LocalMockupPreviewScreen. Scheduled for deletion in M56.

/// Screen 3 of the commerce flow: variant selection + approval + checkout handoff.
///
/// Two-stage flow (ADR-073 / ADR-105):
/// 1. User selects variant options → taps "Approve & buy"
/// 2. [MockupApprovalScreen] captures explicit user consent; writes [MockupApproval] to Firestore
/// 3. [createMerchCart] Firebase Function is called; generated flag grid image shown
/// 4. "Complete checkout →" opens the cached [checkoutUrl] in SFSafariViewController
/// 5. On app resume after browser dismissal, pushes [MerchPostPurchaseScreen] (ADR-074)
class MerchVariantScreen extends StatefulWidget {
  const MerchVariantScreen({
    super.key,
    required this.product,
    required this.selectedCodes,
    this.cardId,
    this.initialTemplate = CardTemplateType.grid,
    this.artworkConfirmationId,
    this.artworkImageBytes,
  });

  final MerchProduct product;
  final List<String> selectedCodes;
  /// Optional TravelCard ID — included in the `createMerchCart` payload so the
  /// resulting order is traceable back to the card (ADR-093).
  final String? cardId;
  /// Card template to pre-select when the screen opens.
  final CardTemplateType initialTemplate;
  /// Optional ArtworkConfirmation ID — included in the `createMerchCart`
  /// payload to link the order to the user-approved artwork (ADR-103 / M51).
  final String? artworkConfirmationId;
  /// Rendered card artwork PNG from [ArtworkConfirmResult] — shown in
  /// [MockupApprovalScreen] for the user to confirm (ADR-105 / M53).
  final Uint8List? artworkImageBytes;

  @override
  State<MerchVariantScreen> createState() => _MerchVariantScreenState();
}

class _MerchVariantScreenState extends State<MerchVariantScreen>
    with WidgetsBindingObserver {
  // T-shirt state
  String _tshirtColor = _tshirtColors.first;
  String _tshirtSize = _tshirtSizes[2]; // default: L

  // Poster state
  String _posterPaper = _posterPapers.first;
  String _posterSize = _posterSizes.first;

  // Card template + placement state (Task 164 / 165)
  late CardTemplateType _selectedTemplate;
  String _placement = 'front'; // 'front' | 'back'; t-shirt only

  _PreviewState _previewState = _PreviewState.initial;
  String? _previewUrl;
  String? _mockupUrl;
  String? _checkoutUrl;
  String? _merchConfigId;
  String? _error;

  /// Set to true after [launchUrl] succeeds; triggers post-purchase poll on resume.
  bool _checkoutLaunched = false;

  // Poll parameters (ADR-087)
  static const int _pollIntervalSeconds = 3;
  static const int _pollMaxAttempts = 10;

  bool get _isTshirt => widget.product == MerchProduct.tshirt;

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

  String get _resolvedVariantGid {
    if (_isTshirt) {
      return _tshirtGids[(_tshirtColor, _tshirtSize)] ??
          _tshirtGids.values.first;
    } else {
      return _posterGids[(_posterPaper, _posterSize)] ??
          _posterGids.values.first;
    }
  }

  String get _variantSummary => _isTshirt
      ? '$_tshirtColor · $_tshirtSize'
      : '$_posterPaper · $_posterSize';

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.initialTemplate;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutLaunched) {
      _checkoutLaunched = false;
      if (!mounted) return;
      _pollForOrderConfirmation();
    }
  }

  /// Polls Firestore for MerchConfig.status == 'ordered' after the in-app
  /// browser is dismissed (ADR-087).
  ///
  /// Shows a loading overlay on this screen while polling, then either:
  /// - Pushes [MerchPostPurchaseScreen] on confirmed payment, or
  /// - Shows a neutral "processing" dialog on timeout.
  Future<void> _pollForOrderConfirmation() async {
    final configId = _merchConfigId;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // If we somehow lack the config ID or uid, fall back to neutral screen.
    if (configId == null || uid == null) {
      if (!mounted) return;
      _showOrderProcessingFallback();
      return;
    }

    // Show a non-blocking loading indicator on this screen while polling.
    if (!mounted) return;
    setState(() => _error = null);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('merch_configs')
        .doc(configId);

    for (int attempt = 0; attempt < _pollMaxAttempts; attempt++) {
      await Future<void>.delayed(
        const Duration(seconds: _pollIntervalSeconds),
      );
      if (!mounted) return;

      try {
        final snap = await docRef.get();
        final status = snap.data()?['status'] as String?;
        if (status == 'ordered') {
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MerchPostPurchaseScreen(
                product: widget.product,
                countryCount: widget.selectedCodes.length,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Network error mid-poll — continue trying until max attempts.
      }
    }

    // Timeout — show neutral fallback.
    if (!mounted) return;
    _showOrderProcessingFallback();
  }

  /// Shows a neutral bottom sheet when the Firestore poll times out.
  /// Allows the user to return to the map without a false-positive celebration.
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

  /// Clears cached preview/checkout when the user changes variant options.
  void _resetPreview() {
    if (_previewState != _PreviewState.initial) {
      _previewState = _PreviewState.initial;
      _previewUrl = null;
      _mockupUrl = null;
      _checkoutUrl = null;
      _merchConfigId = null;
      _error = null;
    }
  }

  /// Navigates to [MockupApprovalScreen] for explicit user consent before
  /// cart creation (ADR-105 / M53). On approval, calls [_generatePreview].
  Future<void> _navigateToApproval() async {
    final result = await Navigator.of(context).push<MockupApprovalResult>(
      MaterialPageRoute(
        builder: (_) => MockupApprovalScreen(
          artworkImageBytes: widget.artworkImageBytes,
          artworkConfirmationId: widget.artworkConfirmationId,
          templateType: _selectedTemplate,
          variantId: _resolvedVariantGid,
          placementType: _isTshirt ? _placement : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _generatePreview(mockupApprovalId: result.mockupApprovalId);
  }

  Future<void> _generatePreview({String? mockupApprovalId}) async {
    setState(() {
      _previewState = _PreviewState.loading;
      _error = null;
    });

    try {
      // Derive clientCardBase64 — use confirmed artwork bytes directly when
      // the template is unchanged (ADR-106 / M54-G1). This avoids a needless
      // re-render that loses trip data for Timeline cards, and ensures the
      // print source of truth is pixel-identical to what the user approved.
      String? cardBase64;
      if (widget.artworkImageBytes != null &&
          _selectedTemplate == widget.initialTemplate) {
        cardBase64 = base64Encode(widget.artworkImageBytes!);
      } else {
        try {
          if (context.mounted) {
            final result = await CardImageRenderer.render(
              context,
              _selectedTemplate,
              codes: widget.selectedCodes,
            );
            cardBase64 = base64Encode(result.bytes);
          }
        } catch (_) {
          // Rendering failure is non-fatal; server falls back to flag grid.
        }
      }

      final callable =
          FirebaseFunctions.instance.httpsCallable('createMerchCart');
      final result = await callable.call<Map<String, dynamic>>({
        'variantId': _resolvedVariantGid,
        'selectedCountryCodes': widget.selectedCodes,
        'quantity': 1,
        if (widget.cardId != null) 'cardId': widget.cardId,
        if (widget.artworkConfirmationId != null)
          'artworkConfirmationId': widget.artworkConfirmationId,
        if (mockupApprovalId != null) 'mockupApprovalId': mockupApprovalId,
        if (cardBase64 != null) 'clientCardBase64': cardBase64,
        if (_isTshirt) 'placement': _placement,
      });

      final checkoutUrl = result.data['checkoutUrl'] as String?;
      final previewUrl = result.data['previewUrl'] as String?;
      final mockupUrl = result.data['mockupUrl'] as String?;
      final merchConfigId = result.data['merchConfigId'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.ready;
        _previewUrl = previewUrl;
        _mockupUrl = mockupUrl;
        _checkoutUrl = checkoutUrl;
        _merchConfigId = merchConfigId;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.initial;
        _error = e.code == 'unavailable'
            ? 'An internet connection is required to generate a preview.'
            : e.message ?? 'An error occurred.';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.initial;
        _error = 'An internet connection is required to generate a preview.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.initial;
        _error = 'An error occurred. Please try again.';
      });
    }
  }

  Future<void> _completeCheckout() async {
    final url = _checkoutUrl;
    if (url == null) return;

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      if (!mounted) return;
      setState(() => _error = 'Could not open checkout.');
      return;
    }
    // launchUrl returns after SFSafariViewController is presented (not dismissed).
    // didChangeAppLifecycleState(resumed) fires when the user closes the browser.
    _checkoutLaunched = true;
  }

  Widget _buildProductImageSlot(ThemeData theme) {
    switch (_previewState) {
      case _PreviewState.initial:
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              _isTshirt
                  ? Icons.checkroom_outlined
                  : Icons.image_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      case _PreviewState.loading:
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      case _PreviewState.ready:
        // Prefer the photorealistic mockup (full t-shirt); fall back to the
        // flag grid preview if mockup generation timed out or is unavailable.
        final url = _mockupUrl ?? _previewUrl;
        if (url == null) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _isTshirt
                    ? Icons.checkroom_outlined
                    : Icons.image_outlined,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 60,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildCTA() {
    switch (_previewState) {
      case _PreviewState.initial:
        return FilledButton(
          onPressed: _navigateToApproval,
          child: const Text('Approve & buy'),
        );
      case _PreviewState.loading:
        return FilledButton(
          onPressed: null,
          child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        );
      case _PreviewState.ready:
        return FilledButton(
          onPressed: _completeCheckout,
          child: const Text('Complete checkout →'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProductImageSlot(theme),
          const SizedBox(height: 16),

          // Country count label
          Text(
            'Designing for ${widget.selectedCodes.length} '
            '${widget.selectedCodes.length == 1 ? 'country' : 'countries'}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FlagGridPreview(selectedCodes: widget.selectedCodes),
          const SizedBox(height: 16),

          // Card template picker (ADR-099)
          _SectionLabel('Card design'),
          _SegmentedPicker(
            options: const ['Grid', 'Heart', 'Passport', 'Timeline'],
            selected: _templateLabel(_selectedTemplate),
            onChanged: (v) => setState(() {
              _selectedTemplate = _templateFromLabel(v);
              _resetPreview();
            }),
          ),

          // Placement picker — t-shirt only (ADR-099)
          if (_isTshirt) ...[
            const SizedBox(height: 16),
            _SectionLabel('Print position'),
            _SegmentedPicker(
              options: const ['Front', 'Back'],
              selected: _placement == 'front' ? 'Front' : 'Back',
              onChanged: (v) => setState(() {
                _placement = v.toLowerCase();
                _resetPreview();
              }),
            ),
          ],
          const SizedBox(height: 8),

          // Variant pickers
          if (_isTshirt) ...[
            _SectionLabel('Colour'),
            _SegmentedPicker(
              options: _tshirtColors,
              selected: _tshirtColor,
              onChanged: (v) => setState(() {
                _tshirtColor = v;
                _resetPreview();
              }),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Size'),
            _SegmentedPicker(
              options: _tshirtSizes,
              selected: _tshirtSize,
              onChanged: (v) => setState(() {
                _tshirtSize = v;
                _resetPreview();
              }),
            ),
          ] else ...[
            _SectionLabel('Paper'),
            _SegmentedPicker(
              options: _posterPapers,
              selected: _posterPaper,
              onChanged: (v) => setState(() {
                _posterPaper = v;
                _resetPreview();
              }),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Size'),
            _SegmentedPicker(
              options: _posterSizes,
              selected: _posterSize,
              onChanged: (v) => setState(() {
                _posterSize = v;
                _resetPreview();
              }),
            ),
          ],

          const SizedBox(height: 24),

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order summary',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.product.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(_variantSummary, style: theme.textTheme.bodyMedium),
                Text(
                  '${widget.selectedCodes.length} countries',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${widget.product.fromPrice}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Error message
          if (_error != null) ...[
            Text(
              _error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCTA(),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

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
