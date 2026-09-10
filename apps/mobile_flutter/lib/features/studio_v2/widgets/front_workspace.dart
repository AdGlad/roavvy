import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';

/// **Front Design** (M21) — the optional, complementary front of the garment.
///
/// The back is the finished design and M21 never touches it. Everything here is
/// front print configuration held beside the back on [StudioController]:
/// [FrontFit] (full / chest / none), the chest side, the [FrontArt] the front
/// is derived from, and — for a ribbon — whether it shows the countries chosen
/// for this design or every country travelled.
///
/// No new front model is introduced and no templates are invented: each control
/// maps to a capability the controller and the cart already use, and the print
/// rectangle the diagrams draw is [StudioController.frontPrintRect] itself, so
/// the picture and the print cannot disagree.
///
/// Controls are contextual — the chest side exists only for a chest print, the
/// artwork only when something prints, the ribbon coverage only for a ribbon.
class FrontWorkspace extends StatelessWidget {
  const FrontWorkspace({super.key, required this.controller});

  final StudioController controller;

  bool get _prints => controller.frontFit != FrontFit.none;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('v2-front-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _card(
          icon: Icons.checkroom_rounded,
          title: 'Front design',
          helper: 'The back carries your design. The front is optional.',
          child: Row(
            children: [
              for (final (fit, label, key) in const [
                (FrontFit.full, 'Full', 'v2-front-fit-full'),
                (FrontFit.chest, 'Chest', 'v2-front-fit-chest'),
                (FrontFit.none, 'None', 'v2-front-fit-none'),
              ])
                Expanded(
                  child: _ModeCard(
                    itemKey: Key(key),
                    label: label,
                    selected: controller.frontFit == fit,
                    // The diagram is drawn from the engine's own print rect, so
                    // it shows where the artwork will actually land.
                    area: controller.frontPrintRectFor(fit),
                    onTap: () => controller.setFrontFit(fit),
                  ),
                ),
            ],
          ),
        ),
        if (controller.frontFit == FrontFit.chest)
          _card(
            icon: Icons.swap_horiz_rounded,
            title: 'Chest side',
            helper: 'Which side of the chest the badge sits on.',
            child: _chips(const [
              ('v2-front-chest-left', 'Left', false),
              ('v2-front-chest-right', 'Right', true),
            ], controller.chestRight, controller.setChestSide),
          ),
        if (_prints)
          _card(
            icon: Icons.auto_awesome_motion_outlined,
            title: 'Front artwork',
            helper: 'What the front is made from.',
            child: Column(
              children: [
                for (final (art, label, helper, key) in const [
                  (
                    FrontArt.ribbon,
                    'Ribbon',
                    'A row of your flags.',
                    'v2-front-art-ribbon',
                  ),
                  (
                    FrontArt.complement,
                    'Complement',
                    'A companion design to the back.',
                    'v2-front-art-complement',
                  ),
                  (
                    FrontArt.matchBack,
                    'Match back',
                    'The same artwork as the back.',
                    'v2-front-art-matchback',
                  ),
                ])
                  _ArtRow(
                    itemKey: Key(key),
                    label: label,
                    helper: helper,
                    selected: controller.frontArt == art,
                    onTap: () => controller.setFrontArt(art),
                  ),
              ],
            ),
          ),
        // Only a ribbon has a country list to widen — the complement and the
        // match-back are both derived from the back and follow its countries.
        if (_prints && controller.frontArt == FrontArt.ribbon)
          _card(
            icon: Icons.public_rounded,
            title: 'Ribbon shows',
            helper: 'Changes the front ribbon only.',
            child: _chips(const [
              ('v2-front-ribbon-selected', 'Selected travels', false),
              ('v2-front-ribbon-all', 'All travelled', true),
            ], controller.ribbonAllCountries, controller.setRibbonCoverage),
          ),
        if (!_prints)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'The front is left blank — the back carries the design.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('v2-front-reset'),
          // Front only: the finished back is not this button's business.
          onPressed: controller.resetFront,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset front'),
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

  Widget _chips(
    List<(String, String, bool)> options,
    bool current,
    void Function(bool) onPick,
  ) => Row(
    children: [
      for (final (key, label, value) in options)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key(key),
              onTap: () => onPick(value),
              child: Semantics(
                button: true,
                selected: current == value,
                label: label,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: _pillDecoration(current == value),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          current == value
                              ? StudioV2Theme.accent
                              : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  static BoxDecoration _pillDecoration(bool selected) => BoxDecoration(
    color:
        selected
            ? StudioV2Theme.accent.withValues(alpha: 0.16)
            : StudioV2Theme.control,
    borderRadius: BorderRadius.circular(13),
    border: Border.all(
      color: selected ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
      width: selected ? 1.6 : 1,
    ),
  );

  Widget _card({
    required IconData icon,
    required String title,
    required String helper,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    helper,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// One of Full / Chest / None, shown as a little shirt with the print on it.
///
/// A word alone does not say where "Chest" puts the artwork; the diagram does,
/// and it is positioned from the same rect the printer is given.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.itemKey,
    required this.label,
    required this.selected,
    required this.area,
    required this.onTap,
  });

  final Key itemKey;
  final String label;
  final bool selected;
  final Rect area;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      key: itemKey,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              padding: const EdgeInsets.all(9),
              decoration: FrontWorkspace._pillDecoration(selected),
              child: AspectRatio(
                aspectRatio: 0.86,
                child: CustomPaint(
                  painter: _ShirtDiagram(
                    area: area,
                    ink:
                        selected
                            ? StudioV2Theme.accent
                            : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? StudioV2Theme.accent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A shirt outline with the print area filled — cheap enough to sit in a list
/// without touching the renderer, and honest because [area] is the engine's.
class _ShirtDiagram extends CustomPainter {
  const _ShirtDiagram({required this.area, required this.ink});

  final Rect area;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path();
    // A blunt tee silhouette: shoulders, sleeves, straight body.
    body.moveTo(w * 0.30, h * 0.02);
    body.lineTo(w * 0.70, h * 0.02);
    body.lineTo(w * 0.98, h * 0.20);
    body.lineTo(w * 0.84, h * 0.34);
    body.lineTo(w * 0.84, h * 0.98);
    body.lineTo(w * 0.16, h * 0.98);
    body.lineTo(w * 0.16, h * 0.34);
    body.lineTo(w * 0.02, h * 0.20);
    body.close();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ink,
    );

    if (area.isEmpty) return;
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          area.left * w,
          area.top * h,
          area.width * w,
          area.height * h,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = ink.withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShirtDiagram old) =>
      old.area != area || old.ink != ink;
}

/// One front-artwork option: what it is, and what it means, on one row.
class _ArtRow extends StatelessWidget {
  const _ArtRow({
    required this.itemKey,
    required this.label,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final Key itemKey;
  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      key: itemKey,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: FrontWorkspace._pillDecoration(selected),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selected ? StudioV2Theme.accent : Colors.white38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? StudioV2Theme.accent : Colors.white,
                      ),
                    ),
                    Text(
                      helper,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
