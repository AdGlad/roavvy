import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

/// The painted dry-brush edge, reusable by any stage (ADR-185 / M208).
///
/// Turns a shape's outline into the outline of the same shape painted with
/// one broad brush moving left → right ([vertical]: top → bottom), as a
/// **vector path** (filled anti-aliased):
///
///  * the edges along the stroke wobble gently, with a few small nicks
///    ([BrushStroke.dryness]);
///  * the trailing edge lifts off in jagged, pointed spikes of varied length
///    with triangular notches between them ([BrushStroke.liftFray] = spike
///    length, [BrushStroke.bristles] = how many spikes across the stroke,
///    [BrushStroke.taper] = how much the lift-off leans);
///  * the stroke is a stack of a few painted bands that start and end at
///    slightly different places ([BrushStroke.spill] = how staggered);
///  * the leading edge stays nearly clean ([BrushStroke.leadClean]).
///
/// Nothing cuts through the inside: the paint is solid, only the outline
/// moves. Inward bites are capped by the shape's local thickness, so a narrow
/// part (a heart's tip) is roughened, never shredded. Outward spikes take the
/// colour of the nearest painted pixel. All sizes are fractions of the shape's
/// bounding box, so preview and print match; everything is seeded.
///
/// ```dart
/// final outline = BrushEdge.outline(heartPath, brush, seed);           // ui.Path
/// final mask = await BrushEdge.maskForPath(heartPath, w, h, brush, seed); // white = keep
/// final mask2 = await BrushEdge.maskForRect(rect, w, h, brush, seed, vertical: true);
/// art = await BrushEdge.brushArtwork(art, brush, seed, shape: heartPath);
/// ```
class BrushEdge {
  const BrushEdge._();

