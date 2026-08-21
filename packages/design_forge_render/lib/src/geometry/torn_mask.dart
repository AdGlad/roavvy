import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

/// Generates a deterministic grayscale **alpha mask** for torn/ripped OUTER
/// edges: opaque (kept) interior, material dissolving inward from the edges into
/// separated tapering fingers. Applied `dstIn` to the artwork.
///
/// Self-contained (hash value-noise fBm, no external deps) so it runs anywhere
/// the pure engine does. Reproducible from `(seed, edge)` via named sub-streams.
/// This is a compact expression of the torn-flag-engine-v2 design: edge-
/// concentrated depth + strand fingers + corner damage + asymmetry; the full
/// per-edge generator can drop in behind this same stage later.
class TornMaskGenerator {
  const TornMaskGenerator();

  /// Returns an RGBA [ui.Image] whose alpha encodes kept (255) vs torn (0).
  Future<ui.Image> generate(int w, int h, EdgeTreatment t, int seed) async {
    final alpha = _alphaBuffer(w, h, t, seed);
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      rgba[i * 4] = 255;
      rgba[i * 4 + 1] = 255;
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = alpha[i];
    }
    return _decode(rgba, w, h);
  }

  /// Tears the artwork's OWN outline (its alpha boundary) rather than the frame
  /// perimeter — so torn/ripped edges follow any shape: a silhouette, a heart, a
  /// circle, or a clipped grid. Material dissolves inward from wherever the
  /// artwork currently ends, into ragged fingers, leaving the interior intact.
  ///
  /// Works by computing each opaque pixel's distance to the nearest transparent
  /// pixel (a two-pass chamfer distance transform) and removing pixels within a
  /// noisy band of that boundary. Deterministic from [seed].
  Future<ui.Image> erodeOutline(ui.Image image, EdgeTreatment t, int seed) async {
    final w = image.width, h = image.height;
    final n = w * h;
    final bytes = await image.toByteData();
    final rgba = bytes!.buffer.asUint8List();

    // Distance to nearest transparent pixel (0 for transparent, ∞ for opaque).
    const inf = 1e9;
    final dist = Float32List(n);
    for (var i = 0; i < n; i++) {
      dist[i] = rgba[i * 4 + 3] > 20 ? inf : 0.0;
    }
    const ortho = 1.0, diag = 1.4142135;
    // Forward pass.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (dist[i] == 0) continue;
        var d = dist[i];
        if (x > 0) d = math.min(d, dist[i - 1] + ortho);
        if (y > 0) d = math.min(d, dist[i - w] + ortho);
        if (x > 0 && y > 0) d = math.min(d, dist[i - w - 1] + diag);
        if (x < w - 1 && y > 0) d = math.min(d, dist[i - w + 1] + diag);
        dist[i] = d;
      }
    }
    // Backward pass.
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        final i = y * w + x;
        if (dist[i] == 0) continue;
        var d = dist[i];
        if (x < w - 1) d = math.min(d, dist[i + 1] + ortho);
        if (y < h - 1) d = math.min(d, dist[i + w] + ortho);
        if (x < w - 1 && y < h - 1) d = math.min(d, dist[i + w + 1] + diag);
        if (x > 0 && y < h - 1) d = math.min(d, dist[i + w - 1] + diag);
        dist[i] = d;
      }
    }

    // A shallow ragged FRINGE relative to the shape, not the frame — so thin
    // silhouette parts survive. band ≈ 3–11% of the min dimension.
    final minDim = math.min(w, h).toDouble();
    final band = minDim * (0.03 + 0.08 * t.edgeDamage.clamp(0.0, 1.0));
    // Mostly high-frequency notches (fine tearing); a slow term adds gentle
    // variation but never deep gouges into the interior.
    final fineFreq = (16.0 + t.frayAmount * 34.0) / minDim;
    final slowFreq = (4.0 + t.frayAmount * 4.0) / minDim;
    final nFine = _Noise2D(seed ^ 0x5151);
    final nSlow = _Noise2D(seed ^ 0x9E37);

    final out = Uint8List(n * 4);
    for (var i = 0; i < n; i++) {
      final a = rgba[i * 4 + 3];
      var keep = true;
      if (a > 20 && dist[i] < band) {
        final x = (i % w).toDouble();
        final y = (i ~/ w).toDouble();
        final fine = nFine.fbm(x * fineFreq, y * fineFreq, 3);
        final slow = nSlow.fbm(x * slowFreq, y * slowFreq, 2);
        // Boundary depth: fine notches (0.6) modulated by a gentle slow term
        // (0.4). Capped at `band`, so erosion stays a fringe.
        final boundary = band * (0.15 + (0.6 * fine + 0.4 * slow) * 0.85);
        if (dist[i] < boundary) keep = false;
      }
      out[i * 4] = rgba[i * 4];
      out[i * 4 + 1] = rgba[i * 4 + 1];
      out[i * 4 + 2] = rgba[i * 4 + 2];
      out[i * 4 + 3] = keep ? a : 0;
    }
    return _decode(out, w, h);
  }

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  Uint8List _alphaBuffer(int w, int h, EdgeTreatment t, int seed) {
    final out = Uint8List(w * h)..fillRange(0, w * h, 255);

    // Per-edge weights: asymmetry biases fly (right) + hem (bottom) heavy, hoist
    // (left) + top light — like a real flag attached at the hoist.
    final a = t.asymmetry.clamp(0.0, 1.0);
    final weights = <String, double>{
      'top': (1 - a) * 0.7 + 0.15,
      'left': (1 - a) * 0.6 + 0.1,
      'right': a * 0.9 + 0.25,
      'bottom': a * 1.0 + 0.3,
    };
    final band = (t.maxDepth.clamp(0.05, 0.5)) *
        (w < h ? w : h) *
        (0.9 + t.edgeDamage * 1.6);
    final gamma = 1.1 + (1 - t.frayAmount) * 1.0; // frayAmount → more/deeper bites
    final baseFreq = 3.0 + t.frayAmount * 4.0;
    final fingerFreq = 26.0 + t.frayAmount * 40.0;

    final nBase = _Noise1D(seed ^ 0x9E37);
    final nFinger = _Noise1D(seed ^ 0x5151);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        // distance to each edge
        final dTop = y.toDouble();
        final dBottom = (h - 1 - y).toDouble();
        final dLeft = x.toDouble();
        final dRight = (w - 1 - x).toDouble();

        var removed = false;
        removed |= _edgeBite(nBase, nFinger, dTop, x / w, band * weights['top']!,
            gamma, baseFreq, fingerFreq, 0.0);
        removed |= _edgeBite(nBase, nFinger, dBottom, x / w,
            band * weights['bottom']!, gamma, baseFreq, fingerFreq, 10.0);
        removed |= _edgeBite(nBase, nFinger, dLeft, y / h, band * weights['left']!,
            gamma, baseFreq, fingerFreq, 20.0);
        removed |= _edgeBite(nBase, nFinger, dRight, y / h,
            band * weights['right']!, gamma, baseFreq, fingerFreq, 30.0);

        // Corner damage: a ragged bite out of each actual corner. Uses true
        // nearest-corner (Euclidean) distance so it stays corner-local.
        if (t.cornerDamage > 0) {
          final cp = _nearestCornerDistance(
              x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble());
          final reach = band * (0.5 + t.cornerDamage);
          if (cp < reach) {
            final n = nFinger.fbm((cp / reach) * 6 + 40, 2);
            if (cp < reach * (0.35 + 0.65 * n)) removed = true;
          }
        }

        if (removed) out[y * w + x] = 0;
      }
    }
    return out;
  }

  /// True if a pixel at inward distance [d] (px) from an edge is torn away.
  bool _edgeBite(
    _Noise1D nBase,
    _Noise1D nFinger,
    double d,
    double t,
    double band,
    double gamma,
    double baseFreq,
    double fingerFreq,
    double phase,
  ) {
    if (band <= 0 || d >= band) return false;
    final depth01 = _gamma(nBase.fbm(t * baseFreq + phase, 4), gamma);
    final finger01 = nFinger.fbm(t * fingerFreq + phase, 3);
    // Removal boundary in px: fingers where finger01 dips keep material deeper,
    // so the boundary breaks into separated tapering strands rather than one
    // monotone ragged line.
    final boundary = band * depth01 * (0.5 + 0.9 * finger01);
    return d < boundary;
  }

  double _nearestCornerDistance(double x, double y, double w, double h) {
    double d(double cx, double cy) {
      final dx = x - cx, dy = y - cy;
      return math.sqrt(dx * dx + dy * dy);
    }

    final a = math.min(d(0, 0), d(w - 1, 0));
    final b = math.min(d(0, h - 1), d(w - 1, h - 1));
    return math.min(a, b);
  }

  double _gamma(double v, double g) => v <= 0 ? 0 : math.pow(v, g).toDouble();
}

