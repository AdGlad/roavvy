import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_stage.dart';

/// Packs N flag instances into the frame using a selectable "fitting algorithm"
/// (see [FillAlgorithm]). Rectangular partitions (grid / treemap / mosaic) draw
/// each flag cover-filled into its cell; organic partitions (diagonal / radial /
/// voronoi / torn / noise) build a per-pixel region label map, then reveal each
/// flag through its region. Every algorithm fills the whole frame and is
/// deterministic from the recipe seed.
class MultiFlagLayout {
  const MultiFlagLayout._();

  static Future<ui.Image> compose(
    RenderContext ctx,
    List<FlagRef> flags,
    Map<String, ui.Image> images,
    FillAlgorithm algo,
    int seed,
  ) async {
    final frame = ctx.fullRect;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    switch (algo) {
      case FillAlgorithm.grid:
        return ctx.rasterise((c) => _rects(
            c, _gridRects(frame, flags.length, _aspect(images, flags)), flags, images, paint));
      case FillAlgorithm.treemap:
        return ctx.rasterise((c) => _rects(
            c, _treemapRects(frame, flags.length), flags, images, paint));
      case FillAlgorithm.mosaic:
        return ctx.rasterise((c) =>
            _mosaic(c, frame, flags, images, seed, _aspect(images, flags), paint));
      case FillAlgorithm.diagonalStripe:
      case FillAlgorithm.radial:
      case FillAlgorithm.voronoi:
      case FillAlgorithm.tornRegion:
      case FillAlgorithm.noiseBlend:
        return _composeLabeled(ctx, flags, images, algo, seed, paint);
    }
  }

  // ---- rectangular partitions ----

  static void _rects(ui.Canvas canvas, List<ui.Rect> rects, List<FlagRef> flags,
      Map<String, ui.Image> images, ui.Paint paint) {
    for (var i = 0; i < rects.length; i++) {
      final img = images[flags[i % flags.length].code];
      if (img != null) _cover(canvas, img, rects[i], paint);
    }
  }

  static List<ui.Rect> _gridRects(ui.Rect frame, int n, double flagAspect) {
    final cols = _colsFor(n, frame.width / frame.height, flagAspect);
    final rows = (n / cols).ceil();
    final cellH = frame.height / rows;
    final out = <ui.Rect>[];
    for (var i = 0; i < n; i++) {
      final r = i ~/ cols;
      final inRow = i - r * cols;
      final itemsInRow = (r < rows - 1) ? cols : (n - cols * (rows - 1));
      final cellW = frame.width / itemsInRow;
      out.add(ui.Rect.fromLTWH(
          frame.left + inRow * cellW, frame.top + r * cellH, cellW, cellH));
    }
    return out;
  }

  /// Balanced binary treemap: split the count in half, slice the rect along its
  /// longer axis proportionally, recurse. Yields fairly square nested cells.
  static List<ui.Rect> _treemapRects(ui.Rect rect, int n) {
    if (n <= 1) return [rect];
    final a = n ~/ 2;
    final b = n - a;
    final splitAlongWidth = rect.width >= rect.height;
    final fracA = a / n;
    if (splitAlongWidth) {
      final mid = rect.left + rect.width * fracA;
      return [
        ..._treemapRects(
            ui.Rect.fromLTRB(rect.left, rect.top, mid, rect.bottom), a),
        ..._treemapRects(
            ui.Rect.fromLTRB(mid, rect.top, rect.right, rect.bottom), b),
      ];
    } else {
      final mid = rect.top + rect.height * fracA;
      return [
        ..._treemapRects(
            ui.Rect.fromLTRB(rect.left, rect.top, rect.right, mid), a),
        ..._treemapRects(
            ui.Rect.fromLTRB(rect.left, mid, rect.right, rect.bottom), b),
      ];
    }
  }

