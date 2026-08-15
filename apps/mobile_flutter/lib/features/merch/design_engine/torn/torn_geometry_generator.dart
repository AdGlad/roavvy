import 'dart:math' as math;
import 'dart:typed_data';

import '../procedural/deterministic_rng.dart';
import 'torn_recipe.dart';

/// Hard cap on how far (as a fraction of the perpendicular dimension) any tear —
/// including large sections and corner damage — may reach inward. Guarantees the
/// central body of the flag is never breached: damage stays an edge phenomenon.
const double kMaxPenetration = 0.30;

/// A pure-Dart grayscale alpha mask: `alpha[y*width + x]`, 255 = kept cloth,
/// 0 = torn away, intermediate = anti-aliased fibre edge. Decoupled from
/// `dart:ui` so it is cheap to generate and test; the renderer (M5) converts it
/// to a `ui.Image` and applies it `dstIn`.
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
/// **Milestone 4 — full edge geometry.** Builds on M2/M3 (per-edge gamma-biased
/// fBm boundary depth + anisotropic tapering strand fingers) with:
///  * **large missing sections** — a cellular field boosts depth in a few cells
///    (`largeTearProbability`) into deep chunks;
///  * **corner damage** — extra depth ramped in toward each edge's ends;
///  * **fibre roughening** — a high-frequency, per-column strand jitter fuzzes
///    the finger edges without breaking connectivity;
///  * **connectivity** — the keep-test is monotone in penetration, so every kept
///    pixel stays attached to the body (no floating islands);
///  * **anti-aliasing** — optional supersample + box downsample for soft fibres.
///
/// All reach is clamped to [kMaxPenetration] so the interior never tears.
class TornGeometryGenerator {
  const TornGeometryGenerator();

  /// Generate the mask at [width]×[height]. [supersample] > 1 renders at that
  /// linear multiple and box-downsamples for anti-aliased fibre edges (graded
  /// alpha); the default of 1 yields a crisp binary mask (cheap + test-stable).
  TornMask generate(
    TornRecipe recipe, {
    required int width,
    required int height,
    int supersample = 1,
  }) {
    if (supersample <= 1) return _binary(recipe, width, height);
    final ss = supersample;
    final hi = _binary(recipe, width * ss, height * ss);
    return _downsample(hi, width, height, ss);
  }

  TornMask _binary(TornRecipe recipe, int width, int height) {
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

  /// Box-average an `ss×ss` block of the high-res binary mask into one graded
  /// alpha, giving anti-aliased fibre edges.
  TornMask _downsample(TornMask hi, int w, int h, int ss) {
    final out = Uint8List(w * h);
    final area = ss * ss;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var kept = 0;
        final x0 = x * ss;
        final y0 = y * ss;
        for (var dy = 0; dy < ss; dy++) {
          final row = (y0 + dy) * hi.width + x0;
          for (var dx = 0; dx < ss; dx++) {
            if (hi.alpha[row + dx] != 0) kept++;
          }
        }
        out[y * w + x] = (kept * 255 / area).round();
      }
    }
    return TornMask(w, h, out);
  }
}

/// Per-edge geometry: gamma-biased fBm boundary depth + large cellular sections
/// + corner ramps, carved into separated tapering fibres by an anisotropic,
/// domain-warped, fibre-roughened strand field.
class _EdgeProfile {
  const _EdgeProfile({
    required int depthBase,
    required double depthCycles,
    required double gamma,
    required double scale,
    required int bigBase,
    required int bigCells,
    required double bigProb,
    required double bigMult,
    required double cornerBoost,
    required int strandBase,
    required double strandCycles,
    required int warpBase,
    required double warpAmp,
    required double warpCycles,
    required double taperPower,
    required int fibreBase,
    required double fibreCycles,
    required double fibreAmp,
  })  : _depthBase = depthBase,
        _depthCycles = depthCycles,
        _gamma = gamma,
        _scale = scale,
        _bigBase = bigBase,
        _bigCells = bigCells,
        _bigProb = bigProb,
        _bigMult = bigMult,
        _cornerBoost = cornerBoost,
        _strandBase = strandBase,
        _strandCycles = strandCycles,
        _warpBase = warpBase,
        _warpAmp = warpAmp,
        _warpCycles = warpCycles,
        _taperPower = taperPower,
        _fibreBase = fibreBase,
        _fibreCycles = fibreCycles,
        _fibreAmp = fibreAmp;

