import 'dart:math' as math;

import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import '../../bundled_silhouette_manifest.dart';
import '../../print_style/print_style.dart' show ColorTreatment, PrintStyleId;
import '../../product_mockup_specs.dart' show ImageSize;
import '../design_params.dart';
import '../../merch_preset.dart'
    show MerchCountrySource, MerchDensity, MerchStampMode;
import 'composition_family.dart';
import 'design_context.dart';
import 'design_dna.dart';
import 'deterministic_rng.dart';
import 'hard_constraints.dart';
import 'procedural_recipe.dart';
import 'quality_model.dart';

/// Bumping this changes the meaning of a seed, so it is part of the
/// reproducibility contract (context + seed + engineVersion ⇒ same recipe).
const String kProceduralEngineVersion = '0.1.0';
const String kProceduralGrammarVersion = '0.1.0';

/// Two-flag blend patterns used by the generator. Excludes `none` and `radial`
/// (the concentric-ring "dial" look, dropped by product preference).
final List<FlagCombination> _kBlendModes = FlagCombination.values
    .where((c) =>
        c != FlagCombination.none && c != FlagCombination.radial)
    .toList(growable: false);

/// A generated design plus its intrinsic quality. The renderable genome is
/// available lazily via [params]; no raster happens until someone asks to draw.
class GeneratedDesign {
  const GeneratedDesign(this.recipe, this.quality);
  final ProceduralDesignRecipe recipe;
  final QualityScore quality;
  DesignParams get params => recipe.toDesignParams();
}

/// Diagnostics for a generation run — fuel for critic/regression metrics.
class GenerationStats {
  const GenerationStats({
    required this.produced,
    required this.rejected,
    required this.survivors,
    required this.rejectionReasons,
    required this.meanQuality,
    required this.topQuality,
  });
  final int produced;
  final int rejected;
  final int survivors;
  final Map<String, int> rejectionReasons;
  final double meanQuality;
  final double topQuality;

  Map<String, dynamic> toJson() => {
        'produced': produced,
        'rejected': rejected,
        'survivors': survivors,
        'rejectionReasons': rejectionReasons,
        'meanQuality': meanQuality,
        'topQuality': topQuality,
      };
}

class GenerationResult {
  const GenerationResult(this.designs, this.stats);
  final List<GeneratedDesign> designs;
  final GenerationStats stats;
}

/// The first working procedural generator. Turns a [DesignContext] + seed into
/// a small set of strong, diverse, printable [ProceduralDesignRecipe]s by
/// sampling the composition grammar under DNA priors, validating cheaply,
/// scoring intrinsic quality, discarding the weak, and selecting for both
/// quality and variety.
class ProceduralDesignGenerator {
  const ProceduralDesignGenerator({
    this.dna = kRoavvyDesignDnaDefault,
    this.quality = const RecipeQualityModel(),
    this.constraints = kDefaultRecipeConstraints,
    this.engineVersion = kProceduralEngineVersion,
    this.grammarVersion = kProceduralGrammarVersion,
  });

  final RoavvyDesignDna dna;
  final RecipeQualityModel quality;
  final List<RecipeConstraint> constraints;
  final String engineVersion;
  final String grammarVersion;

