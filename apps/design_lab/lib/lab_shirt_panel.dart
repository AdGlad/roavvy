import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart' show QaThresholds;
import 'package:design_studio/design_studio.dart';
import 'package:design_studio/garment_mockup.dart';
import 'package:flutter/material.dart';

/// The design on the actual t-shirt — the far-right panel of the Lab screens.
///
/// This is the mobile app's own [ShirtPreview], from the shared
/// `design_studio` package: the same garment photo, recolouring, fold shading
/// and [FabricPrint] bake (displacement, light, weave). A change to the mockup
/// in either host shows up in both, and what is approved here looks the way
/// the traveller will see it in the purchase flow.
class LabShirtPanel extends StatefulWidget {
  const LabShirtPanel({
    super.key,
    required this.service,
    required this.recipe,
    this.title,
    this.width = 380,
  });

  final RenderService service;

  /// The design to show; null shows an empty panel.
  final DesignRecipe? recipe;

  /// Shown above the shirt (e.g. the country being inspected).
  final String? title;

  final double width;

  /// Points the shared garment loader at the mobile app's bundled photography
  /// on disk ([mobileAssets] = `apps/mobile_flutter/assets`), so the Lab uses
  /// the very same photos instead of a copy that could drift.
  static void useMobileAssets(Directory mobileAssets) {
    final root = mobileAssets.parent.path; // asset paths start with `assets/`
    StudioGarments.loadBytes = (path) => File('$root/$path').readAsBytes();
  }

  @override
  State<LabShirtPanel> createState() => _LabShirtPanelState();
}

class _LabShirtPanelState extends State<LabShirtPanel> {
  /// The garments the shop can actually print and ship.
  static const _garments = QaThresholds.orderableGarments;

  int _garment = 0;
  bool _front = true;

  String get _hex {
    final c = _garments[_garment].$1.toARGB32() & 0xFFFFFF;
    return '#${c.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return SizedBox(
      width: widget.width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            Expanded(
              child: Text(widget.title ?? 'On the shirt',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: true, label: Text('Front')),
                ButtonSegment(value: false, label: Text('Back')),
              ],
              selected: {_front},
              onSelectionChanged: (s) => setState(() => _front = s.first),
            ),
          ]),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF1A1C21),
            padding: const EdgeInsets.all(8),
            child: recipe == null
                ? const Center(
                    child: Text('Nothing selected',
                        style: TextStyle(color: Colors.white38)))
                : ShirtPreview(
                    service: widget.service,
                    recipe: recipe,
                    front: _front,
                    garmentColour: _hex,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < _garments.length; i++)
              Tooltip(
                message: _garments[i].$2,
                child: InkWell(
                  onTap: () => setState(() => _garment = i),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _garments[i].$1,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _garment ? Colors.blueAccent : Colors.white24,
                        width: i == _garment ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
