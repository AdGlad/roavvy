import 'composition_family.dart';
import 'design_context.dart';
import 'design_dna.dart';
import 'procedural_recipe.dart';

/// A design's intrinsic quality — how well-made it is as a graphic, judged
/// against the Roavvy Design DNA and universal composition heuristics. This is
/// deliberately **independent of any user's taste** (that lives in the
/// preference profile). Cheap: derived from the recipe's estimated principles,
/// no rasterisation.
class QualityScore {
  const QualityScore({required this.total, required this.breakdown});

  /// Aggregate in 0..1.
  final double total;

  /// Named sub-scores (each 0..1) for diagnosis / critique reports.
  final Map<String, double> breakdown;

  double operator [](String k) => breakdown[k] ?? 0;

  @override
  String toString() =>
      'QualityScore(${total.toStringAsFixed(3)}, ${breakdown.map((k, v) => MapEntry(k, v.toStringAsFixed(2)))})';
}

/// Scores valid [ProceduralDesignRecipe]s. Weights are a tuning surface for the
/// engine-tuner; the default weights sum to 1.0.
class RecipeQualityModel {
  const RecipeQualityModel({
    this.dna = kRoavvyDesignDnaDefault,
    this.wDnaAlignment = 0.30,
    this.wHierarchy = 0.22,
    this.wDensityBalance = 0.15,
    this.wNegativeSpace = 0.10,
    this.wFamilyFit = 0.10,
    this.wFocalContrast = 0.08,
    this.wTreatment = 0.05,
  });

  final RoavvyDesignDna dna;
  final double wDnaAlignment;
  final double wHierarchy;
  final double wDensityBalance;
  final double wNegativeSpace;
  final double wFamilyFit;
  final double wFocalContrast;
  final double wTreatment;

  QualityScore score(ProceduralDesignRecipe r, DesignContext ctx) {
    final p = r.estimatePrinciples();
    final spec = kCompositionFamilies[r.family]!;

    final dnaAlignment = dna.alignment(p);

    // Hierarchy: the crux for multi-country. A single subject is inherently
    // clear; with many countries we reward designs whose hierarchy does NOT
    // collapse. Uniform fields are legitimately flat — judged on order/rhythm,
    // not on having a hero — so they get a moderate (not punished) score.
    final double hierarchy;
    if (r.countryCount <= 1) {
      hierarchy = 0.85;
    } else if (r.hierarchy == HierarchyMode.uniform) {
      // Rewarded for tidy repetition, capped because there's no focal point.
      hierarchy = 0.5 + 0.1 * p[DesignPrinciple.repetition]!;
    } else {
      // Focal families: reward a clear dominant and a real size gap.
      final base = p[DesignPrinciple.visualHierarchy]!;
      final gap =
          spec.heroRequiredWhenMulti && r.heroCode != null
              ? (r.heroScale - (1 - r.heroScale) / r.countryCount).clamp(
                0.0,
                1.0,
              )
              : 0.4;
      hierarchy = (0.6 * base + 0.4 * gap).clamp(0.0, 1.0);
    }

    final densityBalance = dna.targets[DesignPrinciple.visualDensity]!
        .closeness(p[DesignPrinciple.visualDensity]!);
    final negativeSpace = dna.targets[DesignPrinciple.negativeSpace]!.closeness(
      p[DesignPrinciple.negativeSpace]!,
    );

    // Family fit: does this family suit the scope + density, and is it on-DNA?
    final familyFit = (spec.scopeWeight(ctx.scope) *
            spec.densityWeight(ctx.density) *
            dna.familyWeight(r.family))
        .clamp(0.0, 1.0);

    // Focal contrast: how distinct the hero/subject is.
    final double focalContrast;
    if (r.countryCount <= 1) {
      focalContrast = 0.75;
    } else if (r.heroCode != null) {
      focalContrast = r.heroScale.clamp(0.0, 1.0);
    } else if (r.family == CompositionFamily.negativeSpaceCutout) {
      focalContrast = 0.7; // the silhouette is the subject
    } else if (r.hierarchy == HierarchyMode.typeLed) {
      // C-00: a type-led design's focal IS the wordmark/stat — a clear single
      // subject by construction (R-VH-01, R-STORY-03), NOT the 0.45 "no focal"
      // default. Scaled by how much of the canvas the type hero occupies.
      focalContrast = (0.55 + 0.3 * r.heroScale).clamp(0.0, 1.0);
    } else {
      focalContrast = 0.45;
    }

    // Treatment coherence: on-DNA print style + colour sanity vs garment.
    final treatment = (dna.printStyleWeight(r.printStyle) * 0.7 +
            p[DesignPrinciple.colourRelationships]! * 0.3)
        .clamp(0.0, 1.0);

    final total = (wDnaAlignment * dnaAlignment +
            wHierarchy * hierarchy +
            wDensityBalance * densityBalance +
            wNegativeSpace * negativeSpace +
            wFamilyFit * familyFit +
            wFocalContrast * focalContrast +
            wTreatment * treatment)
        .clamp(0.0, 1.0);

    return QualityScore(
      total: total,
      breakdown: {
        'dnaAlignment': dnaAlignment,
        'hierarchy': hierarchy,
        'densityBalance': densityBalance,
        'negativeSpace': negativeSpace,
        'familyFit': familyFit,
        'focalContrast': focalContrast,
        'treatment': treatment,
      },
    );
  }
}
