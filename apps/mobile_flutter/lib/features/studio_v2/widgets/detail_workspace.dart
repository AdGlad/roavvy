import 'dart:math' as math;

import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';

/// **Direction Detail** — how the chosen Direction is expressed.
///
/// Contextual: the options come from [StudioController.detailChoices], which
/// reports what the engine can actually do for the Direction on screen. There
/// is no universal list, nothing is offered that the renderer cannot draw, and
/// a Direction with no sibling to choose between skips this step rather than
/// showing an empty one.
///
/// A subtype, not a set of dials — scatter, size and rotation belong to Fine
/// Tune, not here.
class DetailWorkspace extends StatelessWidget {
  const DetailWorkspace({super.key, required this.controller});

  final StudioController controller;

  /// The question, in the vocabulary of the Direction being refined.
  static (String, String) questionFor(String direction) => switch (direction) {
    'Flags' => (
      'What style of flags?',
      'Choose how the country flags are used in your design.',
    ),
    'Passport' => (
      'How should the stamps sit?',
      'Choose how your travel stamps are arranged.',
    ),
    'Route' => (
      'How should the journey read?',
      'Choose how your trips are drawn.',
    ),
    'Milestones' => (
      'Which achievements lead?',
      'Choose how your travel milestones are shown.',
    ),
    _ => ('How should this look?', 'Choose how this direction is expressed.'),
  };

