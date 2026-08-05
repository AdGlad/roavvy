import 'dart:math' as math;

import '../../print_style/print_style.dart' show PrintStyleId;
import 'composition_family.dart';

/// Abstract graphic-design principles — the ONLY things we extract from
/// reference artwork. We never copy layouts or artwork; we characterise
/// references along these orthogonal axes so the engine can pursue the same
/// *principles* with entirely original, travel-driven compositions.
///
/// Each axis is a 0..1 spectrum (see the doc comment on each). A value near
/// 0.5 is "balanced/neutral" on that axis.
enum DesignPrinciple {
  /// 0 = flat/equal weight … 1 = one element clearly dominates.
  visualHierarchy,

  /// 0 = small/restrained … 1 = large/bold subject scale.
  scale,

  /// 0 = fully contained … 1 = aggressive bleed/crop.
  cropping,

  /// 0 = dense/full frame … 1 = generous negative space.
  negativeSpace,

  /// 0 = asymmetric … 1 = symmetric.
  symmetry,

  /// 0 = strict grid/structured … 1 = organic/freeform placement.
  layout,

  /// 0 = organic forms … 1 = hard geometric forms.
  geometry,

  /// 0 = singular … 1 = strong repetition/pattern.
  repetition,

  /// 0 = clean/flat … 1 = heavy surface texture.
  texture,

  /// 0 = pristine … 1 = heavily distressed/worn.
  distress,

  /// 0 = image-led … 1 = type-led.
  typography,

  /// 0 = monochrome/quiet … 1 = vibrant/high-contrast colour play.
  colourRelationships,

  /// 0 = flat single layer … 1 = multiple overlapping layers.
  layering,

  /// 0 = clean edges … 1 = torn/rough/hand-cut edges.
  edgeTreatment,

  /// 0 = digital-flat … 1 = authentic print character (halftone/riso/screen).
  printCharacter,

  /// 0 = sparse … 1 = visually packed.
  visualDensity,
}

/// The Style DNA of a *single* reference: where it sits on each principle,
/// plus its verdict and free tags. Produced from a studio reference_analysis
/// record (or hand-authored). Never contains the source image.
class StyleDna {
  const StyleDna({
    required this.values,
    this.liked = true,
    this.tags = const [],
    this.sourceId,
  });

  final Map<DesignPrinciple, double> values;
  final bool liked;
  final List<String> tags;
  final String? sourceId;

  double value(DesignPrinciple p) => (values[p] ?? 0.5).clamp(0.0, 1.0);
}

/// A preferred band on one principle plus its importance weight.
class PrincipleTarget {
  const PrincipleTarget(this.min, this.max, this.weight);
  final double min;
  final double max;
  final double weight;

  double get centre => (min + max) / 2;

  /// Closeness of [v] to this band in 0..1: 1 inside the band, decaying
  /// smoothly outside it (tolerance ~ the band half-width, min 0.15).
  double closeness(double v) {
    if (v >= min && v <= max) return 1.0;
    final tol = math.max(0.15, (max - min) / 2 + 0.05);
    final d = v < min ? min - v : v - max;
    return (1.0 - d / tol).clamp(0.0, 1.0);
  }
}

/// The aggregated **Roavvy Design DNA**: the target band per principle, plus
/// soft affinities for composition families and print treatments. This is what
/// steers *quality* scoring and generation priors — the house style — kept
/// entirely separate from any individual user's preference profile.
class RoavvyDesignDna {
  const RoavvyDesignDna({
    required this.targets,
    required this.familyAffinity,
    required this.printStyleAffinity,
    this.explorationBias = 0.5,
    this.sampleCount = 0,
  });

  final Map<DesignPrinciple, PrincipleTarget> targets;
  final Map<CompositionFamily, double> familyAffinity;
  final Map<PrintStyleId, double> printStyleAffinity;

  /// How much the DNA itself encourages exploration vs tight adherence (0..1).
  final double explorationBias;

  /// How many references this DNA was aggregated from (0 = principled default).
  final int sampleCount;

  double familyWeight(CompositionFamily f) => familyAffinity[f] ?? 0.5;
  double printStyleWeight(PrintStyleId s) => printStyleAffinity[s] ?? 0.5;

  /// Weighted alignment of a principle vector with the DNA, in 0..1. Used by
  /// the quality model to reward on-DNA designs without forbidding off-DNA ones.
  double alignment(Map<DesignPrinciple, double> vec) {
    var wsum = 0.0;
    var acc = 0.0;
    targets.forEach((p, t) {
      final v = (vec[p] ?? t.centre).clamp(0.0, 1.0);
      acc += t.weight * t.closeness(v);
      wsum += t.weight;
    });
    return wsum <= 0 ? 0.5 : acc / wsum;
  }

