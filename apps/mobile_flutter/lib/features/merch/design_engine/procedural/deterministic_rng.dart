import 'dart:math' as math;

/// Deterministic, portable PRNG for the procedural design engine.
///
/// Uses SplitMix64 so a design is reproducible from `(seed, engineVersion,
/// context)` alone — independent of `dart:math`'s `Random` implementation,
/// which is not guaranteed stable across platforms/versions. Every stochastic
/// choice in generation MUST come from here so that the same inputs always
/// yield the same [DesignRecipe] (see design_engine/docs/architecture.md).
///
/// Split the master stream into **named sub-streams** (e.g. `'family'`,
/// `'layout'`, `'palette'`) with [stream] so that adding a new random draw in
/// one dimension does not shift the numbers consumed by every other dimension.
class DeterministicRng {
  DeterministicRng(int seed) : _state = _mix(seed & _mask);

  /// Derives a sub-stream deterministically from this rng's seed and a [name].
  /// Two sub-streams with different names are statistically independent, and
  /// the same name always reproduces the same sequence.
  DeterministicRng.stream(int seed, String name)
    : _state = _mix((seed & _mask) ^ _fnv1a(name));

  static const int _mask = 0x7FFFFFFFFFFFFFFF; // 63-bit (avoid sign issues)
  int _state;

  /// A fresh independent sub-stream from this generator.
  DeterministicRng stream(String name) => DeterministicRng.stream(_state, name);

  /// Next raw 63-bit value.
  int _next() {
    _state = (_state + 0x9E3779B97F4A7C15) & _mask;
    var z = _state;
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & _mask;
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & _mask;
    return (z ^ (z >> 31)) & _mask;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => (_next() >> 11) / (1 << 52);

  /// Uniform int in `[0, max)` (max > 0).
  int nextInt(int max) => max <= 1 ? 0 : _next() % max;

  /// Uniform int in `[min, max]` inclusive.
  int nextIntRange(int min, int max) =>
      max <= min ? min : min + nextInt(max - min + 1);

  /// Uniform double in `[min, max)`.
  double nextRange(double min, double max) => min + nextDouble() * (max - min);

  /// Approx. standard normal (Box–Muller); clamped to ±3.5σ for stability.
  double nextGaussian() {
    final u1 = nextDouble().clamp(1e-9, 1.0);
    final u2 = nextDouble();
    final g = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    return g.clamp(-3.5, 3.5);
  }

  /// `true` with probability [p].
  bool chance(double p) => nextDouble() < p;

  /// Uniformly pick one element of [items].
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Weighted pick: index i chosen with probability `weights[i] / sum`.
  /// Non-positive weights are treated as 0. Falls back to the last item.
  int pickWeightedIndex(List<double> weights) {
    var total = 0.0;
    for (final w in weights) {
      if (w > 0) total += w;
    }
    if (total <= 0) return weights.length - 1;
    var r = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      final w = weights[i];
      if (w <= 0) continue;
      r -= w;
      if (r < 0) return i;
    }
    return weights.length - 1;
  }

  /// Weighted pick returning the chosen element.
  T pickWeighted<T>(List<T> items, List<double> weights) =>
      items[pickWeightedIndex(weights)];

  /// Deterministic Fisher–Yates shuffle of a copy of [items].
  List<T> shuffled<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  // SplitMix64 finaliser used to disperse the initial seed.
  static int _mix(int x) {
    var z = (x + 0x9E3779B97F4A7C15) & _mask;
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & _mask;
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & _mask;
    return (z ^ (z >> 31)) & _mask;
  }

  /// Stable 63-bit FNV-1a hash of a string (used for seeds/sub-streams).
  static int _fnv1a(String s) {
    var h = 0xCBF29CE484222325 & _mask;
    for (final c in s.codeUnits) {
      h = (h ^ c) & _mask;
      h = (h * 0x100000001B3) & _mask;
    }
    return h;
  }

  /// Public stable string hash (for deriving seeds from context keys).
  static int hashString(String s) => _fnv1a(s);
}
