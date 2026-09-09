import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';

/// **Fine Tune** — the dials that can actually move THIS design.
///
/// The list is not written here. [StudioController.fineTuneControls] derives it
/// from the recipe on screen: a design with no clip has no Graphics panel
/// because there is no clip to size or rotate, and a single-country design has
/// nothing to arrange. Nothing is shown greyed out for symmetry — a control
/// the renderer would ignore is worse than a control that is absent.
///
/// M17–M19 deepen the groups by adding entries to that list; this screen
/// renders whatever it is handed and has no knowledge of any Direction or Vibe.
class FineTunePanel extends StatelessWidget {
  const FineTunePanel({super.key, required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final controls = controller.fineTuneControls();
    final groups = controller.fineTuneGroups();
    return ListView(
      key: const Key('v2-finetune-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        for (final g in groups)
          _Group(
            group: g,
            controls: [
              for (final c in controls)
                if (c.group == g) c,
            ],
            controller: controller,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('v2-finetune-reset'),
          onPressed: controller.resetFineTune,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset to Default'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: StudioV2Theme.subtleBorder),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.controls,
    required this.controller,
  });

  final FineTuneGroup group;
  final List<FineTuneControl> controls;
  final StudioController controller;

  static const _icons = {
    FineTuneGroup.layout: Icons.grid_view_rounded,
    FineTuneGroup.graphics: Icons.image_outlined,
    FineTuneGroup.colour: Icons.palette_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    key: Key('v2-finetune-group-${group.name}'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
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
            Icon(_icons[group], size: 20, color: StudioV2Theme.accent),
            const SizedBox(width: 10),
            // "Colour, Effects & Print" runs past a phone beside its icon.
            Expanded(
              child: Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final c in controls)
          _ControlRow(control: c, controller: controller),
      ],
    ),
  );
}

/// One parameter, on one row.
///
/// The drag edits live so the shirt keeps up, and the release is what enters
/// the undo history — a gesture costs one step, not one per frame.
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.control, required this.controller});

  final FineTuneControl control;
  final StudioController controller;

  String get _display {
    final v = control.read(controller.current);
    if (control.asPercent) {
      final span = control.max - control.min;
      return '${(((v - control.min) / span) * 100).round()}%';
    }
    return '${v.round()}${control.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final value = control
        .read(controller.current)
        .clamp(control.min, control.max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              control.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: StudioV2Theme.accent,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: StudioV2Theme.accent.withValues(alpha: 0.14),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                key: Key('v2-finetune-${control.id}'),
                min: control.min,
                max: control.max,
                divisions: control.divisions,
                value: value,
                onChangeStart: (_) => controller.beginEdit(),
                // Live: the shirt follows the thumb without filling the undo
                // stack with a step per frame.
                onChanged:
                    (v) => controller.applyLive(
                      control.write(controller.current, v),
                    ),
                onChangeEnd: (_) => controller.endEdit(),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              _display,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
