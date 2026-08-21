import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'multi_flag_layout.dart';
import 'render_stage.dart';

/// Builds the artwork layer (transparent background) from the recipe's flags.
///  * 1 flag / `singleHero` → the flag, aspect-fit (or cover-bleed under a clip).
///  * exactly 2 flags with a [FlagCombination] → the two flags merged by a
///    split/diagonal/vertical/horizontal region.
///  * otherwise → N flag instances packed by the composition's [FillAlgorithm]
///    (grid / treemap / diagonal / voronoi / torn / noise / radial / mosaic),
///    delegated to [MultiFlagLayout].
class CompositionStage extends RenderStage {
  const CompositionStage();

  @override
  String get id => 'composition';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final flags = recipe.content.flags;
    if (flags.isEmpty) return;

    final w = ctx.width.toDouble();
    final h = ctx.height.toDouble();
    final frame = ui.Rect.fromLTWH(0, 0, w, h);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    // Resolve each distinct flag once.
    final images = <String, ui.Image>{};
    for (final f in flags) {
      images[f.code] ??= await ctx.assets.resolveFlag(
        f.code,
        width: ctx.width,
        height: ctx.height,
      );
    }

    final combo = recipe.flagCombination;
    final isSingle =
        flags.length == 1 || recipe.composition.family == DesignFamily.singleHero;

    // Bleed to the frame when a clip or torn edge will carve the outline.
    final bleed = recipe.edgeTreatment != null || recipe.clip != null;

    if (isSingle) {
      ctx.artwork = await ctx.rasterise((canvas) {
        if (bleed) {
          _drawImageCover(canvas, images[flags.first.code]!, frame, paint);
        } else {
          _drawImageFitted(
              canvas, images[flags.first.code]!, _inset(frame, 0.08), paint);
        }
      });
      return;
    }

    if (flags.length == 2 && combo != null) {
      ctx.artwork = await ctx.rasterise((canvas) {
        _drawCombination(canvas, frame, images[flags[0].code]!,
            images[flags[1].code]!, combo, paint);
      });
      return;
    }

    // N instances → the chosen fitting algorithm (default grid).
    final algo = recipe.composition.fillAlgorithm ?? FillAlgorithm.grid;
    ctx.artwork =
        await MultiFlagLayout.compose(ctx, flags, images, algo, recipe.seed);
  }

  /// Draws the two flags into [frame], each clipped to a half defined by [combo].
  void _drawCombination(
    ui.Canvas canvas,
    ui.Rect frame,
    ui.Image a,
    ui.Image b,
    FlagCombination combo,
    ui.Paint paint,
  ) {
    final region = _splitPaths(frame, combo.mode);
    canvas
      ..save()
      ..clipPath(region.$1)
      ..drawImageRect(a, _src(a), frame, paint)
      ..restore()
      ..save()
      ..clipPath(region.$2)
      ..drawImageRect(b, _src(b), frame, paint)
      ..restore();
  }

  /// Two complementary clip paths for a split mode.
  (ui.Path, ui.Path) _splitPaths(ui.Rect r, FlagCombineMode mode) {
    switch (mode) {
      case FlagCombineMode.vertical:
        return (
          ui.Path()..addRect(ui.Rect.fromLTRB(r.left, r.top, r.center.dx, r.bottom)),
          ui.Path()..addRect(ui.Rect.fromLTRB(r.center.dx, r.top, r.right, r.bottom)),
        );
      case FlagCombineMode.horizontal:
        return (
          ui.Path()..addRect(ui.Rect.fromLTRB(r.left, r.top, r.right, r.center.dy)),
          ui.Path()..addRect(ui.Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom)),
        );
      case FlagCombineMode.diagonalSplit:
      default:
        final tl = ui.Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.left, r.bottom)
          ..close();
        final br = ui.Path()
          ..moveTo(r.right, r.top)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..close();
        return (tl, br);
    }
  }

  /// Aspect-fit (contain) an image into [rect], centred.
  void _drawImageFitted(
      ui.Canvas canvas, ui.Image img, ui.Rect rect, ui.Paint paint) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = rect.width / iw;
    final s = scale < rect.height / ih ? scale : rect.height / ih;
    final dw = iw * s;
    final dh = ih * s;
    final dst = ui.Rect.fromLTWH(
      rect.left + (rect.width - dw) / 2,
      rect.top + (rect.height - dh) / 2,
      dw,
      dh,
    );
    canvas.drawImageRect(img, _src(img), dst, paint);
  }

  /// Aspect-fill (cover) an image across [rect], centred, cropping overflow.
  void _drawImageCover(
      ui.Canvas canvas, ui.Image img, ui.Rect rect, ui.Paint paint) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final s = (rect.width / iw) > (rect.height / ih)
        ? rect.width / iw
        : rect.height / ih;
    final dw = iw * s;
    final dh = ih * s;
    final dst = ui.Rect.fromLTWH(
      rect.left + (rect.width - dw) / 2,
      rect.top + (rect.height - dh) / 2,
      dw,
      dh,
    );
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(img, _src(img), dst, paint);
    canvas.restore();
  }

  ui.Rect _src(ui.Image img) =>
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

  ui.Rect _inset(ui.Rect r, double frac) {
    final dx = r.width * frac;
    final dy = r.height * frac;
    return ui.Rect.fromLTRB(r.left + dx, r.top + dy, r.right - dx, r.bottom - dy);
  }
}
