import 'dart:math' as math;

import 'package:design_forge/design_forge.dart';

import 'lab_styles.dart';

/// A development recipe generator that renders a batch in a chosen [LabStyle]
/// (Beachwear, Grunge, Streetwear …) — or the broad [LabStyle.showcase]. Each
/// tile is built in two coherent halves:
///   1. a **subject** ([ClipArchetype]) drawn from the style's front-loaded
///      rotation → a [Clip] (or the plain flag), and
///   2. a **finish** (edge/effects/palette) from the style, layered on top.
///
/// Consecutive seeds walk the rotation so the grid's first tiles deterministically
/// cover the style's signature looks; a given seed always reproduces the same
/// tile. Silhouette + country/continent clips are country-specific, so the Lab
/// passes in the per-country silhouette slugs and available continents; those
/// subjects are simply skipped when unavailable (e.g. a multi-country batch).
/// Implements [RecipeGenerator] so it slots into the mobile contract.
class LabShowcaseGenerator implements RecipeGenerator {
  const LabShowcaseGenerator({
    this.style = LabStyle.showcase,
    this.silhouettesByShape = const {},
    this.continents = const [],
    this.countryNames = const {},
  });

  final LabStyle style;

  /// Lowercase ISO-2 → display name (e.g. `sc` → `Seychelles`), used to offer
  /// the country's own name as a typography subject.
  final Map<String, String> countryNames;

  /// All silhouette slugs available per kind, e.g.
  /// `{ ClipShape.animalSilhouette: ['sc_coco_de_mer', 'af_snow_leopard', …] }`.
  final Map<ClipShape, List<String>> silhouettesByShape;

  /// Continent ids available for region clips (e.g. `['africa', 'europe']`).
  final List<String> continents;

  static const _words = ['ROAM', 'EXPLORE', 'WANDER', 'ADVENTURE', 'WILD', 'NOMAD'];

  @override
  List<DesignRecipe> generate(
    DesignContext context,
    {required int seed, int count = 1}) {
    // Consecutive seeds so the rotation walks the whole grid, and so a single
    // seed reproduces the same tile deterministically.
    return [
      for (var i = 0; i < count; i++) _one(context, seed + i),
    ];
  }

  /// Silhouette slugs of [kind] belonging to [code] (slugs are country-prefixed,
  /// e.g. `sc_coco_de_mer` → country `sc`).
  List<String> _countrySlugs(ClipShape kind, String code) {
    final c = code.toLowerCase();
    return [
      for (final s in (silhouettesByShape[kind] ?? const []))
        if (s.split('_').first == c) s,
    ];
  }

