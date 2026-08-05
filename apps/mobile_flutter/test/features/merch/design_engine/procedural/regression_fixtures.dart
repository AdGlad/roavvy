import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';

/// A stable pool of ISO-2 codes for building fixture contexts.
const kFixtureCodes = [
  'fr', 'jp', 'us', 'ke', 'br', 'it', 'es', 'de', 'gr', 'pt', 'th', 'vn',
  'au', 'nz', 'mx', 'ca', 'gb', 'ie', 'nl', 'be', 'ch', 'at', 'se', 'no',
  'fi', 'dk', 'pl', 'cz', 'hu', 'hr', 'in', 'cn', 'kr', 'sg', 'my', 'id',
];

/// The representative contexts the regression suite and dev batches share.
/// Deliberately spans set size, scope AND garment so no single design category
/// can be improved at the silent expense of another.
Map<String, DesignContext> representativeContexts() => {
      'one-country-dark': DesignContext.of(
        scope: DesignScope.singleCountry,
        countryCodes: const ['jp'],
        garmentIsDark: true,
      ),
      'one-country-light': DesignContext.of(
        scope: DesignScope.singleCountry,
        countryCodes: const ['jp'],
        garmentIsDark: false,
      ),
      'two-countries': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp'],
        garmentIsDark: true,
      ),
      'several-countries': DesignContext.of(
        scope: DesignScope.multiCountry,
        countryCodes: const ['fr', 'jp', 'us', 'ke', 'br'],
        signatureCountries: const ['ke'],
        garmentIsDark: true,
      ),
      'year': DesignContext.of(
        scope: DesignScope.year,
        countryCodes: const ['it', 'es', 'fr', 'de'],
        year: 2024,
        garmentIsDark: false,
      ),
      'region-europe': DesignContext.of(
        scope: DesignScope.region,
        countryCodes: const ['fr', 'de', 'it', 'es', 'gr', 'pt'],
        regionId: 'europe',
        garmentIsDark: true,
      ),
      'lifetime': DesignContext.of(
        scope: DesignScope.lifetime,
        countryCodes: List.generate(28, (i) => kFixtureCodes[i]),
        garmentIsDark: true,
      ),
      'massive-light': DesignContext.of(
        scope: DesignScope.lifetime,
        countryCodes: List.generate(60, (i) => kFixtureCodes[i % kFixtureCodes.length]),
        garmentIsDark: false,
      ),
    };

/// Fixed seeds used everywhere so results are reproducible + comparable.
const kRegressionSeeds = [1, 2, 3];

double _round3(double v) => (v * 1000).round() / 1000;

/// Aggregate metrics for one context over [kRegressionSeeds]. Pure + stable.
Map<String, dynamic> metricsForContext(
  ProceduralDesignGenerator gen,
  DesignContext ctx, {
  int count = 8,
}) {
  final qualities = <double>[];
  final tops = <double>[];
  final rejects = <double>[];
  final familyCounts = <String, int>{};
  for (final seed in kRegressionSeeds) {
    final r = gen.generate(ctx, seed: seed, count: count);
    for (final d in r.designs) {
      qualities.add(d.quality.total);
      familyCounts[d.recipe.family.name] =
          (familyCounts[d.recipe.family.name] ?? 0) + 1;
    }
    tops.add(r.stats.topQuality);
    rejects.add(r.stats.produced == 0
        ? 0
        : r.stats.rejected / r.stats.produced);
  }
  double mean(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  return {
    'meanQuality': _round3(mean(qualities)),
    'topQuality': _round3(mean(tops)),
    'rejectionRate': _round3(mean(rejects)),
    'familyDiversity': familyCounts.length,
    'familyCounts': Map.fromEntries(
        familyCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
  };
}

/// Full metrics table across every representative context.
Map<String, dynamic> computeRegressionMetrics(
    [ProceduralDesignGenerator gen = const ProceduralDesignGenerator()]) {
  final contexts = representativeContexts();
  final perContext = <String, dynamic>{
    for (final e in contexts.entries) e.key: metricsForContext(gen, e.value),
  };
  final means = perContext.values
      .map((m) => (m as Map)['meanQuality'] as double)
      .toList();
  return {
    'engineVersion': kProceduralEngineVersion,
    'grammarVersion': kProceduralGrammarVersion,
    'seeds': kRegressionSeeds,
    'perContext': perContext,
    'aggregate': {
      'meanQuality':
          _round3(means.reduce((a, b) => a + b) / means.length),
    },
  };
}
