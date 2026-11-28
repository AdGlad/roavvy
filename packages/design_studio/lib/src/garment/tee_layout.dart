import 'package:design_forge/design_forge.dart';
import 'package:flutter/material.dart';

import '../print_layout.dart';
import '../production_render.dart';
import '../render_service.dart';
import 'garment_mockup_spec.dart';
import 'shirt_preview.dart';
import 'studio_garments.dart';

/// Which face(s) of the shirt a [TeeSidesPreview] shows.
enum TeeView {
  front('Front'),
  back('Back'),
  both('Both');

  const TeeView(this.label);
  final String label;

  PrintSide? get side => switch (this) {
    TeeView.front => PrintSide.front,
    TeeView.back => PrintSide.back,
    TeeView.both => null,
  };

  static TeeView of(PrintSide side) =>
      side == PrintSide.front ? TeeView.front : TeeView.back;

  /// The view that shows what [layout] actually prints: the back when it
  /// prints there (the primary design), else the front.
  static TeeView forLayout(PrintLayout layout) =>
      layout.back != null ? TeeView.back : TeeView.front;
}

/// A design on the t-shirt, laid out by a [PrintLayout]: one face large
/// (swipe sideways to turn the shirt) or both faces side by side.
///
/// A face the layout doesn't print on shows a blank shirt, never the design
/// in a default spot — what is on screen is what will be printed. With
/// [showGuides] the zone's largest printable area is outlined, so the size
/// limit is visible while it is being chosen.
class TeeSidesPreview extends StatelessWidget {
  const TeeSidesPreview({
    super.key,
    required this.service,
    required this.recipe,
    required this.layout,
    this.backRecipe,
    this.view = TeeView.back,
    this.onViewChanged,
    this.garmentColour,
    this.longSide = 1024,
    this.showGuides = false,
    this.placeholder,
  });

  final RenderService service;

  /// The front's design — and the back's, unless [backRecipe] is given.
  final DesignRecipe recipe;
  final DesignRecipe? backRecipe;
  final PrintLayout layout;
  final TeeView view;

  /// Called when the traveller swipes to the other face. Null disables swipe.
  final ValueChanged<TeeView>? onViewChanged;

  /// `#RRGGBB`; null takes the recipe's own garment colour.
  final String? garmentColour;
  final int longSide;
  final bool showGuides;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (view == TeeView.both) {
      return Row(
        children: [
          for (final side in const [PrintSide.front, PrintSide.back])
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _face(context, side)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _caption(side),
                      key: Key('tee-face-caption-${side.name}'),
                      style: Theme.of(context).textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final side = view.side!;
    final face = _face(context, side);
    final onViewChanged = this.onViewChanged;
    if (onViewChanged == null) return face;
    return GestureDetector(
      key: const Key('tee-swipe'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0).abs() < 100) return;
        onViewChanged(
          side == PrintSide.front ? TeeView.back : TeeView.front,
        );
      },
      child: face,
    );
  }

  String _caption(PrintSide side) {
    final z = layout.on(side);
    final name = side == PrintSide.front ? 'Front' : 'Back';
    return z == null ? '$name · blank' : '$name · ${z.zone.label}';
  }

  Widget _face(BuildContext context, PrintSide side) {
    final front = side == PrintSide.front;
    final zone = layout.on(side);
    final shirtHex = garmentColour ?? recipe.palette?.garmentColour;
    final preview = ShirtPreview(
      key: Key('tee-face-${side.name}'),
      service: service,
      recipe: front ? recipe : (backRecipe ?? recipe),
      front: front,
      printArea: layout.mockupRect(side) ?? Rect.zero,
      longSide: longSide,
      garmentColour: garmentColour,
      placeholder: placeholder,
    );
    final guide =
        showGuides && zone != null
            ? layout.withScale(side, 1).mockupRect(side)
            : null;
    final mark = !front && layout.printsMark;
    if (guide == null && !mark) return preview;
    final shirt =
        (shirtHex == null ? null : StudioGarments.parseHex(shirtHex)) ??
        const Color(0xFF0E0E0E);
    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        IgnorePointer(
          child: CustomPaint(
            key: Key(
              guide != null ? 'tee-guide-${side.name}' : 'tee-overlay-${side.name}',
            ),
            painter: _FaceOverlayPainter(
              guide: guide,
              mark: mark ? PrintLayout.markMockupRect : null,
              markInk: BrandMark.inkFor(shirt).withValues(alpha: 0.92),
              photo:
                  front
                      ? BundledGarments.tintBaseFrontSize
                      : BundledGarments.tintBaseBackSize,
              colour: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        if (mark)
          // Findable in tests; the mark itself is painted above.
          const SizedBox.shrink(key: Key('tee-brand-mark')),
      ],
    );
  }
}

/// Over the contain-fitted photo: the Roavvy mark ([mark], drawn by the
/// print file's own [BrandMark]) and the zone's largest printable area
/// ([guide], dashed).
class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({
    required this.guide,
    required this.mark,
    required this.markInk,
    required this.photo,
    required this.colour,
  });

