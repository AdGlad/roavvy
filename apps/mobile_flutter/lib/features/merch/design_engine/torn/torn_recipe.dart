import '../procedural/deterministic_rng.dart';

/// The four flag edges tears originate from. Grain runs perpendicular-inward:
/// left/right fray horizontally (along the stripes), top/bottom vertically.
enum FlagEdge { top, bottom, left, right }

/// Named torn "families". Each family is a bounded parameter *range* that yields
/// many reproducible variations via [TornFamilySpec.sample] + seed.
enum TearStyle {
  lightlyWorn,
  ragged,
  tornCorners,
  battleWorn,
  deepRips,
  frayed,
  asymmetricTear,
  heavyEdgeDamage,
}

/// A fully-specified, deterministic torn perimeter — the input to the geometry
/// generator (`TornRecipe → TornGeometryGenerator → Mask → Renderer`). It
/// describes ONLY the tear geometry; the flag artwork (single or blended) is a
/// separate intact source. Reproducible from [seed] + the fields.
class TornRecipe {
  const TornRecipe({
    required this.style,
    required this.edgeWeights,
    required this.edgeDamageAmount,
    required this.maxTearDepth,
    required this.tearFrequency,
    required this.largeTearProbability,
    required this.notchScale,
    required this.frayAmount,
    required this.cornerDamage,
    required this.asymmetry,
    required this.seed,
  });

  final TearStyle style;

  /// Per-edge damage weight (0 = intact, 1 = fully affected). The asymmetry
  /// driver: a real flag keeps its hoist + canton near-intact.
  final Map<FlagEdge, double> edgeWeights;

  /// Global damage scale, 0..1.
  final double edgeDamageAmount;

  /// Deepest inward tear as a fraction of the flag's dimension (~0..0.4).
  final double maxTearDepth;

  /// Broad bays / notches per edge (~2..9).
  final double tearFrequency;

  /// Probability a large "missing section" chunk opens up (0..1).
  final double largeTearProbability;

  /// Relative size of small notches (0..1).
  final double notchScale;

  /// Fibre/streamer intensity — strand density + edge fuzz (0..1).
  final double frayAmount;

  /// Extra damage concentrated at corners (0..1).
  final double cornerDamage;

  /// How unevenly damage is spread across edges (0 = even, 1 = one edge only).
  final double asymmetry;

  final int seed;

  double edgeWeight(FlagEdge e) => (edgeWeights[e] ?? 0.0).clamp(0.0, 1.0);

  /// Stable identity — the cache key for the generated mask.
  String get tornId => [
        style.name,
        for (final e in FlagEdge.values) edgeWeight(e).toStringAsFixed(3),
        edgeDamageAmount.toStringAsFixed(3),
        maxTearDepth.toStringAsFixed(3),
        tearFrequency.toStringAsFixed(2),
        largeTearProbability.toStringAsFixed(3),
        notchScale.toStringAsFixed(3),
        frayAmount.toStringAsFixed(3),
        cornerDamage.toStringAsFixed(3),
        asymmetry.toStringAsFixed(3),
        seed,
      ].join('|');

  Map<String, dynamic> toJson() => {
        'style': style.name,
        'edgeWeights': {
          for (final e in edgeWeights.entries) e.key.name: e.value,
        },
        'edgeDamageAmount': edgeDamageAmount,
        'maxTearDepth': maxTearDepth,
        'tearFrequency': tearFrequency,
        'largeTearProbability': largeTearProbability,
        'notchScale': notchScale,
        'frayAmount': frayAmount,
        'cornerDamage': cornerDamage,
        'asymmetry': asymmetry,
        'seed': seed,
        'tornId': tornId,
      };
}

/// A closed range `[min, max]`.
typedef Range = (double, double);

/// A curated torn family: bounded ranges + which edges take the primary damage.
/// [sample] draws a concrete [TornRecipe] deterministically from `(style, seed)`.
class TornFamilySpec {
  const TornFamilySpec({
    required this.style,
    required this.primaryEdges,
    required this.edgeDamage,
    required this.maxDepth,
    required this.frequency,
    required this.largeTearProb,
    required this.notch,
    required this.fray,
    required this.corner,
    required this.asymmetry,
  });

  final TearStyle style;

  /// Edges that take the heavy damage; the rest stay near-intact (scaled by the
  /// sampled asymmetry).
  final Set<FlagEdge> primaryEdges;

  final Range edgeDamage;
  final Range maxDepth;
  final Range frequency;
  final Range largeTearProb;
  final Range notch;
  final Range fray;
  final Range corner;
  final Range asymmetry;

  TornRecipe sample(int seed) {
    final rng = DeterministicRng.stream(seed, 'torn:${style.name}');
    double r(Range g) => rng.nextRange(g.$1, g.$2);
    final asym = r(asymmetry);
    // Non-primary edges fall off with the *square* of asymmetry so a strongly
    // asymmetric recipe leaves the opposite edge (e.g. the hoist) near-intact,
    // not merely lightly torn.
    final weights = <FlagEdge, double>{
      for (final e in FlagEdge.values)
        e: ((primaryEdges.contains(e) ? 1.0 : (1.0 - asym) * (1.0 - asym)) *
                (0.85 + rng.stream('w${e.name}').nextDouble() * 0.3))
            .clamp(0.0, 1.0),
    };
    return TornRecipe(
      style: style,
      edgeWeights: weights,
      edgeDamageAmount: r(edgeDamage),
      maxTearDepth: r(maxDepth),
      tearFrequency: r(frequency),
      largeTearProbability: r(largeTearProb),
      notchScale: r(notch),
      frayAmount: r(fray),
      cornerDamage: r(corner),
      asymmetry: asym,
      seed: seed,
    );
  }
}

