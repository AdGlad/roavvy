import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import 'design_context.dart';

/// How elements relate in a composition — the backbone of visual hierarchy.
enum HierarchyMode {
  /// One subject owns the frame; nothing competes.
  singleFocal,

  /// One dominant element plus smaller supporting accents.
  dominantAccent,

  /// Equal-weight repetition; order (not size) carries meaning.
  uniform,

  /// Elements radiate around a centre; symmetric emphasis.
  radial,

  /// Ordered progression (time / route).
  sequence,

  /// Two asymmetric zones in tension.
  dualZone,

  /// Type leads; imagery supports.
  typeLed,
}

/// A composition **family**: a relationship + the legal parameter ranges that
/// realise it on Roavvy's existing renderer. Families define *relationships*,
/// not finished designs — the generator samples concrete recipes within these
/// ranges (see design_engine/grammar/design_grammar.md).
class CompositionFamilySpec {
  const CompositionFamilySpec({
    required this.family,
    required this.hierarchy,
    required this.minCountries,
    required this.maxCountries,
    required this.templates,
    required this.masks,
    required this.layoutModes,
    required this.heroRequiredWhenMulti,
    required this.heroScaleRange,
    required this.densitySuitability,
    required this.scopeAffinity,
    this.rotationMaxDeg = 0,
    this.baseWeight = 1.0,
  });

  final CompositionFamily family;
  final HierarchyMode hierarchy;
  final int minCountries;
  final int maxCountries;

  /// Card templates that can realise this family (first is the canonical pick).
  final List<CardTemplateType> templates;

  /// Clip/mask shapes legal for this family (grid realisations).
  final List<GridClipShape> masks;
  final List<FlagGridLayoutMode> layoutModes;

  /// When >1 country, does this family need a designated hero?
  final bool heroRequiredWhenMulti;

  /// Legal fraction of the canvas the hero/dominant element occupies.
  final (double, double) heroScaleRange;

  /// Weight (0..1) of how well this family suits each density bucket.
  final Map<DesignDensityClass, double> densitySuitability;

  /// Weight (0..1) of how well this family suits each scope.
  final Map<DesignScope, double> scopeAffinity;

  final double rotationMaxDeg;
  final double baseWeight;

  bool admitsCount(int n) => n >= minCountries && n <= maxCountries;

  double densityWeight(DesignDensityClass d) => densitySuitability[d] ?? 0.0;
  double scopeWeight(DesignScope s) => scopeAffinity[s] ?? 0.4;
}

/// The initial composition grammar. Deliberately small and orthogonal: each
/// family owns a distinct hierarchy so the set spans "one country" → "many
/// countries" without any family collapsing into clutter. Tunable by the
/// engine-tuner; not a fixed catalogue of designs.
enum CompositionFamily {
  /// One country as a bold hero (outline/silhouette clip, badge, or stamp).
  singleHero,

  /// A hero flag with smaller supporting flags around it.
  dominantAccent,

  /// A uniform repeating field of flags (grouped by continent for order).
  repetitionField,

  /// Flags packed inside a bold silhouette/geometric cutout (the mask is hero).
  negativeSpaceCutout,

  /// A centred, symmetric emblem/badge.
  radialEmblem,

  /// Type-led statement with flags integrated/supporting.
  typographicIntegration,

  /// An ordered chronological sequence (timeline / journey route).
  chronoSequence,

  /// Two asymmetric zones — e.g. a ribbon/title band against a flag field.
  splitField,

  /// Exactly two flags merged into one graphic on the GPU (blend + ripple).
  duoBlend,

  /// The traveller's COUNT/scope is the hero — a bold typographic achievement
  /// statement ("47 COUNTRIES · 6 CONTINENTS", "EST. 2011") with flags demoted
  /// to a whisper. The premium answer for large sets where individual flags
  /// overwhelm (KB R-MERCH-02 "16+ → count-forward"; R-STORY-03 identity claim).
  statementCount,
}

