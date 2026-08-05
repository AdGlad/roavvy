import 'package:shared_models/shared_models.dart' show kCountryContinent;

import 'deterministic_rng.dart';

/// The travel filter a design is generated for. Stage 1 of the pipeline.
enum DesignScope {
  random,
  lifetime,
  year,
  region,
  singleCountry,
  multiCountry,
  trip,
}

/// Coarse size bucket of the visible country set — drives family eligibility
/// and hierarchy strategy. Thresholds mirror the merch density language.
enum DesignDensityClass { solo, small, medium, large, massive }

/// Immutable, deterministic description of *what a design is about*. Carries no
/// aesthetic decisions — only the resolved travel content and derived metadata.
///
/// Build with [DesignContext.of]; it computes continents/density from the
/// country set so generation and scoring never re-derive them inconsistently.
class DesignContext {
  DesignContext._({
    required this.scope,
    required this.countryCodes,
    required this.allCountryCodes,
    required this.continents,
    required this.dominantContinent,
    required this.signatureCountries,
    required this.density,
    required this.garmentIsDark,
    this.year,
    this.regionId,
    this.tripId,
    this.persona,
    this.scopeLabel,
  });

  /// Canonical constructor. [countryCodes] are lower-cased/de-duped/sorted so
  /// the context (and its [scopeKey]) is order-independent.
  factory DesignContext.of({
    required DesignScope scope,
    required Iterable<String> countryCodes,
    Iterable<String>? allCountryCodes,
    Iterable<String>? signatureCountries,
    bool garmentIsDark = true,
    int? year,
    String? regionId,
    String? tripId,
    String? persona,
    String? scopeLabel,
  }) {
    final codes = _canon(countryCodes);
    final all = allCountryCodes == null ? codes : _canon(allCountryCodes);
    final continents = <String>{
      for (final c in codes)
        if (kCountryContinent[c.toUpperCase()] != null)
          kCountryContinent[c.toUpperCase()]!,
    };
    // Dominant continent = most represented in the visible set (deterministic
    // tie-break by continent name).
    final counts = <String, int>{};
    for (final c in codes) {
      final cont = kCountryContinent[c.toUpperCase()];
      if (cont != null) counts[cont] = (counts[cont] ?? 0) + 1;
    }
    String? dominant;
    var best = -1;
    for (final e in (counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)))) {
      if (e.value > best) {
        best = e.value;
        dominant = e.key;
      }
    }
    return DesignContext._(
      scope: scope,
      countryCodes: codes,
      allCountryCodes: all,
      continents: continents,
      dominantContinent: dominant,
      signatureCountries: signatureCountries == null
          ? const []
          : _canon(signatureCountries).where(codes.contains).toList(),
      density: densityFor(codes.length),
      garmentIsDark: garmentIsDark,
      year: year,
      regionId: regionId,
      tripId: tripId,
      persona: persona,
      scopeLabel: scopeLabel,
    );
  }

  final DesignScope scope;

  /// Resolved ISO-2 (lowercase) country set this design draws.
  final List<String> countryCodes;

  /// Full lifetime set — context for relative rarity even when scope narrows.
  final List<String> allCountryCodes;

  final Set<String> continents;
  final String? dominantContinent;

  /// Rare/standout countries worth featuring (subset of [countryCodes]).
  final List<String> signatureCountries;

  final DesignDensityClass density;

  /// Whether the garment is dark (affects contrast/treatment eligibility).
  final bool garmentIsDark;

  final int? year;
  final String? regionId;
  final String? tripId;
  final String? persona;
  final String? scopeLabel;

  int get countryCount => countryCodes.length;

  /// Bucket a set size into a density class.
  static DesignDensityClass densityFor(int n) {
    if (n <= 1) return DesignDensityClass.solo;
    if (n <= 4) return DesignDensityClass.small;
    if (n <= 12) return DesignDensityClass.medium;
    if (n <= 30) return DesignDensityClass.large;
    return DesignDensityClass.massive;
  }

  /// Stable, human-readable identity of the scope (part of determinism: the
  /// engine seed is derived from this so the same context reproduces designs).
  String get scopeKey {
    final parts = <String>[
      scope.name,
      countryCodes.join('+'),
      if (year != null) 'y$year',
      if (regionId != null) 'r$regionId',
      if (tripId != null) 't$tripId',
      garmentIsDark ? 'dark' : 'light',
    ];
    return parts.join(':');
  }

  /// A deterministic base seed derived from the context, so callers can offset
  /// it to browse variants (`baseSeed + i`) reproducibly.
  int get baseSeed => DeterministicRng.hashString(scopeKey) & 0x7FFFFFFF;

  static List<String> _canon(Iterable<String> codes) {
    final set = <String>{
      for (final c in codes)
        if (c.trim().isNotEmpty) c.trim().toLowerCase(),
    };
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  @override
  String toString() => 'DesignContext($scopeKey, density=${density.name})';
}
