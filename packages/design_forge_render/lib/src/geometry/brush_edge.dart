import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

/// The dry-brush edge, reusable by any stage (ADR-185 / M208).
///
/// Roughens the edge of a SHAPE — given as artwork whose alpha is the shape —
/// as if it were painted with one broad dry brush moving left → right
/// ([vertical]: top → bottom):
///
///  * the edges running along the stroke break into bristle streaks
///    ([BrushStroke.dryness]) with a few hairs overshooting ([BrushStroke.spill]);
///  * each bristle ends at its own place at the trailing end
///    ([BrushStroke.liftFray]), the frayed lift-off;
///  * the leading edge stays nearly clean ([BrushStroke.leadClean]);
///  * the stroke narrows a little towards its end ([BrushStroke.taper]).
///
/// It never touches the middle of the shape (emblems survive): every bite is
/// limited to a band along the edge, at most about a fifth of the shape.
/// Colours are kept; overshooting hairs take the colour of the nearest inked
/// pixel. All sizes are fractions of the shape's own bounding box, so a
/// preview and the print match.
///
/// Usage:
/// ```dart
/// // Any shape: clip the flag to a heart first, then brush its edge.
/// art = await BrushEdge.brushArtwork(art, params, seed);
/// // A path or a rect, as a mask (white = keep), to dstIn onto anything:
/// final mask = await BrushEdge.maskForPath(heartPath, w, h, params, seed);
/// final block = await BrushEdge.maskForRect(rect, w, h, params, seed, vertical: true);
/// // Pure Dart core (isolate-safe, bit-identical everywhere):
/// final rgba2 = BrushEdge.paint(rgbaPremultiplied, w, h, params, seed);
/// ```
class BrushEdge {
  const BrushEdge._();

  /// Brushes the edge of [art]'s own shape (its alpha), off the UI isolate.
  static Future<ui.Image> brushArtwork(ui.Image art, BrushStroke p, int seed,
      {bool vertical = false}) async {
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final w = art.width, h = art.height;
    final out = await Isolate.run(
        () => paint(bytes, w, h, p, seed, vertical: vertical));
    return _decode(out, w, h);
  }

