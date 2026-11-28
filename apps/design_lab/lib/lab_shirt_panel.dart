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
///
/// With [onLayoutChanged] it is also where a signature's default PRINT LAYOUT
/// is chosen (front/back zones and sizes): the same shared controls and
/// front/back/both preview as the app's product page, saved into the pack so
/// the app opens every tee on the layout approved here.
class LabShirtPanel extends StatefulWidget {
  const LabShirtPanel({
    super.key,
    required this.service,
    required this.recipe,
    this.title,
    this.width = 380,
    this.layout = PrintLayout.standard,
    this.onLayoutChanged,
  });

  /// Where the design prints.
  final PrintLayout layout;

  /// Makes the layout editable; null shows [layout] read-only.
  final ValueChanged<PrintLayout>? onLayoutChanged;

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
  late TeeView _view = TeeView.forLayout(widget.layout);
  bool _guides = false;

  @override
  void didUpdateWidget(covariant LabShirtPanel old) {
    super.didUpdateWidget(old);
    // Keep looking at a face that prints (undo, another pack).
    final side = _view.side;
    if (side != null && !widget.layout.prints(side)) {
      _view = TeeView.forLayout(widget.layout);
    }
  }

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
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TeeViewSwitcher(
            view: _view,
            layout: widget.layout,
            onChanged: (v) => setState(() => _view = v),
          ),
        ),
        Expanded(
          child: TeeBackdrop(
            garmentColour: _hex,
            child: recipe == null
                ? const Center(
                    child: Text('Nothing selected',
                        style: TextStyle(color: Colors.grey)))
                : TeeSidesPreview(
                    service: widget.service,
                    recipe: recipe,
                    layout: widget.layout,
                    view: _view,
                    onViewChanged: (v) => setState(() => _view = v),
                    garmentColour: _hex,
                    showGuides: _guides,
                  ),
          ),
        ),
        if (widget.onLayoutChanged case final onChanged?)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              key: const Key('lab-layout'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: PrintLayoutControls(
                layout: widget.layout,
                dense: true,
                onChanged: (l) {
                  setState(() => _guides = true);
                  onChanged(l);
                },
                onFocus: (side) => setState(() {
                  _guides = true;
                  if (_view != TeeView.both) _view = TeeView.of(side);
                }),
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
