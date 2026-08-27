import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

/// A per-axis **lock** toggle (M4). Locking an axis pins it so [Remix] leaves it
/// untouched — the "keep what I love" half of *keep what I love, remix the rest*.
/// Uses the shared [StudioController.toggleLock] / [StudioController.locked]
/// semantics directly; it adds no new state.
class AxisLockChip extends StatelessWidget {
  const AxisLockChip({
    super.key,
    required this.controller,
    required this.axis,
  });

  final StudioController controller;
  final DesignAxis axis;

  @override
  Widget build(BuildContext context) {
    final locked = controller.locked.contains(axis);
    return GestureDetector(
      key: Key('v2-lock-${axis.name}'),
      onTap: () => controller.toggleLock(axis),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: locked
              ? Colors.amber.withValues(alpha: 0.18)
              : const Color(0xFF23262C),
          border: Border.all(
              color: locked ? Colors.amber : const Color(0xFF3A3D44)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(locked ? Icons.lock : Icons.lock_open,
              size: 13, color: locked ? Colors.amber : Colors.white54),
          const SizedBox(width: 4),
          Text(locked ? 'Locked' : 'Lock',
              style: TextStyle(
                  fontSize: 11,
                  color: locked ? Colors.amber : Colors.white54)),
        ]),
      ),
    );
  }
}

/// **Remix** — re-roll every UNLOCKED axis at once ([StudioController.surprise]),
/// holding locked axes identical. The label makes the promise explicit:
/// *keep what I love, remix the rest*.
class RemixButton extends StatelessWidget {
  const RemixButton({super.key, required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.locked.length;
    return OutlinedButton.icon(
      key: const Key('v2-remix'),
      onPressed: controller.surprise,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.tealAccent,
        side: const BorderSide(color: Color(0xFF3A3D44)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      icon: const Icon(Icons.casino_outlined, size: 16),
      label: Text(n == 0 ? 'Remix' : 'Remix ($n kept)',
          style: const TextStyle(fontSize: 12)),
    );
  }
}
