import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/brush_edge.dart';
import 'render_stage.dart';

/// Paints two flags into brushed hearts when the recipe asks for it
/// ([DesignRecipe.heartPair]); a no-op otherwise. Replaces whatever the
/// composition drew (like the Brush Flag stage).
///
/// * Shared Heart (M210): one heart, A in the left lobe, B in the right,
///   meeting along the layout's seam.
/// * Twin Hearts (M211): two hearts side by side, tilted toward each other.
///
/// Each heart is a [BrushEdge.paintHatch] mask (scribbled stroke ends
/// spilling past the outline) filled with its flag. The flag is fitted by
/// [HeartPairLayout] and its edge pixels are extended past the flag, so a
/// spilled stroke carries the colour next to it. [BrushEdge.paintScratches]
/// distresses the result.
class HeartPairStage extends RenderStage {
  const HeartPairStage();

  @override
  String get id => 'heartPair';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final p = recipe.heartPair;
    final flags = recipe.content.flags;
    if (p == null || flags.length < 2) return;
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();
    final layout = HeartPairLayout.compute(p,
        width: w, height: h, a: flags[0].code, b: flags[1].code);

    final images = <ui.Image>[];
    final shaped = <bool>[];
    for (final s in layout.slots) {
      final img = await ctx.assets.resolveFlag(s.code,
          width: s.flagDest.width.round().clamp(16, 4096),
          height: s.flagDest.height.round().clamp(16, 4096));
      final isShaped = await _isShaped(img);
      shaped.add(isShaped);
      // Edge colours are extended past the flag, so trim the raster's rim
      // first (some flag art has a thin white margin baked in, e.g. Panama).
      images.add(isShaped ? img : await _trim(img));
    }
    final seed = DeterministicRng.hashString('heartPair:${recipe.seed}');
    final full = ui.Rect.fromLTWH(0, 0, w, h);

    ctx.artwork = await ctx.rasterise((canvas) {
      canvas.saveLayer(full, ui.Paint());
      for (final s in layout.slots) {
        final heart = _path(s.heart);
        final unit = math.max(s.heartBox.width, s.heartBox.height);
        // Twin hearts are painted separately; a shared heart's two halves
        // share one set of strokes.
        final strokeSeed = p.isTwin ? seed ^ (0x9E37 * (s.slot + 1)) : seed;
        canvas.save();
        _turn(canvas, s);
        canvas.saveLayer(full, ui.Paint());
        BrushEdge.paintHatch(canvas, heart,
            angleDeg: p.hatchAngle,
            width: p.hatchWidth * unit,
            spill: p.spill,
            tails: p.tails,
            streaks: p.streaks,
            frayed: p.frayed,
            seed: strokeSeed);
        if (p.crossHatch > 0) {
          BrushEdge.paintHatch(canvas, heart,
              angleDeg: p.hatchAngle + 70,
              width: p.hatchWidth * unit,
              spill: p.spill * p.crossHatch,
              tails: p.tails,
              streaks: 0,
              frayed: p.frayed,
              seed: strokeSeed ^ 0xC055);
        }
        canvas.saveLayer(full, ui.Paint()..blendMode = ui.BlendMode.srcIn);
        // A is painted across the whole heart and B over its side of the
        // seam, so the seam never shows a hairline gap.
        final region = s.region;
        if (region != null && s.slot > 0) canvas.clipPath(_path(region));
        _paintFlag(canvas, images[s.slot], s, unit, backed: shaped[s.slot]);
        canvas.restore();
        canvas.restore();
        canvas.restore();
      }
      // Scratches over the paint.
      for (final s in layout.slots) {
        if (!p.isTwin && s.slot > 0) break;
        canvas.save();
        _turn(canvas, s);
        BrushEdge.paintScratches(canvas, _path(s.heart),
            angleDeg: p.hatchAngle,
            amount: p.scratches,
            seed: seed ^ (0x51C7 * (s.slot + 1)));
        canvas.restore();
      }
      canvas.restore();
    });
  }

  /// Rotates [canvas] about the slot's pivot.
  static void _turn(ui.Canvas canvas, HeartSlot s) {
    if (s.rotationDeg == 0) return;
    final (px, py) = s.pivot;
    canvas
      ..translate(px, py)
      ..rotate(s.rotationDeg * math.pi / 180)
      ..translate(-px, -py);
  }

  /// The flag drawn into its fitted box, edge pixels extended outward. A
  /// non-rectangular flag ([backed], Nepal's pennant) sits on white, so the
  /// heart stays a heart.
  static void _paintFlag(
      ui.Canvas canvas, ui.Image img, HeartSlot s, double unit,
      {bool backed = false}) {
    final d = s.flagDest;
    final area = s.heartBox.inflate(unit * 0.35);
    final rect = ui.Rect.fromLTWH(area.left, area.top, area.width, area.height);
    if (backed) {
      canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    }
    final m = Float64List(16)
      ..[0] = d.width / img.width
      ..[5] = d.height / img.height
      ..[10] = 1
      ..[12] = d.left
      ..[13] = d.top
      ..[15] = 1;
    canvas.drawRect(
        rect,
        ui.Paint()
          ..shader = ui.ImageShader(
              img, ui.TileMode.clamp, ui.TileMode.clamp, m,
              filterQuality: ui.FilterQuality.high));
  }

  /// [img] without a 1.5% rim (at least 2 px) on every side.
  static Future<ui.Image> _trim(ui.Image img) {
    final ix = math.max(2.0, img.width * 0.015);
    final iy = math.max(2.0, img.height * 0.015);
    final w = math.max(1, (img.width - 2 * ix).round());
    final h = math.max(1, (img.height - 2 * iy).round());
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(
        img,
        ui.Rect.fromLTWH(ix, iy, img.width - 2 * ix, img.height - 2 * iy),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high);
    return rec.endRecording().toImage(w, h);
  }

  /// True when more than 2% of [img] is see-through (a pennant, not a
  /// rectangle).
  static Future<bool> _isShaped(ui.Image img) async {
    final data =
        await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = data!.buffer.asUint8List();
    var clear = 0, total = 0;
    for (var i = 3; i < px.length; i += 4 * 7) {
      total++;
      if (px[i] < 128) clear++;
    }
    return total > 0 && clear * 50 > total;
  }

  static ui.Path _path(List<(double, double)> pts) {
    final path = ui.Path();
    for (var i = 0; i < pts.length; i++) {
      final (x, y) = pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }
}
