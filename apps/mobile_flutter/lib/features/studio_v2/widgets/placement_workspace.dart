import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../../shared/garment_mockup/mockup_transform.dart';
import '../studio_v2_theme.dart';

/// **Placement** — where the print sits on the shirt.
///
/// The step deliberately has no canvas of its own. The hero above has shown
/// this garment since the first screen, and at this stage it simply becomes
/// live: drag to move the print, pinch to resize, twist to rotate, with the
/// artwork clipped to the real printable area. Putting a second shirt down here
/// would mean arranging one shirt while looking at another.
///
/// So this panel is what the hero cannot be — the instructions, the per-face
/// context, and the way back to centre.
class PlacementWorkspace extends StatelessWidget {
  const PlacementWorkspace({
    super.key,
    required this.controller,
    required this.placement,
  });

  final StudioController controller;

  /// The live placement for the face on screen, shared with the hero.
  final MockupTransformController placement;

  @override
  Widget build(BuildContext context) {
    final front = controller.onFront;
    final blank = front && controller.frontFit == FrontFit.none;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PLACEMENT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: StudioV2Theme.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            blank
                ? 'This shirt has no front print. Switch to the back, or give '
                    'the front artwork in the Front step.'
                : 'Arrange the print on the ${front ? 'front' : 'back'} — drag '
                    'to move, pinch to resize, twist to rotate. Where you leave '
                    'it is where it prints.',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (!blank)
            ValueListenableBuilder<MockupTransform>(
              valueListenable: placement.transform,
              builder: (context, t, _) {
                final moved = !t.isIdentity;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        moved
                            ? '${(t.scale * 100).round()}% · '
                                '${(t.rotation * 180 / 3.141592653589793).round()}°'
                            : 'Centred, at full size',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('v2-placement-reset'),
                      onPressed: moved ? placement.reset : null,
                      icon: const Icon(Icons.center_focus_strong, size: 18),
                      label: const Text('Recentre'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          const Text(
            'The front and back are arranged separately — switch faces above.',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
