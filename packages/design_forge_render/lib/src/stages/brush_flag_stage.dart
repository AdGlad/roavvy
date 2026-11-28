import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/brush_edge.dart';
import 'render_stage.dart';

/// Paints the recipe's first flag as one broad dry-brush stroke when the
/// recipe asks for it ([DesignRecipe.brushStroke]); a no-op otherwise.
///
/// The stroke is a landscape block in the flag's own aspect (clamped to
/// [BrushStroke.minAspect]…[BrushStroke.maxAspect]), [BrushStroke.scale] of the
/// canvas wide and centred at [BrushStroke.centerY], so a caption fits above.
/// Its edges are brushed by [BrushEdge] and the whole stroke is turned by
/// [BrushStroke.skew]. It replaces whatever the composition drew.
class BrushFlagStage extends RenderStage {
  const BrushFlagStage();

  @override
  String get id => 'brushFlag';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final p = recipe.brushStroke;
    if (p == null || recipe.content.flags.isEmpty) return;
    final code = recipe.content.flags.first.code;
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();

    final probe = await ctx.assets.resolveFlag(code, width: 600, height: 600);
    // A non-rectangular flag (Nepal's pennant) keeps its own shape and
    // aspect: the brush roughens the pennant's outline instead.
    final opaque = await _opaqueBounds(probe);
    final shaped = opaque != null;
    final native = shaped
        ? opaque.width /
            math.max(1e-6, opaque.height) *
            probe.width /
            probe.height
        : probe.width / math.max(1, probe.height);
    final aspect =
        shaped ? native : native.clamp(p.minAspect, p.maxAspect).toDouble();
    var bw = w * p.scale.clamp(0.2, 1.0);
    var bh = bw / aspect;
    final maxH = h * 0.68;
    if (bh > maxH) {
      bh = maxH;
      bw = bh * aspect;
    }
    final box = ui.Rect.fromCenter(
        center: ui.Offset(w / 2, h * p.centerY.clamp(0.2, 0.8)),
        width: bw,
        height: bh);

    final flag = await ctx.assets.resolveFlag(code,
        width: bw.round().clamp(16, 4096), height: bh.round().clamp(16, 4096));
    final painted = await ctx.rasterise((canvas) {
      final fw = flag.width.toDouble(), fh = flag.height.toDouble();
      canvas.drawImageRect(
          flag,
          opaque == null
              ? ui.Rect.fromLTWH(0, 0, fw, fh)
              : ui.Rect.fromLTRB(opaque.left * fw, opaque.top * fh,
                  opaque.right * fw, opaque.bottom * fh),
          box,
          ui.Paint()..filterQuality = ui.FilterQuality.high);
    });

    final seed = DeterministicRng.hashString('brushStroke:${recipe.seed}');
    final brushed = await BrushEdge.brushArtwork(painted, p, seed);
    if (p.skew == 0) {
      ctx.artwork = brushed;
      return;
    }
    ctx.artwork = await ctx.rasterise((canvas) {
      canvas
        ..translate(box.center.dx, box.center.dy)
        // Canvas y points down: negative angle = anticlockwise on screen.
        ..rotate(-p.skew * math.pi / 180)
        ..translate(-box.center.dx, -box.center.dy)
        ..drawImage(brushed, ui.Offset.zero,
            ui.Paint()..filterQuality = ui.FilterQuality.high);
    });
  }

  /// For a noticeably transparent (non-rectangular) flag, the bounds of its
  /// opaque pixels as fractions of the image; null for a rectangular flag.
  static Future<ui.Rect?> _opaqueBounds(ui.Image img) async {
    final data =
        await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = data!.buffer.asUint8List();
    final w = img.width, h = img.height;
    var transparent = 0, total = 0;
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        total++;
        if (px[(y * w + x) * 4 + 3] < 128) {
          transparent++;
        } else {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (transparent * 50 < total || x1 < 0) return null;
    return ui.Rect.fromLTRB(x0 / w, y0 / h, (x1 + 1) / w, (y1 + 1) / h);
  }
}
