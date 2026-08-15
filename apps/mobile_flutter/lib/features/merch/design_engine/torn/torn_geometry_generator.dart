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
/// **Milestone 3 — edge boundary + separated tapering fingers.** Each edge gets
/// an independent gamma-biased 1-D fBm *boundary depth* (asymmetry via per-edge
/// weight), and within that damaged band an **anisotropic strand field** decides
/// what survives: a pixel is torn only where the (domain-warped, high-frequency)
/// strand value falls below a **depth-keyed taper threshold** — which rises
/// toward the outer edge. So strands are wide where they meet the intact body and
/// taper to points at the edge, reading as separated hanging fingers/streamers
/// that follow the grain (perpendicular-inward per edge). Large missing sections,
/// corner damage and fibre roughening arrive in M4.
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
      final penTop = y / h; // inward fraction from the top edge
      final penBottom = (h - 1 - y) / h;
      final tLR = y / (h - 1); // along-edge coord for left/right edges
      final depL = depthLeft[y];
      final depR = depthRight[y];
      final rowBase = y * w;
      for (var x = 0; x < w; x++) {
        final penLeft = x / w;
        final penRight = (w - 1 - x) / w;
        final tTB = x / (w - 1); // along-edge coord for top/bottom edges
        final torn = top.tears(tTB, penTop, depthTop[x]) ||
            bottom.tears(tTB, penBottom, depthBottom[x]) ||
            left.tears(tLR, penLeft, depL) ||
            right.tears(tLR, penRight, depR);
        alpha[rowBase + x] = torn ? 0 : 255;
      }
    }
    return TornMask(w, h, alpha);
  }
}

/// Per-edge geometry: a gamma-biased fBm boundary depth plus an anisotropic
/// strand field that carves the damaged band into separated tapering fingers.
class _EdgeProfile {
  const _EdgeProfile({
    required int depthBase,
    required double depthCycles,
    required double gamma,
    required double scale,
    required int strandBase,
    required double strandCycles,
    required int warpBase,
    required double warpAmp,
    required double warpCycles,
    required double taperPower,
  })  : _depthBase = depthBase,
        _depthCycles = depthCycles,
        _gamma = gamma,
        _scale = scale,
        _strandBase = strandBase,
        _strandCycles = strandCycles,
        _warpBase = warpBase,
        _warpAmp = warpAmp,
        _warpCycles = warpCycles,
        _taperPower = taperPower;

  final int _depthBase;
  final double _depthCycles;
  final double _gamma;
  final double _scale; // == maxTearDepth * edgeWeight * edgeDamageAmount

  final int _strandBase;
  final double _strandCycles; // fingers per edge length
  final int _warpBase;
  final double _warpAmp; // domain-warp displacement (strand-widths)
  final double _warpCycles;
  final double _taperPower; // >1 sharpens the finger tips

  factory _EdgeProfile.forEdge(TornRecipe recipe, FlagEdge edge) {
    final rng = DeterministicRng.stream(
      recipe.seed,
      'torngeo:${recipe.style.name}:${edge.name}',
    );
    // Broad bays: a handful of them, scaling gently with tearFrequency.
    final cycles =
        (recipe.tearFrequency * 0.9 * rng.nextRange(0.85, 1.15)).clamp(2.0, 12.0);
    final gamma = rng.nextRange(1.8, 3.0);
    var scale =
        recipe.maxTearDepth * recipe.edgeWeight(edge) * recipe.edgeDamageAmount;
    // Below this the tear is a barely-visible sliver; snap it to fully intact so
    // protected edges (e.g. the hoist of an asymmetric recipe) read as clean.
    if (scale < 0.012) scale = 0;

    // Fine strands: fray drives density; more fray → more, finer fingers.
    final strandCycles =
        (12.0 + recipe.frayAmount * 44.0) * rng.nextRange(0.85, 1.15);
    // High fray → longer, more separated streamers (sharper taper).
    final taperPower = 1.0 + recipe.frayAmount;
    final warpAmp = 0.10 + recipe.frayAmount * 0.18;
    final warpCycles = cycles * 1.7;

    return _EdgeProfile(
      depthBase: rng.nextInt(1 << 30),
      depthCycles: cycles,
      gamma: gamma,
      scale: scale,
      strandBase: rng.nextInt(1 << 30),
      strandCycles: strandCycles,
      warpBase: rng.nextInt(1 << 30),
      warpAmp: warpAmp,
      warpCycles: warpCycles,
      taperPower: taperPower,
    );
  }

  /// Max inward reach of damage at along-edge position [t] (0 == intact).
  double depthAt(double t) {
    if (_scale <= 0) return 0;
    var n = _fbm1(t * _depthCycles, _depthBase);
    n = math.pow(n, _gamma).toDouble(); // bias toward intact; occasional deep
    final d = n * _scale;
    return d > _scale ? _scale : d;
  }

  /// True if the pixel at along-edge coord [t], inward penetration [pen]
  /// (fraction), given the local boundary depth [dep], is torn away by this edge.
  bool tears(double t, double pen, double dep) {
    if (dep <= 0 || pen >= dep) return false; // outside the damaged band
    // Anisotropic strand field: mostly a function of t (fingers run inward),
    // gently domain-warped so strands bend and split rather than comb straight.
    final warp = _warpAmp *
        (_fbm1(t * _warpCycles + pen * 3.0, _warpBase, octaves: 2) - 0.5);
    final sf = _valueNoise1((t + warp) * _strandCycles, _strandBase);
    // Depth-keyed taper: near the body (q→1) almost everything survives (wide
    // base); near the outer edge (q→0) only the strongest strands do (a point).
    final q = pen / dep;
    final threshold = math.pow(1 - q, _taperPower).toDouble();
    return sf < threshold; // below the survival bar → carved away
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

/// Fractional Brownian motion, normalised to [0, 1].
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