  /// Generate the strongest [count] designs for [context].
  ///
  /// [poolSize] recipes are sampled and cheaply validated/scored; the weak are
  /// discarded ([qualityFloor]) and the survivors are selected for quality with
  /// [exploration] controlling how much variety is favoured over pure ranking
  /// (0 = greedy best, 1 = quality-weighted random). Fully deterministic in
  /// (context, seed, engineVersion, grammarVersion).
  GenerationResult generate(
    DesignContext context, {
    int seed = 0,
    int count = 6,
    int poolSize = 48,
    double qualityFloor = 0.45,
    double exploration = 0.35,
  }) {
    final rootSeed = _deriveSeed(context, seed);
    final master = DeterministicRng(rootSeed);
    final families = eligibleFamilies(context);
    if (families.isEmpty) {
      return const GenerationResult([], GenerationStats(
        produced: 0,
        rejected: 0,
        survivors: 0,
        rejectionReasons: {},
        meanQuality: 0,
        topQuality: 0,
      ));
    }

    final famWeights = [
      for (final f in families)
        (f.scopeWeight(context.scope) *
                f.densityWeight(context.density) *
                dna.familyWeight(f.family) *
                f.baseWeight)
            .clamp(1e-3, double.infinity),
    ];

    final scored = <GeneratedDesign>[];
    final reasons = <String, int>{};
    var rejected = 0;

    for (var i = 0; i < poolSize; i++) {
      final crng = master.stream('cand$i');
      final spec = families[crng.stream('family').pickWeightedIndex(famWeights)];
      final recipeSeed =
          (rootSeed ^ (i * 0x9E3779B1)) & 0x7FFFFFFF;
      final recipe = _construct(spec, context, crng, recipeSeed);
      final reason = validateRecipe(recipe, context, constraints: constraints);
      if (reason != null) {
        rejected++;
        reasons[reason.split(' ').take(3).join(' ')] =
            (reasons[reason.split(' ').take(3).join(' ')] ?? 0) + 1;
        continue;
      }
      scored.add(GeneratedDesign(recipe, quality.score(recipe, context)));
    }

    // Discard weak; relax the floor if too few survive so we always return work.
    var survivors = scored.where((d) => d.quality.total >= qualityFloor).toList();
    if (survivors.length < count) {
      survivors = List.of(scored)
        ..sort((a, b) => b.quality.total.compareTo(a.quality.total));
      survivors = survivors.take(math.max(count * 2, survivors.length)).toList();
    }

    final selected = _selectDiverse(
      survivors,
      count,
      exploration,
      master.stream('select'),
    );

    final mean = scored.isEmpty
        ? 0.0
        : scored.map((d) => d.quality.total).reduce((a, b) => a + b) /
            scored.length;
    final top = scored.isEmpty
        ? 0.0
        : scored.map((d) => d.quality.total).reduce(math.max);

    return GenerationResult(
      selected,
      GenerationStats(
        produced: poolSize,
        rejected: rejected,
        survivors: scored.length,
        rejectionReasons: reasons,
        meanQuality: mean,
        topQuality: top,
      ),
    );
  }

  /// Combine seed with the context identity + engine/grammar versions so the
  /// same request always reproduces, and different scopes never alias.
  int _deriveSeed(DesignContext ctx, int seed) =>
      (DeterministicRng.hashString(
                  '$engineVersion|$grammarVersion|${ctx.scopeKey}') ^
              (seed & 0x7FFFFFFF)) &
          0x7FFFFFFF;

  // ── Recipe construction ────────────────────────────────────────────────────

