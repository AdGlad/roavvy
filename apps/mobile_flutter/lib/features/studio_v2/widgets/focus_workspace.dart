import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'alternatives_tray.dart';
import 'axis_controls.dart';

/// Focus edits composition only. Layout alternatives remain the primary action;
/// lock/remix stay available as optional expert tools.
class FocusWorkspace extends StatefulWidget {
  const FocusWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<FocusWorkspace> createState() => _FocusWorkspaceState();
}

class _FocusWorkspaceState extends State<FocusWorkspace> {
  bool _showOptions = false;
  StudioController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Pick the layout',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Try a few arrangements without changing your style.',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('v2-focus-options'),
                onPressed: () => setState(() => _showOptions = !_showOptions),
                child: Text(_showOptions ? 'Done' : 'Options'),
              ),
            ],
          ),
          if (_showOptions) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AxisLockChip(controller: controller, axis: DesignAxis.focus),
                const SizedBox(width: 8),
                RemixButton(controller: controller),
              ],
            ),
          ],
          const SizedBox(height: 12),
          AlternativesTray(
            controller: controller,
            axis: DesignAxis.focus,
            label: 'Choose a layout',
          ),
        ],
      ),
    );
  }
}
