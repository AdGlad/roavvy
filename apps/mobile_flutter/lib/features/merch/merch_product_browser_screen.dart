import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'merch_variant_lookup.dart';
import 'merch_variant_screen.dart';

// DEPRECATED(M55): No longer in the primary commerce navigation path.
// Use LocalMockupPreviewScreen. Scheduled for deletion in M56.

/// Screen 2 of the commerce flow: product browser.
///
/// Shows T-Shirt and Poster cards. Tapping a card navigates to
/// [MerchVariantScreen] with the selected product and country codes.
class MerchProductBrowserScreen extends StatelessWidget {
  const MerchProductBrowserScreen({
    super.key,
    required this.selectedCodes,
    this.cardId,
    this.initialTemplate = CardTemplateType.grid,
    this.artworkConfirmationId,
    this.artworkImageBytes,
  });

  final List<String> selectedCodes;

  /// Optional TravelCard ID — passed through to [MerchVariantScreen] and
  /// on to `createMerchCart` so the order is traceable to the card (ADR-093).
  final String? cardId;

  /// Card template to pre-select in [MerchVariantScreen] (ADR-099).
  final CardTemplateType initialTemplate;

  /// Firestore ID of the confirmed [ArtworkConfirmation] (ADR-103 / M51-E2).
  /// When set, passed to `createMerchCart` to link the order to the
  /// user-approved artwork.
  final String? artworkConfirmationId;

  /// PNG bytes of the confirmed artwork, shown as a thumbnail header when
  /// non-null (ADR-103 / M51-E2).
  final Uint8List? artworkImageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Designing for ${selectedCodes.length} countries'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Confirmed artwork thumbnail (ADR-103 / M51-E2)
          if (artworkImageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                artworkImageBytes!,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _ProductCard(
            product: MerchProduct.tshirt,
            selectedCodes: selectedCodes,
            cardId: cardId,
            initialTemplate: initialTemplate,
            artworkConfirmationId: artworkConfirmationId,
            artworkImageBytes: artworkImageBytes,
          ),
          const SizedBox(height: 16),
          _ProductCard(
            product: MerchProduct.poster,
            selectedCodes: selectedCodes,
            cardId: cardId,
            initialTemplate: initialTemplate,
            artworkConfirmationId: artworkConfirmationId,
            artworkImageBytes: artworkImageBytes,
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
    this.cardId,
    this.initialTemplate = CardTemplateType.grid,
    this.artworkConfirmationId,
    this.artworkImageBytes,
  });

  final MerchProduct product;
  final List<String> selectedCodes;
  final String? cardId;
  final CardTemplateType initialTemplate;
  final String? artworkConfirmationId;
  final Uint8List? artworkImageBytes;

  void _goToVariant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MerchVariantScreen(
          product: product,
          selectedCodes: selectedCodes,
          cardId: cardId,
          initialTemplate: initialTemplate,
          artworkConfirmationId: artworkConfirmationId,
          artworkImageBytes: artworkImageBytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _goToVariant(context),
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
                onPressed: () => _goToVariant(context),
                child: const Text('Customise →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