  ProceduralDesignRecipe _construct(
    CompositionFamilySpec spec,
    DesignContext ctx,
    DeterministicRng rng,
    int recipeSeed,
  ) {
    final n = ctx.countryCount;

    // Template (canonical first, weighted higher).
    final tRng = rng.stream('template');
    final template = spec.templates[tRng.pickWeightedIndex([
      for (var i = 0; i < spec.templates.length; i++) i == 0 ? 1.0 : 0.5,
    ])];
    final isGrid = template == CardTemplateType.grid;

    // Hero selection (signature country preferred, else deterministic).
    final needsHero = spec.heroRequiredWhenMulti && n > 1;
    String? hero;
    if (n == 1) {
      hero = ctx.countryCodes.first;
    } else if (needsHero || spec.hierarchy == HierarchyMode.dominantAccent) {
      final pool = ctx.signatureCountries.isNotEmpty
          ? ctx.signatureCountries
          : ctx.countryCodes;
      hero = pool[rng.stream('hero').nextInt(pool.length)];
    }

    // Mask — filtered to what is legal for this count and resolvable via codes.
    final mask = isGrid ? _pickMask(spec, ctx, hero, rng.stream('mask')) : GridClipShape.none;
    final maskCode = _maskCode(mask, ctx, hero);

    // Layout mode.
    final layoutMode = isGrid
        ? spec.layoutModes[
            rng.stream('layout').nextInt(spec.layoutModes.length)]
        : FlagGridLayoutMode.packedRow;

    // Rows: from set size + orientation, clamped; hero families stay shallow.
    final isPortrait = rng.stream('orient').chance(_portraitProb(spec, template));
    final int rowCount;
    if (spec.hierarchy == HierarchyMode.uniform) {
      final aspect = isPortrait ? 1.35 : 0.72;
      rowCount = (math.sqrt(n * aspect)).round().clamp(1, 10);
    } else if (needsHero || spec.hierarchy == HierarchyMode.dominantAccent) {
      rowCount = rng.stream('rows').nextIntRange(1, 3);
    } else {
      rowCount = rng.stream('rows').nextIntRange(1, 4).clamp(1, 10);
    }

    // Hero scale within the family's legal band.
    final (loScale, hiScale) = spec.heroScaleRange;
    final heroScale =
        hiScale <= 0 ? 0.0 : rng.stream('scale').nextRange(loScale, hiScale);

    // Density / jitter (montage is looser than a tidy grid).
    final density = _pickDensity(ctx.density, rng.stream('density'));
    final jitter = layoutMode == FlagGridLayoutMode.montage
        ? rng.stream('jitter').nextRange(0.15, 0.5)
        : rng.stream('jitter').nextRange(0.0, 0.22);

    final stampMode = (template == CardTemplateType.passport)
        ? (rng.stream('stamp').chance(0.5)
            ? MerchStampMode.entryExit
            : MerchStampMode.entryOnly)
        : MerchStampMode.entryExit;

    final imageSize = _pickImageSize(rng.stream('size'));

    // Treatment: choose a coherent print style (texture+colour+edge together).
    final printStyle = _pickPrintStyle(ctx, rng.stream('print'));
    final colourTreatment = _colourFor(printStyle);

    // Continuous treatment genes, seeded from the style's typical character +
    // jitter, so they're coherent but now first-class + learnable.
    final f = printStyleFacets(printStyle);
    final distress =
        (f.distress * rng.stream('trD').nextRange(0.7, 1.05)).clamp(0.0, 0.85);
    final grain =
        (f.texture * 0.7 * rng.stream('trG').nextRange(0.6, 1.1)).clamp(0.0, 0.6);
    final halftone = f.printChar > 0.6
        ? rng.stream('trH').nextRange(0.3, 0.7)
        : rng.stream('trH').nextRange(0.0, 0.12);
    final fade =
        (f.distress * 0.5 * rng.stream('trF').nextRange(0.4, 1.0)).clamp(0.0, 0.5);
    final flagTreatment = template == CardTemplateType.typography &&
            rng.stream('flag').chance(0.3)
        ? FlagTreatment.monochrome
        : FlagTreatment.fullColour;

    // Placement / crop / rotation / layering.
    final placement = _pickPlacement(spec, rng.stream('place'));
    final placementOffset = rng.stream('poff').nextRange(-0.12, 0.12);
    final cropMode = rng.stream('crop').pickWeighted(
      const [CropMode.contained, CropMode.inset, CropMode.bleed],
      const [0.6, 0.3, 0.1],
    );
    final rotationDeg = spec.rotationMaxDeg <= 0
        ? 0.0
        : rng.stream('rot').nextRange(-spec.rotationMaxDeg, spec.rotationMaxDeg);
    final layerMode = (mask != GridClipShape.none &&
            rng.stream('layer').chance(0.5))
        ? LayerMode.layered
        : LayerMode.flat;

    // Flag-merge genes — only for the duoBlend family (exactly two flags). Picks
    // from the full palette of blend patterns for variety.
    final isDuo = spec.family == CompositionFamily.duoBlend;
    final combination = isDuo
        ? rng.stream('combo').pick(_kBlendModes)
        : FlagCombination.none;
    final weightA = isDuo ? rng.stream('wa').nextRange(0.35, 0.65) : 0.5;
    final rippleAmp = isDuo ? rng.stream('ramp').nextRange(0.0, 0.08) : 0.0;
    final rippleFreq = isDuo ? rng.stream('rfreq').nextRange(2.0, 6.0) : 3.0;

    return ProceduralDesignRecipe(
      engineVersion: engineVersion,
      grammarVersion: grammarVersion,
      seed: recipeSeed,
      scopeKey: ctx.scopeKey,
      family: spec.family,
      hierarchy: spec.hierarchy,
      template: template,
      layoutMode: layoutMode,
      mask: mask,
      maskCode: maskCode,
      rowCount: rowCount,
      countryCodes: ctx.countryCodes,
      heroCode: hero,
      source: _sourceFor(ctx.scope),
      density: density,
      jitter: jitter,
      stampMode: stampMode,
      isPortrait: isPortrait,
      imageSize: imageSize,
      garmentColour: ctx.garmentIsDark ? 'Black' : 'White',
      flagTreatment: flagTreatment,
      colourTreatment: colourTreatment,
      printStyle: printStyle,
      heroScale: heroScale,
      placement: placement,
      placementOffset: placementOffset,
      cropMode: cropMode,
      rotationDeg: rotationDeg,
      layerMode: layerMode,
      combination: combination,
      weightA: weightA,
      rippleAmp: rippleAmp,
      rippleFreq: rippleFreq,
      distress: distress,
      grain: grain,
      halftone: halftone,
      fade: fade,
    );
  }

