import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart garment-wear effects on PREMULTIPLIED RGBA (no dart:ui, so they
/// run on an isolate and are bit-identical everywhere):
///
///  * [acidWash] — marbled bleach veins and washed-out patches, like
///    acid-washed denim: colour goes pale and grey in organic swirls.
///  * [cracks] — a network of fine cracks in the print ink, like a
///    well-washed screen print.
///
/// All sizes are fractions of the canvas short side, so a preview and the
/// print show the same wear.
class WearRaster {
  const WearRaster._();

  static Uint8List acidWash(Uint8List rgba, int w, int h, double amount, int seed) {
    final out = Uint8List.fromList(rgba);
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return out;
    final s = math.min(w, h).toDouble();
    final step = math.max(1, (s / 360).floor());
    final n1 = _Noise(seed ^ 0xAC1D), n2 = _Noise(seed ^ 0x5EED), n3 = _Noise(seed ^ 0x0B1E);
    // Domain-warped ridged noise → thin marble veins; plus broad blotches.
    final veins = _Field(w, h, step, (x, y) {
      final u = x / s * 2.6, v = y / s * 2.6;
      final wx = n2.fbm(u, v, 3) * 1.8, wy = n2.fbm(u + 7.3, v - 2.1, 3) * 1.8;
      final r = 1 - (2 * n1.fbm(u + wx, v + wy, 5) - 1).abs();
      return _smooth(0.72, 0.95, r);
    });
    final blotch = _Field(w, h, step,
        (x, y) => _smooth(0.52, 0.74, n3.fbm(x / s * 3.4, y / s * 3.4, 4)));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final al = rgba[i + 3] / 255.0;
        if (al <= 0) continue;
        var r = rgba[i] / 255.0 / al, g = rgba[i + 1] / 255.0 / al, b = rgba[i + 2] / 255.0 / al;
        final v = veins.at(x, y), bl = blotch.at(x, y);
        final bleach = (a * (0.9 * v + 0.45 * bl)).clamp(0.0, 0.95);
        // Bleached tone: pale, mostly grey, keeping a hint of the hue.
        final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        final pale = 0.78 + 0.2 * l;
        final br = pale + (r - l) * 0.25, bg = pale + (g - l) * 0.25, bb = pale + (b - l) * 0.25;
        // A faint darker rim where the bleach front stopped (marble contrast).
        final rim = 1 - a * 0.14 * 4 * v * (1 - v);
        r = (r + (br - r) * bleach) * rim;
        g = (g + (bg - g) * bleach) * rim;
        b = (b + (bb - b) * bleach) * rim;
        out[i] = (r.clamp(0.0, 1.0) * al * 255).round();
        out[i + 1] = (g.clamp(0.0, 1.0) * al * 255).round();
        out[i + 2] = (b.clamp(0.0, 1.0) * al * 255).round();
      }
    }
    return out;
  }

  static Uint8List cracks(Uint8List rgba, int w, int h, double amount, int seed) {
    final out = Uint8List.fromList(rgba);
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return out;
    final s = math.min(w, h).toDouble();
    // Worley cells; a crack where the two nearest cell centres are nearly
    // equidistant (F2 − F1 small). Only some edges crack (amount).
    final cell = s / (5 + 5 * a);
    final width = math.max(0.5, s * 0.0012);
    final keep = _Noise(seed ^ 0xC4AC);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (rgba[i + 3] == 0) continue;
        final gx = (x / cell).floor(), gy = (y / cell).floor();
        var f1 = 1e9, f2 = 1e9;
        var id1 = 0, id2 = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final cx = gx + dx, cy = gy + dy;
            final px = (cx + _hash01(cx, cy, seed)) * cell;
            final py = (cy + _hash01(cx, cy, seed ^ 0x77)) * cell;
            final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
            final id = cx * 73856093 ^ cy * 19349663;
            if (d < f1) {
              f2 = f1;
              id2 = id1;
              f1 = d;
              id1 = id;
            } else if (d < f2) {
              f2 = d;
              id2 = id;
            }
          }
        }
        final edge = (f2 - f1) / 2;
        if (edge > width * 1.5) continue;
        // Only a share of the cell walls crack, decided per pair of cells.
        final pair = (id1 ^ id2) & 0x7FFFFFFF;
        if (_hash01(pair, 0, seed) > 0.2 + 0.55 * a) continue;
        // Cracks fade in and out along their length.
        final along = keep.fbm(x / s * 9, y / s * 9, 2);
        if (along < 0.5 - 0.15 * a) continue;
        final cov = (width + 0.5 - edge).clamp(0.0, 1.0);
        final k = 1 - cov;
        for (var c = 0; c < 4; c++) {
          out[i + c] = (rgba[i + c] * k).round();
        }
      }
    }
    return out;
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _hash01(int x, int y, int seed) {
    var hsh = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF;
    hsh = ((hsh ^ (hsh >> 13)) * 1274126177) & 0xFFFFFFFF;
    hsh ^= hsh >> 16;
    return (hsh & 0xFFFFFF) / 0x1000000;
  }
}

class _Noise {
  _Noise(this.seed);
  final int seed;

  double _value(double x, double y) {
    final x0 = x.floor(), y0 = y.floor();
    final tx = x - x0, ty = y - y0;
    final sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
    final a = WearRaster._hash01(x0, y0, seed), b = WearRaster._hash01(x0 + 1, y0, seed);
    final c = WearRaster._hash01(x0, y0 + 1, seed), d = WearRaster._hash01(x0 + 1, y0 + 1, seed);
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy;
  }

  double fbm(double x, double y, int octaves) {
    var sum = 0.0, amp = 0.5, norm = 0.0, f = 1.0;
    for (var o = 0; o < octaves; o++) {
      sum += amp * _value(x * f + o * 13.1, y * f - o * 7.7);
      norm += amp;
      amp *= 0.5;
      f *= 2.07;
    }
    return sum / norm;
  }
}

class _Field {
  _Field(this.w, this.h, this.step, double Function(double x, double y) fn)
      : gw = (w / step).ceil() + 2,
        gh = (h / step).ceil() + 2 {
    _v = Float32List(gw * gh);
    for (var gy = 0; gy < gh; gy++) {
      for (var gx = 0; gx < gw; gx++) {
        _v[gy * gw + gx] = fn((gx * step).toDouble(), (gy * step).toDouble());
      }
    }
  }

  final int w, h, step, gw, gh;
  late final Float32List _v;

  double at(int x, int y) {
    if (step == 1) return _v[y * gw + x];
    final fx = x / step, fy = y / step;
    final x0 = fx.floor(), y0 = fy.floor();
    final tx = fx - x0, ty = fy - y0;
    final i = y0 * gw + x0;
    final top = _v[i] * (1 - tx) + _v[i + 1] * tx;
    final bot = _v[i + gw] * (1 - tx) + _v[i + gw + 1] * tx;
    return top * (1 - ty) + bot * ty;
  }
}
