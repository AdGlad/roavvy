import 'dart:math' as math;
import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';

/// Pure-Dart watercolour painter (see [Watercolour]). Takes the clipped
/// artwork as PREMULTIPLIED RGBA and returns a new premultiplied buffer of the
/// same size. No dart:ui, so it runs on a background isolate and is
/// bit-identical everywhere.
///
/// Every length is a fraction of the canvas short side [s], and the smooth
/// noise fields are sampled in that normalised space, so a 300 px preview and
/// a 4500 px print show the same painting.
class WatercolourRaster {
  const WatercolourRaster._();

  static Uint8List paint(
    Uint8List rgba,
    int w,
    int h,
    Watercolour p,
    int seed,
  ) {
    final n = w * h;
    final s = math.min(w, h).toDouble();
    final paper = _hex(p.paper);
    // Smooth fields are evaluated on a coarse grid (≈ 480 cells across the
    // short side) and interpolated — they have no detail finer than that.
    final step = math.max(1, (s / 480).floor());

    // ---- 1. brush wobble: warp the whole painting -------------------------
    final wobbleAmp = p.wobble.clamp(0.0, 1.0) * 0.028 * s;
    final wobbleFreq = 10 - 7 * p.wobbleScale.clamp(0.0, 1.0); // cycles / s
    final nx = _Noise(seed ^ 0x51A7), ny = _Noise(seed ^ 0x2C9E);
    // A slow wave plus a finer brushed ripple (3.5× the frequency).
    double wave(_Noise nz, double x, double y) =>
        (nz.fbm(x / s * wobbleFreq, y / s * wobbleFreq, 4) * 2 - 1) +
        0.25 * (nz.fbm(x / s * wobbleFreq * 3.5 + 31, y / s * wobbleFreq * 3.5 - 7, 3) * 2 - 1);
    final warpX = _Field(w, h, step, (x, y) => wave(nx, x, y) * wobbleAmp);
    final warpY = _Field(w, h, step, (x, y) => wave(ny, x, y) * wobbleAmp);

    final src = Float32List(n * 4);
    for (var i = 0; i < n * 4; i++) {
      src[i] = rgba[i] / 255.0;
    }
    final warped = Float32List(n * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        _bilinear(src, w, h, x + warpX.at(x, y), y + warpY.at(x, y), warped, i);
      }
    }

    // ---- 2. bleed: soften every colour edge ---------------------------------
    final blurR = math.max(1, (p.bleed.clamp(0.0, 1.0) * 0.022 * s).round());
    final blurred = _boxBlur3(warped, w, h, blurR);
    final mixK = 0.8 * p.bleed.clamp(0.0, 1.0);

    // Outline proximity (for splatter): a wide blur of alpha.
    final near = p.splatter > 0
        ? _boxBlur3Alpha(warped, w, h,
            math.max(2, ((0.035 + 0.09 * p.splatterSpread.clamp(0.0, 1.0)) * s).round()))
        : null;

    // ---- 3. pigment fields -------------------------------------------------
    final pn = _Noise(seed ^ 0x7E11), bn = _Noise(seed ^ 0x3B05),
        rn = _Noise(seed ^ 0x6D2F);
    final pigment = _Field(w, h, step,
        (x, y) => pn.fbm(x / s * 2.6, y / s * 2.6, 3) * 2 - 1);
    final bloom = _Field(w, h, step,
        (x, y) => _smooth(0.48, 0.72, bn.fbm(x / s * 4.5, y / s * 4.5, 4)));
    final sn = _Noise(seed ^ 0x4AB1);
    // Long thin streaks along x: noise stretched 10× along the brush.
    final streak = _Field(w, h, step,
        (x, y) => _smooth(0.56, 0.8, sn.fbm(x / s * 1.4, y / s * 16, 3)));
    final ragged = _Field(w, h, step,
        (x, y) => rn.fbm(x / s * 14, y / s * 14, 3) * 2 - 1);
    final grainCell = math.max(1.0, s / 700);
    final grainSeed = seed ^ 0x19F3;

