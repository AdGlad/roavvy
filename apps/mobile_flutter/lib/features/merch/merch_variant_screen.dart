import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flag_grid_preview.dart';
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

/// Screen 3 of the commerce flow: variant selection + checkout handoff.
///
/// Shows pickers appropriate to the selected product, an order summary row,
/// and a "Buy Now" button that calls the `createMerchCart` Firebase Function.
/// On success, opens the returned checkoutUrl in an in-app browser
/// (SFSafariViewController on iOS via url_launcher inAppBrowserView).
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

class _MerchVariantScreenState extends State<MerchVariantScreen> {
  // T-shirt state
  String _tshirtColor = _tshirtColors.first;
  String _tshirtSize = _tshirtSizes[2]; // default: L

  // Poster state
  String _posterPaper = _posterPapers.first;
  String _posterSize = _posterSizes.first;

  bool _loading = false;
  String? _error;

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

  Future<void> _buyNow() async {
    setState(() {
      _loading = true;
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
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      final uri = Uri.parse(checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        throw Exception('Could not open checkout.');
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'An error occurred.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
          // Placeholder product image
          Container(
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
          ),
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
              onChanged: (v) => setState(() => _tshirtColor = v),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Size'),
            _SegmentedPicker(
              options: _tshirtSizes,
              selected: _tshirtSize,
              onChanged: (v) => setState(() => _tshirtSize = v),
            ),
          ] else ...[
            _SectionLabel('Paper'),
            _SegmentedPicker(
              options: _posterPapers,
              selected: _posterPaper,
              onChanged: (v) => setState(() => _posterPaper = v),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Size'),
            _SegmentedPicker(
              options: _posterSizes,
              selected: _posterSize,
              onChanged: (v) => setState(() => _posterSize = v),
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
                Text(_variantSummary,
                    style: theme.textTheme.bodyMedium),
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
          child: FilledButton(
            onPressed: _loading ? null : _buyNow,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Buy Now'),
          ),
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
