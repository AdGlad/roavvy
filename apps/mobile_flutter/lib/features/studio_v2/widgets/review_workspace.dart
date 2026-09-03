import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import '../commerce/garment_cart_request.dart';
import '../../shared/garment_mockup/mockup_transform.dart';
import '../studio_v2_theme.dart';

/// **Review** workspace (M8) — the purchase-oriented final step. It consumes the
/// existing [StudioController]/GarmentDesign session (no new model) and presents
/// both real faces and the purchase summary without re-exposing Fine Tune.
class ReviewWorkspace extends StatefulWidget {
  const ReviewWorkspace({
    super.key,
    required this.controller,
    this.onAddToCart,
    this.frontPlacement = MockupTransform.identity,
    this.backPlacement = MockupTransform.identity,
  });

  final StudioController controller;
  final AddToCartCallback? onAddToCart;

  /// What the Placement step arranged, per face — baked into the print files
  /// by the shared builder so what was arranged is what gets printed.
  final MockupTransform frontPlacement;
  final MockupTransform backPlacement;

  @override
  State<ReviewWorkspace> createState() => _ReviewWorkspaceState();
}

class _ReviewWorkspaceState extends State<ReviewWorkspace> {
  StudioController get _c => widget.controller;
  bool _busy = false;
  bool _saved = false;

  Future<void> _save() async {
    _c.saveGarment();
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Design saved to your library')),
    );
  }

  Future<void> _addToCart() async {
    final cb = widget.onAddToCart;
    if (cb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is not available in this build')),
      );
      return;
    }
    setState(() => _busy = true);
    // The one description of a garment order, shared with Instant's Buy it
    // and the footer's Buy Now — a second hand-rolled copy is how the paths
    // quietly start ordering different things.
    final req = buildGarmentCartRequest(
      _c,
      frontPlacement: widget.frontPlacement,
      backPlacement: widget.backPlacement,
    );
    try {
      await cb(context, req);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _c.currentTitle;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'REVIEW',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: StudioV2Theme.accent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Both sides, ready to order. Switch Front/Back to check '
            'each face, then save or add to cart.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _sideBtn(
                'v2-review-side-back',
                'Back',
                !_c.onFront,
                () => _c.setSide(false),
              ),
              const SizedBox(width: 8),
              _sideBtn(
                'v2-review-side-front',
                'Front',
                _c.onFront,
                () => _c.setSide(true),
              ),
              const Spacer(),
              Text(
                _c.onFront ? 'Front' : 'Back',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (title.trim().isNotEmpty) ...[
            _summaryRow('Title', title),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final chip in _c.reviewSpec()) _specChip(chip)],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('v2-review-save'),
                onPressed: _busy ? null : _save,
                icon: Icon(
                  _saved ? Icons.check : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(_saved ? 'Saved' : 'Save design'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: StudioV2Theme.border),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('v2-review-addtocart'),
                  onPressed: _busy ? null : _addToCart,
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Add to cart'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Shirt size and quantity are chosen at checkout.',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _sideBtn(
    String key,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => GestureDetector(
    key: Key(key),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:
            selected
                ? StudioV2Theme.accent.withValues(alpha: 0.16)
                : StudioV2Theme.control,
        border: Border.all(
          color: selected ? StudioV2Theme.accent : StudioV2Theme.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? StudioV2Theme.accent : Colors.white70,
        ),
      ),
    ),
  );

  Widget _specChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: StudioV2Theme.card,
      border: Border.all(color: StudioV2Theme.subtleBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.white70),
    ),
  );

  Widget _summaryRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 56,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
