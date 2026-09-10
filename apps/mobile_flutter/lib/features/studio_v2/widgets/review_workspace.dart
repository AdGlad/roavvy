import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart' hide Orientation;

import '../../shared/garment_mockup/mockup_transform.dart';
import '../commerce/garment_cart_request.dart';
import '../studio_v2_theme.dart';
import 'shirt_preview.dart';

/// **Review & Buy** (M22) — the finished product, and the way to own it.
///
/// The design phase is over: there is not a single engine control on this
/// screen. It consumes the completed session exactly as M21 left it — the hero
/// on the back, the configured face on the front — and never regenerates,
/// re-rolls or re-defaults anything. Both previews come from the same
/// [RenderService] cache the rest of the Studio has been filling, so arriving
/// here costs no new renders.
///
/// Everything it does is an existing behaviour:
/// [StudioController.saveGarment] persists both faces as one reproducible
/// garment, [StudioController.toggleFavourite] hearts it through the same
/// library the app already uses, and [buildGarmentCartRequest] is the one
/// description of a garment order shared with Instant's Buy it and the footer's
/// Buy Now.
///
/// Physical size and quantity are deliberately ABSENT. They belong to the
/// commerce screen this hands off to, which already collects them — asking
/// twice would mean two answers that can disagree.
class ReviewWorkspace extends StatefulWidget {
  const ReviewWorkspace({
    super.key,
    required this.controller,
    this.onAddToCart,
    this.frontPlacement = MockupTransform.identity,
    this.backPlacement = MockupTransform.identity,
    this.priceLabel,
  });

  final StudioController controller;
  final AddToCartCallback? onAddToCart;

  /// What the Placement step arranged, per face — baked into the print files
  /// by the shared builder so what was arranged is what gets printed.
  final MockupTransform frontPlacement;
  final MockupTransform backPlacement;

  /// The store's own price for a tee, supplied by the host (the Studio may not
  /// reach into the merch feature). Null means the store has not said — in
  /// which case this screen says so rather than inventing a number.
  final String? priceLabel;

  @override
  State<ReviewWorkspace> createState() => _ReviewWorkspaceState();
}

class _ReviewWorkspaceState extends State<ReviewWorkspace> {
  StudioController get _c => widget.controller;
  bool _busy = false;
  bool _saved = false;

  /// Save, and say honestly whether it stuck.
  ///
  /// The design is in the wardrobe in memory the moment this returns — a failed
  /// write costs the customer nothing of what is on screen, only the promise
  /// that it will still be there tomorrow. So a failure offers Retry rather
  /// than tearing anything down.
  Future<void> _save() async {
    final written = await _c.saveGarment();
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      written
          ? const SnackBar(content: Text('Design saved to your library'))
          : SnackBar(
            content: const Text("Saved here, but couldn't be stored"),
            action: SnackBarAction(label: 'Retry', onPressed: _save),
          ),
    );
  }

  void _favourite() {
    _c.toggleFavourite();
    if (!mounted) return;
    setState(() {});
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
    // quietly start ordering different things. It carries the FINAL recipes;
    // nothing is regenerated on the way to the cart.
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
    // The buy button is PINNED rather than scrolled to. It is the one thing
    // this screen exists for, and a customer should never have to go looking
    // for it at the bottom of a list.
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('v2-review-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _face(front: true, label: 'Front')),
                  const SizedBox(width: 12),
                  Expanded(child: _face(front: false, label: 'Back')),
                ],
              ),
              const SizedBox(height: 16),
              _summary(),
              _actions(),
              _assurances(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _buyButton(),
        ),
      ],
    );
  }

  /// One finished side, labelled. Read-only: no placement handles, no toggle
  /// that could edit — reviewing a design must not be able to change it.
  Widget _face({required bool front, required String label}) => Column(
    children: [
      AspectRatio(
        aspectRatio: 0.82,
        child: ShirtPreview(
          key: Key(front ? 'v2-review-front' : 'v2-review-back'),
          service: _c.service,
          recipe: front ? _c.frontFace : _c.hero,
          front: front,
          // A blank front is a blank shirt, not a shrunken print.
          printArea: front ? _c.frontPrintRect() : null,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: StudioV2Theme.control,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StudioV2Theme.subtleBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ),
    ],
  );

  /// What the customer chose, in their words — not a dump of the recipe.
  Widget _summary() {
    final countries = _c.selectedCountryCodes.length;
    final title = _c.currentTitle;
    final rows = <(String, String)>[
      ('Garment', 'Classic Tee'),
      ('Colour', _c.garmentName),
      ('Countries', '$countries ${countries == 1 ? 'country' : 'countries'}'),
      ('Design', _c.subjectLabel),
      if (_c.currentStyle != null) ('Style', _c.currentStyle!.label),
      ('Front print', _c.frontLabel),
      if (title.isNotEmpty) ('Title', title),
    ];
    return _card(
      icon: Icons.checkroom_rounded,
      title: 'Your design',
      child: Column(
        children: [
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      k,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      v,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('v2-review-save'),
            onPressed: _save,
            icon: Icon(
              _saved ? Icons.check_rounded : Icons.bookmark_border_rounded,
              size: 18,
            ),
            label: Text(_saved ? 'Saved' : 'Save design'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _saved ? StudioV2Theme.accent : Colors.white70,
              side: BorderSide(
                color:
                    _saved ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
              ),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('v2-review-favourite'),
            onPressed: _favourite,
            icon: Icon(
              _c.isFavourite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
            ),
            label: Text(_c.isFavourite ? 'Favourited' : 'Favourite'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  _c.isFavourite ? StudioV2Theme.accent : Colors.white70,
              side: BorderSide(
                color:
                    _c.isFavourite
                        ? StudioV2Theme.accent
                        : StudioV2Theme.subtleBorder,
              ),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _assurances() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (final (icon, head, body) in const [
          (
            Icons.local_shipping_outlined,
            'Printed on demand',
            'High quality print by our trusted partner.',
          ),
          (
            Icons.eco_outlined,
            'Sustainable choice',
            'Made only when you order.',
          ),
          (
            Icons.lock_outline_rounded,
            'Secure checkout',
            'Size and delivery are chosen at the next step.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        head,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buyButton() => FilledButton(
    key: const Key('v2-review-add-to-cart'),
    onPressed: _busy ? null : _addToCart,
    style: FilledButton.styleFrom(
      backgroundColor: StudioV2Theme.accent,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child:
        _busy
            ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
            : Text(
              // The store's own price when it has told us one, and an honest
              // sentence when it has not — never a number from a mockup.
              widget.priceLabel == null
                  ? 'Add to cart'
                  : 'Add to cart  ·  ${widget.priceLabel}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
  );

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: StudioV2Theme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: StudioV2Theme.subtleBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: StudioV2Theme.accent),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
