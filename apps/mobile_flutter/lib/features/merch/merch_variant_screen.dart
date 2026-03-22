import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flag_grid_preview.dart';
import 'merch_post_purchase_screen.dart';
import 'merch_product_browser_screen.dart';

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

/// Screen 3 of the commerce flow: variant selection + preview + checkout handoff.
///
/// Two-stage flow (ADR-073):
/// 1. User selects variant options → taps "Preview my design"
/// 2. [createMerchCart] Firebase Function is called; generated flag grid image shown
/// 3. "Complete checkout →" opens the cached [checkoutUrl] in SFSafariViewController
/// 4. On app resume after browser dismissal, pushes [MerchPostPurchaseScreen] (ADR-074)
class MerchVariantScreen extends StatefulWidget {
  const MerchVariantScreen({
    super.key,
    required this.product,
    required this.selectedCodes,
  });

  final MerchProduct product;
  final List<String> selectedCodes;

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

  _PreviewState _previewState = _PreviewState.initial;
  String? _previewUrl;
  String? _checkoutUrl;
  String? _error;

  /// Set to true after [launchUrl] succeeds; triggers post-purchase screen on resume.
  bool _checkoutLaunched = false;

  bool get _isTshirt => widget.product == MerchProduct.tshirt;

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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MerchPostPurchaseScreen(
            product: widget.product,
            countryCount: widget.selectedCodes.length,
          ),
        ),
      );
    }
  }

  /// Clears cached preview/checkout when the user changes variant options.
  void _resetPreview() {
    if (_previewState != _PreviewState.initial) {
      _previewState = _PreviewState.initial;
      _previewUrl = null;
      _checkoutUrl = null;
      _error = null;
    }
  }

  Future<void> _generatePreview() async {
    setState(() {
      _previewState = _PreviewState.loading;
      _error = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createMerchCart');
      final result = await callable.call<Map<String, dynamic>>({
        'variantId': _resolvedVariantGid,
        'selectedCountryCodes': widget.selectedCodes,
        'quantity': 1,
      });

      final checkoutUrl = result.data['checkoutUrl'] as String?;
      final previewUrl = result.data['previewUrl'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.ready;
        _previewUrl = previewUrl;
        _checkoutUrl = checkoutUrl;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.initial;
        _error = e.message ?? 'An error occurred.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewState = _PreviewState.initial;
        _error = e.toString();
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
        final url = _previewUrl;
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
            fit: BoxFit.cover,
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
          onPressed: _generatePreview,
          child: const Text('Preview my design'),
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

          // Flag grid preview
          Text(
            'Designing for ${widget.selectedCodes.length} '
            '${widget.selectedCodes.length == 1 ? 'country' : 'countries'}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FlagGridPreview(selectedCodes: widget.selectedCodes),
          const SizedBox(height: 8),

          // Pickers
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
