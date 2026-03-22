import 'package:flutter/material.dart';

import 'merch_variant_screen.dart';

/// Products available in the PoC.
enum MerchProduct {
  tshirt(
    name: 'Roavvy Test Tee',
    tagline: 'Wear your world',
    fromPrice: '£29.99',
    gid: 'gid://shopify/Product/8357194694843',
  ),
  poster(
    name: 'Roavvy Travel Poster',
    tagline: 'Frame the journey',
    fromPrice: '£24.99',
    gid: 'gid://shopify/Product/8357218353339',
  );

  const MerchProduct({
    required this.name,
    required this.tagline,
    required this.fromPrice,
    required this.gid,
  });

  final String name;
  final String tagline;
  final String fromPrice;
  final String gid;
}

/// Screen 2 of the commerce flow: product browser.
///
/// Shows T-Shirt and Poster cards. Tapping a card navigates to
/// [MerchVariantScreen] with the selected product and country codes.
class MerchProductBrowserScreen extends StatelessWidget {
  const MerchProductBrowserScreen({
    super.key,
    required this.selectedCodes,
  });

  final List<String> selectedCodes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Designing for ${selectedCodes.length} countries'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProductCard(
            product: MerchProduct.tshirt,
            selectedCodes: selectedCodes,
          ),
          const SizedBox(height: 16),
          _ProductCard(
            product: MerchProduct.poster,
            selectedCodes: selectedCodes,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selectedCodes,
  });

  final MerchProduct product;
  final List<String> selectedCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MerchVariantScreen(
              product: product,
              selectedCodes: selectedCodes,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder product image
            Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  product == MerchProduct.tshirt
                      ? Icons.checkroom_outlined
                      : Icons.image_outlined,
                  size: 80,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.tagline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'From ${product.fromPrice}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MerchVariantScreen(
                      product: product,
                      selectedCodes: selectedCodes,
                    ),
                  ),
                ),
                child: const Text('Customise →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
