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
    this.template,
    this.silhouettesByShape = const {},
    this.continents = const [],
    this.countryNames = const {},
  });

  final LabStyle style;

  /// When set to a data-driven family (timeline / journeys / wordCloud), the
  /// generator emits that template from the context's travel history instead of
  /// the flag/clip showcase.
  final DesignFamily? template;

  /// Lowercase ISO-2 → display name (e.g. `sc` → `Seychelles`), used to offer
  /// the country's own name as a typography subject.
  final Map<String, String> countryNames;

  /// All silhouette slugs available per kind, e.g.
  /// `{ ClipShape.animalSilhouette: ['sc_coco_de_mer', 'af_snow_leopard', …] }`.
  final Map<ClipShape, List<String>> silhouettesByShape;

  /// Continent ids available for region clips (e.g. `['africa', 'europe']`).
  final List<String> continents;

  static const _words = ['ROAM', 'EXPLORE', 'WANDER', 'ADVENTURE', 'WILD', 'NOMAD'];

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// Format a real trip date as `DD MMM YY` for a stamp.
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} '
      '${(d.year % 100).toString().padLeft(2, '0')}';

  /// A plausible, deterministic trip (entry, exit) as `DD MMM YY` — used only
  /// when the context has no real travel history for the country.
  static (String, String) tripDates(DeterministicRng r) {
    final year = 20 + r.nextInt(6); // '20'..'25'
    final month = 1 + r.nextInt(12);
    final entryDay = 1 + r.nextInt(20);
    final exitDay = (entryDay + 3 + r.nextInt(12)).clamp(1, 28);
    String fmt(int d, int y) =>
        '${d.toString().padLeft(2, '0')} ${_months[month - 1]} ${y.toString().padLeft(2, '0')}';
    return (fmt(entryDay, year), fmt(exitDay, year));
  }

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

  static const _dataFamilies = {
    DesignFamily.timeline,
    DesignFamily.journeys,
    DesignFamily.wordCloud,
  };

  DesignRecipe _one(DesignContext context, int seed) {
    if (template != null && _dataFamilies.contains(template)) {
      return _dataRecipe(context, seed, template!);
    }
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
    // All selected countries that have a real passport stamp — the passport
    // PAGE works for one OR many countries (one image with every country's
    // entry/exit stamps, each filled with its own flag).
    final stampSlugs = silhouettesByShape[ClipShape.passportStampOutline] ?? const [];
    final stampCcs = [
      for (final c in codes.map((e) => e.toLowerCase()))
        if (stampSlugs.any((s) => s.split('_').first == c)) c,
    ];

    bool available(ClipArchetype a) {
      switch (a) {
        case ClipArchetype.animalSilhouette:
          return animals.isNotEmpty;
        case ClipArchetype.plantSilhouette:
          return plants.isNotEmpty;
        case ClipArchetype.landmarkSilhouette:
          return landmarks.isNotEmpty;
        case ClipArchetype.passportStampReal:
          return stamps.isNotEmpty; // single-country single stamp
        case ClipArchetype.passportPage:
          return stampCcs.isNotEmpty; // one or many countries
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
      stampCcs: stampCcs, history: context.history,
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

  /// Build a data-driven design (timeline / journeys / word cloud) from the
  /// context's travel history. Entries carry the country label + dates + visit
  /// weight so the recipe is self-contained and reproducible.
  DesignRecipe _dataRecipe(DesignContext context, int seed, DesignFamily family) {
    final rng = DeterministicRng(seed);
    final history = context.history;
    String nameOf(String cc) => countryNames[cc.toLowerCase()] ?? cc.toUpperCase();

    List<RecipeEntry> entries;
    if (family == DesignFamily.wordCloud) {
      final counts = history.visitCounts;
      final codes = counts.isNotEmpty
          ? counts.keys.toList()
          : context.flagCodes.map((e) => e.toLowerCase()).toList();
      entries = [
        for (final cc in codes)
          RecipeEntry(code: cc, label: nameOf(cc), weight: counts[cc] ?? 1),
      ];
    } else {
      // timeline / journeys → one entry per real trip (dated); else per flag.
      entries = history.isNotEmpty
          ? [
              for (final t in history.trips)
                RecipeEntry(
                    code: t.cc, label: nameOf(t.cc), start: t.startedOn, end: t.endedOn)
            ]
          : [
              for (final cc in context.flagCodes)
                RecipeEntry(code: cc.toLowerCase(), label: nameOf(cc))
            ];
    }
    if (entries.isEmpty) {
      entries = [RecipeEntry(code: 'us', label: nameOf('us'))];
    }

    final orientation = family == DesignFamily.wordCloud
        ? rng.stream('o').pick(const [Orientation.square, Orientation.landscape])
        : rng.stream('o').pick(const [Orientation.portrait, Orientation.square]);
    final pr = rng.stream('pal');
    final palette = pr.chance(0.4)
        ? Palette(
            strategy: ColourStrategy.flagDerived,
            vintageGrade: pr.nextRange(0.3, 0.6))
        : null;

    final distinct = <String>{for (final e in entries) e.code}.toList();
    return DesignRecipe(
      seed: seed,
      content: RecipeContent(
        flags: [for (final c in distinct) FlagRef(c)],
        entries: entries,
        source: context.scopeKey,
      ),
      composition: Composition(family: family, orientation: orientation),
      palette: palette,
      provenance: RecipeProvenance(generator: 'lab:template:${family.name}'),
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
    required List<String> stampCcs,
    required TravelHistory history,
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
        // A single real stamp with its trip date. Prefer the country's most
        // recent real trip; fall back to a synthesised date.
        final slug = r.pick(stamps);
        final cc = slug.split('_').first;
        final recent = history.mostRecentFor(cc);
        final String entry, exit;
        if (recent != null) {
          entry = formatDate(recent.startedOn);
          exit = formatDate(recent.endedOn);
        } else {
          (entry, exit) = tripDates(r);
        }
        return Clip(
            shapeId: 'passportStampOutline',
            code: '$slug|${slug.endsWith('_exit') ? exit : entry}');
      case ClipArchetype.passportPage:
        // Entry + exit stamps for ALL selected countries — one `cc|entry|exit`
        // segment per REAL trip (multiple trips → multiple stamp pairs), each
        // filled with its own flag. Falls back to a synthesised date per country.
        final segs = <String>[];
        for (final cc in stampCcs) {
          final tripsForCc = history.forCountry(cc);
          if (tripsForCc.isNotEmpty) {
            for (final t in tripsForCc) {
              segs.add('$cc|${formatDate(t.startedOn)}|${formatDate(t.endedOn)}');
            }
          } else {
            final (entry, exit) = tripDates(r);
            segs.add('$cc|$entry|$exit');
          }
        }
        return Clip(
            shapeId: 'passportPage',
            code: segs.join(';'),
            scatter: r.nextRange(0.35, 0.7),
            scale: r.nextRange(0.85, 1.1));
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
