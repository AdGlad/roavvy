import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'garment_mockup_spec.dart';

/// Prints artwork INTO the fabric for a mockup, rather than laying it on top.
///
/// The mockup's own shading pass (`GarmentMockupPainter`, layer 3) can only
/// multiply the photo's folds over the ink: it darkens, never lifts, and the
/// print stays perfectly flat — the folds pass under it like a sticker. A real
/// DTG print moves with the cloth. This bakes that into the artwork, in the
/// garment photo's own geometry:
///
///  * **Displacement.** The artwork is warped along the slope of the fabric's
///    (smoothed) luminance — the folds — so a stripe bends where the shirt
///    does.
///  * **Light.** The ink takes the fabric's light relative to the print area's
///    average: darker in a fold, lighter on a raised ridge.
///  * **Weave.** The photo's fine heather texture is let through the ink, a
///    little, the way ink soaks into cotton instead of sitting on it.
///
/// Pure pixel maths on an isolate; the result is cached per design, shading
/// map and print area, so it runs once per tee, not per frame. Only valid for
/// a design at its default placement (no pan/pinch), which is what every
/// non-interactive preview shows.
abstract final class FabricPrint {
  /// How far the folds push the ink, in shading-photo pixels per unit of
  /// relative luminance slope. Clamped by [_maxShift].
  static const double _displace = 160;
  static const double _maxShift = 2.0;

  /// How strongly the fabric's light reaches the ink: the photo's folds are
  /// soft, so their relative light is amplified (1 = as photographed).
  static const double _light = 1.8;

  /// How much the weave thins the ink, and how much of its light shows.
  static const double _weave = 1.2;
  static const double _weaveLight = 0.8;

  static final Map<String, Future<ui.Image>> _cache = {};
  static const int _maxCache = 48;

