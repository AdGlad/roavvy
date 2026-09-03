import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../commerce/garment_cart_request.dart';
import '../studio_v2_theme.dart';
import 'shirt_preview.dart';

/// **Your designs** — the payoff for deterministic recipes.
///
/// A design that reproduces exactly but that nobody can reopen is a promise
/// with no payoff. Everything saved at Review is here, as the shirt it was:
/// tap one to carry on with it, or order it again without designing anything.
///
/// Each entry stores the whole two-face [GarmentDesign] — both printed sides
/// and the garment colour — so reopening restores the same `garmentId`, not a
/// lookalike regenerated from a seed.
class SavedDesignsSheet extends StatelessWidget {
  const SavedDesignsSheet({
    super.key,
    required this.controller,
    required this.onOpen,
    this.onAddToCart,
  });

  final StudioController controller;

  /// Called after a saved design is loaded, so the host can land the flow
  /// somewhere sensible (Review, where saving happened).
  final ValueChanged<GarmentDesign> onOpen;

  final AddToCartCallback? onAddToCart;

  static const _emptyKey = Key('v2-saved-empty');

  List<SavedDesign> get _saved =>
      controller.library?.library.garments ?? const [];

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR DESIGNS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: StudioV2Theme.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              saved.isEmpty
                  ? 'Nothing saved yet. Save a design at Review and it will '
                      'wait for you here.'
                  : '${saved.length} saved. Tap one to carry on with it, or '
                      'order it again as it is.',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            if (saved.isEmpty)
              const Padding(
                key: _emptyKey,
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    size: 34,
                    color: Colors.white24,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  key: const Key('v2-saved-list'),
                  shrinkWrap: true,
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _row(context, saved[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, SavedDesign entry) {
    final g = entry.garment!;
    final back = g.back ?? g.front!;
    final id = g.garmentId;
    return InkWell(
      key: Key('v2-saved-open-$id'),
      onTap: () {
        controller.loadGarment(g);
        Navigator.of(context).pop();
        onOpen(g);
      },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 68,
            // The design as the shirt it is, not a swatch — this is a wardrobe.
            child: ShirtPreview(
              key: Key('v2-saved-thumb-$id'),
              service: controller.service,
              recipe: back,
              front: false,
              longSide: 256,
              placeholder: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.instantName(back),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _describe(entry, g),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          if (onAddToCart != null)
            IconButton(
              key: Key('v2-saved-reorder-$id'),
              tooltip: 'Order this again',
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              color: StudioV2Theme.accent,
              // Re-ordering is not re-designing: load the saved garment and
              // hand over the same request the Studio would have built for it.
              onPressed: () async {
                controller.loadGarment(g);
                final cb = onAddToCart!;
                Navigator.of(context).pop();
                await cb(context, buildGarmentCartRequest(controller));
              },
            ),
        ],
      ),
    );
  }

  String _describe(SavedDesign entry, GarmentDesign g) {
    final colour = _colourName(g.garmentColour);
    final when = DateTime.fromMillisecondsSinceEpoch(entry.savedAtEpochMs);
    final date = '${when.day} ${_months[when.month - 1]} ${when.year}';
    return entry.usedForTshirt
        ? '$colour · ordered · $date'
        : '$colour · $date';
  }

  static String _colourName(String? hex) {
    for (final (h, name) in StudioController.garments) {
      if (h == hex) return name;
    }
    return 'Custom colour';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
