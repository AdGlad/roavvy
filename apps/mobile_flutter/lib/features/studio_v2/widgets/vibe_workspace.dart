import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'alternatives_tray.dart';
import 'axis_controls.dart';
import 'garment_preview.dart';

/// **Vibe** workspace (M4) — the real style selector. Presents all 13 named
/// [LabStyle]s ([StudioController.vibeStyleOptions]) as live thumbnails restyled
/// from the user's CURRENT design (not generic samples), so each card previews
/// exactly what that vibe does to this shirt. Selecting one commits it through
/// [StudioController.onStyleTap] (immediate live update, undoable) while every
/// Tier-1 control and the travel / Direction / Detail selection is preserved.
///
/// Below the picker sits a compact [AlternativesTray] over the Vibe axis — more
/// deterministic interpretations of the chosen look — plus a per-axis lock and
/// the global Remix (keep what I love, remix the rest). The shirt above stays the
/// hero; this strip only swaps the finish.
class VibeWorkspace extends StatelessWidget {
  const VibeWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final options = controller.vibeStyleOptions();
    final current = controller.currentStyle;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(
              child: Text('VIBE',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: Colors.tealAccent)),
            ),
            AxisLockChip(controller: controller, axis: DesignAxis.vibe),
            const SizedBox(width: 8),
            RemixButton(controller: controller),
          ]),
          const SizedBox(height: 4),
          const Text('Pick the overall style.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final (style, styled) = options[i];
                return _VibeCard(
                  key: Key('v2-vibe-${style.name}'),
                  service: controller.service,
                  recipe: styled,
                  label: style.label,
                  selected: current == style,
                  onTap: () {
                    controller.onStyleTap(style, styled);
                    // Refresh the tray so its variations follow the new look.
                    controller.focusAxis(DesignAxis.vibe);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          AlternativesTray(
            controller: controller,
            axis: DesignAxis.vibe,
            label: 'More like this',
          ),
        ],
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    super.key,
    required this.service,
    required this.recipe,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RenderService service;
  final DesignRecipe recipe;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          color: selected
              ? Colors.tealAccent.withValues(alpha: 0.14)
              : const Color(0xFF1B1E24),
          border: Border.all(
              color: selected ? Colors.tealAccent : const Color(0xFF3A3D44),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 84,
              width: double.infinity,
              child: GarmentPreview(
                  service: service, recipe: recipe, longSide: 220),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.tealAccent : Colors.white70)),
          ],
        ),
      ),
    );
  }
}