  DesignRecipe _one(DesignContext context, int seed) {
    final rng = DeterministicRng(seed);
    final spec = style.spec;
    final codes = context.flagCodes;
    final flags = [for (final c in codes) FlagRef(c)];
    final single = codes.length == 1;
    final code = codes.isEmpty ? 'us' : codes.first.toLowerCase();

    // Composition follows the flag count; the style only varies the look.
    FlagCombination? combo;
    FillAlgorithm? fillAlgorithm;
    DesignFamily family;
    if (flags.length == 1) {
      family = DesignFamily.singleHero;
    } else if (flags.length == 2) {
      family = DesignFamily.duoBlend;
      combo = FlagCombination(
        mode: rng.stream('combo').pick(const [
          FlagCombineMode.diagonalSplit,
          FlagCombineMode.vertical,
          FlagCombineMode.horizontal,
        ]),
      );
    } else {
      family = DesignFamily.grid;
      fillAlgorithm = rng.stream('algo').pick(FillAlgorithm.values);
    }

    final animals =
        single ? _countrySlugs(ClipShape.animalSilhouette, code) : const <String>[];
    final plants =
        single ? _countrySlugs(ClipShape.plantSilhouette, code) : const <String>[];
    final landmarks =
        single ? _countrySlugs(ClipShape.landmarkSilhouette, code) : const <String>[];
    final stamps = single
        ? _countrySlugs(ClipShape.passportStampOutline, code)
        : const <String>[];

    bool available(ClipArchetype a) {
      switch (a) {
        case ClipArchetype.animalSilhouette:
          return animals.isNotEmpty;
        case ClipArchetype.plantSilhouette:
          return plants.isNotEmpty;
        case ClipArchetype.landmarkSilhouette:
          return landmarks.isNotEmpty;
        case ClipArchetype.passportStampReal:
        case ClipArchetype.passportPage:
          return stamps.isNotEmpty;
        case ClipArchetype.countryOutline:
          return single;
        case ClipArchetype.continentOutline:
          return continents.isNotEmpty;
        default:
          return true;
      }
    }

    // Walk the style's rotation across the grid. Offset by the default base seed
    // (1) so the grid's first tile lands on rotation[0]; a given seed still maps
    // to a fixed archetype, so reproduce/variations stay deterministic.
    final avail = [for (final a in spec.rotation) if (available(a)) a];
    final arc = avail[(seed - 1).abs() % avail.length];

    final clip = _clipFor(
      arc, rng.stream('clip'), spec, code,
      animals: animals, plants: plants, landmarks: landmarks, stamps: stamps,
    );

    // Finish: edge/effects/palette from the style. Don't tear a clipped shape
    // unless the style opts in (grunge grit on silhouettes etc.).
    final finish = spec.finish(rng.stream('finish'), clip != null);
    final edge = (clip != null && !spec.tornOnClip) ? null : finish.edge;

    final orientation = rng.stream('orient').pickWeighted(
      const [Orientation.square, Orientation.portrait, Orientation.landscape],
      spec.orientationWeights,
    );

    return DesignRecipe(
      seed: seed,
      content: RecipeContent(flags: flags, source: context.scopeKey),
      composition: Composition(
          family: family, orientation: orientation, fillAlgorithm: fillAlgorithm),
      flagCombination: combo,
      clip: clip,
      edgeTreatment: edge,
      effects: finish.fx,
      palette: finish.palette,
      provenance: RecipeProvenance(generator: 'lab:${style.name}'),
    );
  }

  /// Turn a subject archetype into a [Clip] (or null for the plain flag).
  Clip? _clipFor(
    ClipArchetype arc,
    DeterministicRng r,
    StyleSpec spec,
    String code, {
    required List<String> animals,
    required List<String> plants,
    required List<String> landmarks,
    required List<String> stamps,
  }) {
    final (lo, hi) = spec.clipScale;
    Clip proc(String id) => Clip(
          shapeId: id,
          scale: r.nextRange(lo, hi),
          rotationDeg: r.chance(0.3) ? r.nextRange(-10, 10) : 0.0,
        );

    switch (arc) {
      case ClipArchetype.basicFlag:
        return null;
      case ClipArchetype.animalSilhouette:
        return Clip(shapeId: 'animalSilhouette', code: r.pick(animals));
      case ClipArchetype.plantSilhouette:
        return Clip(shapeId: 'plantSilhouette', code: r.pick(plants));
      case ClipArchetype.landmarkSilhouette:
        return Clip(shapeId: 'landmarkSilhouette', code: r.pick(landmarks));
      case ClipArchetype.passportStampReal:
        return Clip(shapeId: 'passportStampOutline', code: r.pick(stamps));
      case ClipArchetype.passportPage:
        // Both entry + exit stamps for this country, overlaid at angles.
        return Clip(shapeId: 'passportPage', code: code);
      case ClipArchetype.countryOutline:
        return Clip(shapeId: 'countryOutline', code: code);
      case ClipArchetype.continentOutline:
        return Clip(shapeId: 'continentOutline', code: r.pick(continents));
      case ClipArchetype.badge:
        return proc(r.pick(const ['circle', 'passportStamp', 'shield', 'postageStamp']));
      case ClipArchetype.text:
        // Offer the country's own name (e.g. SEYCHELLES) alongside the slogans.
        final name = countryNames[code];
        final words = <String>[
          ..._words,
          code.toUpperCase(),
          if (name != null) name.toUpperCase(),
        ];
        return Clip(
            shapeId: 'text', text: r.pick(words), scale: r.nextRange(0.9, 1.1));
      // Procedural shapes map straight to their catalog id.
      case ClipArchetype.circle:
      case ClipArchetype.oval:
      case ClipArchetype.arch:
      case ClipArchetype.roundedRect:
      case ClipArchetype.diamond:
      case ClipArchetype.triangle:
      case ClipArchetype.hexagon:
      case ClipArchetype.shield:
      case ClipArchetype.heart:
      case ClipArchetype.star:
      case ClipArchetype.lightning:
      case ClipArchetype.mountain:
      case ClipArchetype.island:
      case ClipArchetype.sunset:
      case ClipArchetype.wave:
      case ClipArchetype.mapPin:
      case ClipArchetype.ticket:
      case ClipArchetype.luggageTag:
      case ClipArchetype.postageStamp:
      case ClipArchetype.passportStamp:
      case ClipArchetype.entryStamp:
      case ClipArchetype.compass:
        return proc(arc.name);
    }
  }
}