  final Rect? guide;
  final Rect? mark;
  final Color markInk;
  final Size photo;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final s = (size.width / photo.width) < (size.height / photo.height)
        ? size.width / photo.width
        : size.height / photo.height;
    final w = photo.width * s, h = photo.height * s;
    final g = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
    Rect onPhoto(Rect n) => Rect.fromLTWH(
      g.left + n.left * g.width,
      g.top + n.top * g.height,
      n.width * g.width,
      n.height * g.height,
    );
    if (mark != null) BrandMark.paint(canvas, onPhoto(mark!), markInk);
    if (guide == null) return;
    final r = onPhoto(guide!);
    final paint = Paint()
      ..color = colour.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        final e = t + dash < len ? t + dash : len;
        canvas.drawLine(a + dir * t, a + dir * e, paint);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_FaceOverlayPainter old) =>
      old.guide != guide ||
      old.mark != mark ||
      old.markInk != markInk ||
      old.photo != photo ||
      old.colour != colour;
}

/// Front / Back / Both, with a dot on each face that prints.
class TeeViewSwitcher extends StatelessWidget {
  const TeeViewSwitcher({
    super.key,
    required this.view,
    required this.layout,
    required this.onChanged,
  });

  final TeeView view;
  final PrintLayout layout;
  final ValueChanged<TeeView> onChanged;

  @override
  Widget build(BuildContext context) {
    final dot = Theme.of(context).colorScheme.primary;
    Widget label(TeeView v) {
      final prints = v.side != null && layout.prints(v.side!);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.label),
          if (prints) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
        ],
      );
    }

    return SegmentedButton<TeeView>(
      key: const Key('tee-view'),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final v in TeeView.values)
          ButtonSegment(
            value: v,
            label: KeyedSubtree(key: Key('tee-view-${v.name}'), child: label(v)),
          ),
      ],
      selected: {view},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// The print layout's controls: one-tap presets, then each face's zone and
/// size. Sizes are limited to the zone's printable area, and the size reads
/// out in inches so a chest crest and a full back are never confused.
///
/// [onFocus] is told which face was just edited, so the host can turn the
/// preview to it.
class PrintLayoutControls extends StatelessWidget {
  const PrintLayoutControls({
    super.key,
    required this.layout,
    required this.onChanged,
    this.onFocus,
    this.dense = false,
  });

  final PrintLayout layout;
  final ValueChanged<PrintLayout> onChanged;
  final ValueChanged<PrintSide>? onFocus;

  /// Tighter spacing, for the Lab's side panel.
  final bool dense;

  void _set(PrintLayout next, PrintSide? focus) {
    if (next != layout) onChanged(next);
    if (focus != null) onFocus?.call(focus);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final gap = dense ? 6.0 : 10.0;
    final density = dense ? VisualDensity.compact : VisualDensity.standard;
    final preset = layout.preset;

    Widget section(String title, {String? trailing}) => Padding(
      padding: EdgeInsets.only(top: gap, bottom: 4),
      child: Row(
        children: [
          Text(title, style: text.labelLarge),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                trailing,
                style: text.labelMedium?.copyWith(color: muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    Widget sideControls(PrintSide side) {
      final zp = layout.on(side);
      final other = side == PrintSide.front ? layout.back : layout.front;
      final name = side == PrintSide.front ? 'Front' : 'Back';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(name, trailing: zp == null ? 'nothing printed' : null),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final z in PrintZone.on(side))
                ChoiceChip(
                  key: Key('layout-zone-${side.name}-${z.name}'),
                  visualDensity: density,
                  label: Text(z.label),
                  selected: zp?.zone == z,
                  onSelected: (_) => _set(layout.withZone(side, z), side),
                ),
              ChoiceChip(
                key: Key('layout-zone-${side.name}-none'),
                visualDensity: density,
                label: const Text('None'),
                selected: zp == null,
                // The last printed face can't be cleared.
                onSelected:
                    other == null
                        ? null
                        : (_) => _set(layout.withZone(side, null), side),
              ),
            ],
          ),
          if (zp != null)
            Row(
              children: [
                SizedBox(
                  width: dense ? 36 : 40,
                  child: Text('Size', style: text.labelMedium),
                ),
                Expanded(
                  child: Slider(
                    key: Key('layout-size-${side.name}'),
                    min: zp.zone.minScale,
                    max: 1,
                    value: zp.scale,
                    onChanged: (v) => _set(layout.withScale(side, v), null),
                    onChangeStart: (_) => onFocus?.call(side),
                  ),
                ),
                Text(
                  layout.sizeLabel(side)!,
                  key: Key('layout-size-label-${side.name}'),
                  style: text.labelMedium,
                ),
              ],
            ),
          if (zp != null && zp.scale >= 0.999)
            Text(
              'Largest size for ${zp.zone.label.toLowerCase()}',
              style: text.bodySmall?.copyWith(color: muted),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        section('Print layout', trailing: preset == null ? 'Custom' : null),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in PrintLayoutPreset.values)
              ChoiceChip(
                key: Key('layout-preset-${p.name}'),
                visualDensity: density,
                label: Text(p.label),
                selected: preset == p,
                onSelected:
                    (_) => _set(
                      p.applyTo(layout),
                      p.backZone != null ? PrintSide.back : PrintSide.front,
                    ),
              ),
          ],
        ),
        sideControls(PrintSide.front),
        sideControls(PrintSide.back),
        Padding(
          padding: EdgeInsets.only(top: gap / 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Roavvy mark at back neck', style: text.labelLarge),
                    Text(
                      layout.markBlockedReason ??
                          (layout.brandMark
                              ? 'roavvy.com, small, below the collar'
                              : 'Off'),
                      key: const Key('layout-mark-note'),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('layout-mark'),
                value: layout.brandMark,
                onChanged:
                    (on) => _set(layout.withBrandMark(on), PrintSide.back),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