  /// The brushed outline of [shape] (one closed path per contour).
  static ui.Path outline(ui.Path shape, BrushStroke p, int seed,
      {bool vertical = false}) {
    final bounds = shape.getBounds();
    if (bounds.isEmpty) return ui.Path();
    // Work in stroke space: the stroke always runs along +x.
    final toStroke = vertical ? _swapXY : _identity;
    final src = shape.transform(toStroke);
    final b = src.getBounds();
    final along = b.width, across = b.height;
    final unit = math.min(along, across);
    final s0 = seed & 0x7FFFFFFF;

    final dry = p.dryness.clamp(0.0, 1.0);
    final wobbleAmp = unit * 0.022 * (0.3 + dry);
    final nickDepth = unit * 0.02 * dry;
    final fray = along * 0.16 * p.liftFray.clamp(0.0, 1.0);
    final teeth = p.bristles.clamp(3.0, 40.0);
    final lean = p.taper.clamp(0.0, 1.0);
    final stagger = along * 0.09 * p.spill.clamp(0.0, 1.0);
    final endTaper = across * 0.09 * p.taper.clamp(0.0, 1.0);
    final lead = p.leadClean.clamp(0.0, 1.0);

    // Painted bands across the stroke, each with its own start and end.
    const bands = 4;
    final bandStart = [
      for (var k = 0; k < bands; k++)
        k == bands - 1
            ? stagger * (0.6 + 0.6 * _hash(s0 ^ 0xB0A1, k))
            : stagger * 0.6 * math.pow(_hash(s0 ^ 0xB0A1, k), 1.5),
    ];
    final bandEnd = [
      for (var k = 0; k < bands; k++) stagger * (2 * _hash(s0 ^ 0xB0A2, k) - 1),
    ];
    double banded(List<double> v, double yn) {
      final f = (yn * bands - 0.5).clamp(0.0, bands - 1.0);
      final i = f.floor().clamp(0, bands - 1), j = math.min(i + 1, bands - 1);
      final t = _smooth(0.35, 0.65, f - i);
      return v[i] + (v[j] - v[i]) * t;
    }

    // Spikes on the trailing edge: pointed triangles of varied length; now
    // and then a notch instead.
    double spike(double yn) {
      final f = yn * teeth + 1.2 * (_noise(s0 ^ 0x5716, yn * 4) - 0.5);
      final k = f.floor();
      final u = f - k;
      final tip = 0.25 + 0.5 * _hash(s0 ^ 0x5717, k);
      final r = _hash(s0 ^ 0x5718, k);
      // Mostly spikes of very different lengths, now and then a notch.
      final len =
          r < 0.18 ? -0.3 : 0.1 + 0.9 * math.pow(_hash(s0 ^ 0x5719, k), 1.2);
      final tri = u < tip ? u / tip : (1 - u) / (1 - tip);
      // Thin pointed spikes; the valleys between them bite in a little.
      return fray * ((0.35 + len) * tri - 0.35);
    }

    final out = ui.Path();
    for (final metric in src.computeMetrics()) {
      final len = metric.length;
      if (len <= 0) continue;
      final n = math.max(64, (len / unit * 260).round());
      // Small nicks: short inward dents at random places along the outline.
      final nickCount = (len / unit * 3 * dry).round();
      final nicks = [
        for (var k = 0; k < nickCount; k++)
          (
            _hash(s0 ^ 0x41C0, k) * len,
            unit * (0.012 + 0.025 * _hash(s0 ^ 0x41C1, k)),
            nickDepth * (0.5 + _hash(s0 ^ 0x41C2, k)),
          ),
      ];
      final pts = <ui.Offset>[];
      for (var i = 0; i < n; i++) {
        final s = len * i / n;
        final t = metric.getTangentForOffset(s);
        if (t == null) continue;
        final pos = t.position;
        var nx = t.vector.dy, ny = -t.vector.dx;
        if (src.contains(pos + ui.Offset(nx, ny) * (unit * 0.004))) {
          nx = -nx;
          ny = -ny;
        }
        final yn = ((pos.dy - b.top) / across).clamp(0.0, 1.0);
        final trailing = _smooth(0.35, 0.85, nx);
        final leading = _smooth(0.35, 0.85, -nx);
        final side = 1 - trailing - leading; // along-stroke edges

        // Gentle low-frequency wobble (quieter on the leading edge).
        var d = wobbleAmp *
            (2 * _noise(s0 ^ 0x70B1, s / (unit * 0.45)) -
                1 +
                0.35 * (2 * _noise(s0 ^ 0x70B2, s / (unit * 0.08)) - 1)) *
            (1 - leading * lead * 0.8);
        // Nicks, mostly on the long edges.
        for (final (at, width, depth) in nicks) {
          final dist = (s - at).abs();
          if (dist < width)
            d -= depth * (1 - dist / width) * (side + 0.4 * trailing);
        }
        // Staggered bands: where each band starts and ends.
        d -= leading * banded(bandStart, yn);
        d += trailing * banded(bandEnd, yn);
        // The lift-off: spikes, leaning (bottom reaches further).
        // (Spikes fade out at the corners so none floats off on its own.)
        final ends = _smooth(0.03, 0.16, yn) * _smooth(0.03, 0.16, 1 - yn);
        d += trailing * (spike(yn) * ends + fray * lean * 0.6 * (yn - 0.5));

        // The stroke thins towards its end (pressure lifting): the long edges
        // close in near the trailing end.
        final xn = ((pos.dx - b.left) / along).clamp(0.0, 1.0);
        d -= (side + trailing) * endTaper * xn * xn;
        // Never bite deeper than a share of the local thickness.
        if (d < 0) {
          final room = _inward(src, pos, -nx, -ny, unit);
          d = math.max(d, -0.3 * room);
        }
        pts.add(pos + ui.Offset(nx, ny) * d);
      }
      if (pts.length < 3) continue;
      out.addPolygon(pts, true);
    }
    return out.transform(toStroke); // the swap is its own inverse
  }