/// Simple 1-D value-noise + fBm with a hashed integer lattice — deterministic
/// and platform-stable (no `dart:math` Random).
class _Noise1D {
  _Noise1D(this.seed);
  final int seed;

  double _hash(int i) {
    var h = (i ^ seed) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 30)) * 0xBF58476D1CE4E5B9) & 0x7FFFFFFFFFFFFFFF;
    h = ((h ^ (h >> 27)) * 0x94D049BB133111EB) & 0x7FFFFFFFFFFFFFFF;
    h = h ^ (h >> 31);
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }

  double value(double x) {
    final i = x.floor();
    final f = x - i;
    final a = _hash(i);
    final b = _hash(i + 1);
    final u = f * f * (3 - 2 * f); // smoothstep
    return a + (b - a) * u;
  }

  double fbm(double x, int octaves) {
    var sum = 0.0, amp = 0.5, freq = 1.0, norm = 0.0;
    for (var o = 0; o < octaves; o++) {
      sum += amp * value(x * freq);
      norm += amp;
      amp *= 0.5;
      freq *= 1.97;
    }
    return norm == 0 ? 0 : (sum / norm).clamp(0.0, 1.0);
  }
}

/// 2-D value-noise + fBm on a hashed integer lattice — deterministic, used to
/// tear an arbitrary alpha boundary (silhouette / heart / circle).
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
    final ux = fx * fx * (3 - 2 * fx);
    final uy = fy * fy * (3 - 2 * fy);
    final a = _hash(xi, yi);
    final b = _hash(xi + 1, yi);
    final c = _hash(xi, yi + 1);
    final d = _hash(xi + 1, yi + 1);
    final top = a + (b - a) * ux;
    final bot = c + (d - c) * ux;
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