  final int _depthBase;
  final double _depthCycles;
  final double _gamma;
  final double _scale; // == maxTearDepth * edgeWeight * edgeDamageAmount

  final int _bigBase;
  final int _bigCells;
  final double _bigProb; // chance a cell becomes a large missing section
  final double _bigMult; // depth multiplier inside a big-tear cell (~2..3)
  final double _cornerBoost; // extra depth ramped in toward the edge's ends

  final int _strandBase;
  final double _strandCycles; // fingers per edge length
  final int _warpBase;
  final double _warpAmp; // domain-warp displacement (strand-widths)
  final double _warpCycles;
  final double _taperPower; // >1 sharpens the finger tips

  final int _fibreBase;
  final double _fibreCycles; // very-high-freq roughening of the finger edges
  final double _fibreAmp;

  static const double _cornerFrac = 0.16; // fraction of the edge near each end

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

    return _EdgeProfile(
      depthBase: rng.nextInt(1 << 30),
      depthCycles: cycles,
      gamma: gamma,
      scale: scale,
      bigBase: rng.nextInt(1 << 30),
      bigCells: rng.nextIntRange(3, 6),
      bigProb: recipe.largeTearProbability,
      bigMult: rng.nextRange(2.0, 3.0),
      cornerBoost: recipe.cornerDamage * recipe.maxTearDepth,
      strandBase: rng.nextInt(1 << 30),
      strandCycles: strandCycles,
      warpBase: rng.nextInt(1 << 30),
      warpAmp: warpAmp,
      warpCycles: cycles * 1.7,
      taperPower: taperPower,
      fibreBase: rng.nextInt(1 << 30),
      fibreCycles: strandCycles * 3.5,
      fibreAmp: 0.06 + recipe.frayAmount * 0.12,
    );
  }

  /// Max inward reach of damage at along-edge position [t] (0 == intact),
  /// clamped to [kMaxPenetration].
  double depthAt(double t) {
    if (_scale <= 0) return 0;
    var n = _fbm1(t * _depthCycles, _depthBase);
    n = math.pow(n, _gamma).toDouble(); // bias toward intact; occasional deep
    var d = n * _scale * _bigMultAt(t) + _cornerBoostAt(t);
    return d > kMaxPenetration ? kMaxPenetration : d;
  }

  /// Cellular large-section multiplier: a few cells open into deep chunks.
  double _bigMultAt(double t) {
    if (_bigProb <= 0) return 1;
    final cell = (t * _bigCells).floor();
    if (_lattice(cell, _bigBase) >= _bigProb) return 1;
    final local = t * _bigCells - cell; // 0..1 within the cell
    final bump = math.sin(math.pi * local); // 0 at cell edges, 1 mid → a chunk
    return 1 + (_bigMult - 1) * bump;
  }

  /// Additive corner ramp: extra depth toward each end of the edge.
  double _cornerBoostAt(double t) {
    if (_cornerBoost <= 0) return 0;
    final nearStart = t < _cornerFrac ? 1 - t / _cornerFrac : 0.0;
    final nearEnd = t > 1 - _cornerFrac ? (t - (1 - _cornerFrac)) / _cornerFrac : 0.0;
    final ramp = nearStart > nearEnd ? nearStart : nearEnd;
    return _cornerBoost * ramp * ramp; // eased so corners bite, edges taper off
  }

  /// True if the pixel at along-edge coord [t], inward penetration [pen]
  /// (fraction), given the local boundary depth [dep], is torn away by this edge.
  bool tears(double t, double pen, double dep) {
    if (dep <= 0 || pen >= dep) return false; // outside the damaged band
    // Anisotropic strand field: mostly a function of t (fingers run inward),
    // gently domain-warped so strands bend and split rather than comb straight.
    final warp = _warpAmp *
        (_fbm1(t * _warpCycles + pen * 3.0, _warpBase, octaves: 2) - 0.5);
    var sf = _valueNoise1((t + warp) * _strandCycles, _strandBase);
    // Fibre roughening: a per-column (t-only) high-freq jitter fuzzes the finger
    // edges; being independent of pen it keeps the keep-test monotone in pen.
    sf += _fibreAmp * (_valueNoise1(t * _fibreCycles, _fibreBase) - 0.5);
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
