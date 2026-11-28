import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/wear_raster.dart';
import '../qa/pair_qa.dart';
import 'render_stage.dart';

/// Composition for [DesignFamily.splitPair]: two flags in one block meeting
/// along a seam ([SplitPair], ADR-185 §5). The layout (block, seam, each
/// flag's crop) is [SplitPairLayout] — the same maths pair QA reads through
/// [PairGeometry] — so what is checked is what is drawn.
///
/// Steps: place both flags, add a garment-colour channel when they look
/// alike along the seam ([SplitPair.autoGap]), shade A along the seam, then
/// wear the block ([WearRaster.grunge]) off the UI isolate.
///
/// [SplitEdge.brush] is drawn as [SplitEdge.torn] until the dry-brush edge
/// (M208 `BrushEdge`) is wired in here — the hook is [_brushEdge].
class SplitPairComposer {
  const SplitPairComposer._();

  static bool handles(DesignFamily family) => family == DesignFamily.splitPair;

  static Future<void> build(DesignRecipe recipe, RenderContext ctx) async {
    final codes = recipe.content.flags;
    if (codes.length < 2 || recipe.splitPair == null) return;
    final w = ctx.width.toDouble(), h = ctx.height.toDouble();

    Future<double> aspectOf(String code) async {
      final probe = await ctx.assets.resolveFlag(code, width: 400, height: 400);
      return probe.width / probe.height;
    }

    final layout = SplitPairLayout.of(recipe, w, h,
        aspectA: await aspectOf(codes[0].code),
        aspectB: await aspectOf(codes[1].code));
    if (layout == null) return;
    final p = layout.params;

    // Each flag rasterised at its drawn size (native aspect, so 1:1).
    final images = <ui.Image>[];
    for (final f in layout.flags) {
      final iw = (f.rotated ? f.height : f.width).round();
      final ih = (f.rotated ? f.width : f.height).round();
      images.add(await ctx.assets.resolveFlag(f.code,
          width: math.max(1, iw), height: math.max(1, ih)));
    }

    final edges = [for (final img in images) await _EdgeColours.of(img)];
    // Vertical-stripe flags with nothing protected (France, Italy, Ireland)
    // are narrowed to show every stripe in their half instead of one colour.
    var flags = layout.flags;
    for (var k = 0; k < flags.length; k++) {
      final f = flags[k];
      if (f.rotated || FlagFocus.of(f.code).emblem != null) continue;
      if (!await _verticalStripes(images[k])) continue;
      final bl = layout.blockLeft, bw = layout.blockWidth;
      final xs = [for (final (x, _) in f.region) x];
      final l = f.slot == 0 ? bl : xs.reduce(math.min);
      final r = f.slot == 0 ? xs.reduce(math.max) : bl + bw;
      // Never wider than the flag was, never narrower than half of it.
      final w = math.max(f.width * 0.5, math.min(f.width, r - l));
      flags = [...flags]..[k] = SplitFlagPlacement(
          slot: f.slot,
          code: f.code,
          left: l,
          top: f.top,
          width: w,
          height: f.height,
          rotated: false,
          region: f.region);
    }
    Future<ui.Image> compose(double gap, double shadow) => ctx.rasterise(
        (canvas) => _draw(canvas, layout, flags, images, edges, gap, shadow));

    // Shared rule: a channel when the flags look alike where they meet.
    var gap = p.seamGap;
    if (gap <= 0 && p.autoGap > 0) {
      final probe = await compose(0, 0);
      final data =
          await probe.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final seam = PairSeam([
        for (final (x, y) in layout.seamPoints) (x / w, y / h),
      ]);
      final dist = PairQa.seamLegibility(
          data!.buffer.asUint8List(), probe.width, probe.height, seam);
      // Margin over the QA limit: wear lowers the contrast further.
      if (dist != null && dist < PairQa.minSeamDistance * 1.3) gap = p.autoGap;
    }

    var art = await compose(gap, p.shadow);

    if (p.edge == SplitEdge.brush) art = await _brushEdge(art, layout);

    final worn = p.edge != SplitEdge.clean ||
        p.distress > 0 ||
        p.scratches > 0 ||
        p.fade > 0;
    if (worn) {
      final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      final job = _Wear(
        rgba: bytes,
        w: art.width,
        h: art.height,
        left: layout.blockLeft,
        top: layout.blockTop,
        right: layout.blockLeft + layout.blockWidth,
        bottom: layout.blockTop + layout.blockHeight,
        edgeWear: p.edge == SplitEdge.clean ? 0 : p.edgeWear,
        distress: p.distress,
        scale: p.distressScale,
        scratches: p.scratches,
        fade: p.fade,
        seed: recipe.seed,
      );
      final out = await Isolate.run(job.run);
      art = await _decode(out, art.width, art.height);
    }
    ctx.artwork = art;
  }

