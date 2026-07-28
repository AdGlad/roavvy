import 'dart:math' as math;

import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart';
import '../merch_preset.dart';
import '../merch_template_ranker.dart';
import '../merch_variant_lookup.dart';
import '../product_mockup_specs.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'travel_profile.dart';

/// A [CandidateGenerator] that seeds an evolutionary population from strong
/// priors (M199 / architecture §5):
///
/// 1. **`MerchTemplateRanker`** template priors per country-set — high-rank
///    (low-priority, non-excluded) templates get seeded first.
/// 2. **`kMerchPresets`** as known-good anchors, mapped onto the profile's sets.
/// 3. **Persona** biases palette / orientation / density / clip / layout mode.
/// 4. **Diversity injection** — at least one seed per `candidateSet` and per top
///    template so the population spans distinct *ideas*, not near-duplicates.
///
/// Every returned genome is `.normalize()`d and `.isValid`. Output is
/// deterministic for a given injected [math.Random] (repeated `seed` calls
/// advance the stream, which is exactly what the loop's diversity injection
/// wants — fresh variants each generation, reproducible as a whole).
class RankerSeededGenerator implements CandidateGenerator {
  RankerSeededGenerator({math.Random? rng}) : _rng = rng ?? math.Random(0);

  final math.Random _rng;

  /// Templates the genome may explore (badge is excluded from the design
  /// genome per architecture §4).
  static const List<CardTemplateType> _templatePool = [
    CardTemplateType.grid,
    CardTemplateType.passport,
    CardTemplateType.timeline,
    CardTemplateType.wordCloud,
    CardTemplateType.landmark,
    CardTemplateType.typography,
    CardTemplateType.heart,
    CardTemplateType.frontRibbon,
  ];

  /// How many top-ranked templates to seed per country-set before padding.
  static const int _templatesPerSet = 3;

  @override
  List<DesignParams> seed(TravelProfile profile, {int count = 60}) {
    final sets =
        profile.candidateSets.where((s) => s.codes.isNotEmpty).toList();
    if (sets.isEmpty) return const <DesignParams>[];

    // contentHash -> params, preserving first-insertion (diversity) order.
    final out = <String, DesignParams>{};

    void add(DesignParams p) {
      final n = p.normalize();
      if (n.isValid) out.putIfAbsent(n.contentHash, () => n);
    }

    // (1) + (4): guaranteed diversity — one persona-biased seed per
    // (set × top-ranked template).
    for (final set in sets) {
      final ranks = MerchTemplateRanker.rankFor(codeCount: set.codes.length)
          .where((r) => !r.exclude)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      if (ranks.isEmpty) {
        add(_seedFor(profile, set, CardTemplateType.grid));
        continue;
      }
      for (final r in ranks.take(_templatesPerSet)) {
        add(_seedFor(profile, set, r.template));
      }
    }

    // (2): built-in presets as known-good anchors mapped onto matching sets.
    for (final preset in kMerchPresets) {
      final set = _setForSource(sets, preset.config.source) ?? sets.first;
      add(_seedFromPreset(profile, set, preset.config));
    }

    // (3): expansion — pad with random valid variants up to [count] to give the
    // loop a broad initial population. Never trims below the diversity floor.
    var guard = 0;
    final maxGuard = math.max(count, out.length) * 8;
    while (out.length < count && guard < maxGuard) {
      guard++;
      final set = sets[_rng.nextInt(sets.length)];
      add(_randomVariant(profile, set));
    }

    return out.values.toList();
  }

  // ── Seeding ────────────────────────────────────────────────────────────────

