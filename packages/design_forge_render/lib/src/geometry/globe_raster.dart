import 'dart:math' as math;
import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';

/// Pure-Dart flag-on-a-ball projection + lighting (see [Globe]). Input: the
/// flag covering the whole frame, PREMULTIPLIED RGBA. Output: a new
/// premultiplied buffer with the ball (radius [r] at [cx],[cy], including the
/// rim) and transparency elsewhere. No dart:ui, so it runs on an isolate.
class GlobeRaster {
  const GlobeRaster._();

  static Uint8List paint(Uint8List src, int w, int h, Globe p, double cx,
      double cy, double r) {
    final out = Uint8List(w * h * 4);
    final rim = p.rim.clamp(0.0, 0.3);
    final rs = r * (1 - rim); // sphere radius inside the rim
    final rimRgb = _hex(p.rimColour);
    final half = math.min(w, h) / 2 * p.zoom.clamp(0.3, 1.0);
    final bulge = p.bulge.clamp(0.0, 1.0);
    final shading = p.shading.clamp(0.0, 1.0);

    // Light from the given side, toward the viewer.
    var lx = p.lightX, ly = p.lightY, lz = 0.9;
    final ll = math.sqrt(lx * lx + ly * ly + lz * lz);
    lx /= ll;
    ly /= ll;
    lz /= ll;
    // Half-vector between light and viewer (0, 0, 1) for the highlight.
    var hx = lx, hy = ly, hz = lz + 1;
    final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
    hx /= hl;
    hy /= hl;
    hz /= hl;

    final x0 = math.max(0, (cx - r - 2).floor()), x1 = math.min(w - 1, (cx + r + 2).ceil());
    final y0 = math.max(0, (cy - r - 2).floor()), y1 = math.min(h - 1, (cy + r + 2).ceil());
    final sample = Float64List(4);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        final d = math.sqrt(dx * dx + dy * dy);
        final outerA = (r + 0.5 - d).clamp(0.0, 1.0);
        if (outerA <= 0) continue;
        final i = (y * w + x) * 4;

        // Sphere coverage (anti-aliased at its edge).
        final sphereA = (rs + 0.5 - d).clamp(0.0, 1.0);
        double cr = 0, cg = 0, cb = 0;
        if (sphereA > 0) {
          final nx = (dx / rs).clamp(-1.0, 1.0), ny = (dy / rs).clamp(-1.0, 1.0);
          final z = math.sqrt(math.max(0.0, 1 - nx * nx - ny * ny));
          // Orthographic sphere → longitude / latitude, blended with flat.
          final lon = math.atan2(nx, z) / (math.pi / 2);
          final lat = math.asin(ny) / (math.pi / 2);
          final u = nx + (lon - nx) * bulge, v = ny + (lat - ny) * bulge;
          _bilinear(src, w, h, cx + u * half - 0.5, cy + v * half - 0.5, sample);
          final a = sample[3];
          if (a > 1e-4) {
            cr = sample[0] / a;
            cg = sample[1] / a;
            cb = sample[2] / a;
          }
          // Lighting: diffuse + darker limb + soft glow + crisp highlight.
          final ndl = math.max(0.0, nx * lx + ny * ly + z * lz);
          final limb = math.pow(1 - z, 1.6).toDouble();
          final shade = (1 + shading * (0.55 * (ndl - 0.6) - 0.45 * limb))
              .clamp(0.0, 2.0);
          final ndh = math.max(0.0, nx * hx + ny * hy + z * hz);
          final glow = p.specular * 0.22 * math.pow(ndh, 6);
          final spec = p.specular * 0.85 * math.pow(ndh, 48);
          cr = cr * shade + (1 - cr * shade) * (glow + spec);
          cg = cg * shade + (1 - cg * shade) * (glow + spec);
          cb = cb * shade + (1 - cb * shade) * (glow + spec);
        }
        // Rim behind/around the sphere.
        final rr = rimRgb[0], rg = rimRgb[1], rb = rimRgb[2];
        final r0 = cr * sphereA + rr * (1 - sphereA);
        final g0 = cg * sphereA + rg * (1 - sphereA);
        final b0 = cb * sphereA + rb * (1 - sphereA);
        final a0 = rim > 0 ? outerA : sphereA;
        out[i] = (r0.clamp(0.0, 1.0) * a0 * 255).round();
        out[i + 1] = (g0.clamp(0.0, 1.0) * a0 * 255).round();
        out[i + 2] = (b0.clamp(0.0, 1.0) * a0 * 255).round();
        out[i + 3] = (a0 * 255).round();
      }
    }
    return out;
  }

  static List<double> _hex(String hex) {
    final v = int.parse(hex.substring(1), radix: 16);
    return [((v >> 16) & 0xFF) / 255, ((v >> 8) & 0xFF) / 255, (v & 0xFF) / 255];
  }

  static void _bilinear(Uint8List src, int w, int h, double fx, double fy,
      Float64List out) {
    final x0 = fx.floor().clamp(0, w - 1), y0 = fy.floor().clamp(0, h - 1);
    final x1 = (x0 + 1).clamp(0, w - 1), y1 = (y0 + 1).clamp(0, h - 1);
    final tx = (fx - fx.floor()).clamp(0.0, 1.0), ty = (fy - fy.floor()).clamp(0.0, 1.0);
    for (var k = 0; k < 4; k++) {
      final a = src[(y0 * w + x0) * 4 + k] / 255.0;
      final b = src[(y0 * w + x1) * 4 + k] / 255.0;
      final c = src[(y1 * w + x0) * 4 + k] / 255.0;
      final d = src[(y1 * w + x1) * 4 + k] / 255.0;
      out[k] = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty;
    }
  }
}
