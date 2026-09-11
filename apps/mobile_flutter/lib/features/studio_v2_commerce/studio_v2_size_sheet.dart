import 'package:flutter/material.dart';

import '../merch/merch_variant_lookup.dart' show tshirtSizes;
import 'studio_v2_cart_service.dart';

/// The one thing commerce needs that the design does not answer: what size,
/// and how many.
///
/// Deliberately not a Studio step. Size is not a design decision — the same
/// shirt is the same shirt in S or 2XL — so it is asked at the moment it is
/// needed, in a sheet, and never appears among the creative controls.
class StudioV2SizeSheet extends StatefulWidget {
  const StudioV2SizeSheet({super.key, this.priceLabel});

  final String? priceLabel;

  /// Returns the chosen options, or null if the customer backed out.
  static Future<StudioV2PurchaseOptions?> show(
    BuildContext context, {
    String? priceLabel,
  }) => showModalBottomSheet<StudioV2PurchaseOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15171C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StudioV2SizeSheet(priceLabel: priceLabel),
  );

  @override
  State<StudioV2SizeSheet> createState() => _StudioV2SizeSheetState();
}

class _StudioV2SizeSheetState extends State<StudioV2SizeSheet> {
  String? _size;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your size',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                for (final size in tshirtSizes)
                  ChoiceChip(
                    key: Key('v2-size-$size'),
                    label: Text(size),
                    selected: _size == size,
                    onSelected: (_) => setState(() => _size = size),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('v2-qty-less'),
                  onPressed:
                      _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.white70,
                ),
                Text(
                  '$_quantity',
                  key: const Key('v2-qty-value'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  key: const Key('v2-qty-more'),
                  onPressed:
                      _quantity < 10
                          ? () => setState(() => _quantity++)
                          : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('v2-size-confirm'),
                onPressed:
                    _size == null
                        ? null
                        : () => Navigator.of(context).pop(
                          StudioV2PurchaseOptions(
                            size: _size!,
                            quantity: _quantity,
                          ),
                        ),
                child: Text(
                  widget.priceLabel == null
                      ? 'Add to cart'
                      : 'Add to cart · ${widget.priceLabel}',
                ),
              ),
            ),
            if (widget.priceLabel == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Price is confirmed at checkout.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