  static void _mosaic(ui.Canvas canvas, ui.Rect frame, List<FlagRef> flags,
      Map<String, ui.Image> images, int seed, double flagAspect, ui.Paint paint) {
    final n = flags.length;
    final cols = math.max(2, _colsFor(n, frame.width / frame.height, flagAspect));
    final rows = math.max(2, (n / cols).ceil());
    final cellW = frame.width / cols;
    final cellH = frame.height / rows;
    final covered = List<bool>.filled(cols * rows, false);
    final rng = DeterministicRng(seed).stream('mosaic');
    var idx = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (covered[r * cols + c]) continue;
        var span = 1;
        final canBlock = c + 1 < cols &&
            r + 1 < rows &&
            !covered[r * cols + c + 1] &&
            !covered[(r + 1) * cols + c] &&
            !covered[(r + 1) * cols + c + 1];
        if (canBlock && rng.chance(0.35)) span = 2;
        final rect = ui.Rect.fromLTWH(frame.left + c * cellW,
            frame.top + r * cellH, cellW * span, cellH * span);
        for (var dr = 0; dr < span; dr++) {
          for (var dc = 0; dc < span; dc++) {
            covered[(r + dr) * cols + (c + dc)] = true;
          }
        }
        final img = images[flags[idx % n].code];
        idx++;
        if (img != null) _cover(canvas, img, rect, paint);
      }
    }
  }

  // ---- organic partitions via a per-pixel region label map ----

  static Future<ui.Image> _composeLabeled(
    RenderContext ctx,
    List<FlagRef> flags,
    Map<String, ui.Image> images,
    FillAlgorithm algo,
    int seed,
    ui.Paint paint,
  ) async {
    final w = ctx.width, h = ctx.height;
    final n = flags.length;
    final labels = _labelMap(algo, w, h, n, seed);

    // Per-region alpha masks + bounding boxes.
    final masks = <ui.Image>[];
    final bounds = <ui.Rect>[];
    for (var i = 0; i < n; i++) {
      final rgba = Uint8List(w * h * 4);
      var minX = w, minY = h, maxX = 0, maxY = 0;
      var any = false;
      for (var p = 0; p < w * h; p++) {
        if (labels[p] == i) {
          rgba[p * 4] = 255;
          rgba[p * 4 + 1] = 255;
          rgba[p * 4 + 2] = 255;
          rgba[p * 4 + 3] = 255;
          final x = p % w, y = p ~/ w;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
          any = true;
        }
      }
      masks.add(await _decode(rgba, w, h));
      bounds.add(any
          ? ui.Rect.fromLTRB(
              minX.toDouble(), minY.toDouble(), (maxX + 1).toDouble(), (maxY + 1).toDouble())
          : ctx.fullRect);
    }

    return ctx.rasterise((canvas) {
      for (var i = 0; i < n; i++) {
        final img = images[flags[i].code];
        if (img == null) continue;
        canvas.saveLayer(ctx.fullRect, ui.Paint());
        _cover(canvas, img, bounds[i], paint);
        canvas.drawImage(
            masks[i], ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.dstIn);
        canvas.restore();
      }
    });
  }

  static Uint8List _labelMap(FillAlgorithm algo, int w, int h, int n, int seed) {
    final labels = Uint8List(w * h);
    final rng = DeterministicRng(seed).stream('layout');
    switch (algo) {
      case FillAlgorithm.diagonalStripe:
        final flip = rng.chance(0.5);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final t = flip ? (x + (h - y)) : (x + y);
            var idx = (t / (w + h) * n).floor();
            if (idx >= n) idx = n - 1;
            labels[y * w + x] = idx;
          }
        }
        break;
      case FillAlgorithm.radial:
        final cx = w / 2, cy = h / 2;
        final rot = rng.nextDouble() * 2 * math.pi;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            var a = math.atan2(y - cy, x - cx) + math.pi + rot;
            a %= 2 * math.pi;
            var idx = (a / (2 * math.pi) * n).floor();
            if (idx >= n) idx = n - 1;
            labels[y * w + x] = idx;
          }
        }
        break;
      case FillAlgorithm.voronoi:
      case FillAlgorithm.tornRegion:
        final sx = Float32List(n), sy = Float32List(n);
        for (var i = 0; i < n; i++) {
          sx[i] = rng.nextDouble() * w;
          sy[i] = rng.nextDouble() * h;
        }
        final warp = algo == FillAlgorithm.tornRegion;
        final nx = _Noise2D(seed ^ 0x1234);
        final ny = _Noise2D(seed ^ 0x5678);
        final amp = (w < h ? w : h) * 0.12;
        final freq = 6.0 / (w < h ? w : h);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            var px = x.toDouble(), py = y.toDouble();
            if (warp) {
              px += (nx.fbm(x * freq, y * freq, 2) - 0.5) * 2 * amp;
              py += (ny.fbm(x * freq, y * freq, 2) - 0.5) * 2 * amp;
            }
            var best = 0;
            var bestD = double.infinity;
            for (var i = 0; i < n; i++) {
              final dx = px - sx[i], dy = py - sy[i];
              final d = dx * dx + dy * dy;
              if (d < bestD) {
                bestD = d;
                best = i;
              }
            }
            labels[y * w + x] = best;
          }
        }
        break;
      case FillAlgorithm.noiseBlend:
        final offs = List.generate(n, (_) => rng.nextDouble() * 1000);
        final noise = _Noise2D(seed ^ 0x9E37);
        final freq = 3.5 / (w < h ? w : h);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            var best = 0;
            var bestV = -1.0;
            for (var i = 0; i < n; i++) {
              final v = noise.fbm((x + offs[i]) * freq, (y + offs[i]) * freq, 3);
              if (v > bestV) {
                bestV = v;
                best = i;
              }
            }
            labels[y * w + x] = best;
          }
        }
        break;
      default:
        break;
    }
    return labels;
  }

  // ---- shared helpers ----

  static double _aspect(Map<String, ui.Image> images, List<FlagRef> flags) {
    final img = images[flags.first.code];
    return (img == null || img.height == 0) ? 1.5 : img.width / img.height;
  }

  static int _colsFor(int n, double frameAspect, double flagAspect) {
    if (n <= 1) return 1;
    final c = math.sqrt(n * frameAspect / (flagAspect <= 0 ? 1.5 : flagAspect));
    return c.round().clamp(1, n);
  }

  static void _cover(
      ui.Canvas canvas, ui.Image img, ui.Rect rect, ui.Paint paint) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final s = math.max(rect.width / iw, rect.height / ih);
    final dw = iw * s, dh = ih * s;
    final dst = ui.Rect.fromLTWH(rect.left + (rect.width - dw) / 2,
        rect.top + (rect.height - dh) / 2, dw, dh);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(img,
        ui.Rect.fromLTWH(0, 0, iw, ih), dst, paint);
    canvas.restore();
  }

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}

/// 2-D value-noise + fBm (hashed lattice) — deterministic, for organic regions.
class _Noise2D {
  _Noise2D(this.seed);
  final int seed;

  double _hash(int x, int y) {
    var h = (x * 0x1F1F1F1F ^ y * 0x9E3779B1 ^ seed) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & 0x7FFFFFFFFFFFFFFF;
    h = h ^ (h >> 31);
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }

  double value(double px, double py) {
    final xi = px.floor(), yi = py.floor();
    final fx = px - xi, fy = py - yi;
    final ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
    final a = _hash(xi, yi), b = _hash(xi + 1, yi);
    final c = _hash(xi, yi + 1), d = _hash(xi + 1, yi + 1);
    final top = a + (b - a) * ux, bot = c + (d - c) * ux;
    return top + (bot - top) * uy;
  }

  double fbm(double x, double y, int octaves) {
    var sum = 0.0, amp = 0.5, freq = 1.0, norm = 0.0;
    for (var o = 0; o < octaves; o++) {
      sum += amp * value(x * freq, y * freq);
      norm += amp;
      amp *= 0.5;
      freq *= 1.97;
    }
    return norm == 0 ? 0 : (sum / norm).clamp(0.0, 1.0);
  }
}