  /// Aggregate a DNA from labelled references. Liked references define the
  /// target bands (mean ± spread); disliked references push bands *away* from
  /// their mean. Weight rises with how consistent the liked set is on an axis
  /// (tight agreement ⇒ stronger conviction). Falls back to the principled
  /// default for axes with no signal.
  factory RoavvyDesignDna.aggregate(
    List<StyleDna> references, {
    RoavvyDesignDna base = kRoavvyDesignDnaDefault,
  }) {
    final liked = references.where((r) => r.liked).toList();
    if (liked.isEmpty) return base;
    final targets = <DesignPrinciple, PrincipleTarget>{};
    for (final p in DesignPrinciple.values) {
      final xs = liked.map((r) => r.value(p)).toList();
      final mean = xs.reduce((a, b) => a + b) / xs.length;
      final variance =
          xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
              xs.length;
      final sd = math.sqrt(variance);
      // Band = mean ± max(sd, 0.08); tighter agreement ⇒ higher weight.
      final half = math.max(sd, 0.08);
      final weight = (1.0 - sd.clamp(0.0, 0.5) / 0.5)
          .clamp(0.2, 1.0); // 1 when unanimous, ≥0.2 when scattered
      targets[p] = PrincipleTarget(
        (mean - half).clamp(0.0, 1.0),
        (mean + half).clamp(0.0, 1.0),
        weight,
      );
    }
    return RoavvyDesignDna(
      targets: targets,
      familyAffinity: base.familyAffinity,
      printStyleAffinity: base.printStyleAffinity,
      explorationBias: base.explorationBias,
      sampleCount: liked.length,
    );
  }
}

/// Principled default DNA for Roavvy — a premium, bold-but-clean travel brand:
/// strong hierarchy, honest negative space, readable flags (limited cropping),
/// controlled density, and characterful-not-grungy print. Used until the
/// reference library is populated; the aggregate replaces it once references
/// exist. These bands are a primary tuning surface for the engine-tuner.
const RoavvyDesignDna kRoavvyDesignDnaDefault = RoavvyDesignDna(
  targets: {
    DesignPrinciple.visualHierarchy: PrincipleTarget(0.55, 0.95, 1.0),
    DesignPrinciple.negativeSpace: PrincipleTarget(0.30, 0.65, 0.9),
    DesignPrinciple.visualDensity: PrincipleTarget(0.25, 0.70, 0.9),
    DesignPrinciple.scale: PrincipleTarget(0.45, 0.90, 0.7),
    DesignPrinciple.cropping: PrincipleTarget(0.00, 0.45, 0.6),
    DesignPrinciple.colourRelationships: PrincipleTarget(0.35, 0.90, 0.5),
    DesignPrinciple.printCharacter: PrincipleTarget(0.20, 0.80, 0.6),
    DesignPrinciple.texture: PrincipleTarget(0.10, 0.60, 0.4),
    DesignPrinciple.distress: PrincipleTarget(0.00, 0.55, 0.4),
    DesignPrinciple.typography: PrincipleTarget(0.15, 0.75, 0.5),
    DesignPrinciple.geometry: PrincipleTarget(0.40, 0.90, 0.4),
    DesignPrinciple.symmetry: PrincipleTarget(0.20, 0.80, 0.3),
    DesignPrinciple.edgeTreatment: PrincipleTarget(0.00, 0.60, 0.3),
    DesignPrinciple.layering: PrincipleTarget(0.00, 0.60, 0.3),
    DesignPrinciple.layout: PrincipleTarget(0.20, 0.80, 0.2),
    DesignPrinciple.repetition: PrincipleTarget(0.00, 1.00, 0.2),
  },
  familyAffinity: {
    CompositionFamily.singleHero: 0.9,
    CompositionFamily.dominantAccent: 0.85,
    CompositionFamily.negativeSpaceCutout: 0.9,
    CompositionFamily.repetitionField: 0.7,
    CompositionFamily.radialEmblem: 0.65,
    CompositionFamily.typographicIntegration: 0.7,
    CompositionFamily.chronoSequence: 0.6,
    CompositionFamily.splitField: 0.6,
  },
  printStyleAffinity: {
    PrintStyleId.clean: 0.9,
    PrintStyleId.vintage: 0.8,
    PrintStyleId.retro: 0.75,
    PrintStyleId.halftone: 0.7,
    PrintStyleId.stamp: 0.65,
    PrintStyleId.edgeTear: 0.6,
    PrintStyleId.grunge: 0.5,
    PrintStyleId.riso: 0.6,
    PrintStyleId.sunFaded: 0.6,
    PrintStyleId.acidWash: 0.5,
    PrintStyleId.newsprint: 0.45,
    PrintStyleId.photocopy: 0.4,
  },
  explorationBias: 0.5,
);
