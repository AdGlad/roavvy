import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart garment-wear effects on PREMULTIPLIED RGBA (no dart:ui, so they
/// run on an isolate and are bit-identical everywhere):
///
///  * [acidWash] — marbled bleach veins and washed-out patches, like
///    acid-washed denim: colour goes pale and grey in organic swirls.
///  * [dyed] — tie-dye in the artwork's own colours.
///  * [spiralDye] — spiral tie-dye of the artwork's own colours.
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

  /// Tie-dye in the artwork's own colours: colour borders bleed into
  /// feathered spikes across the border, crinkle-fold veins darken (dye
  /// pooled) and lighten (undyed creases) the colour, whites pick up a tint
  /// from their neighbours, dark colours lift to bright dyed-cotton tones,
  /// and the outer edge (or the canvas edge) goes soft and ragged.
  static Uint8List dyed(Uint8List rgba, int w, int h, double amount, int seed) {
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return Uint8List.fromList(rgba);
    final n = w * h;
    final s = math.min(w, h).toDouble();
    // Premultiplied float planes.
    final pr = Float32List(n), pg = Float32List(n), pb = Float32List(n), pa = Float32List(n);
    for (var i = 0; i < n; i++) {
      pr[i] = rgba[i * 4] / 255.0;
      pg[i] = rgba[i * 4 + 1] / 255.0;
      pb[i] = rgba[i * 4 + 2] / 255.0;
      pa[i] = rgba[i * 4 + 3] / 255.0;
    }
    // Blurred straight colour: the bleed colour and the border field.
    final rb = math.max(1, (s * 0.012).round());
    final br = _blur(pr, w, h, rb), bg = _blur(pg, w, h, rb), bb = _blur(pb, w, h, rb);
    final ba = _blur(pa, w, h, rb);
    for (var i = 0; i < n; i++) {
      final al = ba[i];
      if (al > 1e-4) {
        br[i] /= al;
        bg[i] /= al;
        bb[i] /= al;
      } else {
        br[i] = bg[i] = bb[i] = 1;
      }
    }
    // A much wider bleed: the dye that wicks into white areas as streaks.
    final rw = math.max(2, (s * 0.035).round());
    final wr = _blur(pr, w, h, rw), wg = _blur(pg, w, h, rw), wb = _blur(pb, w, h, rw);
    final wa = _blur(pa, w, h, rw);
    for (var i = 0; i < n; i++) {
      final al = wa[i];
      if (al > 1e-4) {
        wr[i] /= al;
        wg[i] /= al;
        wb[i] /= al;
      } else {
        wr[i] = wg[i] = wb[i] = 1;
      }
    }
    // Structure tensor of the blurred colour → border normal + strength.
    final jxx = Float32List(n), jxy = Float32List(n), jyy = Float32List(n);
    for (var y = 0; y < h; y++) {
      final ym = y > 0 ? y - 1 : y, yp = y < h - 1 ? y + 1 : y;
      for (var x = 0; x < w; x++) {
        final xm = x > 0 ? x - 1 : x, xp = x < w - 1 ? x + 1 : x;
        double xx = 0, xy = 0, yy = 0;
        for (final c in [br, bg, bb]) {
          final gx = (c[y * w + xp] - c[y * w + xm]) * 0.5;
          final gy = (c[yp * w + x] - c[ym * w + x]) * 0.5;
          xx += gx * gx;
          xy += gx * gy;
          yy += gy * gy;
        }
        final i = y * w + x;
        jxx[i] = xx;
        jxy[i] = xy;
        jyy[i] = yy;
      }
    }
    final rt = math.max(1, (s * 0.015).round());
    final txx = _blur(jxx, w, h, rt), txy = _blur(jxy, w, h, rt), tyy = _blur(jyy, w, h, rt);
    final eNorm = (2.0 * rb) * (2.0 * rb);

    // Distance to the outside (transparent pixels and the canvas border).
    final dist = _chamfer(pa, w, h);

    final step = math.max(1, (s / 420).floor());
    final cn1 = _Noise(seed ^ 0xD7E1), cn2 = _Noise(seed ^ 0xD7E2), wn = _Noise(seed ^ 0xD7E3);
    // Crinkle folds: domain-warped ridged noise (two independent sets).
    double ridge(_Noise nz, double x, double y) {
      final u = x / s * 6.5, v = y / s * 6.5;
      final ox = wn.fbm(u * 0.5, v * 0.5, 3) * 2.2, oy = wn.fbm(u * 0.5 + 5.2, v * 0.5 - 3.7, 3) * 2.2;
      return 1 - (2 * nz.fbm(u + ox, v + oy, 4) - 1).abs();
    }

    // Crinkle folds: warped Worley cells → angular fold lines (dye pooled
    // dark) with paler facets between them, like scrunched cotton.
    final cell = s / 11;
    final wobX = _Field(w, h, step, (x, y) => (ridge(cn1, x, y) - 0.5) * cell * 0.9);
    final wobY = _Field(w, h, step, (x, y) => (ridge(cn2, x + 91, y - 37) - 0.5) * cell * 0.9);
    final mottle = _Field(w, h, step, (x, y) => cn2.fbm(x / s * 5, y / s * 5, 3));
    final warpX = _Field(w, h, step, (x, y) => wn.fbm(x / s * 3 + 11, y / s * 3, 3) - 0.5);
    final warpY = _Field(w, h, step, (x, y) => wn.fbm(x / s * 3, y / s * 3 + 17, 3) - 0.5);
    final rag = _Field(w, h, step, (x, y) => cn1.fbm(x / s * 16, y / s * 16, 3) - 0.5);
    final spikes = _Noise(seed ^ 0xD7E4);

    final spikeLen = s * 0.032 * a;
    final warpLen = s * 0.035 * a;
    final fw = s * 0.05 * a;
    final out = Uint8List(n * 4);

    double bil(Float32List c, double fx, double fy) {
      fx = fx.clamp(0.0, w - 1.0);
      fy = fy.clamp(0.0, h - 1.0);
      final x0 = fx.floor(), y0 = fy.floor();
      final x1 = math.min(w - 1, x0 + 1), y1 = math.min(h - 1, y0 + 1);
      final tx = fx - x0, ty = fy - y0;
      final top = c[y0 * w + x0] * (1 - tx) + c[y0 * w + x1] * tx;
      final bot = c[y1 * w + x0] * (1 - tx) + c[y1 * w + x1] * tx;
      return top * (1 - ty) + bot * ty;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final al = pa[i];
        if (al <= 0) continue;
        // Spikes across colour borders.
        final xx = txx[i], xy = txy[i], yy = tyy[i];
        final edgeW = _smooth(0.015, 0.25, (xx + yy) * eNorm);
        final th = 0.5 * math.atan2(2 * xy, xx - yy);
        final nx = math.cos(th), ny = math.sin(th);
        var sx = x + warpX.at(x, y) * warpLen * 2, sy = y + warpY.at(x, y) * warpLen * 2;
        if (edgeW > 0.01) {
          final u = (x * -ny + y * nx) / s * 90;
          final v = (x * nx + y * ny) / s * 5;
          // Fine, uneven feathers: sharp peaks of varying length both ways.
          final f = spikes.fbm(u, v, 4) - 0.5;
          final len = 0.35 + 0.65 * spikes.fbm(u * 0.15 + 40, v, 2);
          final k = (f.sign * math.pow((f.abs() * 3.0).clamp(0.0, 1.0), 1.6)) * len;
          sx += nx * k * spikeLen * edgeW;
          sy += ny * k * spikeLen * edgeW;
        }
        // Two taps (full and half way) so spike tips feather into the
        // neighbouring colour instead of ending in a hard saw edge.
        final hx = (sx + x) / 2, hy = (sy + y) / 2;
        final sa = bil(pa, sx, sy) + bil(pa, hx, hy);
        double r, g, b;
        if (sa > 0.1) {
          r = (bil(pr, sx, sy) + bil(pr, hx, hy)) / sa;
          g = (bil(pg, sx, sy) + bil(pg, hx, hy)) / sa;
          b = (bil(pb, sx, sy) + bil(pb, hx, hy)) / sa;
        } else {
          r = pr[i] / al;
          g = pg[i] / al;
          b = pb[i] / al;
        }
        // Bleed toward the neighbourhood colour.
        final bl = 0.3 * a;
        r += (br[i] - r) * bl;
        g += (bg[i] - g) * bl;
        b += (bb[i] - b) * bl;
        // Dye wicking into white: streaks running along the border, so a
        // white band picks up pink/blue striations from its neighbours.
        final white = math.min(r, math.min(g, b));
        if (white > 0.6) {
          // Warped wisps (direction-free, so no seams where borders meet).
          final su = x / s * 9 + warpX.at(x, y) * 4, sv = y / s * 9 + warpY.at(x, y) * 4;
          final st = _smooth(0.52, 0.8, spikes.fbm(su + 70, sv, 4));
          final wk = 0.6 * a * st * _smooth(0.6, 0.9, white);
          // The wicked dye: the nearby colour, concentrated (the wide blur
          // averages it with white).
          double conc(double c) => (1 - (1 - c) * 3.5).clamp(0.0, 1.0);
          r += (conc(wr[i]) - r) * wk;
          g += (conc(wg[i]) - g) * wk;
          b += (conc(wb[i]) - b) * wk;
        }
        // Dyed cotton: dark colours lift to bright dye tones.
        final lift = 1 + 0.7 * a;
        r = 1 - math.pow(1 - r.clamp(0.0, 1.0), lift).toDouble();
        g = 1 - math.pow(1 - g.clamp(0.0, 1.0), lift).toDouble();
        b = 1 - math.pow(1 - b.clamp(0.0, 1.0), lift).toDouble();
        // Crinkle folds, strongest where there is dye (not on whites).
        final dye = 1 - math.min(r, math.min(g, b));
        final (f1, f2) = _worley(x + wobX.at(x, y), y + wobY.at(x, y), cell, seed);
        final edge = (f2 - f1) / cell; // 0 on a fold line
        final dv = 1 - _smooth(0.0, 0.1, edge);
        final facet = _smooth(0.15, 0.6, edge) * (1 - (f1 / cell).clamp(0.0, 1.0));
        final m = (mottle.at(x, y) - 0.5) * 2;
        // Folds deepen the dye in its own hue (c → c^2.4): yellow goes
        // golden, blue goes navy, white stays white.
        final deep = (0.75 * a * dv).clamp(0.0, 1.0);
        r += (math.pow(r.clamp(0.0, 1.0), 2.4) - r) * deep;
        g += (math.pow(g.clamp(0.0, 1.0), 2.4) - g) * deep;
        b += (math.pow(b.clamp(0.0, 1.0), 2.4) - b) * deep;
        final darken = 1 - 0.18 * a * m * dye;
        r *= darken;
        g *= darken;
        b *= darken;
        final lighten = 0.55 * a * facet * dye;
        r += (1 - r) * lighten;
        g += (1 - g) * lighten;
        b += (1 - b) * lighten;
        // Soft ragged edge.
        final f = fw <= 0 ? 1.0 : _smooth(0, fw, dist[i] + rag.at(x, y) * fw * 1.6 - fw * 0.2);
        final oa = al * f;
        out[i * 4] = (r.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 1] = (g.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 2] = (b.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 3] = (oa * 255).round();
      }
    }
    return out;
  }

  /// Spiral tie-dye: the artwork twisted into a swirl around the centre (as
  /// the cloth is pinched and twisted), colours feathering into each other
  /// along the arms, white undyed creases following the spiral folds,
  /// wobbly rubber-band rings, bright dyed-cotton colour and a soft ragged
  /// edge. [amount] sets how far it twists and how strong the dye marks are.
  static Uint8List spiralDye(Uint8List rgba, int w, int h, double amount, int seed) {
    final a = amount.clamp(0.0, 1.0);
    if (a <= 0) return Uint8List.fromList(rgba);
    final n = w * h;
    final s = math.min(w, h).toDouble();
    final pr = Float32List(n), pg = Float32List(n), pb = Float32List(n), pa = Float32List(n);
    var minX = w, minY = h, maxX = 0, maxY = 0;
    for (var i = 0; i < n; i++) {
      pr[i] = rgba[i * 4] / 255.0;
      pg[i] = rgba[i * 4 + 1] / 255.0;
      pb[i] = rgba[i * 4 + 2] / 255.0;
      pa[i] = rgba[i * 4 + 3] / 255.0;
      if (pa[i] > 0.5) {
        final x = i % w, y = i ~/ w;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX) return Uint8List.fromList(rgba);
    // Twist about the centre of the artwork.
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final fw = s * 0.045;
    // A round of cloth over the artwork, kept clear of the print-area edge.
    final rad = math.min(math.max(maxX - minX, maxY - minY) / 2,
        math.min(math.min(cx, w - 1 - cx), math.min(cy, h - 1 - cy)) - fw * 1.2);
    final nz = _Noise(seed ^ 0x5B1A), nz2 = _Noise(seed ^ 0x5B1B);
    final turns = 0.6 + 1.1 * a; // full turns from centre to rim
    final folds = 7 + (seed % 4); // spiral fold creases
    final arms = 3 + (seed % 2); // dye sections between the twisted arms
    final out = Uint8List(n * 4);

    double bil(Float32List c, double fx, double fy) {
      fx = fx.clamp(0.0, w - 1.0);
      fy = fy.clamp(0.0, h - 1.0);
      final x0 = fx.floor(), y0 = fy.floor();
      final x1 = math.min(w - 1, x0 + 1), y1 = math.min(h - 1, y0 + 1);
      final tx = fx - x0, ty = fy - y0;
      final top = c[y0 * w + x0] * (1 - tx) + c[y0 * w + x1] * tx;
      final bot = c[y1 * w + x0] * (1 - tx) + c[y1 * w + x1] * tx;
      return top * (1 - ty) + bot * ty;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final dx = x - cx, dy = y - cy;
        final r = math.sqrt(dx * dx + dy * dy);
        // The whole round of cloth is dyed, whatever the artwork's shape
        // (Nepal's pennant): undyed cloth stays white cotton.
        if (r > rad + fw) continue;
        final rn = (r / rad).clamp(0.0, 1.2);
        final th = math.atan2(dy, dx);
        // Fold wobble so arms are hand-made, not mathematical.
        final wob = (nz.fbm(x / s * 3, y / s * 3, 3) - 0.5) * 0.9;
        // Twist: inner cloth turns more (it was pinched at the centre).
        final twist = 2 * math.pi * turns * math.pow(1 - rn.clamp(0.0, 1.0), 0.8) + wob;
        // The arms also carry colour in and out along the radius, so even a
        // centred disc (Japan) throws spiral arms through its surround.
        final armPhase = (th + twist) * arms;
        final pull = 1 + 0.38 * a * math.sin(armPhase + wob * 2) * _smooth(0.05, 0.35, rn);
        // Feathered bleed: average taps spread along the arm direction.
        double sr = 0, sg = 0, sb = 0, sa = 0;
        const taps = 5;
        for (var t = 0; t < taps; t++) {
          final jit = (t - (taps - 1) / 2) / taps;
          final spread = 0.16 * a * (0.4 + nz2.fbm(th * 3 + t, rn * 6, 2));
          final ang = th + twist + jit * spread;
          // Fine spikes across the arms: dye wicking along the fold ridges
          // gives tie-dye its fuzzy, feathered colour edges.
          final sp = ((nz2.fbm(x / s * 70 + t * 0.4, y / s * 70, 2) - 0.5) * 3.2).clamp(-1.0, 1.0);
          final spike = sp.sign * math.pow(sp.abs(), 1.6) * 0.07 * a * _smooth(0.05, 0.3, rn);
          final rr = math.min(r * pull * (1 + jit * 0.08 * a + spike), rad * 0.96);
          final sx = cx + math.cos(ang) * rr, sy = cy + math.sin(ang) * rr;
          final aa = bil(pa, sx, sy);
          sr += bil(pr, sx, sy);
          sg += bil(pg, sx, sy);
          sb += bil(pb, sx, sy);
          sa += aa;
        }
        // Premultiplied taps over white cotton.
        var cr = (sr + (taps - sa)) / taps;
        var cg = (sg + (taps - sa)) / taps;
        var cb = (sb + (taps - sa)) / taps;
        // Spiral coordinate: constant along an arm.
        final phi = th + twist;
        // White creases along the folds: thin, broken, feathered.
        final fp = (phi / (2 * math.pi) * folds + wob * 2) % 1.0;
        final fd = (fp < 0.5 ? fp : 1 - fp) * 2; // 0 on a crease
        final cw = 0.18 + 0.3 * nz2.fbm(phi * 2, rn * 9, 3);
        final crease = (1 - _smooth(0, cw, fd)) *
            _smooth(0.35, 0.6, nz.fbm(phi * 4 + 9, rn * 14, 3)) *
            _smooth(0.03, 0.12, rn);
        // Section boundaries between dye arms: a pale gap where the bands
        // held the cloth.
        final ap = (phi / (2 * math.pi) * arms + 0.5 * wob) % 1.0;
        final ad = (ap < 0.5 ? ap : 1 - ap) * 2;
        final gap = (1 - _smooth(0, 0.05, ad)) * 0.6;
        // Rubber-band rings.
        final ringP = (rn * 3.2 + wob * 0.6) % 1.0;
        final rd = (ringP < 0.5 ? ringP : 1 - ringP) * 2;
        final ring = (1 - _smooth(0, 0.07, rd)) *
            _smooth(0.3, 0.6, nz2.fbm(th * 5, rn * 3 + 4, 2)) * 0.7;
        // Dyed cotton: bright and saturated, darks lifted.
        final l = 0.3 * cr + 0.59 * cg + 0.11 * cb;
        final sat = 1 + 0.35 * a;
        cr = l + (cr - l) * sat;
        cg = l + (cg - l) * sat;
        cb = l + (cb - l) * sat;
        final lift = 1 + 0.6 * a;
        cr = 1 - math.pow(1 - cr.clamp(0.0, 1.0), lift).toDouble();
        cg = 1 - math.pow(1 - cg.clamp(0.0, 1.0), lift).toDouble();
        cb = 1 - math.pow(1 - cb.clamp(0.0, 1.0), lift).toDouble();
        // Uneven dye take-up.
        final m = (nz.fbm(x / s * 9 + 3, y / s * 9, 3) - 0.5) * 2;
        final mot = 1 - 0.22 * a * m;
        cr *= mot;
        cg *= mot;
        cb *= mot;
        // Cotton grain: fine speckle where the dye took unevenly.
        final grain = (nz2.fbm(x / s * 260, y / s * 260, 2) - 0.5) * 0.2 * a;
        cr += grain;
        cg += grain;
        cb += grain;
        final white = (math.max(crease * 0.7, math.max(gap, ring)) * a).clamp(0.0, 0.92);
        cr += (1 - cr) * white;
        cg += (1 - cg) * white;
        cb += (1 - cb) * white;
        final rag = (nz2.fbm(x / s * 16, y / s * 16, 3) - 0.5) * fw * 1.6;
        final f = _smooth(0, fw, rad - r + rag - fw * 0.2);
        final oa = f;
        out[i * 4] = (cr.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 1] = (cg.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 2] = (cb.clamp(0.0, 1.0) * oa * 255).round();
        out[i * 4 + 3] = (oa * 255).round();
      }
    }
    return out;
  }

  /// Nearest and second-nearest jittered cell centre distances.
  static (double, double) _worley(double x, double y, double cell, int seed) {
    final gx = (x / cell).floor(), gy = (y / cell).floor();
    var f1 = 1e9, f2 = 1e9;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final cx = gx + dx, cy = gy + dy;
        final px = (cx + 0.1 + 0.8 * _hash01(cx, cy, seed ^ 0xF01D)) * cell;
        final py = (cy + 0.1 + 0.8 * _hash01(cx, cy, seed ^ 0xF02D)) * cell;
        final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
        if (d < f1) {
          f2 = f1;
          f1 = d;
        } else if (d < f2) {
          f2 = d;
        }
      }
    }
    return (f1, f2);
  }

  /// Two-pass separable box blur (≈ gaussian) with clamped edges.
  static Float32List _blur(Float32List src, int w, int h, int r) {
    var a = Float32List.fromList(src);
    final tmp = Float32List(w * h);
    for (var pass = 0; pass < 2; pass++) {
      for (var y = 0; y < h; y++) {
        var sum = 0.0;
        for (var k = -r; k <= r; k++) {
          sum += a[y * w + k.clamp(0, w - 1)];
        }
        for (var x = 0; x < w; x++) {
          tmp[y * w + x] = sum / (2 * r + 1);
          sum += a[y * w + math.min(w - 1, x + r + 1)] - a[y * w + math.max(0, x - r)];
        }
      }
      for (var x = 0; x < w; x++) {
        var sum = 0.0;
        for (var k = -r; k <= r; k++) {
          sum += tmp[k.clamp(0, h - 1) * w + x];
        }
        for (var y = 0; y < h; y++) {
          a[y * w + x] = sum / (2 * r + 1);
          sum += tmp[math.min(h - 1, y + r + 1) * w + x] - tmp[math.max(0, y - r) * w + x];
        }
      }
    }
    return a;
  }

  /// Chamfer distance from each pixel to the nearest mostly-transparent
  /// pixel; outside the canvas counts as transparent.
  static Float32List _chamfer(Float32List alpha, int w, int h) {
    const inf = 1e9, d1 = 1.0, d2 = 1.41421356;
    final d = Float32List(w * h);
    for (var i = 0; i < w * h; i++) {
      d[i] = alpha[i] < 0.5 ? 0 : inf;
    }
    double at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : d[y * w + x];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (d[i] == 0) continue;
        var v = d[i];
        v = math.min(v, at(x - 1, y) + d1);
        v = math.min(v, at(x, y - 1) + d1);
        v = math.min(v, at(x - 1, y - 1) + d2);
        v = math.min(v, at(x + 1, y - 1) + d2);
        d[i] = v;
      }
    }
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        final i = y * w + x;
        if (d[i] == 0) continue;
        var v = d[i];
        v = math.min(v, at(x + 1, y) + d1);
        v = math.min(v, at(x, y + 1) + d1);
        v = math.min(v, at(x + 1, y + 1) + d2);
        v = math.min(v, at(x - 1, y + 1) + d2);
        d[i] = v;
      }
    }
    return d;
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
