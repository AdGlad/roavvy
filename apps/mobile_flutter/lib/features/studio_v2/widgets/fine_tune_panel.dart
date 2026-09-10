import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';
import 'garment_preview.dart';

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
  const FineTunePanel({super.key, required this.controller, this.only});

  final StudioController controller;

  /// Show just one group, at full depth (M17–M19). Null shows every group
  /// that applies, which is the M16 overview.
  final FineTuneGroup? only;

  @override
  Widget build(BuildContext context) {
    final controls = controller.fineTuneControls();
    final choices = [
      ...controller.fineTuneChoices(),
      ...controller.graphicChoices(),
      ...controller.colourChoices(),
    ];
    final groups = [
      for (final g in controller.fineTuneGroups())
        if (only == null || g == only) g,
    ];
    return ListView(
      key: const Key('v2-finetune-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Nothing to adjust here for this design.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white38),
            ),
          ),
        for (final g in groups)
          _Group(
            group: g,
            controls: [
              for (final c in controls)
                if (c.group == g) c,
            ],
            choices: [
              for (final c in choices)
                if (c.group == g) c,
            ],
            // On a single-group screen the step heading already names it;
            // repeating it inside the panel says the same thing twice.
            showTitle: only == null,
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
    required this.choices,
    required this.controller,
    this.showTitle = true,
  });

  final bool showTitle;

  final FineTuneGroup group;
  final List<FineTuneControl> controls;
  final List<FineTuneChoice> choices;
  final StudioController controller;

  static const _icons = {
    FineTuneGroup.layout: Icons.grid_view_rounded,
    FineTuneGroup.graphics: Icons.image_outlined,
    FineTuneGroup.colour: Icons.palette_outlined,
  };

  static Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
    decoration: BoxDecoration(
      color: StudioV2Theme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: StudioV2Theme.subtleBorder),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final previews = [
      for (final c in choices)
        if (c.preview) c,
    ];
    final rest = [
      for (final c in choices)
        if (!c.preview) c,
    ];

    // A treatment that has to be SEEN gets a card of its own, so the screen
    // reads as "colour, then effects, then print" rather than as one long
    // panel. Sliders and text chips stay together underneath, as the depth
    // behind those choices.
    return Column(
      key: Key('v2-finetune-group-${group.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          _card(
            child: Row(
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
          ),
        for (final c in previews)
          _card(child: _PreviewChoiceRow(choice: c, controller: controller)),
        if (rest.isNotEmpty || controls.isNotEmpty)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in rest)
                  _ChoiceRow(choice: c, controller: controller),
                for (final c in controls)
                  _ControlRow(control: c, controller: controller),
              ],
            ),
          ),
      ],
    );
  }
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
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  control.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                if (control.helper.isNotEmpty)
                  Text(
                    control.helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
              ],
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

/// A pick-one control, as a row of chips — an arrangement is a look, so it is
/// chosen by name rather than by dragging a number.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.controller});

  final FineTuneChoice choice;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final current = choice.read(controller.current);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            choice.label,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
          if (choice.helper.isNotEmpty)
            Text(
              choice.helper,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              key: Key('v2-finetune-choice-${choice.id}'),
              scrollDirection: Axis.horizontal,
              children: [
                for (final o in choice.options) _chip(o, o.id == current),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(FineTuneOption o, bool selected) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      key: Key('v2-finetune-${choice.id}-${o.id}'),
      // One tap is one decision, so it is one undo step — no live phase.
      onTap:
          () =>
              controller.commitFineTune(choice.write(controller.current, o.id)),
      child: Semantics(
        button: true,
        selected: selected,
        label: o.label,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color:
                selected
                    ? StudioV2Theme.accent.withValues(alpha: 0.16)
                    : StudioV2Theme.control,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color:
                  selected ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            o.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? StudioV2Theme.accent : Colors.white70,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A pick-one control whose options are LOOKS, shown as live thumbnails.
///
/// "Riso" or "Duotone" means nothing as a word on a chip — so each option
/// renders the candidate it would produce: `choice.write(current, option.id)`,
/// the same pure function the tap commits. What is previewed is therefore
/// exactly what is applied, on the wearer's own artwork rather than a stock
/// sample.
///
/// Cost is kept down three ways: the thumbnails are small, the row builds
/// lazily so options scrolled past are never rendered, and [GarmentPreview]
/// re-fetches only when a recipe's identity changes — with the
/// [RenderService] cache (keyed `recipeId@size`) absorbing everything the
/// wearer scrolls back to.
class _PreviewChoiceRow extends StatelessWidget {
  const _PreviewChoiceRow({required this.choice, required this.controller});

  final FineTuneChoice choice;
  final StudioController controller;

  static const double _thumb = 74;

  @override
  Widget build(BuildContext context) {
    final current = choice.read(controller.current);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            choice.label,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
          if (choice.helper.isNotEmpty)
            Text(
              choice.helper,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: _thumb + 26,
            child: ListView.builder(
              key: Key('v2-finetune-choice-${choice.id}'),
              scrollDirection: Axis.horizontal,
              itemCount: choice.options.length,
              itemBuilder: (context, i) {
                final o = choice.options[i];
                return _tile(o, o.id == current);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FineTuneOption o, bool selected) {
    // The candidate this option would produce — previewed and committed by the
    // same pure write, so they can never disagree.
    final candidate = choice.write(controller.current, o.id);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        key: Key('v2-finetune-${choice.id}-${o.id}'),
        // One tap is one decision, so it is one undo step — no live phase.
        onTap: () => controller.commitFineTune(candidate),
        child: Semantics(
          button: true,
          selected: selected,
          label: o.label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _thumb,
                height: _thumb,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: StudioV2Theme.control,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color:
                        selected
                            ? StudioV2Theme.accent
                            : StudioV2Theme.subtleBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: GarmentPreview(
                  service: controller.service,
                  recipe: candidate,
                  longSide: 150,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: _thumb,
                child: Text(
                  o.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? StudioV2Theme.accent : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