  /// Hook for the dry-brush outer edge (M208). Until then the torn grunge
  /// edge is used.
  static Future<ui.Image> _brushEdge(
          ui.Image art, SplitPairLayout layout) async =>
      art;

  static void _draw(
      ui.Canvas canvas,
      SplitPairLayout layout,
      List<SplitFlagPlacement> flags,
      List<ui.Image> images,
      List<_EdgeColours> edges,
      double gap,
      double shadow) {
    for (var k = 0; k < flags.length; k++) {
      final f = flags[k];
      final img = images[k];
      final region = _path(layout.regionOf(f.slot, gap: gap));
      canvas
        ..save()
        ..clipPath(region);
      // When a flag was shrunk to fit its emblem (or moved off a cover to
      // keep it), each one-colour edge is extended to fill the half
      // (Switzerland's red, the UAE's hoist); other edges stay bare.
      final dw = f.rotated ? f.height : f.width;
      final dh = f.rotated ? f.width : f.height;
      canvas.save();
      if (f.rotated) {
        canvas
          ..translate(f.left + f.width, f.top)
          ..rotate(math.pi / 2);
      } else {
        canvas.translate(f.left, f.top);
      }
      edges[k].paintAround(
          canvas, dw, dh, 4.0 * (layout.canvasWidth + layout.canvasHeight));
      canvas
        ..drawImageRect(
            img,
            ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            ui.Rect.fromLTWH(0, 0, dw, dh),
            ui.Paint()
              ..filterQuality = ui.FilterQuality.high
              ..isAntiAlias = true)
        ..restore();
      // A soft shadow on A along the seam, as if B lies on top of it.
      if (f.slot == 0 && shadow > 0) {
        final seam = ui.Path();
        final pts = layout.seamPoints;
        final off = gap / 2 * layout.blockWidth;
        for (var i = 0; i < pts.length; i++) {
          final (x, y) = pts[i];
          if (i == 0) {
            seam.moveTo(x - off, y);
          } else {
            seam.lineTo(x - off, y);
          }
        }
        final bw = layout.blockWidth;
        canvas.drawPath(
            seam,
            ui.Paint()
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = bw * 0.035
              ..color =
                  ui.Color.fromRGBO(0, 0, 0, (0.55 * shadow).clamp(0.0, 1.0))
              ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, bw * 0.022)
              // Only over A's own ink: never a grey line on bare garment.
              ..blendMode = ui.BlendMode.srcATop);
      }
      canvas.restore();
    }
  }

  /// True when (nearly) every column of the flag is one colour.
  static Future<bool> _verticalStripes(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final b = data!.buffer.asUint8List();
    final w = img.width, h = img.height;
    var uniform = 0;
    const cols = 24, rows = 16;
    for (var c = 0; c < cols; c++) {
      final x = ((c + 0.5) / cols * w).floor();
      final i0 = ((h ~/ 2) * w + x) * 4;
      var ok = true;
      for (var r = 0; r < rows && ok; r++) {
        final y = ((r + 0.5) / rows * h).floor();
        final i = (y * w + x) * 4;
        final d = (b[i] - b[i0]).abs() +
            (b[i + 1] - b[i0 + 1]).abs() +
            (b[i + 2] - b[i0 + 2]).abs();
        if (d > 60) ok = false;
      }
      if (ok) uniform++;
    }
    return uniform >= cols - 1;
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

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }
}