  /// A white-on-transparent mask of [path], brushed.
  static Future<ui.Image> maskForPath(
      ui.Path path, int w, int h, BrushStroke p, int seed,
      {bool vertical = false}) {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())).drawPath(
        outline(path, p, seed, vertical: vertical),
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF)
          ..isAntiAlias = true);
    return rec.endRecording().toImage(w, h);
  }

  /// A white-on-transparent mask of [rect], brushed.
  static Future<ui.Image> maskForRect(
          ui.Rect rect, int w, int h, BrushStroke p, int seed,
          {bool vertical = false}) =>
      maskForPath(
          ui.Path()
            ..addRRect(ui.RRect.fromRectAndRadius(
                rect, ui.Radius.circular(rect.shortestSide * 0.04))),
          w,
          h,
          p,
          seed,
          vertical: vertical);

  /// Brushes [art] along [shape] (default: the box of its painted pixels).
  /// Colour is first extended outward from the painted pixels, so spikes
  /// past the original edge carry the paint next to them (a stripe runs on
  /// into its spike).
  static Future<ui.Image> brushArtwork(ui.Image art, BrushStroke p, int seed,
      {ui.Path? shape, bool vertical = false}) async {
    final w = art.width, h = art.height;
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    var path = shape;
    if (path == null) {
      final box = _alphaBounds(bytes, w, h);
      if (box == null) return art;
      path = ui.Path()..addRect(box);
    }
    final reach = (math.max(w, h) * 0.2).round();
    final extended = await _decode(
        await Isolate.run(() => extendColour(bytes, w, h, reach)), w, h);
    final rec = ui.PictureRecorder();
    final canvas =
        ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.saveLayer(null, ui.Paint());
    canvas.drawPath(
        outline(path, p, seed, vertical: vertical),
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF)
          ..isAntiAlias = true);
    canvas.drawImage(
        extended, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.srcIn);
    if (shape == null) {
      // Without a vector shape, the artwork's own alpha still bounds it
      // (e.g. a pennant flag keeps its diagonal edges).
      canvas.drawImage(
          art, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    }
    canvas.restore();
    return rec.endRecording().toImage(w, h);
  }

  /// Fills transparent pixels within [reach] px of the painted ones with the
  /// colour of the nearest painted pixel (premultiplied RGBA in and out).
  /// Pure Dart; nearest by a two-pass chamfer propagation.
  static Uint8List extendColour(Uint8List rgba, int w, int h, int reach) {
    final n = w * h;
    const big = 1 << 28;
    final dist = Int32List(n);
    final from = Int32List(n);
    for (var i = 0; i < n; i++) {
      // Only fully painted pixels are sources: an anti-aliased rim would
      // leave a seam where the paint is extended.
      if (rgba[i * 4 + 3] >= 250) {
        dist[i] = 0;
        from[i] = i;
      } else {
        dist[i] = big;
        from[i] = -1;
      }
    }
    void relax(int i, int j, int cost) {
      final c = dist[j] + cost;
      if (c < dist[i]) {
        dist[i] = c;
        from[i] = from[j];
      }
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (dist[i] == 0) continue;
        if (x > 0) relax(i, i - 1, 3);
        if (y > 0) {
          relax(i, i - w, 3);
          if (x > 0) relax(i, i - w - 1, 4);
          if (x < w - 1) relax(i, i - w + 1, 4);
        }
      }
    }
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        final i = y * w + x;
        if (dist[i] == 0) continue;
        if (x < w - 1) relax(i, i + 1, 3);
        if (y < h - 1) {
          relax(i, i + w, 3);
          if (x < w - 1) relax(i, i + w + 1, 4);
          if (x > 0) relax(i, i + w - 1, 4);
        }
      }
    }
    final out = Uint8List.fromList(rgba);
    final limit = reach * 3;
    for (var i = 0; i < n; i++) {
      final f = from[i];
      if (dist[i] == 0 || f < 0 || dist[i] > limit) continue;
      final a = rgba[f * 4 + 3];
      if (a == 0) continue;
      // Un-premultiply then write fully opaque.
      for (var c = 0; c < 3; c++) {
        out[i * 4 + c] = (rgba[f * 4 + c] * 255 / a).round().clamp(0, 255);
      }
      out[i * 4 + 3] = 255;
    }
    return out;
  }

  /// Paints [shape] as hatched dry-brush strokes (the scribbled-heart look,
  /// M210/M211): parallel strokes [width] px thick at [angleDeg] (0 =
  /// horizontal) that overlap to cover the inside solidly, while their round
  /// ends spill past the outline or stop just short of it ([spill]). Thin
  /// bristle tails trail from some ends ([tails]); dry streaks — thin unpainted
  /// lines — run in from others ([streaks], drawn with `dstOut`, so call this
  /// inside its own `saveLayer`). White on transparent: use it as a mask.
  ///
  /// Where a stroke line leaves the shape and re-enters it (a heart's top
  /// notch), its ends never bridge more than a third of the gap, so concave
  /// parts stay open. Seeded; sizes scale with [width].
  static void paintHatch(
    ui.Canvas canvas,
    ui.Path shape, {
    required double angleDeg,
    required double width,
    double spill = 0.5,
    double tails = 0.5,
    double streaks = 0.3,
    bool frayed = false,
    required int seed,
  }) {
    final b = shape.getBounds();
    if (b.isEmpty || width <= 0) return;
    final s0 = seed & 0x7FFFFFFF;
    final a = angleDeg * math.pi / 180;
    // Frayed ends: square-cut strokes whose ends break into a fan of
    // bristles of different lengths (Twin Hearts); otherwise round ends
    // (the scalloped Shared Heart look).
    final dir = ui.Offset(math.cos(a), math.sin(a));
    final nrm = ui.Offset(-dir.dy, dir.dx);
    final c = b.center;
    // Extent of the shape's box along the stroke and across it.
    double proj(ui.Offset p, ui.Offset axis) =>
        (p.dx - c.dx) * axis.dx + (p.dy - c.dy) * axis.dy;
    final corners = [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight];
    final along = corners.map((p) => proj(p, dir)).toList();
    final across = corners.map((p) => proj(p, nrm)).toList();
    final aMin = along.reduce(math.min) - width,
        aMax = along.reduce(math.max) + width;
    final cMin = across.reduce(math.min) - width,
        cMax = across.reduce(math.max) + width;

    final unit = math.max(b.width, b.height);
    final spillLen = unit * 0.045 * spill.clamp(0.0, 1.5);
    final step = math.max(0.5, width * 0.12);
    final spacing = width * 0.62;
    final white = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = frayed ? ui.StrokeCap.butt : ui.StrokeCap.round
      ..isAntiAlias = true;
    final bristle = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..isAntiAlias = true;
    final cut = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..blendMode = ui.BlendMode.dstOut
      ..isAntiAlias = true;
    final gaps = <(ui.Offset, ui.Offset, double, double)>[];

    var k = 0;
    for (var o = cMin; o <= cMax; o += spacing, k++) {
      final off = o + spacing * 0.3 * (_hash(s0 ^ 0x4A7C, k) - 0.5);
      final base = c + nrm * off;
      bool inside(double t) => shape.contains(base + dir * t);
      // Runs of the line inside the shape.
      final runs = <(double, double)>[];
      double? start;
      var prev = false;
      for (var t = aMin; t <= aMax; t += step) {
        final now = inside(t);
        if (now && !prev) start = _edge(inside, t - step, t);
        if (!now && prev && start != null) {
          runs.add((start, _edge(inside, t, t - step)));
          start = null;
        }
        prev = now;
      }
      if (prev && start != null) runs.add((start, aMax));
      for (var r = 0; r < runs.length; r++) {
        var (t0, t1) = runs[r];
        final room0 = r == 0 ? double.infinity : (t0 - runs[r - 1].$2) / 3;
        final room1 =
            r == runs.length - 1 ? double.infinity : (runs[r + 1].$1 - t1) / 3;
        // Each end spills out (most) or stops short (some).
        double ext(int salt, double room) => math.min(
            room, spillLen * (1.5 * _hash(s0 ^ salt, k * 31 + r) - 0.45));
        t0 -= ext(0x5E01, room0);
        t1 += ext(0x5E02, room1);
        final wk = width * (0.85 + 0.3 * _hash(s0 ^ 0x5E03, k * 31 + r));
        if (t1 - t0 < wk * 0.2) continue;
        // A whisker of angle jitter so strokes don't look ruled.
        final jitter = (_hash(s0 ^ 0x5E04, k * 31 + r) - 0.5) * wk * 0.5;
        final p0 = base + dir * t0 - nrm * (jitter * 0.5);
        final p1 = base + dir * t1 + nrm * (jitter * 0.5);
        canvas.drawLine(p0, p1, white..strokeWidth = wk);
        // Bristle tails and dry streaks at either end (sign: inward).
        for (final (end, sign, salt) in [
          (p0, 1.0, 0x7A11),
          (p1, -1.0, 0x7A21),
        ]) {
          final h0 = _hash(s0 ^ salt, k * 31 + r);
          if (frayed) {
            // A fan of bristles across the whole stroke width.
            final nTail = 4 + (_hash(s0 ^ (salt + 1), k * 31 + r) * 4).floor();
            for (var q = 0; q < nTail; q++) {
              final id = k * 97 + r * 7 + q;
              final hq = _hash(s0 ^ (salt + 2), id);
              final off2 = ((q + 0.3 + 0.4 * hq) / nTail - 0.5) * wk;
              final len = spillLen *
                  (0.1 + 1.1 * math.pow(_hash(s0 ^ (salt + 3), id), 1.5)) *
                  (0.4 + tails);
              final from = end + nrm * off2 + dir * (sign * wk * 0.2);
              canvas.drawLine(from, from - dir * (sign * len),
                  bristle..strokeWidth = wk / nTail * (0.9 + 0.8 * hq));
            }
          } else if (h0 < tails * 0.8) {
            final nTail = 1 + (_hash(s0 ^ (salt + 1), k) * 2.5).floor();
            for (var q = 0; q < nTail; q++) {
              final hq = _hash(s0 ^ (salt + 2), k * 97 + r * 7 + q);
              final off2 = (hq - 0.5) * wk * 0.8;
              final len = spillLen *
                  (0.3 + 1.2 * _hash(s0 ^ (salt + 3), k * 97 + r * 7 + q));
              final from = end + nrm * off2;
              canvas.drawLine(from, from - dir * (sign * len),
                  bristle..strokeWidth = wk * (0.1 + 0.18 * hq));
            }
          }
          // Dry streaks: thin unpainted lines along the stroke, mostly
          // starting at (or just inside) its end.
          final run = t1 - t0;
          for (var q = 0; q < 3; q++) {
            final id = k * 97 + r * 7 + q;
            final h1 = _hash(s0 ^ (salt + 4), id);
            if (h1 >= streaks * (q == 0 ? 0.9 : 0.5)) continue;
            final hq = _hash(s0 ^ (salt + 5), id);
            final off2 = (hq - 0.5) * wk * 0.85;
            final inset = run * 0.25 * math.pow(_hash(s0 ^ (salt + 7), id), 2);
            final len = math.min(
                run * 0.45,
                unit *
                    (0.03 + 0.12 * _hash(s0 ^ (salt + 6), id)) *
                    (0.5 + streaks));
            final from = end + nrm * off2 + dir * (sign * inset);
            gaps.add((
              from,
              from + dir * (sign * len),
              wk * (0.04 + 0.1 * hq),
              0.6 + 0.4 * _hash(s0 ^ (salt + 8), id),
            ));
          }
        }
      }
    }
    for (final (p0, p1, w, alpha) in gaps) {
      canvas.drawLine(
          p0,
          p1,
          cut
            ..strokeWidth = w
            ..color = ui.Color.fromARGB(
                (alpha.clamp(0.0, 1.0) * 255).round(), 255, 255, 255));
    }
  }

  /// Scratches across a painted [shape] (distress): thin, slightly bent
  /// knockout lines mostly along [angleDeg]; [amount] 0..1 sets how many.
  /// Drawn with `dstOut`, so call inside the artwork's own `saveLayer`.
  static void paintScratches(
    ui.Canvas canvas,
    ui.Path shape, {
    required double angleDeg,
    required double amount,
    required int seed,
  }) {
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return;
    final b = shape.getBounds();
    if (b.isEmpty) return;
    final s0 = seed & 0x7FFFFFFF;
    final unit = math.max(b.width, b.height);
    // Mostly short grain (worn-print scuffs), a few longer scratches; half
    // run with the brush, half near-vertical.
    final count = (a * 420).round();
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..blendMode = ui.BlendMode.dstOut
      ..isAntiAlias = true;
    for (var i = 0; i < count; i++) {
      final p = ui.Offset(b.left + b.width * _hash(s0 ^ 0x5C01, i),
          b.top + b.height * _hash(s0 ^ 0x5C02, i));
      if (!shape.contains(p)) continue;
      final base = _hash(s0 ^ 0x5C08, i) < 0.5 ? angleDeg : 90.0;
      final ang = (base + 30 * (_hash(s0 ^ 0x5C03, i) - 0.5)) * math.pi / 180;
      final len = unit * (0.006 + 0.07 * math.pow(_hash(s0 ^ 0x5C04, i), 3));
      final d = ui.Offset(math.cos(ang), math.sin(ang)) * len;
      final bend =
          ui.Offset(-d.dy, d.dx) * (0.12 * (_hash(s0 ^ 0x5C05, i) - 0.5));
      final path = ui.Path()
        ..moveTo(p.dx - d.dx / 2, p.dy - d.dy / 2)
        ..quadraticBezierTo(
            p.dx + bend.dx, p.dy + bend.dy, p.dx + d.dx / 2, p.dy + d.dy / 2);
      canvas.drawPath(
          path,
          paint
            ..strokeWidth = unit * (0.0015 + 0.004 * _hash(s0 ^ 0x5C06, i))
            ..color = ui.Color.fromARGB(
                (150 + 105 * _hash(s0 ^ 0x5C07, i)).round(), 255, 255, 255));
    }
  }

  /// Bisects the boundary between [outside] and [insideAt] (5 steps).
  static double _edge(
      bool Function(double) inside, double outside, double insideAt) {
    var lo = outside, hi = insideAt;
    for (var i = 0; i < 5; i++) {
      final m = (lo + hi) / 2;
      if (inside(m)) {
        hi = m;
      } else {
        lo = m;
      }
    }
    return hi;
  }

  /// How far the shape extends from [pos] in direction (dx, dy).
  static double _inward(
      ui.Path shape, ui.Offset pos, double dx, double dy, double unit) {
    final step = unit / 120;
    var d = step;
    while (d < unit && shape.contains(pos + ui.Offset(dx, dy) * d)) {
      d += step;
    }
    return d;
  }

  static ui.Rect? _alphaBounds(Uint8List px, int w, int h) {
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (px[(y * w + x) * 4 + 3] >= 128) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0) return null;
    return ui.Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
  }

  static Future<ui.Image> _decode(Uint8List px, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  static final Float64List _identity = Float64List(16)
    ..[0] = 1
    ..[5] = 1
    ..[10] = 1
    ..[15] = 1;

  static final Float64List _swapXY = Float64List(16)
    ..[1] = 1
    ..[4] = 1
    ..[10] = 1
    ..[15] = 1;

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// murmur3 fmix32 of (seed, k) → [0, 1).
  static double _hash(int seed, int k) {
    var h = (seed * 0x9E3779B1 + k * 0x85EBCA77) & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h / 4294967296.0;
  }

  /// Smooth 1-D value noise in [0, 1].
  static double _noise(int seed, double t) {
    final i = t.floor();
    final f = t - i;
    final u = f * f * (3 - 2 * f);
    final a = _hash(seed, i), b = _hash(seed, i + 1);
    return a + (b - a) * u;
  }
}
