import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'axis_controls.dart';

/// **Direction** workspace (M3) — pick what the shirt is *about*. A compact,
/// visual row of the six storyboard subjects (Flags / Passport / Route / World /
/// Words / Milestones) driven entirely by the shared [StudioController]
/// ([StudioController.subjects] + [StudioController.selectSubject]). Selecting a
/// subject regenerates the live preview immediately while preserving the travel
/// selection and Tier-1 garment state — the shirt above stays the hero; only
/// this lower strip changes.
class DirectionWorkspace extends StatelessWidget {
  const DirectionWorkspace({super.key, required this.controller});

  final StudioController controller;

  static const _icons = <IconData>[
    Icons.flag_outlined, // Flags
    Icons.menu_book_outlined, // Passport
    Icons.route_outlined, // Route
    Icons.public, // World
    Icons.title, // Words
    Icons.emoji_events_outlined, // Milestones
  ];

  @override
  Widget build(BuildContext context) {
    final subjects = StudioController.subjects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          const Expanded(
            child: Text('DIRECTION',
                style: TextStyle(
                    fontSize: 11, letterSpacing: 1.4, color: Colors.tealAccent)),
          ),
          AxisLockChip(controller: controller, axis: DesignAxis.direction),
        ]),
        const SizedBox(height: 4),
        const Text('Pick what your shirt is about.',
            style: TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < subjects.length; i++)
              _DirectionChip(
                key: Key('v2-direction-$i'),
                icon: _icons[i],
                label: subjects[i].$3,
                selected: controller.subjectIndex == i,
                onTap: () => controller.selectSubject(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF23262C),
          border: Border.all(
              color: selected ? accent : const Color(0xFF3A3D44),
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22, color: selected ? accent : Colors.white70),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? accent : Colors.white70)),
          ],
        ),
      ),
    );
  }
}