/// Registry of family specs. Country ranges + density/scope weights are the
/// primary "tuning surface" for the engine-tuner.
const Map<CompositionFamily, CompositionFamilySpec> kCompositionFamilies = {
  CompositionFamily.singleHero: CompositionFamilySpec(
    family: CompositionFamily.singleHero,
    hierarchy: HierarchyMode.singleFocal,
    minCountries: 1,
    maxCountries: 2,
    templates: [
      CardTemplateType.grid,
      CardTemplateType.badge,
      CardTemplateType.passport,
      CardTemplateType.landmark,
    ],
    masks: [
      GridClipShape.countryOutline,
      GridClipShape.animalSilhouette,
      GridClipShape.plantSilhouette,
      GridClipShape.landmarkSilhouette,
      GridClipShape.circle,
      GridClipShape.none,
    ],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: true,
    heroScaleRange: (0.55, 0.9),
    densitySuitability: {
      DesignDensityClass.solo: 1.0,
      DesignDensityClass.small: 0.35,
    },
    scopeAffinity: {
      DesignScope.singleCountry: 1.0,
      DesignScope.trip: 0.8,
      DesignScope.random: 0.5,
    },
  ),
  CompositionFamily.dominantAccent: CompositionFamilySpec(
    family: CompositionFamily.dominantAccent,
    hierarchy: HierarchyMode.dominantAccent,
    minCountries: 2,
    maxCountries: 10,
    templates: [CardTemplateType.grid],
    masks: [GridClipShape.none, GridClipShape.circle, GridClipShape.heart],
    // E-007 (recipe-QA, 5/960 FRAGMENT-RISK): montage scatters the 2 flags into
    // fragmented quadrants when clipped small (same montage-scatter failure as
    // E-006). treemap gives dominantAccent the weighted hero+accent tiles it
    // actually wants, so use it exclusively.
    layoutModes: [FlagGridLayoutMode.treemap],
    heroRequiredWhenMulti: true,
    heroScaleRange: (0.32, 0.55),
    densitySuitability: {
      DesignDensityClass.small: 1.0,
      DesignDensityClass.medium: 0.8,
    },
    scopeAffinity: {
      DesignScope.multiCountry: 1.0,
      DesignScope.trip: 0.7,
      DesignScope.year: 0.6,
      DesignScope.random: 0.6,
    },
    rotationMaxDeg: 6,
  ),
  CompositionFamily.repetitionField: CompositionFamilySpec(
    family: CompositionFamily.repetitionField,
    hierarchy: HierarchyMode.uniform,
    minCountries: 4,
    maxCountries: 240,
    templates: [CardTemplateType.grid],
    // A field of flags can also be cut into a heart/circle for variety.
    masks: [GridClipShape.none, GridClipShape.heart, GridClipShape.circle],
    layoutModes: [
      FlagGridLayoutMode.packedRow,
      FlagGridLayoutMode.normalizedGrid,
      FlagGridLayoutMode.montage,
      FlagGridLayoutMode.treemap,
    ],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.0, 0.0),
    densitySuitability: {
      DesignDensityClass.medium: 0.9,
      DesignDensityClass.large: 1.0,
      DesignDensityClass.massive: 1.0,
    },
    scopeAffinity: {
      DesignScope.lifetime: 1.0,
      DesignScope.multiCountry: 0.9,
      DesignScope.year: 0.6,
      DesignScope.random: 0.6,
    },
  ),
  CompositionFamily.negativeSpaceCutout: CompositionFamilySpec(
    family: CompositionFamily.negativeSpaceCutout,
    hierarchy: HierarchyMode.singleFocal,
    // E-006 (instrumented: clip + coverGrid are correct; the real issue is
    // suitability): "flags PACKED inside a silhouette" needs several flags — with
    // 1–2 it renders sparse (thin outlines fit few; a mostly-white flag on a light
    // garment is near-invisible). Single/pair country is singleHero's job (R-VH-01),
    // so require >=3 flags to actually fill a cutout.
    minCountries: 3,
    maxCountries: 80,
    templates: [CardTemplateType.grid],
    masks: [
      GridClipShape.countryOutline,
      GridClipShape.continentOutline,
      GridClipShape.heart,
      GridClipShape.circle,
    ],
    // E-006 mitigation: all tiny/off-center negativeSpaceCutout renders shared
    // `montage`, which scatters few flags into a small cluster so the clipped
    // silhouette reads tiny. Use the fill-the-canvas modes (packedRow rows fill
    // width+height; normalizedGrid fills the canvas) so flags fill the outline.
    // (Root cause is the montage↔clip fill interaction in the renderer; this is a
    // low-risk generator steer, not the deep render fix — verify on-device.)
    layoutModes: [FlagGridLayoutMode.packedRow, FlagGridLayoutMode.normalizedGrid],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.7, 0.95),
    densitySuitability: {
      DesignDensityClass.solo: 0.7,
      DesignDensityClass.small: 0.9,
      DesignDensityClass.medium: 1.0,
      DesignDensityClass.large: 0.8,
      DesignDensityClass.massive: 0.5,
    },
    scopeAffinity: {
      DesignScope.region: 1.0,
      DesignScope.singleCountry: 0.8,
      DesignScope.multiCountry: 0.7,
      DesignScope.lifetime: 0.6,
      DesignScope.random: 0.6,
    },
  ),
  CompositionFamily.radialEmblem: CompositionFamilySpec(
    family: CompositionFamily.radialEmblem,
    hierarchy: HierarchyMode.radial,
    minCountries: 1,
    maxCountries: 24,
    templates: [CardTemplateType.badge, CardTemplateType.grid],
    masks: [GridClipShape.circle, GridClipShape.none],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.4, 0.7),
    densitySuitability: {
      DesignDensityClass.solo: 0.8,
      DesignDensityClass.small: 1.0,
      DesignDensityClass.medium: 0.7,
    },
    scopeAffinity: {
      DesignScope.singleCountry: 0.7,
      DesignScope.multiCountry: 0.7,
      DesignScope.region: 0.6,
      DesignScope.random: 0.6,
    },
    rotationMaxDeg: 0,
  ),
  CompositionFamily.typographicIntegration: CompositionFamilySpec(
    family: CompositionFamily.typographicIntegration,
    hierarchy: HierarchyMode.typeLed,
    minCountries: 1,
    maxCountries: 240,
    templates: [CardTemplateType.typography, CardTemplateType.wordCloud],
    masks: [GridClipShape.none],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.5, 0.85),
    densitySuitability: {
      DesignDensityClass.solo: 0.7,
      DesignDensityClass.small: 0.8,
      DesignDensityClass.medium: 0.9,
      DesignDensityClass.large: 0.9,
      DesignDensityClass.massive: 1.0,
    },
    scopeAffinity: {
      DesignScope.lifetime: 0.9,
      DesignScope.year: 0.8,
      DesignScope.multiCountry: 0.7,
      DesignScope.singleCountry: 0.7,
      DesignScope.random: 0.7,
    },
  ),
  CompositionFamily.chronoSequence: CompositionFamilySpec(
    family: CompositionFamily.chronoSequence,
    hierarchy: HierarchyMode.sequence,
    minCountries: 2,
    // E-001: a sequence renders each country ~1/n of the width, so beyond ~19
    // countries every candidate falls below the min printable feature (90px) and
    // is ALWAYS rejected — it had 0 survivors at lifetime(28)/massive(60) yet was
    // sampled every pool, inflating rejection (0.52 / 0.67). Cap to its legible,
    // survivable range (also R-MERCH-02: a timeline of >20 entries is clutter).
    maxCountries: 20,
    templates: [CardTemplateType.timeline, CardTemplateType.journeys],
    masks: [GridClipShape.none],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.0, 0.0),
    densitySuitability: {
      DesignDensityClass.small: 0.8,
      DesignDensityClass.medium: 1.0,
      DesignDensityClass.large: 0.9,
      DesignDensityClass.massive: 0.6,
    },
    scopeAffinity: {
      DesignScope.year: 1.0,
      DesignScope.lifetime: 0.9,
      DesignScope.trip: 0.7,
      DesignScope.multiCountry: 0.6,
      DesignScope.random: 0.5,
    },
  ),
  CompositionFamily.splitField: CompositionFamilySpec(
    family: CompositionFamily.splitField,
    hierarchy: HierarchyMode.dualZone,
    minCountries: 2,
    maxCountries: 30,
    templates: [CardTemplateType.frontRibbon, CardTemplateType.grid],
    masks: [GridClipShape.none],
    layoutModes: [
      FlagGridLayoutMode.packedRow,
      FlagGridLayoutMode.normalizedGrid,
    ],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.3, 0.5),
    densitySuitability: {
      DesignDensityClass.small: 0.9,
      DesignDensityClass.medium: 1.0,
      DesignDensityClass.large: 0.7,
    },
    scopeAffinity: {
      DesignScope.multiCountry: 0.8,
      DesignScope.trip: 0.7,
      DesignScope.year: 0.6,
      DesignScope.random: 0.6,
    },
  ),
  CompositionFamily.duoBlend: CompositionFamilySpec(
    family: CompositionFamily.duoBlend,
    hierarchy: HierarchyMode.dualZone,
    minCountries: 2,
    maxCountries: 2,
    templates: [CardTemplateType.grid], // placeholder; rendered by the shader
    masks: [GridClipShape.none],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.0, 0.0),
    densitySuitability: {DesignDensityClass.small: 0.9},
    scopeAffinity: {
      DesignScope.multiCountry: 0.9,
      DesignScope.trip: 0.7,
      DesignScope.random: 0.6,
    },
  ),
  // NEW FAMILY (concept C-01, 2026-08-16). Count/achievement-forward: the scope
  // statement is the hero. Large-set focused (min 5) so it becomes a strong
  // premium option exactly where many-flag layouts read as clutter — the weakest
  // contexts (lifetime/massive). Pure recombination of the existing `typography`
  // template; the count STRING is a TitleGen content variant (see catalogue entry
  // + rendering requirement). Distinct from typographicIntegration, which spans
  // all counts and integrates flags rather than leading with the numeric stat.
  CompositionFamily.statementCount: CompositionFamilySpec(
    family: CompositionFamily.statementCount,
    hierarchy: HierarchyMode.typeLed,
    minCountries: 5,
    maxCountries: 300,
    templates: [CardTemplateType.typography],
    masks: [GridClipShape.none],
    layoutModes: [FlagGridLayoutMode.packedRow],
    heroRequiredWhenMulti: false,
    heroScaleRange: (0.5, 0.8),
    densitySuitability: {
      DesignDensityClass.medium: 0.6,
      DesignDensityClass.large: 1.0,
      DesignDensityClass.massive: 1.0,
    },
    scopeAffinity: {
      DesignScope.lifetime: 1.0,
      DesignScope.region: 0.9,
      DesignScope.year: 0.7,
      DesignScope.multiCountry: 0.6,
      DesignScope.random: 0.5,
    },
  ),
};

/// Families whose country-range and density admit [context]. This is the first
/// cheap gate: a family that can't host the set is never even sampled.
List<CompositionFamilySpec> eligibleFamilies(DesignContext context) {
  final n = context.countryCount;
  return [
    for (final spec in kCompositionFamilies.values)
      // radialEmblem (the centred circular "dial" badge) is retired from
      // generation by product preference.
      if (spec.family != CompositionFamily.radialEmblem &&
          spec.admitsCount(n) &&
          spec.densityWeight(context.density) > 0)
        spec,
  ];
}