  GridClipShape _pickMask(
    CompositionFamilySpec spec,
    DesignContext ctx,
    String? hero,
    DeterministicRng rng,
  ) {
    // Shapes we can resolve 100% locally. `animalSilhouette` is backed by the
    // bundled silhouette manifest (offline); plant/landmark silhouettes still
    // need Storage, so they stay excluded.
    const resolvable = {
      GridClipShape.none,
      GridClipShape.circle,
      GridClipShape.heart,
      GridClipShape.countryOutline,
      GridClipShape.continentOutline,
      GridClipShape.animalSilhouette,
    };
    final legal = <GridClipShape>[
      for (final m in spec.masks)
        if (resolvable.contains(m) &&
            _maskLegal(m, ctx.countryCount, ctx.dominantContinent, hero))
          m,
    ];
    if (legal.isEmpty) return GridClipShape.none;
    // Slight bias toward `none`, but low enough that shaped cut-outs (heart/
    // circle/outline) surface regularly for variety.
    final weights = [
      for (final m in legal) m == GridClipShape.none ? 1.05 : 1.0,
    ];
    return rng.pickWeighted(legal, weights);
  }

  bool _maskLegal(GridClipShape m, int n, String? continent, String? hero) {
    switch (m) {
      case GridClipShape.countryOutline:
        return n == 1 && hero != null;
      case GridClipShape.continentOutline:
        return continent != null;
      case GridClipShape.animalSilhouette:
        // Single-country only, and only when a BUNDLED silhouette exists (local).
        return n == 1 &&
            hero != null &&
            kBundledSilhouetteSlugs.containsKey(hero.toUpperCase());
      case GridClipShape.plantSilhouette:
      case GridClipShape.landmarkSilhouette:
        return false; // still Storage-only
      default:
        return true;
    }
  }

  String? _maskCode(GridClipShape m, DesignContext ctx, String? hero) =>
      switch (m) {
        GridClipShape.countryOutline => hero ?? ctx.countryCodes.first,
        GridClipShape.continentOutline =>
          ctx.dominantContinent?.toLowerCase().replaceAll(' ', '_'),
        // Composite "CC|slug" clipCode for the bundled silhouette.
        GridClipShape.animalSilhouette => hero == null
            ? null
            : '${hero.toUpperCase()}|${kBundledSilhouetteSlugs[hero.toUpperCase()]}',
        _ => null,
      };

  double _portraitProb(CompositionFamilySpec spec, CardTemplateType t) {
    if (spec.family == CompositionFamily.singleHero) return 0.35;
    if (t == CardTemplateType.typography) return 0.3;
    return 0.15;
  }

  MerchDensity _pickDensity(DesignDensityClass c, DeterministicRng rng) {
    final weights = switch (c) {
      DesignDensityClass.solo => const [0.5, 0.5, 0.0],
      DesignDensityClass.small => const [0.3, 0.6, 0.1],
      DesignDensityClass.medium => const [0.15, 0.6, 0.25],
      DesignDensityClass.large => const [0.05, 0.45, 0.5],
      DesignDensityClass.massive => const [0.0, 0.35, 0.65],
    };
    return rng.pickWeighted(
      const [MerchDensity.sparse, MerchDensity.balanced, MerchDensity.dense],
      weights,
    );
  }

  ImageSize _pickImageSize(DeterministicRng rng) => rng.pickWeighted(
        const [ImageSize.small, ImageSize.medium, ImageSize.large],
        const [0.15, 0.6, 0.25],
      );