  /// A white-on-transparent mask of [path] with a brushed edge.
  static Future<ui.Image> maskForPath(
      ui.Path path, int w, int h, BrushStroke p, int seed,
      {bool vertical = false}) async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()))
        .drawPath(path, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final img = await rec.endRecording().toImage(w, h);
    return brushArtwork(img, p, seed, vertical: vertical);
  }

  /// A white-on-transparent mask of [rect] with a brushed edge.
  static Future<ui.Image> maskForRect(
          ui.Rect rect, int w, int h, BrushStroke p, int seed,
          {bool vertical = false}) =>
      maskForPath(ui.Path()..addRect(rect), w, h, p, seed, vertical: vertical);

  static Future<ui.Image> _decode(Uint8List px, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Pure-Dart core on PREMULTIPLIED RGBA. Returns a new buffer.
  static Uint8List paint(Uint8List rgba, int w, int h, BrushStroke p, int seed,
      {bool vertical = false}) {
    if (vertical) {
      final t = _transpose(rgba, w, h);
      return _transpose(_paint(t, h, w, p, seed), h, w);
    }
    return _paint(rgba, w, h, p, seed);
  }

  static Uint8List _paint(
      Uint8List rgba, int w, int h, BrushStroke p, int seed) {
    final n = w * h;
    final inside = Uint8List(n);
    var x0 = w, x1 = -1, y0 = h, y1 = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (rgba[(y * w + x) * 4 + 3] >= 128) {
          inside[y * w + x] = 1;
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0) return Uint8List.fromList(rgba);
    final bw = (x1 - x0 + 1).toDouble(), bh = (y1 - y0 + 1).toDouble();

    final dIn = _chamfer(inside, w, h, 1); // inside → distance to outside
    final dOut = _chamfer(inside, w, h, 0); // outside → distance to inside

    // Row extents (for the trailing fray).
    final rowRight = Int32List(h)..fillRange(0, h, -1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x1; x >= x0; x--) {
        if (inside[y * w + x] == 1) {
          rowRight[y] = x;
          break;
        }
      }
    }

    final dry = p.dryness.clamp(0.0, 1.0);
    final edge = math.max(1.0, dry * 0.18 * bh); // streaky band depth, px
    final band = bh / p.bristles.clamp(4.0, 200.0); // one bristle, px
    final fray = p.liftFray.clamp(0.0, 1.0) * 0.25 * bw;
    final spill = p.spill.clamp(0.0, 1.0) * 0.05 * bh;
    final taper = p.taper.clamp(0.0, 1.0) * 0.06 * bh;
    final lead = p.leadClean.clamp(0.0, 1.0);
    final streakLen = bw * 0.16; // typical streak length along the stroke
    final s = seed & 0x7FFFFFFF;

    // Bristles run along the stroke, with a very slight drift.
    int bristleAt(int x, int y) {
      final wob = band * 0.2 * (_noise(s ^ 0x3B1, x / (bw * 0.5)) - 0.5);
      return ((y - y0 + wob) / band).floor();
    }

    // Each bristle's ink along its length: long on/off runs plus fine skips.
    double ink(int b, int x) =>
        _noise(s ^ (b * 7919), x / streakLen) * 0.75 +
        _noise(s ^ (b * 104729 + 17), x / (streakLen * 0.22)) * 0.25;

    final out = Uint8List.fromList(rgba);
    final maxReach = spill + 2;
    for (var y = 0; y < h; y++) {
      final nearRows = y >= y0 - maxReach && y <= y1 + maxReach;
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (inside[i] == 0) {
          // Outside: transparent, except the few overshooting hairs.
          out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = out[i * 4 + 3] = 0;
          if (!nearRows || spill <= 0) continue;
          final d = dOut[i];
          if (d > spill) continue;
          final b = bristleAt(x, y);
          if (_hash(s ^ 0x5B11, b) < 1 - p.spill * 0.5) continue;
          final reach = spill * (0.3 + 0.7 * _hash(s ^ 0x5B12, b));
          if (d > reach || ink(b, x) < 0.55) continue;
          final r = rowRight[y.clamp(y0, y1)];
          if (r >= 0 && x > r - fray) continue;
          final src = _nearestInside(inside, w, h, x, y, (spill + 2).ceil());
          if (src < 0) continue;
          for (var c = 0; c < 4; c++) {
            out[i * 4 + c] = rgba[src * 4 + c];
          }
          continue;
        }
        final xn = ((x - x0) / bw).clamp(0.0, 1.0);
        final d = dIn[i] - taper * xn * xn;
        final r = rowRight[y];
        final inFray = fray > 0 && r >= 0 && x > r - fray - 1;
        if (d > edge && !inFray) continue;
        final b = bristleAt(x, y);
        final n = ink(b, x);
        var keep = 1.0;
        if (d < edge) {
          // Close to the edge more bristles run dry; deep inside none do.
          final t = math.pow((1 - d / edge).clamp(0.0, 1.0), 1.3).toDouble();
          final leadW = (1 - lead) + lead * _smooth(0.0, 0.2, xn);
          final thr = 0.97 * t * leadW;
          keep = ((n - thr) * 25 + 0.5).clamp(0.0, 1.0);
          if (d <= 0) keep = 0;
        }
        if (inFray) {
          // Frayed lift-off: each bristle ends at its own place, and the
          // bristles separate (thin dry gaps) towards the end.
          final end = r - fray * math.pow(_hash(s ^ 0xF4A7, b), 0.9);
          keep = math.min(keep, (end - x + 0.5).clamp(0.0, 1.0));
          final zone = ((x - (r - fray)) / fray).clamp(0.0, 1.0);
          final thr = zone * (0.25 + 0.5 * dry);
          keep = math.min(keep, ((n - thr) * 25 + 0.5).clamp(0.0, 1.0));
        }
        if (keep < 1) _scale(out, i * 4, keep);
      }
    }
    return out;
  }

  static void _scale(Uint8List px, int o, double k) {
    px[o] = (px[o] * k).round();
    px[o + 1] = (px[o + 1] * k).round();
    px[o + 2] = (px[o + 2] * k).round();
    px[o + 3] = (px[o + 3] * k).round();
  }

  /// Index of the nearest inside pixel straight up/down/left/right, or -1.
  static int _nearestInside(
      Uint8List inside, int w, int h, int x, int y, int max) {
    for (var r = 1; r <= max; r++) {
      if (y + r < h && inside[(y + r) * w + x] == 1) return (y + r) * w + x;
      if (y - r >= 0 && inside[(y - r) * w + x] == 1) return (y - r) * w + x;
      if (x - r >= 0 && inside[y * w + x - r] == 1) return y * w + x - r;
      if (x + r < w && inside[y * w + x + r] == 1) return y * w + x + r;
    }
    return -1;
  }

  /// 3-4 chamfer distance (in px) from each pixel whose [inside] equals
  /// [target] to the nearest pixel that doesn't; 0 elsewhere.
  static Float32List _chamfer(Uint8List inside, int w, int h, int target) {
    const big = 1 << 28;
    final d = Int32List(w * h);
    for (var i = 0; i < w * h; i++) {
      d[i] = inside[i] == target ? big : 0;
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        var v = d[i];
        if (v == 0) continue;
        if (x > 0) v = math.min(v, d[i - 1] + 3);
        if (y > 0) {
          v = math.min(v, d[i - w] + 3);
          if (x > 0) v = math.min(v, d[i - w - 1] + 4);
          if (x < w - 1) v = math.min(v, d[i - w + 1] + 4);
        }
        d[i] = v;
      }
    }
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        final i = y * w + x;
        var v = d[i];
        if (v == 0) continue;
        if (x < w - 1) v = math.min(v, d[i + 1] + 3);
        if (y < h - 1) {
          v = math.min(v, d[i + w] + 3);
          if (x < w - 1) v = math.min(v, d[i + w + 1] + 4);
          if (x > 0) v = math.min(v, d[i + w - 1] + 4);
        }
        d[i] = v;
      }
    }
    final out = Float32List(w * h);
    for (var i = 0; i < w * h; i++) {
      out[i] = d[i] >= big ? 1e9 : d[i] / 3.0;
    }
    return out;
  }

  static Uint8List _transpose(Uint8List px, int w, int h) {
    final out = Uint8List(px.length);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final s = (y * w + x) * 4, d = (x * h + y) * 4;
        out[d] = px[s];
        out[d + 1] = px[s + 1];
        out[d + 2] = px[s + 2];
        out[d + 3] = px[s + 3];
      }
    }
    return out;
  }

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
