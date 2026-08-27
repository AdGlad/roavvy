import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'garment_preview.dart';

/// A compact **alternatives tray** (M4) — several deterministic interpretations
/// of ONE axis (Vibe or Focus), rendered as small live thumbnails. These are NOT
/// templates: each is a real re-roll of the current design's [axis] via the
/// shared [StudioController]'s deterministic sub-seed stream
/// ([StudioController.focusAxis] / [StudioController.alternatives]), so the same
/// state always yields the same tray. Tapping one commits it (undoable);
/// ✕ sends a reject signal; **More** rolls a fresh set.
///
/// The tray owns no design state — it only reflects [StudioController.alternatives]
/// for the [axis] it made active, and keeps the thumbnails cheap by rendering at a
/// small [_thumbLongSide] (the [RenderService] caches by `recipeId@size`).
class AlternativesTray extends StatefulWidget {
  const AlternativesTray({
    super.key,
    required this.controller,
    required this.axis,
    this.label = 'Variations',
  });

  final StudioController controller;
  final DesignAxis axis;
  final String label;

  static const int _thumbLongSide = 220;

  @override
  State<AlternativesTray> createState() => _AlternativesTrayState();
}

class _AlternativesTrayState extends State<AlternativesTray> {
  @override
  void initState() {
    super.initState();
    // Populate this axis's alternatives once the first frame is up (never during
    // build — focusAxis notifies listeners). Idempotent: only (re)rolls when the
    // tray isn't already showing this axis.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocused());
  }

  void _ensureFocused() {
    final c = widget.controller;
    if (c.activeAxis != widget.axis || c.alternatives.isEmpty) {
      c.focusAxis(widget.axis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final showing = c.activeAxis == widget.axis;
    final alts = showing ? c.alternatives : const <DesignRecipe>[];
    final currentId = c.current.recipeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(widget.label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.tealAccent)),
          ),
          TextButton.icon(
            key: const Key('v2-alt-more'),
            onPressed: () => c.focusAxis(widget.axis),
            style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('More', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: alts.isEmpty
              ? const Center(
                  child: Text('Rolling variations…',
                      style: TextStyle(fontSize: 12, color: Colors.white38)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: alts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _tile(c, alts[i], i,
                      selected: alts[i].recipeId == currentId),
                ),
        ),
      ],
    );
  }

  Widget _tile(StudioController c, DesignRecipe alt, int i,
      {required bool selected}) {
    return GestureDetector(
      key: Key('v2-alt-$i'),
      onTap: () => c.onAlternativeTap(i, alt),
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E24),
          border: Border.all(
              color: selected ? Colors.tealAccent : const Color(0xFF3A3D44),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: GarmentPreview(
              service: c.service,
              recipe: alt,
              longSide: AlternativesTray._thumbLongSide,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              key: Key('v2-alt-dismiss-$i'),
              onTap: () => c.dismissAlternative(i),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Color(0xCC121317),
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        topRight: Radius.circular(9))),
                child: const Icon(Icons.close, size: 13, color: Colors.white54),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