/// The isolate payload: plain data only.
class _Wear {
  const _Wear({
    required this.rgba,
    required this.w,
    required this.h,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.edgeWear,
    required this.distress,
    required this.scale,
    required this.scratches,
    required this.fade,
    required this.seed,
  });

  final Uint8List rgba;
  final int w, h;
  final double left, top, right, bottom;
  final double edgeWear, distress, scale, scratches, fade;
  final int seed;

  Uint8List run() => WearRaster.grunge(rgba, w, h,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      edgeWear: edgeWear,
      distress: distress,
      scale: scale,
      scratches: scratches,
      fade: fade,
      seed: seed);
}

/// The colour of each edge of a flag raster when that edge is one opaque
/// colour, else null; and each corner's colour when both its edges are.
class _EdgeColours {
  const _EdgeColours(this.left, this.right, this.top, this.bottom);

  final ui.Color? left, right, top, bottom;

  static Future<_EdgeColours> of(ui.Image img) async {
    final data =
        await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final b = data!.buffer.asUint8List();
    final w = img.width, h = img.height;
    // Inset: rasterised edges are anti-aliased.
    final i = math.min(2, math.min(w, h) ~/ 4);
    // Only a rectangular flag extends (not Nepal's pennant).
    for (final (x, y) in [
      (i, i),
      (w - 1 - i, i),
      (i, h - 1 - i),
      (w - 1 - i, h - 1 - i)
    ]) {
      if (b[(y * w + x) * 4 + 3] < 230)
        return const _EdgeColours(null, null, null, null);
    }
    ui.Color? line(int x0, int y0, int x1, int y1) {
      const n = 16;
      var r = 0, g = 0, bl = 0;
      final px = <(int, int, int)>[];
      for (var k = 0; k < n; k++) {
        final x = x0 + ((x1 - x0) * (k + 0.5) / n).floor();
        final y = y0 + ((y1 - y0) * (k + 0.5) / n).floor();
        final o = (y * w + x) * 4;
        if (b[o + 3] < 230) return null;
        px.add((b[o], b[o + 1], b[o + 2]));
        r += b[o];
        g += b[o + 1];
        bl += b[o + 2];
      }
      final mr = r / n, mg = g / n, mb = bl / n;
      for (final (pr, pg, pb) in px) {
        if ((pr - mr).abs() + (pg - mg).abs() + (pb - mb).abs() > 45) {
          return null;
        }
      }
      return ui.Color.fromARGB(255, mr.round(), mg.round(), mb.round());
    }

    return _EdgeColours(
      line(i, i, i, h - 1 - i),
      line(w - 1 - i, i, w - 1 - i, h - 1 - i),
      line(i, i, w - 1 - i, i),
      line(i, h - 1 - i, w - 1 - i, h - 1 - i),
    );
  }

  /// Fills outside the [w]×[h] flag box (local coordinates) with each
  /// one-colour edge, overlapping the flag by a pixel so no hairline shows.
  void paintAround(ui.Canvas canvas, double w, double h, double big) {
    void fill(ui.Color? c, ui.Rect r) {
      if (c != null) canvas.drawRect(r, ui.Paint()..color = c);
    }

    const o = 1.0;
    fill(left, ui.Rect.fromLTRB(-big, o, o, h - o));
    fill(right, ui.Rect.fromLTRB(w - o, o, big, h - o));
    fill(top, ui.Rect.fromLTRB(o, -big, w - o, o));
    fill(bottom, ui.Rect.fromLTRB(o, h - o, w - o, big));
    // Corners only where both edges agree on one colour.
    ui.Color? both(ui.Color? a, ui.Color? b) =>
        a != null && b != null && a == b ? a : null;
    fill(both(left, top), ui.Rect.fromLTRB(-big, -big, o, o));
    fill(both(right, top), ui.Rect.fromLTRB(w - o, -big, big, o));
    fill(both(left, bottom), ui.Rect.fromLTRB(-big, h - o, o, big));
    fill(both(right, bottom), ui.Rect.fromLTRB(w - o, h - o, big, big));
  }
}
