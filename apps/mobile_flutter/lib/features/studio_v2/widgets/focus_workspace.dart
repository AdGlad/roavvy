import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'alternatives_tray.dart';
import 'axis_controls.dart';

/// **Focus** workspace (M4) — composition / emphasis alternatives for the CURRENT
/// Direction + Detail + Vibe. Focus is the [DesignAxis.focus] axis
/// (orientation · density · layout · how the flags merge), so this reuses the
/// shared [AlternativesTray] over that axis rather than adding new controller
/// state: each option is a real, deterministic re-roll of only the composition,
/// leaving the subject and finish intact. Labels stay plain-language ("How it's
/// arranged") for non-designers.
///
/// Includes the per-axis lock and the global Remix so Focus can be pinned while
/// the rest is re-rolled (keep what I love, remix the rest). The shirt above
/// stays the hero.
class FocusWorkspace extends StatelessWidget {
  const FocusWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(
              child: Text('FOCUS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: Colors.tealAccent)),
            ),
            AxisLockChip(controller: controller, axis: DesignAxis.focus),
            const SizedBox(width: 8),
            RemixButton(controller: controller),
          ]),
          const SizedBox(height: 4),
          const Text('How it’s arranged — tap a layout you like.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          AlternativesTray(
            controller: controller,
            axis: DesignAxis.focus,
            label: 'Layouts',
          ),
        ],
      ),
    );
  }
}