/// Smart batch generator that produces a preference-weighted, diversity-
/// constrained set of 6–8 designs.
///
/// Pipeline:
///  1. [StratifiedSampler] allocates a pool budget across style clusters.
///  2. For each cluster, delegates to [LabShowcaseGenerator] per lab style.
///  3. [PreferenceScorer] scores every recipe against [DesignPreferences].
///  4. [DiversitySelector] picks the final set.
class LabSmartGenerator implements RecipeGenerator {
  const LabSmartGenerator({
    required this.preferences,
    this.silhouettesByShape = const {},
    this.continents = const [],
    this.countryNames = const {},
    this.poolSize = 150,
    this.outputCount = 8,
  });

  final DesignPreferences preferences;
  final Map<ClipShape, List<String>> silhouettesByShape;
  final List<String> continents;
  final Map<String, String> countryNames;

  /// How many candidate recipes to generate across all clusters.
  final int poolSize;

  /// How many recipes to return after diversity selection.
  final int outputCount;

  @override
  List<DesignRecipe> generate(
    DesignContext context, {
    required int seed,
    int count = 1,
  }) {
    final rng = DeterministicRng(seed);

    // 1. Allocate pool budget across clusters.
    final sampler = const StratifiedSampler();
    final allocation = sampler.allocate(
      preferences,
      poolSize: poolSize,
      rng: rng.stream('alloc'),
    );

    // 2. Generate recipes per cluster via existing LabShowcaseGenerator.
    final pool = <DesignRecipe>[];
    var seedOffset = 0;
    for (final entry in allocation.entries) {
      final cluster = entry.key;
      final quota = entry.value;
      final labStyleNames = kClusterToLabStyles[cluster] ?? [];

      for (final styleName in labStyleNames) {
        final labStyle = LabStyle.values
            .where((s) => s.name == styleName)
            .firstOrNull;
        if (labStyle == null) continue;

        final gen = LabShowcaseGenerator(
          style: labStyle,
          silhouettesByShape: silhouettesByShape,
          continents: continents,
          countryNames: countryNames,
        );

        // Split the cluster's quota across its lab styles.
        final perStyle = math.max(1, quota ~/ labStyleNames.length);
        final recipes = gen.generate(
          context,
          seed: seed + seedOffset,
          count: perStyle,
        );
        pool.addAll(recipes);
        seedOffset += perStyle;
      }
    }

    // 3. Score all recipes.
    const scorer = PreferenceScorer();
    final scored = pool
        .map((r) => (r, scorer.score(r, preferences)))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    // 4. Diversity-select final set.
    const selector = DiversitySelector();
    return selector.select(scored, count: outputCount);
  }
}
