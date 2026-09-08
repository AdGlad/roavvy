import 'dart:math' as math;

import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../../core/country_names.dart';
import '../studio_v2_theme.dart';

/// **Direction** — what the shirt is about.
///
/// Six choices, shown as the thing they make rather than named in the
/// engine's vocabulary. Each card is drawn from the traveller's OWN countries
/// where that is possible — their flags, their place names — so the grid shows
/// six versions of their trip rather than six stock illustrations.
///
/// No garment here. Direction redraws the artwork wholesale, so a preview
/// would spend the screen showing the design about to be replaced; the cards
/// themselves are the preview.
class DirectionWorkspace extends StatelessWidget {
  const DirectionWorkspace({super.key, required this.controller});

  final StudioController controller;

  /// The six Directions, in the order the storyboard shows them, each bound to
  /// the existing engine subject at the same index — there is no second
  /// Direction model.
  static const List<(String, String)> copy = [
    ('Flags', 'Your country flags'),
    ('Passport', 'Stamps of travel'),
    ('Route', 'Your journeys'),
    ('World', 'Global perspective'),
    ('Words', 'Typography art'),
    ('Milestones', 'Your achievements'),
  ];

  @override
  Widget build(BuildContext context) {
    final codes = controller.selectedCountryCodes.toList();
    return CustomScrollView(
      key: const Key('v2-direction-scroll'),
      slivers: [
        SliverToBoxAdapter(child: _heading()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: copy.length,
            itemBuilder: (context, i) {
              final (title, subtitle) = copy[i];
              return _DirectionCard(
                index: i,
                title: title,
                subtitle: subtitle,
                selected: controller.subjectLabel == title,
                codes: codes,
                onTap: () => controller.selectSubject(i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _heading() => Padding(
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
                '2',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Direction',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'What should lead the design?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose the main creative direction for your shirt. '
          'You can refine your choice in the next step.',
          style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.35),
        ),
      ],
    ),
  );
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.codes,
    required this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool selected;
  final List<String> codes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('v2-direction-${title.toLowerCase()}'),
    onTap: onTap,
    child: Semantics(
      button: true,
      selected: selected,
      label: '$title — $subtitle',
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
            Expanded(child: Center(child: _art(index, codes))),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );

  /// What this Direction makes, drawn from the traveller's own countries where
  /// there are any. Cheap by construction: emoji, text and two small painters,
  /// so a grid of six costs no image decode and repaints on selection alone.
  static Widget _art(int index, List<String> codes) => switch (index) {
    0 => _FlagGrid(codes: codes),
    1 => _StampGrid(codes: codes),
    2 => const _RouteArt(),
    3 => const _WorldArt(),
    4 => _WordsArt(codes: codes),
    _ => const _MilestonesArt(),
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

/// Their flags, tiled — the design this Direction actually produces.
class _FlagGrid extends StatelessWidget {
  const _FlagGrid({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final show = codes.take(12).toList();
    if (show.isEmpty) {
      return const Icon(Icons.flag_rounded, size: 40, color: Colors.white30);
    }
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: [
        for (final cc in show)
          Text(_flagEmoji(cc), style: const TextStyle(fontSize: 19)),
      ],
    );
  }
}

/// Their countries as inked passport stamps.
class _StampGrid extends StatelessWidget {
  const _StampGrid({required this.codes});
  final List<String> codes;

  static const _inks = [
    Color(0xFFC2452C),
    Color(0xFF2E6B57),
    Color(0xFF35618E),
    Color(0xFF8A5A2B),
    Color(0xFF6B3F73),
    Color(0xFF3F6B3F),
  ];

  @override
  Widget build(BuildContext context) {
    final show = codes.take(6).toList();
    if (show.isEmpty) {
      return const Icon(Icons.approval, size: 40, color: Colors.white30);
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < show.length; i++)
          Transform.rotate(
            angle: (i.isEven ? -1 : 1) * 0.12,
            child: Container(
              width: 34,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _inks[i % _inks.length].withValues(alpha: 0.9),
                  width: 1.4,
                ),
                color: _inks[i % _inks.length].withValues(alpha: 0.18),
              ),
              child: Text(
                show[i].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _inks[i % _inks.length],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A flight path between two points.
class _RouteArt extends StatelessWidget {
  const _RouteArt();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 74),
    painter: _RoutePainter(),
    child: const SizedBox.expand(),
  );
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final y = size.height * 0.62;
    path.moveTo(size.width * 0.14, y);
    path.cubicTo(
      size.width * 0.34,
      y - size.height * 0.55,
      size.width * 0.52,
      y + size.height * 0.30,
      size.width * 0.80,
      size.height * 0.22,
    );
    // A dashed trail, walked by hand — dash support is not built in.
    final metric = path.computeMetrics().first;
    final dashed = Path();
    var d = 0.0;
    while (d < metric.length) {
      dashed.addPath(
        metric.extractPath(d, math.min(d + 5, metric.length)),
        Offset.zero,
      );
      d += 9;
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
    // The pin at the destination.
    final pin = Offset(size.width * 0.80, size.height * 0.22);
    canvas.drawCircle(pin, 7, Paint()..color = StudioV2Theme.accent);
    canvas.drawCircle(pin, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A globe, ruled by its own meridians.
class _WorldArt extends StatelessWidget {
  const _WorldArt();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 74),
    painter: _WorldPainter(),
    child: const SizedBox.expand(),
  );
}

class _WorldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 3;
    final c = Offset(size.width / 2, size.height / 2);
    final line =
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r, line);
    // Latitudes, flattening towards the poles.
    for (final f in [-0.6, -0.25, 0.0, 0.25, 0.6]) {
      final dy = r * f;
      final rx = r * math.sqrt(1 - f * f);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, dy),
          width: rx * 2,
          height: r * 0.34,
        ),
        line,
      );
    }
    // Meridians.
    for (final f in [0.35, 0.72, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2 * f, height: r * 2),
        line,
      );
    }
    canvas.drawCircle(
      c.translate(r * 0.42, -r * 0.34),
      4,
      Paint()..color = StudioV2Theme.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Their places, set as type.
class _WordsArt extends StatelessWidget {
  const _WordsArt({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final cc in codes.take(4))
        (kCountryNames[cc.toUpperCase()] ?? cc.toUpperCase()).toUpperCase(),
    ];
    if (names.isEmpty) {
      return const Icon(Icons.title_rounded, size: 40, color: Colors.white30);
    }
    return FittedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < names.length; i++)
            Text(
              names[i],
              style: TextStyle(
                fontSize: 17,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: i.isOdd ? StudioV2Theme.accent : Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// The moments a trip is remembered by.
class _MilestonesArt extends StatelessWidget {
  const _MilestonesArt();

  static const _icons = [
    Icons.photo_camera_outlined,
    Icons.terrain_rounded,
    Icons.signpost_outlined,
    Icons.groups_outlined,
    Icons.park_outlined,
    Icons.explore_outlined,
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (var i = 0; i < _icons.length; i++)
        Icon(
          _icons[i],
          size: 24,
          color: i.isOdd ? StudioV2Theme.accent : Colors.white70,
        ),
    ],
  );
}
