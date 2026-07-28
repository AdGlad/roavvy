import '../merch_preset.dart';
import '../merch_template_ranker.dart';

/// A coarse "who is this traveller?" classification that biases template,
/// palette, copy tone, and country-set selection — the designer's first
/// question (M197 / architecture §3).
enum TravelPersona {
  /// One country, explored in depth.
  soloDeepDive,

  /// A handful of countries, mostly recent.
  recentAdventurer,

  /// Many countries across several continents.
  continentHopper,

  /// Concentrated in one dominant continent/region.
  regionExplorer,

  /// Large, broad history spanning most of the world.
  globeTrotter,

  /// A small, occasional traveller (2–3 countries, spread out).
  homebodyPlusOne,
}

/// A concrete, labelled set of country codes a design can be built from.
/// The same history yields several legitimate designs (this-year / all-time /
/// a single country / a continent), so each becomes a generation seed.
class CountrySetOption {
  const CountrySetOption({
    required this.source,
    required this.label,
    required this.codes,
    this.scopeKey,
  });

  final MerchCountrySource source;
  final String label;
  final List<String> codes;

  /// Continent key / ISO code for outline-clipped designs, when applicable.
  final String? scopeKey;
}

/// Structured understanding of a user's travel history, derived purely from
/// their trips. Cheap + cacheable (recomputed only when trips change).
class TravelProfile {
  const TravelProfile({
    required this.allCodes,
    required this.density,
    required this.continents,
    required this.dominantContinent,
    required this.candidateSets,
    required this.earliest,
    required this.latest,
    required this.isRecencyHeavy,
    required this.signatureCountries,
    required this.persona,
  });

  final List<String> allCodes;
  int get countryCount => allCodes.length;
  final MerchDensityClass density;
  final Set<String> continents;
  final String? dominantContinent;

  /// Distinct design starting points (all-time, this-year, recent, single,
  /// continent). Always contains at least one.
  final List<CountrySetOption> candidateSets;

  final DateTime? earliest;
  final DateTime? latest;

  /// True when a large share of travel happened in the last ~12 months.
  final bool isRecencyHeavy;

  /// Countries with the most photos (hero affinity), most-first.
  final List<String> signatureCountries;

  final TravelPersona persona;

  bool get isEmpty => allCodes.isEmpty;
}
