import 'dart:math' as math;
import 'dart:typed_data';

import '../procedural/deterministic_rng.dart';
import 'torn_recipe.dart';

/// A pure-Dart grayscale alpha mask: `alpha[y*width + x]`, 255 = kept cloth,
/// 0 = torn away. Decoupled from `dart:ui` so it is cheap to generate and test;
/// the renderer (M5) converts it to a `ui.Image` and applies it `dstIn`.
class TornMask {
  const TornMask(this.width, this.height, this.alpha);

  final int width;
  final int height;
  final Uint8List alpha; // length == width * height

  int alphaAt(int x, int y) => alpha[y * width + x];

  /// Fraction of pixels fully torn away (alpha == 0).
  double get removedFraction {
    var torn = 0;
    for (final a in alpha) {
      if (a == 0) torn++;
    }
    return torn / alpha.length;
  }
}

/// Turns a [TornRecipe] into a [TornMask].
///
/// **Milestone 2 — edge-boundary geometry only.** Each edge gets an independent
/// 1-D fBm *boundary depth* profile, gamma-biased so the cloth stays mostly
/// intact with occasional deep bites, scaled by that edge's damage weight
/// (asymmetry) and the global damage amount, capped at [TornRecipe.maxTearDepth].
/// A pixel is torn if it lies within the inward reach of *any* edge. The result
/// is a ragged **boundary** concentrated on the outer edges — separated tapering
/// fingers, large sections, corners and fibre roughening arrive in M3/M4.
class TornGeometryGenerator {
  const TornGeometryGenerator();

  TornMask generate(
    TornRecipe recipe, {
    required int width,
    required int height,
  }) {
    assert(width > 1 && height > 1);
    final w = width;
    final h = height;

    final top = _EdgeProfile.forEdge(recipe, FlagEdge.top);
    final bottom = _EdgeProfile.forEdge(recipe, FlagEdge.bottom);
    final left = _EdgeProfile.forEdge(recipe, FlagEdge.left);
    final right = _EdgeProfile.forEdge(recipe, FlagEdge.right);

    // Boundary depth sampled per pixel along each edge (fraction of the
    // perpendicular dimension). Top/bottom index by x; left/right by y.
    final depthTop = Float64List(w);
    final depthBottom = Float64List(w);
    for (var x = 0; x < w; x++) {
      final t = x / (w - 1);
      depthTop[x] = top.depthAt(t);
      depthBottom[x] = bottom.depthAt(t);
    }
    final depthLeft = Float64List(h);
    final depthRight = Float64List(h);
    for (var y = 0; y < h; y++) {
      final t = y / (h - 1);
      depthLeft[y] = left.depthAt(t);
      depthRight[y] = right.depthAt(t);
    }

    final alpha = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final dnTop = y / h; // inward fraction from the top edge
      final dnBottom = (h - 1 - y) / h;
      final dLeftRow = depthLeft[y];
      final dRightRow = depthRight[y];
      final rowBase = y * w;
      for (var x = 0; x < w; x++) {
        final dnLeft = x / w;
        final dnRight = (w - 1 - x) / w;
        final torn = dnTop < depthTop[x] ||
            dnBottom < depthBottom[x] ||
            dnLeft < dLeftRow ||
            dnRight < dRightRow;
        alpha[rowBase + x] = torn ? 0 : 255;
      }
    }
    return TornMask(w, h, alpha);
  }
}

/// Per-edge boundary-depth function: gamma-biased 1-D fBm scaled by the edge's
/// damage weight and the global amount, capped at the recipe's max depth.
class _EdgeProfile {
  const _EdgeProfile(this._base, this._cycles, this._gamma, this._scale);

  final int _base;
  final double _cycles;
  final double _gamma;
  final double _scale; // == maxTearDepth * edgeWeight * edgeDamageAmount

  factory _EdgeProfile.forEdge(TornRecipe recipe, FlagEdge edge) {
    final rng = DeterministicRng.stream(
      recipe.seed,
      'torngeo:${recipe.style.name}:${edge.name}',
    );
    // More notches when the recipe asks for higher frequency (~2..9 → cycles).
    final freqJitter = rng.nextRange(0.85, 1.15);
    final cycles = (recipe.tearFrequency * 0.9 * freqJitter).clamp(2.0, 12.0);
    final gamma = rng.nextRange(1.8, 3.0);
    final base = rng.nextInt(1 << 30);
    final scale =
        recipe.maxTearDepth * recipe.edgeWeight(edge) * recipe.edgeDamageAmount;
    return _EdgeProfile(base, cycles, gamma, scale);
  }

  double depthAt(double t) {
    if (_scale <= 0) return 0;
    var n = _fbm1(t * _cycles, _base);
    n = math.pow(n, _gamma).toDouble(); // bias toward intact; occasional deep
    final d = n * _scale;
    return d > _scale ? _scale : d;
  }
}

// --- Deterministic 1-D value-noise fBm --------------------------------------

const int _mask32 = 0xFFFFFFFF;

/// Integer avalanche hash → uniform double in [0, 1). Deterministic, portable.
double _lattice(int i, int base) {
  var h = (i * 0x9E3779B1 ^ base) & _mask32;
  h ^= h >> 16;
  h = (h * 0x7FEB352D) & _mask32;
  h ^= h >> 15;
  h = (h * 0x846CA68B) & _mask32;
  h ^= h >> 16;
  return (h & _mask32) / 0x100000000;
}

/// 1-D value noise with smoothstep interpolation, range [0, 1].
double _valueNoise1(double x, int base) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  final a = _lattice(i, base);
  final b = _lattice(i + 1, base);
  return a + (b - a) * u;
}

/// Fractional Brownian motion (5 octaves), normalised to [0, 1].
double _fbm1(
  double x,
  int base, {
  int octaves = 5,
  double persistence = 0.5,
  double lacunarity = 1.93,
}) {
  var sum = 0.0;
  var amp = 1.0;
  var freq = 1.0;
  var norm = 0.0;
  for (var o = 0; o < octaves; o++) {
    sum += amp * _valueNoise1(x * freq, base + o * 1013);
    norm += amp;
    amp *= persistence;
    freq *= lacunarity;
  }
  return sum / norm;
}
