import 'continent_map.dart';
import 'continent_subregion_map.dart';
import 'effective_visited_country.dart';

/// Evaluates which achievements are unlocked for a given set of visits.
///
/// All logic is pure and offline — no I/O, no network calls (ADR-034).
/// The caller is responsible for persisting the returned IDs.
///
/// Country codes absent from [kCountryContinent] are silently ignored when
/// computing continent counts; they still contribute to the country count.
class AchievementEngine {
  const AchievementEngine._();

  /// Returns the set of achievement IDs unlocked by [visits].
  ///
  /// [visits] is the current effective visit list — one entry per country.
  /// [tripCount] is the total number of logged trips (default 0 for callers
  /// that do not yet supply this value — backward-compatible, ADR-148).
  /// [thisYearCountryCount] is the number of distinct countries first seen in
  /// the current calendar year (default 0 — backward-compatible).
  /// [heritageCount] is the total number of visited UNESCO World Heritage Sites
  /// (default 0 — backward-compatible, ADR-166).
  /// [heritageByCategory] is a breakdown of visited WHS by category string
  /// (`"cultural"`, `"natural"`, `"mixed"`). Default empty — backward-compatible.
  ///
  /// The returned [Set] contains only the IDs defined in [kAchievements].
  static Set<String> evaluate(
    List<EffectiveVisitedCountry> visits, {
    int tripCount = 0,
    int thisYearCountryCount = 0,
    int heritageCount = 0,
    Map<String, int> heritageByCategory = const {},
  }) {
    final countryCount = visits.length;

    final continentCount = visits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;

    // Per-continent country counts for continent-explorer achievements (ADR-152).
    int _continentCount(String continent) => visits
        .where((v) => kCountryContinent[v.countryCode] == continent)
        .length;
    final europeCount = _continentCount('Europe');
    final asiaCount = _continentCount('Asia');
    final africaCount = _continentCount('Africa');
    final northAmericaCount = _continentCount('North America');
    final southAmericaCount = _continentCount('South America');
    final oceaniaCount = _continentCount('Oceania');

    // Per-region country counts for region achievements (ADR-152).
    int _regionCount(String region) => visits
        .where((v) => kCountrySubRegion[v.countryCode] == region)
        .length;
    final mediterraneanCount = _regionCount('Mediterranean');
    final southeastAsiaCount = _regionCount('SoutheastAsia');

    // Passport stamp approximation: each trip generates ~2 stamps (entry + exit).
    final stampCount = tripCount * 2;

    final unlocked = <String>{};

    // ── Country count ──────────────────────────────────────────────────────
    if (countryCount >= 1) unlocked.add('countries_1');
    if (countryCount >= 3) unlocked.add('countries_3');
    if (countryCount >= 5) unlocked.add('countries_5');
    if (countryCount >= 10) unlocked.add('countries_10');
    if (countryCount >= 15) unlocked.add('countries_15');
    if (countryCount >= 20) unlocked.add('countries_20');
    if (countryCount >= 25) unlocked.add('countries_25');
    if (countryCount >= 30) unlocked.add('countries_30');
    if (countryCount >= 40) unlocked.add('countries_40');
    if (countryCount >= 50) unlocked.add('countries_50');
    if (countryCount >= 75) unlocked.add('countries_75');
    if (countryCount >= 100) unlocked.add('countries_100');
    if (countryCount >= 125) unlocked.add('countries_125');
    if (countryCount >= 150) unlocked.add('countries_150');
    if (countryCount >= 195) unlocked.add('countries_195');

    // ── Continent count ────────────────────────────────────────────────────
    if (continentCount >= 2) unlocked.add('continents_2');
    if (continentCount >= 3) unlocked.add('continents_3');
    if (continentCount >= 4) unlocked.add('continents_4');
    if (continentCount >= 5) unlocked.add('continents_5');
    if (continentCount >= 6) unlocked.add('continents_all');

    // ── Trip count ─────────────────────────────────────────────────────────
    if (tripCount >= 1) unlocked.add('trips_1');
    if (tripCount >= 3) unlocked.add('trips_3');
    if (tripCount >= 5) unlocked.add('trips_5');
    if (tripCount >= 10) unlocked.add('trips_10');
    if (tripCount >= 25) unlocked.add('trips_25');
    if (tripCount >= 50) unlocked.add('trips_50');

    // ── This-year country count ────────────────────────────────────────────
    if (thisYearCountryCount >= 3) unlocked.add('year_countries_3');
    if (thisYearCountryCount >= 5) unlocked.add('year_countries_5');
    if (thisYearCountryCount >= 10) unlocked.add('year_countries_10');

    // ── Continent explorers (ADR-152) ──────────────────────────────────────
    if (europeCount >= 3) unlocked.add('continent_europe_3');
    if (europeCount >= 5) unlocked.add('continent_europe_5');
    if (europeCount >= 10) unlocked.add('continent_europe_10');
    if (asiaCount >= 3) unlocked.add('continent_asia_3');
    if (asiaCount >= 5) unlocked.add('continent_asia_5');
    if (africaCount >= 3) unlocked.add('continent_africa_3');
    if (northAmericaCount >= 3) unlocked.add('continent_north_america_3');
    if (southAmericaCount >= 3) unlocked.add('continent_south_america_3');
    if (oceaniaCount >= 3) unlocked.add('continent_oceania_3');

    // ── Region explorers (ADR-152) ─────────────────────────────────────────
    if (mediterraneanCount >= 5) unlocked.add('region_mediterranean');
    if (southeastAsiaCount >= 5) unlocked.add('region_southeast_asia');

    // ── Passport stamp milestones (ADR-152) ────────────────────────────────
    // Stamp count approximated as tripCount × 2 (entry + exit per trip).
    if (stampCount >= 10) unlocked.add('passport_10');
    if (stampCount >= 25) unlocked.add('passport_25');
    if (stampCount >= 50) unlocked.add('passport_50');

    // ── World Heritage Sites (M119, ADR-166) ───────────────────────────────
    if (heritageCount >= 1) unlocked.add('whs_1');
    if (heritageCount >= 5) unlocked.add('whs_5');
    if (heritageCount >= 10) unlocked.add('whs_10');
    if (heritageCount >= 25) unlocked.add('whs_25');
    if (heritageCount >= 50) unlocked.add('whs_50');
    if (heritageCount >= 100) unlocked.add('whs_100');
    if ((heritageByCategory['natural'] ?? 0) >= 1) unlocked.add('whs_natural_1');
    if ((heritageByCategory['cultural'] ?? 0) >= 1) unlocked.add('whs_cultural_1');
    if ((heritageByCategory['mixed'] ?? 0) >= 1) unlocked.add('whs_mixed_1');

    return unlocked;
  }
}