  /// A persona-biased base genome for [set] rendered with [template].
  DesignParams _seedFor(
    TravelProfile profile,
    CountrySetOption set,
    CardTemplateType template,
  ) {
    final persona = profile.persona;
    final isGrid = template == CardTemplateType.grid;
    final single = set.codes.length == 1;
    final continentScoped = set.scopeKey != null && set.codes.length > 1;

    var gridMode = FlagGridLayoutMode.packedRow;
    var clip = GridClipShape.none;
    String? clipCode;
    var density = MerchDensity.balanced;
    var portrait = false;

    switch (persona) {
      case TravelPersona.soloDeepDive:
        density = MerchDensity.sparse;
        portrait = true;
        if (isGrid && single) {
          clip = GridClipShape.countryOutline;
          clipCode = set.codes.first;
        }
      case TravelPersona.homebodyPlusOne:
        density = MerchDensity.sparse;
        if (isGrid && single) {
          clip = GridClipShape.countryOutline;
          clipCode = set.codes.first;
        }
      case TravelPersona.globeTrotter:
        density = MerchDensity.dense;
        if (isGrid) gridMode = FlagGridLayoutMode.montage;
      case TravelPersona.continentHopper:
        density = MerchDensity.dense;
        if (isGrid && continentScoped) {
          clip = GridClipShape.continentOutline;
          clipCode = set.scopeKey;
        } else if (isGrid) {
          gridMode = FlagGridLayoutMode.montage;
        }
      case TravelPersona.regionExplorer:
        if (isGrid && continentScoped) {
          clip = GridClipShape.continentOutline;
          clipCode = set.scopeKey;
        }
      case TravelPersona.recentAdventurer:
        if (isGrid) gridMode = FlagGridLayoutMode.treemap;
    }

    return DesignParams(
      template: template,
      source: set.source,
      countryCodes: set.codes,
      gridLayoutMode: gridMode,
      clipShape: clip,
      clipCode: clipCode,
      rowCount: _rowsFor(set.codes.length),
      density: density,
      jitter: 0.2,
      stampMode: MerchStampMode.entryExit,
      isPortrait: portrait,
      imageSize: ImageSize.medium,
      shirtColour: _colourFor(persona),
      seed: _rng.nextInt(1 << 20),
    );
  }

  /// A genome built from a known-good [config] applied to [set].
  DesignParams _seedFromPreset(
    TravelProfile profile,
    CountrySetOption set,
    MerchPresetConfig config,
  ) {
    return DesignParams(
      template: config.layout,
      source: set.source,
      countryCodes: set.codes,
      rowCount: _rowsFor(set.codes.length),
      density: config.density,
      jitter: config.jitter,
      stampMode: config.stampMode,
      imageSize: ImageSize.medium,
      shirtColour: _colourFor(profile.persona),
      seed: _rng.nextInt(1 << 20),
    );
  }

  /// A randomly perturbed variant off a persona seed — used to pad the
  /// population. Always normalized/validated by the caller's `add`.
  DesignParams _randomVariant(TravelProfile profile, CountrySetOption set) {
    final base = _seedFor(
      profile,
      set,
      _templatePool[_rng.nextInt(_templatePool.length)],
    );
    return base.copyWith(
      gridLayoutMode: _pick(FlagGridLayoutMode.values),
      density: _pick(MerchDensity.values),
      rowCount: 1 + _rng.nextInt(10),
      jitter: _rng.nextDouble(),
      imageSize: _pick(ImageSize.values),
      isPortrait: _rng.nextBool(),
      shirtColour: tshirtColors[_rng.nextInt(tshirtColors.length)],
      seed: _rng.nextInt(1 << 20),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Persona-weighted shirt colour (all values drawn from [tshirtColors]).
  String _colourFor(TravelPersona persona) {
    final prefs = switch (persona) {
      TravelPersona.soloDeepDive => const ['Black', 'Blue'],
      TravelPersona.globeTrotter => const ['Black', 'Grey'],
      TravelPersona.continentHopper => const ['Blue', 'Black'],
      TravelPersona.regionExplorer => const ['Grey', 'Blue'],
      TravelPersona.recentAdventurer => const ['Blue', 'Red'],
      TravelPersona.homebodyPlusOne => const ['White', 'Grey'],
    };
    return prefs[_rng.nextInt(prefs.length)];
  }

  int _rowsFor(int codeCount) => math.sqrt(codeCount).round().clamp(1, 10);

  CountrySetOption? _setForSource(
    List<CountrySetOption> sets,
    MerchCountrySource source,
  ) {
    for (final s in sets) {
      if (s.source == source) return s;
    }
    return null;
  }

  T _pick<T>(List<T> values) => values[_rng.nextInt(values.length)];
}
