import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'alternatives_tray.dart';
import 'axis_controls.dart';
import 'garment_preview.dart';

/// Vibe remains a live, current-design style selector. Expert tools are kept
/// intact but disclosed on demand so the default experience stays visual.
class VibeWorkspace extends StatefulWidget {
  const VibeWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<VibeWorkspace> createState() => _VibeWorkspaceState();
}

class _VibeWorkspaceState extends State<VibeWorkspace> {
  bool _showOptions = false;
  StudioController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final options = controller.vibeStyleOptions();
    final current = controller.currentStyle;
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
                    Text('Choose a vibe',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Same travels. A completely different feel.',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              TextButton(
                key: const Key('v2-vibe-options'),
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
                AxisLockChip(controller: controller, axis: DesignAxis.vibe),
                const SizedBox(width: 8),
                RemixButton(controller: controller),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final (style, styled) = options[i];
                return _VibeCard(
                  key: Key('v2-vibe-${style.name}'),
                  service: controller.service,
                  recipe: styled,
                  label: style.label,
                  selected: current == style,
                  onTap: () {
                    controller.onStyleTap(style, styled);
                    controller.focusAxis(DesignAxis.vibe);
                  },
                );
              },
            ),
          ),
          if (_showOptions) ...[
            const SizedBox(height: 16),
            AlternativesTray(
              controller: controller,
              axis: DesignAxis.vibe,
              label: 'More like this',
            ),
          ],
        ],
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    super.key,
    required this.service,
    required this.recipe,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RenderService service;
  final DesignRecipe recipe;
  final String label;
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
          width: 116,
          decoration: BoxDecoration(
            color: selected
                ? Colors.tealAccent.withValues(alpha: 0.10)
                : const Color(0xFF1B1E24),
            border: Border.all(
                color: selected ? Colors.tealAccent : Colors.white10,
                width: selected ? 1.6 : 1),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(7),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GarmentPreview(
                      service: service, recipe: recipe, longSide: 220),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: Colors.white)),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.tealAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