    final out = Uint8List(n * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final aw = warped[i + 3], ab = blurred[i + 3];

        // Outer edge: threshold the softened alpha around a noisy level, so
        // the rim is irregular and slightly soft, like paint soaking in.
        final level = 0.5 + 0.22 * p.raggedEdge * ragged.at(x, y);
        final soft = 0.08 + 0.1 * p.raggedEdge;
        final a = _smooth(level - soft, level + soft, aw * (1 - mixK) + ab * mixK);
        if (a <= 0.002) continue;

        // Colour: warped, partly bled into its neighbours (premultiplied mix,
        // then straight).
        final ca = aw * (1 - mixK) + ab * mixK;
        if (ca <= 1e-4) continue;
        var r = (warped[i] * (1 - mixK) + blurred[i] * mixK) / ca;
        var g = (warped[i + 1] * (1 - mixK) + blurred[i + 1] * mixK) / ca;
        var b = (warped[i + 2] * (1 - mixK) + blurred[i + 2] * mixK) / ca;

        // Whites read as paper.
        final minC = math.min(r, math.min(g, b));
        final white = _smooth(0.72, 0.93, minC);
        r += (paper[0] - r) * white;
        g += (paper[1] - g) * white;
        b += (paper[2] - b) * white;

        // Pigment density relative to the paper: pools (>1), washes (<1),
        // blooms (pale patches with a faint darker ring), dried rims at colour
        // edges and along the outline, and grain.
        var d = 1 + 0.75 * p.pigment * pigment.at(x, y);
        final bm = bloom.at(x, y) * p.blooms;
        d *= 1 - 0.85 * bm + 0.6 * bm * (1 - bm);
        d *= 1 - 0.8 * p.streaks * streak.at(x, y);
        final colourEdge = ((warped[i] / math.max(aw, 1e-4) - blurred[i] / math.max(ab, 1e-4)).abs() +
                (warped[i + 1] / math.max(aw, 1e-4) - blurred[i + 1] / math.max(ab, 1e-4)).abs() +
                (warped[i + 2] / math.max(aw, 1e-4) - blurred[i + 2] / math.max(ab, 1e-4)).abs())
            .clamp(0.0, 1.0);
        final rimEdge = 4 * ab * (1 - ab);
        d *= 1 + p.tideLine * (0.9 * colourEdge + 0.6 * rimEdge);
        final gr = _hash01((x / grainCell).floor(), (y / grainCell).floor(), grainSeed);
        d *= 1 + p.granulation * 0.45 * (gr - 0.5);

        r = paper[0] + (r - paper[0]) * d;
        g = paper[1] + (g - paper[1]) * d;
        b = paper[2] + (b - paper[2]) * d;

        // Saturation.
        final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        r = l + (r - l) * p.saturation;
        g = l + (g - l) * p.saturation;
        b = l + (b - l) * p.saturation;

        _write(out, i, r, g, b, a);
      }
    }

    // ---- 4. halo wash (computed from the painting, composited beneath) -----
    final halo = p.halo > 0 ? _halo(out, w, h, s, step, p, paper, seed) : null;

    // ---- 5. splatter --------------------------------------------------------
    if (near != null && p.splatter > 0) {
      _splatter(out, near, w, h, s, p.splatter, p.splatterSpread, seed);
    }
    if (halo != null) {
      // Painting (and splatter) OVER the halo, premultiplied.
      for (var i = 0; i < n * 4; i += 4) {
        final a = out[i + 3] / 255.0;
        if (a >= 0.999) continue;
        for (var k = 0; k < 4; k++) {
          out[i + k] = (out[i + k] + halo[i + k] * (1 - a)).round().clamp(0, 255);
        }
      }
    }
    return out;
  }

  /// A pale cloudy wash of the painting's own edge colours around it:
  /// the painting blurred wide, broken into clouds by noise, lightened toward
  /// the paper, with a faint darker rim where each cloud dried. Returned as a
  /// premultiplied layer to composite beneath the painting.
  static Uint8List _halo(Uint8List painted, int w, int h, double s, int step,
      Watercolour p, List<double> paper, int seed) {
    final n = w * h;
    final f = Float32List(n * 4);
    for (var i = 0; i < n * 4; i++) {
      f[i] = painted[i] / 255.0;
    }
    final r = math.max(2, ((0.05 + 0.14 * p.haloSize.clamp(0.0, 1.0)) * s).round());
    final big = _boxBlur3(f, w, h, r);
    final hn = _Noise(seed ^ 0x0A10);
    final cloudNoise = _Field(w, h, step,
        (x, y) => hn.fbm(x / s * 3.2, y / s * 3.2, 4));
    final out = Uint8List(n * 4);
    final strength = p.halo.clamp(0.0, 1.0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final ba = big[i + 3];
        if (ba < 0.01) continue;
        // Clouds are likelier close to the painting.
        final c = _smooth(0.3, 0.56, cloudNoise.at(x, y) + (ba - 0.35) * 1.1);
        if (c <= 0) continue;
        // Fade out before the print-area edge: a wash never hard-cuts there.
        final border = math.min(math.min(x, y), math.min(w - 1 - x, h - 1 - y));
        final fade = _smooth(0.01 * s, 0.08 * s, border.toDouble());
        var a = strength * 0.95 * c * (ba * 3).clamp(0.0, 1.0) * fade;
        final rim = 4 * c * (1 - c);
        var cr = big[i] / ba, cg = big[i + 1] / ba, cb = big[i + 2] / ba;
        // Lighter than the paint, with a slightly denser dried rim.
        final lift = 0.38 - 0.18 * rim;
        cr += (paper[0] - cr) * lift;
        cg += (paper[1] - cg) * lift;
        cb += (paper[2] - cb) * lift;
        a = (a * (1 + 0.35 * rim)).clamp(0.0, 1.0);
        out[i] = (cr.clamp(0.0, 1.0) * a * 255).round();
        out[i + 1] = (cg.clamp(0.0, 1.0) * a * 255).round();
        out[i + 2] = (cb.clamp(0.0, 1.0) * a * 255).round();
        out[i + 3] = (a * 255).round();
      }
    }
    return out;
  }

  /// Droplets just outside the outline, each in the colour of the painting
  /// nearest to it. [spread] throws more of them, wider and in mixed sizes.
  static void _splatter(Uint8List out, Float32List near, int w, int h, double s,
      double amount, double spread, int seed) {
    final rng = DeterministicRng(seed).stream('watercolour:splatter');
    final sp = spread.clamp(0.0, 1.0);
    final count = (amount.clamp(0.0, 1.0) * 34 * (1 + 3 * sp)).round();
    var placed = 0;
    for (var tries = 0; placed < count && tries < count * 60; tries++) {
      final x = rng.nextInt(w), y = rng.nextInt(h);
      final v = near[y * w + x];
      // Close to the painting but outside it.
      if (v < 0.04 - 0.03 * sp || v > 0.42 || out[(y * w + x) * 4 + 3] > 10) continue;
      // Keep drops off the print-area edge.
      final margin = 0.035 * s;
      if (x < margin || y < margin || x > w - 1 - margin || y > h - 1 - margin) continue;
      // Colour: walk toward the nearest painted pixel along the near gradient.
      var cx = x.toDouble(), cy = y.toDouble();
      int? hit;
      for (var k = 0; k < 400 && hit == null; k++) {
        final ix = cx.round().clamp(1, w - 2), iy = cy.round().clamp(1, h - 2);
        if (out[(iy * w + ix) * 4 + 3] > 200) {
          hit = (iy * w + ix) * 4;
          break;
        }
        final gx = near[iy * w + ix + 1] - near[iy * w + ix - 1];
        final gy = near[(iy + 1) * w + ix] - near[(iy - 1) * w + ix];
        final len = math.sqrt(gx * gx + gy * gy);
        if (len < 1e-6) break;
        cx += gx / len * math.max(1.0, s / 400);
        cy += gy / len * math.max(1.0, s / 400);
      }
      if (hit == null) continue;
      final a = out[hit + 3] / 255.0;
      final cr = out[hit] / 255.0 / a, cg = out[hit + 1] / 255.0 / a, cb = out[hit + 2] / 255.0 / a;
      final radius = s * (0.0018 + 0.0022 * sp + (0.006 + 0.012 * sp) * math.pow(rng.nextDouble(), 1.8));
      final r0 = radius.ceil() + 1;
      for (var dy = -r0; dy <= r0; dy++) {
        for (var dx = -r0; dx <= r0; dx++) {
          final px = x + dx, py = y + dy;
          if (px < 0 || py < 0 || px >= w || py >= h) continue;
          final dist = math.sqrt(dx * dx + dy * dy.toDouble());
          final cov = _smooth(radius + 0.7, radius - 0.7, dist) * 0.9;
          if (cov <= 0) continue;
          final j = (py * w + px) * 4;
          final da = out[j + 3] / 255.0;
          final na = cov + da * (1 - cov);
          for (var k = 0; k < 3; k++) {
            final c = [cr, cg, cb][k];
            out[j + k] = ((c * cov + out[j + k] / 255.0 * (1 - cov)) * 255).round().clamp(0, 255);
          }
          out[j + 3] = (na * 255).round().clamp(0, 255);
        }
      }
      placed++;
    }
  }

  // ---- helpers ---------------------------------------------------------------

  static void _write(Uint8List out, int i, double r, double g, double b, double a) {
    out[i] = (r.clamp(0.0, 1.0) * a * 255).round();
    out[i + 1] = (g.clamp(0.0, 1.0) * a * 255).round();
    out[i + 2] = (b.clamp(0.0, 1.0) * a * 255).round();
    out[i + 3] = (a * 255).round();
  }

  static List<double> _hex(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    return [((v >> 16) & 0xFF) / 255, ((v >> 8) & 0xFF) / 255, (v & 0xFF) / 255];
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static void _bilinear(Float32List src, int w, int h, double fx, double fy,
      Float32List dst, int di) {
    final x0 = fx.floor(), y0 = fy.floor();
    final tx = fx - x0, ty = fy - y0;
    for (var k = 0; k < 4; k++) {
      double at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h)
          ? 0.0
          : src[(y * w + x) * 4 + k];
      final top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx;
      final bot = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx;
      dst[di + k] = top * (1 - ty) + bot * ty;
    }
  }

  /// Three box blurs ≈ a Gaussian; all four premultiplied channels.
  static Float32List _boxBlur3(Float32List src, int w, int h, int r) {
    var a = Float32List.fromList(src);
    var b = Float32List(src.length);
    for (var pass = 0; pass < 3; pass++) {
      _boxH(a, b, w, h, r, 4);
      _boxV(b, a, w, h, r, 4);
    }
    return a;
  }

  static Float32List _boxBlur3Alpha(Float32List rgba, int w, int h, int r) {
    var a = Float32List(w * h);
    for (var i = 0; i < w * h; i++) {
      a[i] = rgba[i * 4 + 3];
    }
    final b = Float32List(w * h);
    for (var pass = 0; pass < 3; pass++) {
      _boxH(a, b, w, h, r, 1);
      _boxV(b, a, w, h, r, 1);
    }
    return a;
  }

  static void _boxH(Float32List src, Float32List dst, int w, int h, int r, int ch) {
    final norm = 1.0 / (2 * r + 1);
    for (var y = 0; y < h; y++) {
      for (var k = 0; k < ch; k++) {
        double acc = 0;
        for (var x = -r; x <= r; x++) {
          acc += src[(y * w + x.clamp(0, w - 1)) * ch + k];
        }
        for (var x = 0; x < w; x++) {
          dst[(y * w + x) * ch + k] = acc * norm;
          acc += src[(y * w + (x + r + 1).clamp(0, w - 1)) * ch + k] -
              src[(y * w + (x - r).clamp(0, w - 1)) * ch + k];
        }
      }
    }
  }

  static void _boxV(Float32List src, Float32List dst, int w, int h, int r, int ch) {
    final norm = 1.0 / (2 * r + 1);
    for (var x = 0; x < w; x++) {
      for (var k = 0; k < ch; k++) {
        double acc = 0;
        for (var y = -r; y <= r; y++) {
          acc += src[(y.clamp(0, h - 1) * w + x) * ch + k];
        }
        for (var y = 0; y < h; y++) {
          dst[(y * w + x) * ch + k] = acc * norm;
          acc += src[((y + r + 1).clamp(0, h - 1) * w + x) * ch + k] -
              src[((y - r).clamp(0, h - 1) * w + x) * ch + k];
        }
      }
    }
  }

  static double _hash01(int x, int y, int seed) {
    var hsh = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF;
    hsh = ((hsh ^ (hsh >> 13)) * 1274126177) & 0xFFFFFFFF;
    hsh ^= hsh >> 16;
    return (hsh & 0xFFFFFF) / 0x1000000;
  }
}

/// Smooth value noise with fractal octaves, in [0, 1].
class _Noise {
  _Noise(this.seed);
  final int seed;

  double _value(double x, double y) {
    final x0 = x.floor(), y0 = y.floor();
    final tx = x - x0, ty = y - y0;
    final sx = tx * tx * tx * (tx * (tx * 6 - 15) + 10);
    final sy = ty * ty * ty * (ty * (ty * 6 - 15) + 10);
    final a = WatercolourRaster._hash01(x0, y0, seed);
    final b = WatercolourRaster._hash01(x0 + 1, y0, seed);
    final c = WatercolourRaster._hash01(x0, y0 + 1, seed);
    final d = WatercolourRaster._hash01(x0 + 1, y0 + 1, seed);
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy;
  }

  double fbm(double x, double y, int octaves) {
    var sum = 0.0, amp = 0.5, norm = 0.0, f = 1.0;
    for (var o = 0; o < octaves; o++) {
      sum += amp * _value(x * f + o * 17.3, y * f - o * 9.1);
      norm += amp;
      amp *= 0.5;
      f *= 2.03;
    }
    return sum / norm;
  }
}

/// A smooth scalar field sampled on a coarse grid and bilinearly interpolated.
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
