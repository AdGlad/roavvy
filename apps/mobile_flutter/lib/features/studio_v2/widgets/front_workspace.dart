import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import 'garment_preview.dart';

/// **Front** workspace (M6) — configures the *complementary* shirt front. The
/// hero back stays the main design; the front is a supporting motif: a flag
/// ribbon, a matching complement, or the same artwork. Every control reads and
/// writes the shared [StudioController] Front state directly — no duplicated
/// widget state:
///  * **Placement** ([StudioController.frontFit]) — Full · Chest · None. None
///    prints nothing on the front.
///  * **Chest side** ([StudioController.chestRight]) — Left · Right, only when
///    the placement is Chest.
///  * **Artwork** ([StudioController.frontArt]) — Ribbon · Complement · Match
///    back. Only meaningful when something is printed (placement ≠ None).
///  * **Ribbon coverage** ([StudioController.ribbonAllCountries]) — the selected
///    travels vs every country, only when the artwork is a Ribbon.
///
/// A small shirt-front schematic previews the placement using the engine's own
/// [StudioController.frontPrintRect] geometry (chest left/right reflected, None
/// shows a blank front). The persistent Front/Back toggle in the bar above
/// switches the *hero* preview between the two real faces.
class FrontWorkspace extends StatelessWidget {
  const FrontWorkspace({super.key, required this.controller});

  final StudioController controller;

  bool get _prints => controller.frontFit != FrontFit.none;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('FRONT',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.4, color: Colors.tealAccent)),
          const SizedBox(height: 4),
          const Text('A complementary front for your hero back. Switch '
              'Front/Back in the bar above to preview each side.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FrontMockup(controller: controller),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _group('Placement', [
                      _seg('v2-front-fit-full', 'Full',
                          controller.frontFit == FrontFit.full,
                          () => controller.setFrontFit(FrontFit.full)),
                      _seg('v2-front-fit-chest', 'Chest',
                          controller.frontFit == FrontFit.chest,
                          () => controller.setFrontFit(FrontFit.chest)),
                      _seg('v2-front-fit-none', 'None',
                          controller.frontFit == FrontFit.none,
                          () => controller.setFrontFit(FrontFit.none)),
                    ]),
                    if (controller.frontFit == FrontFit.chest) ...[
                      const SizedBox(height: 10),
                      _group('Chest side', [
                        _seg('v2-front-chest-left', 'Left',
                            !controller.chestRight,
                            () => controller.setChestSide(false)),
                        _seg('v2-front-chest-right', 'Right',
                            controller.chestRight,
                            () => controller.setChestSide(true)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_prints) ...[
            _group('Front artwork', [
              _seg('v2-front-art-ribbon', 'Ribbon',
                  controller.frontArt == FrontArt.ribbon,
                  () => controller.setFrontArt(FrontArt.ribbon)),
              _seg('v2-front-art-complement', 'Complement',
                  controller.frontArt == FrontArt.complement,
                  () => controller.setFrontArt(FrontArt.complement)),
              _seg('v2-front-art-matchback', 'Match back',
                  controller.frontArt == FrontArt.matchBack,
                  () => controller.setFrontArt(FrontArt.matchBack)),
            ]),
            if (controller.frontArt == FrontArt.ribbon) ...[
              const SizedBox(height: 10),
              _group('Ribbon shows', [
                _seg('v2-front-ribbon-selected', 'Selected travels',
                    !controller.ribbonAllCountries,
                    () => controller.setRibbonCoverage(false)),
                _seg('v2-front-ribbon-all', 'All travelled',
                    controller.ribbonAllCountries,
                    () => controller.setRibbonCoverage(true)),
              ]),
            ],
          ] else
            const Text('The front is left blank — the back carries the design.',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _group(String label, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 1.2, color: Colors.white38)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: children),
        ],
      );

  Widget _seg(String id, String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        key: Key(id),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.tealAccent.withValues(alpha: 0.2)
                : const Color(0xFF23262C),
            border: Border.all(
                color: selected ? Colors.tealAccent : const Color(0xFF3A3D44)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.tealAccent : Colors.white70)),
        ),
      );
}

/// A small shirt-front schematic that places a thumbnail of the front design
/// using the engine's [StudioController.frontPrintRect] fractions, so chest
/// left/right and a blank (None) front are reflected without hard-coded
/// coordinates.
class _FrontMockup extends StatelessWidget {
  const _FrontMockup({required this.controller});

  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final rect = controller.frontPrintRect();
    const w = 120.0;
    const h = 140.0;
    return Container(
      key: const Key('v2-front-mockup'),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E24),
        border: Border.all(color: const Color(0xFF3A3D44)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: rect.isEmpty
          ? const Center(
              child: Text('Blank\nfront',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            )
          : Stack(children: [
              Positioned(
                left: rect.left * w,
                top: rect.top * h,
                width: rect.width * w,
                height: rect.height * h,
                child: GarmentPreview(
                    service: controller.service,
                    recipe: controller.frontFace,
                    longSide: 220),
              ),
            ]),
    );
  }
}
