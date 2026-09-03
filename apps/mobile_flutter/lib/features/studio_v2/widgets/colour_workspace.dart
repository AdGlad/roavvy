import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';
import 'alternatives_tray.dart';
import 'axis_controls.dart';
import 'garment_preview.dart';

/// **Colour** workspace (M5) — the ARTWORK colour treatment, i.e. how the design's
/// ink is coloured. This is explicitly *not* the blank garment colour (that lives
/// in the persistent bar above, labelled "Shirt colour"). Each treatment maps a
/// plain-language label to an engine [ColourStrategy] via
/// [StudioController.colourTreatments], rendered as a live thumbnail of that
/// treatment applied to the CURRENT design. Tapping one commits it through
/// [StudioController.setColourTreatment] — palette-only, so the layout, Vibe and
/// garment colour are all preserved, and it is undoable.
class ColourWorkspace extends StatelessWidget {
  const ColourWorkspace({super.key, required this.controller});

  final StudioController controller;

  static String _slug(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _isActive((String, ColourStrategy, double) t) {
    if (controller.colourStrategy != t.$2) return false;
    final wantsVintage = t.$3 >= 0.3;
    return wantsVintage
        ? controller.vintageGrade >= 0.3
        : controller.vintageGrade < 0.3;
  }

  DesignRecipe _preview((String, ColourStrategy, double) t) {
    final pal = controller.current.palette ?? const Palette();
    return controller.current.copyWith(
      palette: pal.copyWith(strategy: t.$2, vintageGrade: t.$3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treatments = StudioController.colourTreatments;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'COLOUR',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: StudioV2Theme.accent,
                  ),
                ),
              ),
              AxisLockChip(controller: controller, axis: DesignAxis.colour),
              const SizedBox(width: 8),
              RemixButton(controller: controller),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'How the artwork is coloured — your shirt colour stays in '
            'the bar above.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: treatments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t = treatments[i];
                return _TreatmentCard(
                  key: Key('v2-colour-${_slug(t.$1)}'),
                  service: controller.service,
                  recipe: _preview(t),
                  label: t.$1,
                  selected: _isActive(t),
                  onTap: () => controller.setColourTreatment(t),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          AlternativesTray(
            controller: controller,
            axis: DesignAxis.colour,
            label: 'More colours',
          ),
        ],
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({
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
          color:
              selected
                  ? StudioV2Theme.accent.withValues(alpha: 0.12)
                  : StudioV2Theme.card,
          border: Border.all(
            color: selected ? StudioV2Theme.accent : StudioV2Theme.border,
            width: selected ? 2 : 1,
          ),
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
                service: service,
                recipe: recipe,
                longSide: 220,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: selected ? StudioV2Theme.accent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