  @override
  Widget build(BuildContext context) {
    final choices = controller.detailChoices;
    final (question, helper) = questionFor(controller.subjectLabel);
    final codes = controller.selectedCountryCodes.toList();
    final current = controller.currentDetailId;
    return CustomScrollView(
      key: const Key('v2-detail-scroll'),
      slivers: [
        SliverToBoxAdapter(child: _heading(question, helper)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: choices.length,
            itemBuilder: (context, i) {
              final c = choices[i];
              return _DetailCard(
                choice: c,
                selected: c.id == current,
                codes: codes,
                onTap: () => controller.applyDetailChoice(c.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _heading(String question, String helper) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: StudioV2Theme.accent,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '3',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Direction Detail',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          question,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white54,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.choice,
    required this.selected,
    required this.codes,
    required this.onTap,
  });

  final DetailChoice choice;
  final bool selected;
  final List<String> codes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('v2-detail-${choice.id}'),
    onTap: onTap,
    child: Semantics(
      button: true,
      selected: selected,
      label: '${choice.title} — ${choice.subtitle}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: StudioV2Theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: StudioV2Theme.accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                  ]
                  : null,
        ),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          children: [
            Expanded(
              child: Center(child: _DetailArt(id: choice.id, codes: codes)),
            ),
            const SizedBox(height: 10),
            Text(
              choice.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              choice.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What each Detail produces, shown with the traveller's own flags wherever the
/// choice is about arranging them — the card is the option, not a label for it.
class _DetailArt extends StatelessWidget {
  const _DetailArt({required this.id, required this.codes});

  final String id;
  final List<String> codes;

  @override
  Widget build(BuildContext context) => switch (id) {
    'grid' => _Tiled(codes: codes, perRow: 3, take: 9),
    'circle' => _Clipped(codes: codes, clipper: const _CircleClip()),
    'heart' => _Clipped(codes: codes, clipper: const _HeartClip()),
    'map' => _Clipped(codes: codes, clipper: const _MapClip()),
    'animals' => const _Glyph(Icons.pets_rounded),
    'plants' => const _Glyph(Icons.local_florist_rounded),
    'landmarks' => const _Glyph(Icons.account_balance_rounded),
    'passportPage' => _StampPage(codes: codes),
    'passportStampOutline' => _SingleStamp(codes: codes),
    'journeys' => const _Glyph(Icons.route_rounded),
    'timeline' => const _Glyph(Icons.timeline_rounded),
    'badge' => const _Glyph(Icons.workspace_premium_rounded),
    'achievements' => const _Glyph(Icons.emoji_events_rounded),
    'stats' => const _Glyph(Icons.insights_rounded),
    _ => const _Glyph(Icons.category_rounded),
  };
}

String _flagEmoji(String iso) {
  final code = iso.toUpperCase();
  if (code.length != 2) return '🏳️';
  return String.fromCharCodes([
    0x1F1E6 + code.codeUnitAt(0) - 65,
    0x1F1E6 + code.codeUnitAt(1) - 65,
  ]);
}

/// A single strong symbol, tinted to the accent so the grid reads at a glance.
class _Glyph extends StatelessWidget {
  const _Glyph(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 44, color: StudioV2Theme.accent);
}

/// Their flags, laid out as this option would lay them out.
class _Tiled extends StatelessWidget {
  const _Tiled({required this.codes, required this.perRow, required this.take});
  final List<String> codes;
  final int perRow;
  final int take;

  @override
  Widget build(BuildContext context) {
    final show = codes.take(take).toList();
    if (show.isEmpty) {
      return const Icon(Icons.flag_rounded, size: 40, color: Colors.white30);
    }
    return SizedBox(
      width: perRow * 24.0,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: [
          for (final cc in show)
            Text(_flagEmoji(cc), style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

/// Their flags packed into the shape this option clips to.
class _Clipped extends StatelessWidget {
  const _Clipped({required this.codes, required this.clipper});
  final List<String> codes;
  final CustomClipper<Path> clipper;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 62,
    child: ClipPath(
      clipper: clipper,
      child: ColoredBox(
        color: Colors.white10,
        child: Center(child: _Tiled(codes: codes, perRow: 4, take: 16)),
      ),
    ),
  );
}

class _CircleClip extends CustomClipper<Path> {
  const _CircleClip();
  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _HeartClip extends CustomClipper<Path> {
  const _HeartClip();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w / 2, h * 0.95)
      ..cubicTo(-w * 0.25, h * 0.52, w * 0.16, -h * 0.12, w / 2, h * 0.28)
      ..cubicTo(w * 0.84, -h * 0.12, w * 1.25, h * 0.52, w / 2, h * 0.95)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// A landmass-ish blob — enough to read as "in the shape of a country".
class _MapClip extends CustomClipper<Path> {
  const _MapClip();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path()..moveTo(w * 0.10, h * 0.42);
    p.cubicTo(w * 0.18, h * 0.10, w * 0.52, h * 0.02, w * 0.66, h * 0.22);
    p.cubicTo(w * 0.98, h * 0.28, w * 0.92, h * 0.62, w * 0.72, h * 0.70);
    p.cubicTo(w * 0.66, h * 0.98, w * 0.30, h * 0.98, w * 0.24, h * 0.72);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// A passport spread: several stamps struck across the page.
class _StampPage extends StatelessWidget {
  const _StampPage({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final show = codes.take(4).toList();
    if (show.isEmpty) {
      return const _Glyph(Icons.menu_book_rounded);
    }
    return Container(
      width: 74,
      height: 62,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < show.length; i++)
            Transform.rotate(
              angle: (i.isEven ? -1 : 1) * 0.16,
              child: _stamp(show[i], 28, 20, 9),
            ),
        ],
      ),
    );
  }
}

/// One stamp, struck large.
class _SingleStamp extends StatelessWidget {
  const _SingleStamp({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const _Glyph(Icons.approval_rounded);
    return Transform.rotate(
      angle: -0.1,
      child: _stamp(codes.first, 62, 44, 16),
    );
  }
}

Widget _stamp(String code, double w, double h, double fontSize) => Container(
  width: w,
  height: h,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: StudioV2Theme.accent, width: 1.6),
    color: StudioV2Theme.accent.withValues(alpha: 0.16),
  ),
  child: Transform.rotate(
    angle: math.pi / 90,
    child: Text(
      code.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: StudioV2Theme.accent,
      ),
    ),
  ),
);