  /// [artwork] as printed on the garment whose folds [shading] carries.
  ///
  /// [shading] must be drawn into the same garment rect as the photo (it is:
  /// the painter draws both through one contain-fit honouring
  /// [GarmentMockupSpec.srcRectNorm]). [cacheKey] identifies [artwork]; the
  /// spec's shading asset and print area are added to it.
  static Future<ui.Image> bake({
    required ui.Image artwork,
    required ui.Image shading,
    required GarmentMockupSpec spec,
    required String cacheKey,
  }) {
    final key =
        '$cacheKey|${spec.shadingAssetPath}|${spec.printAreaNorm}|'
        '${spec.srcRectNorm}';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit; // LRU touch
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    final future = _bake(artwork, shading, spec);
    _cache[key] = future;
    // A failed bake must not be served from the cache forever.
    future.then((_) {}, onError: (Object _) => _cache.remove(key));
    return future;
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  static Future<ui.Image> _bake(
    ui.Image artwork,
    ui.Image shading,
    GarmentMockupSpec spec,
  ) async {
    final art = await artwork.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final shade = await shading.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final job = FabricPrintJob(
      art: art!.buffer.asUint8List(),
      artW: artwork.width,
      artH: artwork.height,
      shade: shade!.buffer.asUint8List(),
      shadeW: shading.width,
      shadeH: shading.height,
      printArea: (
        spec.printAreaNorm.left,
        spec.printAreaNorm.top,
        spec.printAreaNorm.width,
        spec.printAreaNorm.height,
      ),
      crop:
          spec.srcRectNorm == null
              ? null
              : (
                spec.srcRectNorm!.left,
                spec.srcRectNorm!.top,
                spec.srcRectNorm!.width,
                spec.srcRectNorm!.height,
              ),
    );
    final out = await Isolate.run(() => apply(job));
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      artwork.width,
      artwork.height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  /// The bake itself, as a pure function of straight-alpha RGBA bytes —
  /// returns premultiplied RGBA for `decodeImageFromPixels`.
  @visibleForTesting
  static Uint8List apply(FabricPrintJob j) {
    final sw = j.shadeW, sh = j.shadeH;
    // Fabric luminance, 0..1.
    final lum = Float32List(sw * sh);
    for (var i = 0; i < sw * sh; i++) {
      lum[i] =
          (0.299 * j.shade[i * 4] +
              0.587 * j.shade[i * 4 + 1] +
              0.114 * j.shade[i * 4 + 2]) /
          255.0;
    }
    // Folds = the luminance with the weave smoothed away; the weave is what
    // the smoothing removed.
    final folds = _blur(_blur(lum, sw, sh, 3), sw, sh, 3);

    // The effective (cropped) photo in shading pixels.
    final crop = j.crop ?? (0.0, 0.0, 1.0, 1.0);
    final ex = crop.$1 * sw, ey = crop.$2 * sh;
    final ew = crop.$3 * sw, eh = crop.$4 * sh;
    // The print area, and the artwork contain-fitted into it, exactly as the
    // painter lays them out.
    final px = ex + j.printArea.$1 * ew, py = ey + j.printArea.$2 * eh;
    final pw = j.printArea.$3 * ew, ph = j.printArea.$4 * eh;
    final s = math.min(pw / j.artW, ph / j.artH);
    final ox = px + (pw - j.artW * s) / 2, oy = py + (ph - j.artH * s) / 2;

    // The print area's average light: the ink's neutral exposure.
    var sum = 0.0, count = 0;
    for (var y = py.floor(); y < (py + ph).ceil(); y++) {
      for (var x = px.floor(); x < (px + pw).ceil(); x++) {
        if (x < 0 || y < 0 || x >= sw || y >= sh) continue;
        sum += folds[y * sw + x];
        count++;
      }
    }
    final ref = count == 0 ? 0.5 : math.max(0.05, sum / count);

    double at(Float32List f, double x, double y) {
      x = x.clamp(0.0, sw - 1.0);
      y = y.clamp(0.0, sh - 1.0);
      final x0 = x.floor(), y0 = y.floor();
      final x1 = math.min(sw - 1, x0 + 1), y1 = math.min(sh - 1, y0 + 1);
      final tx = x - x0, ty = y - y0;
      final a = f[y0 * sw + x0] * (1 - tx) + f[y0 * sw + x1] * tx;
      final b = f[y1 * sw + x0] * (1 - tx) + f[y1 * sw + x1] * tx;
      return a * (1 - ty) + b * ty;
    }

    final aw = j.artW, ah = j.artH, src = j.art;
    // Premultiplied bilinear sample of the artwork.
    final sample = Float64List(4);
    void art(double x, double y) {
      sample.fillRange(0, 4, 0);
      if (x < -1 || y < -1 || x > aw || y > ah) return;
      final x0 = x.floor(), y0 = y.floor();
      final tx = x - x0, ty = y - y0;
      for (var k = 0; k < 4; k++) {
        final xx = x0 + (k & 1), yy = y0 + (k >> 1);
        if (xx < 0 || yy < 0 || xx >= aw || yy >= ah) continue;
        final w = ((k & 1) == 1 ? tx : 1 - tx) * ((k >> 1) == 1 ? ty : 1 - ty);
        final i = (yy * aw + xx) * 4;
        final a = src[i + 3] / 255.0 * w;
        sample[0] += src[i] / 255.0 * a;
        sample[1] += src[i + 1] / 255.0 * a;
        sample[2] += src[i + 2] / 255.0 * a;
        sample[3] += a;
      }
    }

    final out = Uint8List(aw * ah * 4);
    for (var y = 0; y < ah; y++) {
      for (var x = 0; x < aw; x++) {
        // Where this artwork pixel's centre lands on the photo, in the photo's
        // pixel-index space (pixel i's centre is at i).
        final fx = ox + (x + 0.5) * s - 0.5, fy = oy + (y + 0.5) * s - 0.5;
        // The fold slope, relative to the area's light.
        final gx = (at(folds, fx + 1, fy) - at(folds, fx - 1, fy)) / (2 * ref);
        final gy = (at(folds, fx, fy + 1) - at(folds, fx, fy - 1)) / (2 * ref);
        final dx = (gx * _displace).clamp(-_maxShift, _maxShift);
        final dy = (gy * _displace).clamp(-_maxShift, _maxShift);
        // Displaced lookup, back in artwork pixels.
        art(x + dx / s, y + dy / s);
        final a = sample[3];
        if (a <= 0.002) continue;
        var r = sample[0] / a, g = sample[1] / a, b = sample[2] / a;

        final fold = at(folds, fx, fy);
        // Weave: the fibres' own flecks, relative to the local fold light.
        final weave = (at(lum, fx, fy) - fold) / ref;
        final light = (1 +
                _light * (fold / ref - 1) +
                _weaveLight * weave)
            .clamp(0.5, 1.35);
        r = math.min(1, r * light);
        g = math.min(1, g * light);
        b = math.min(1, b * light);
        // ...and the dark flecks thin the ink, as it soaks into the cotton.
        final alpha = a * (1 + _weave * math.min(0.0, weave)).clamp(0.6, 1.0);

        final o = (y * aw + x) * 4;
        out[o] = (r * alpha * 255).round();
        out[o + 1] = (g * alpha * 255).round();
        out[o + 2] = (b * alpha * 255).round();
        out[o + 3] = (alpha * 255).round();
      }
    }
    return out;
  }

  /// Separable box blur, radius [r].
  static Float32List _blur(Float32List src, int w, int h, int r) {
    final tmp = Float32List(w * h), out = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var s = 0.0, n = 0;
        for (var k = -r; k <= r; k++) {
          final xx = x + k;
          if (xx < 0 || xx >= w) continue;
          s += src[y * w + xx];
          n++;
        }
        tmp[y * w + x] = s / n;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var s = 0.0, n = 0;
        for (var k = -r; k <= r; k++) {
          final yy = y + k;
          if (yy < 0 || yy >= h) continue;
          s += tmp[yy * w + x];
          n++;
        }
        out[y * w + x] = s / n;
      }
    }
    return out;
  }
}

/// The inputs of one bake, sendable to an isolate.
@immutable
class FabricPrintJob {
  const FabricPrintJob({
    required this.art,
    required this.artW,
    required this.artH,
    required this.shade,
    required this.shadeW,
    required this.shadeH,
    required this.printArea,
    this.crop,
  });

  /// Straight-alpha RGBA.
  final Uint8List art;
  final int artW, artH;

  /// Straight-alpha RGBA of the shading photo.
  final Uint8List shade;
  final int shadeW, shadeH;

  /// Print area (left, top, width, height), normalised to the cropped photo.
  final (double, double, double, double) printArea;

  /// Source crop of the photo, normalised; null = whole photo.
  final (double, double, double, double)? crop;
}
