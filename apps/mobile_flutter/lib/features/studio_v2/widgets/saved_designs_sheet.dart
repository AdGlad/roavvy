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
/// and the garment colour — plus the [StudioSession] behind it, so reopening
/// restores the same `garmentId` AND the state it was made in, not a lookalike
/// regenerated from a seed.
///
/// A wardrobe is browsed by eye, so this is a gallery of shirts rather than a
/// list of records: the thumbnail is the row, and everything else is a caption.
class SavedDesignsSheet extends StatefulWidget {
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

  @override
  State<SavedDesignsSheet> createState() => _SavedDesignsSheetState();
}

class _SavedDesignsSheetState extends State<SavedDesignsSheet> {
  StudioController get _c => widget.controller;
  PersistentDesignLibrary? get _lib => _c.library;

  List<SavedDesign> get _saved => _lib?.library.garments ?? const [];

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
                key: SavedDesignsSheet._emptyKey,
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
                child: GridView.builder(
                  key: const Key('v2-saved-list'),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.66,
                      ),
                  itemCount: saved.length,
                  itemBuilder: (context, i) => _card(context, saved[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _open(GarmentDesign g, SavedDesign entry) {
    // openSaved restores BOTH faces and the session behind them, and refuses
    // rather than half-restoring — so a record it cannot read leaves the
    // Studio exactly as it was instead of stranding the customer in a design
    // that is partly someone else's.
    if (!_c.openSaved(entry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That design couldn't be reopened")),
      );
      return;
    }
    Navigator.of(context).pop();
    widget.onOpen(g);
  }

  /// The heart, through the same library like the rest of the app uses — the
  /// single-face like keyed by the back recipe, exactly what Review's Favourite
  /// and Instant's ♥ write. Un-hearting a design does NOT remove it from the
  /// wardrobe: the two are separate records on purpose, so losing interest in a
  /// design is not the same as throwing it away.
  Future<void> _toggleFavourite(SavedDesign entry) async {
    final lib = _lib;
    if (lib == null) return;
    await lib.toggleLike(entry.garment!.back ?? entry.garment!.front!);
    if (mounted) setState(() {});
  }

  Future<void> _duplicate(SavedDesign entry) async {
    final lib = _lib;
    if (lib == null) return;
    // A copy is the same design under a new name, never a re-roll: both
    // recipes cross untouched and only the identity changes.
    final id = await lib.duplicate(entry.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(id == null ? "Couldn't copy that design" : 'Copied'),
      ),
    );
  }

  Future<void> _delete(SavedDesign entry) async {
    final lib = _lib;
    if (lib == null) return;
    final name = _c.instantName(entry.garment!.back ?? entry.garment!.front!);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1A1C21),
            title: const Text('Delete this design?'),
            content: Text(
              '"$name" will be removed from your designs. Your travels and '
              'your other designs are not affected.',
            ),
            actions: [
              TextButton(
                key: const Key('v2-saved-delete-cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              TextButton(
                key: const Key('v2-saved-delete-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: StudioV2Theme.accent,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await lib.remove(entry.id);
    if (mounted) setState(() {});
  }

  Future<void> _reorder(SavedDesign entry) async {
    // Re-ordering is not re-designing: reopen the saved garment and hand over
    // the same request the Studio would have built for it.
    if (!_c.openSaved(entry)) return;
    final cb = widget.onAddToCart!;
    Navigator.of(context).pop();
    await cb(context, buildGarmentCartRequest(_c));
  }

  // ── One shirt ──────────────────────────────────────────────────────────────

  Widget _card(BuildContext context, SavedDesign entry) {
    final g = entry.garment!;
    final back = g.back ?? g.front!;
    final id = entry.id;
    final favourite = _lib?.library.isLiked(back.recipeId) ?? false;
    return InkWell(
      key: Key('v2-saved-open-$id'),
      onTap: () => _open(g, entry),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: StudioV2Theme.subtleBorder),
                    ),
                    // The design as the shirt it is, not a swatch — this is a
                    // wardrobe. Rendered small and served from the same cache
                    // the Studio already filled, so opening the gallery never
                    // costs a production render.
                    child: ShirtPreview(
                      key: Key('v2-saved-thumb-$id'),
                      service: _c.service,
                      recipe: back,
                      front: false,
                      longSide: 256,
                      // A quiet ghost rather than a spinner: a grid of
                      // thumbnails that each spin while they decode is a
                      // busier screen than the shirts it is meant to show.
                      placeholder: const Center(
                        child: Icon(
                          Icons.checkroom_rounded,
                          size: 26,
                          color: Colors.white12,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: _iconButton(
                    key: Key('v2-saved-favourite-$id'),
                    tooltip: favourite ? 'Remove from favourites' : 'Favourite',
                    icon:
                        favourite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                    colour: favourite ? StudioV2Theme.accent : Colors.white54,
                    onPressed: () => _toggleFavourite(entry),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: _menu(entry),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _c.instantName(back),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            _describe(entry, g),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _menu(SavedDesign entry) => PopupMenuButton<String>(
    key: Key('v2-saved-menu-${entry.id}'),
    tooltip: 'More',
    padding: EdgeInsets.zero,
    color: const Color(0xFF23262C),
    icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.white54),
    onSelected: (value) => switch (value) {
      'reorder' => _reorder(entry),
      'duplicate' => _duplicate(entry),
      _ => _delete(entry),
    },
    itemBuilder:
        (_) => [
          if (widget.onAddToCart != null)
            PopupMenuItem(
              key: Key('v2-saved-reorder-${entry.id}'),
              value: 'reorder',
              child: const _MenuRow(
                icon: Icons.shopping_bag_outlined,
                label: 'Order this again',
              ),
            ),
          PopupMenuItem(
            key: Key('v2-saved-duplicate-${entry.id}'),
            value: 'duplicate',
            child: const _MenuRow(
              icon: Icons.copy_all_outlined,
              label: 'Duplicate',
            ),
          ),
          PopupMenuItem(
            key: Key('v2-saved-delete-${entry.id}'),
            value: 'delete',
            child: const _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
            ),
          ),
        ],
  );

  Widget _iconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required Color colour,
    required VoidCallback onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    icon: Icon(icon, size: 18),
    color: colour,
    onPressed: onPressed,
  );

  String _describe(SavedDesign entry, GarmentDesign g) {
    final colour = _colourName(g.garmentColour);
    final when = DateTime.fromMillisecondsSinceEpoch(entry.sortedAtEpochMs);
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: Colors.white70),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
