import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'axis_controls.dart';

/// Direction chooses what the shirt is about. The controller behaviour is
/// unchanged; this widget only presents the six subjects as visual creative
/// choices rather than a settings-style icon grid.
class DirectionWorkspace extends StatefulWidget {
  const DirectionWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<DirectionWorkspace> createState() => _DirectionWorkspaceState();
}

class _DirectionWorkspaceState extends State<DirectionWorkspace> {
  bool _showOptions = false;
  StudioController get controller => widget.controller;

  static const _descriptions = <String>[
    'Your flags, arranged as the hero',
    'Stamps and marks from the journey',
    'A route-led travel story',
    'Your travels across the world',
    'Let the words lead the design',
    'Celebrate how far you’ve travelled',
  ];

  @override
  Widget build(BuildContext context) {
    final subjects = StudioController.subjects;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What should lead the design?',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Choose the idea that feels most like your trip.',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showOptions = !_showOptions),
                child: Text(_showOptions ? 'Done' : 'Options'),
              ),
            ],
          ),
          if (_showOptions) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: AxisLockChip(
                  controller: controller, axis: DesignAxis.direction),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final width = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < subjects.length; i++)
                    SizedBox(
                      width: width,
                      child: _DirectionCard(
                        key: Key('v2-direction-$i'),
                        index: i,
                        label: subjects[i].$3,
                        description: _descriptions[i],
                        selected: controller.subjectIndex == i,
                        onTap: () => controller.selectSubject(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    super.key,
    required this.index,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 132,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.tealAccent.withValues(alpha: 0.10)
                : const Color(0xFF1B1E24),
            border: Border.all(
              color: selected ? Colors.tealAccent : Colors.white10,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DirectionMotif(index: index, selected: selected)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 18, color: Colors.tealAccent),
                ],
              ),
              const SizedBox(height: 2),
              Text(description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.46))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionMotif extends StatelessWidget {
  const _DirectionMotif({required this.index, required this.selected});

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Colors.tealAccent : Colors.white54;
    final muted = selected ? Colors.tealAccent.withValues(alpha: .35) : Colors.white12;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(12),
      ),
      child: switch (index) {
        0 => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 22,
                  height: 30 + (i.isEven ? 8 : 0),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i.isEven ? accent : muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        1 => Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -.18,
                child: _stamp(accent.withValues(alpha: .5)),
              ),
              Transform.translate(
                offset: const Offset(22, 4),
                child: Transform.rotate(angle: .14, child: _stamp(accent)),
              ),
            ],
          ),
        2 => CustomPaint(
            painter: _RoutePainter(accent),
            child: const SizedBox.expand(),
          ),
        3 => Center(
            child: Icon(Icons.public_rounded, size: 54, color: accent),
          ),
        4 => Center(
            child: Text('ROAM',
                style: TextStyle(
                    color: accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
        _ => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_rounded, color: muted, size: 26),
              const SizedBox(width: 8),
              Text('12',
                  style: TextStyle(
                      color: accent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Icon(Icons.location_on_rounded, color: muted, size: 26),
            ],
          ),
      },
    );
  }

  Widget _stamp(Color colour) => Container(
        width: 48,
        height: 38,
        decoration: BoxDecoration(
          border: Border.all(color: colour, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.flight_rounded, size: 18, color: colour),
      );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .16, size.height * .7)
      ..cubicTo(size.width * .32, size.height * .1, size.width * .58,
          size.height * .88, size.width * .84, size.height * .3);
    canvas.drawPath(path, paint);
    final dot = Paint()..color = colour;
    canvas.drawCircle(Offset(size.width * .16, size.height * .7), 5, dot);
    canvas.drawCircle(Offset(size.width * .84, size.height * .3), 5, dot);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.colour != colour;
}