  PrintStyleId _pickPrintStyle(DesignContext ctx, DeterministicRng rng) {
    const styles = PrintStyleId.values;
    // Single-country designs (the flag is the hero) lean into the torn /
    // distressed "flag tee" look — Edge Tear especially — while staying varied.
    final tornFlag = ctx.countryCount == 1;
    final weights = [
      for (final s in styles)
        dna.printStyleWeight(s) * (tornFlag ? _tornFlagBoost(s) : 1.0),
    ];
    return rng.pickWeighted(styles, weights);
  }

  static double _tornFlagBoost(PrintStyleId s) => switch (s) {
        PrintStyleId.edgeTear => 4.0,
        PrintStyleId.grunge => 1.8,
        PrintStyleId.vintage => 1.6,
        PrintStyleId.stamp => 1.4,
        PrintStyleId.clean => 0.35, // fewer plain, untreated flags
        _ => 1.0,
      };

  ColorTreatment _colourFor(PrintStyleId s) => switch (s) {
        PrintStyleId.clean => ColorTreatment.none,
        PrintStyleId.vintage => ColorTreatment.vintageWarm,
        PrintStyleId.retro => ColorTreatment.muted,
        PrintStyleId.halftone => ColorTreatment.none,
        PrintStyleId.stamp => ColorTreatment.monoInk,
        PrintStyleId.grunge => ColorTreatment.muted,
        PrintStyleId.riso => ColorTreatment.duotone,
        PrintStyleId.newsprint => ColorTreatment.monoInk,
        PrintStyleId.sunFaded => ColorTreatment.vintageWarm,
        PrintStyleId.photocopy => ColorTreatment.monoInk,
        PrintStyleId.edgeTear => ColorTreatment.none,
        PrintStyleId.acidWash => ColorTreatment.muted,
      };

  PlacementAnchor _pickPlacement(
          CompositionFamilySpec spec, DeterministicRng rng) =>
      switch (spec.hierarchy) {
        HierarchyMode.dualZone =>
          rng.chance(0.5) ? PlacementAnchor.topCenter : PlacementAnchor.bottomCenter,
        HierarchyMode.singleFocal ||
        HierarchyMode.radial ||
        HierarchyMode.typeLed =>
          PlacementAnchor.center,
        _ => rng.pickWeighted(
            const [PlacementAnchor.center, PlacementAnchor.topCenter],
            const [0.7, 0.3],
          ),
      };

  MerchCountrySource _sourceFor(DesignScope scope) => switch (scope) {
        DesignScope.year => MerchCountrySource.thisYear,
        DesignScope.trip => MerchCountrySource.recentTrip,
        DesignScope.singleCountry => MerchCountrySource.singleCountry,
        DesignScope.random ||
        DesignScope.lifetime ||
        DesignScope.region ||
        DesignScope.multiCountry =>
          MerchCountrySource.allTime,
      };

  // ── Selection (quality + diversity + controlled exploration) ────────────────

  List<GeneratedDesign> _selectDiverse(
    List<GeneratedDesign> pool,
    int count,
    double exploration,
    DeterministicRng rng,
  ) {
    if (pool.length <= count) {
      return List.of(pool)
        ..sort((a, b) => b.quality.total.compareTo(a.quality.total));
    }
    final remaining = List.of(pool)
      ..sort((a, b) => b.quality.total.compareTo(a.quality.total));
    final chosen = <GeneratedDesign>[];
    final familyCounts = <CompositionFamily, int>{};

    while (chosen.isNotEmpty ? chosen.length < count : true) {
      if (remaining.isEmpty || chosen.length >= count) break;
      // Diversity-adjusted scores: penalise families already chosen so the set
      // spans looks instead of collapsing onto one aesthetic.
      final adjusted = [
        for (final d in remaining)
          d.quality.total *
              math.pow(0.55, familyCounts[d.recipe.family] ?? 0).toDouble(),
      ];
      final int idx;
      if (rng.chance(exploration)) {
        idx = rng.pickWeightedIndex(adjusted); // explore, quality-weighted
      } else {
        var best = 0;
        for (var i = 1; i < adjusted.length; i++) {
          if (adjusted[i] > adjusted[best]) best = i;
        }
        idx = best; // exploit
      }
      final pick = remaining.removeAt(idx);
      chosen.add(pick);
      familyCounts[pick.recipe.family] =
          (familyCounts[pick.recipe.family] ?? 0) + 1;
    }
    return chosen;
  }
}