/// The eight curated torn families. Defaults bias the fly (right) + bottom hem
/// heavy and keep the hoist (left) + top near-intact, matching real flags.
const Map<TearStyle, TornFamilySpec> kTornFamilies = {
  TearStyle.lightlyWorn: TornFamilySpec(
    style: TearStyle.lightlyWorn,
    // E-T01: raised the damage floor so this family actually reads as *worn*
    // (was scale≈0.014, barely above the 0.012 snap-to-intact → ~0.5% removed,
    // 1–2 fingers). Still the LIGHTEST family (below ragged's 0.35–0.55/0.12–0.20)
    // so the light↔heavy diversity spread is preserved.
    primaryEdges: {FlagEdge.right, FlagEdge.bottom},
    edgeDamage: (0.28, 0.45),
    // E-T04: after E-T03 raised global strand density, lightlyWorn's finer strands
    // merged under its shallow band (fingers 4.7→4.0). Deepen the band slightly so
    // strands separate again — still the lightest family (below ragged 0.12–0.20).
    maxDepth: (0.11, 0.17),
    frequency: (4, 6),
    largeTearProb: (0.0, 0.05),
    notch: (0.3, 0.5),
    fray: (0.30, 0.50),
    corner: (0.10, 0.25),
    asymmetry: (0.20, 0.40),
  ),
  TearStyle.ragged: TornFamilySpec(
    style: TearStyle.ragged,
    primaryEdges: {FlagEdge.right, FlagEdge.bottom},
    edgeDamage: (0.35, 0.55),
    maxDepth: (0.12, 0.20),
    frequency: (4, 7),
    largeTearProb: (0.10, 0.20),
    notch: (0.4, 0.7),
    fray: (0.50, 0.70),
    corner: (0.30, 0.50),
    asymmetry: (0.30, 0.50),
  ),
  TearStyle.tornCorners: TornFamilySpec(
    style: TearStyle.tornCorners,
    primaryEdges: {FlagEdge.right, FlagEdge.top},
    edgeDamage: (0.20, 0.35),
    maxDepth: (0.10, 0.18),
    frequency: (3, 5),
    largeTearProb: (0.10, 0.20),
    notch: (0.3, 0.5),
    fray: (0.40, 0.60),
    corner: (0.70, 1.00),
    asymmetry: (0.40, 0.60),
  ),
  TearStyle.battleWorn: TornFamilySpec(
    style: TearStyle.battleWorn,
    primaryEdges: {FlagEdge.right, FlagEdge.bottom},
    edgeDamage: (0.50, 0.70),
    maxDepth: (0.18, 0.28),
    frequency: (4, 7),
    largeTearProb: (0.20, 0.35),
    notch: (0.4, 0.7),
    fray: (0.60, 0.80),
    corner: (0.50, 0.80),
    asymmetry: (0.30, 0.50),
  ),
  TearStyle.deepRips: TornFamilySpec(
    style: TearStyle.deepRips,
    primaryEdges: {FlagEdge.right},
    edgeDamage: (0.40, 0.60),
    maxDepth: (0.25, 0.38),
    frequency: (2, 4), // fewer, deeper
    largeTearProb: (0.30, 0.50),
    notch: (0.2, 0.4),
    fray: (0.40, 0.60),
    corner: (0.30, 0.55),
    asymmetry: (0.50, 0.70),
  ),
  TearStyle.frayed: TornFamilySpec(
    style: TearStyle.frayed,
    primaryEdges: {FlagEdge.right, FlagEdge.bottom, FlagEdge.left},
    edgeDamage: (0.30, 0.45),
    // E-T02: frayed has the HIGHEST fray (0.80–1.00) yet produced the FEWEST
    // finger transitions (~4.7) — the fine strands had too shallow a band to
    // taper into separated, countable fingers. Deepen the band so high fray
    // actually reads as many separated streamers (its whole identity).
    maxDepth: (0.14, 0.22),
    frequency: (6, 9), // many fine strands
    largeTearProb: (0.05, 0.15),
    notch: (0.5, 0.8),
    fray: (0.80, 1.00),
    corner: (0.30, 0.50),
    asymmetry: (0.20, 0.40),
  ),
  TearStyle.asymmetricTear: TornFamilySpec(
    style: TearStyle.asymmetricTear,
    primaryEdges: {FlagEdge.right}, // one edge only
    edgeDamage: (0.40, 0.60),
    maxDepth: (0.20, 0.30),
    frequency: (3, 6),
    largeTearProb: (0.15, 0.30),
    notch: (0.3, 0.6),
    fray: (0.50, 0.70),
    corner: (0.20, 0.40),
    asymmetry: (0.70, 0.90),
  ),
  TearStyle.heavyEdgeDamage: TornFamilySpec(
    style: TearStyle.heavyEdgeDamage,
    primaryEdges: {FlagEdge.top, FlagEdge.bottom, FlagEdge.left, FlagEdge.right},
    edgeDamage: (0.55, 0.75),
    maxDepth: (0.20, 0.30),
    frequency: (5, 8),
    largeTearProb: (0.20, 0.35),
    notch: (0.4, 0.7),
    fray: (0.60, 0.85),
    corner: (0.50, 0.75),
    asymmetry: (0.10, 0.30),
  ),
};

/// Deterministically sample a recipe from a family + seed.
TornRecipe sampleTornRecipe(TearStyle style, int seed) =>
    kTornFamilies[style]!.sample(seed);
