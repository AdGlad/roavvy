import 'continent_map.dart';
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
  ///
  /// The returned [Set] contains only the IDs defined in [kAchievements].
  static Set<String> evaluate(
    List<EffectiveVisitedCountry> visits, {
    int tripCount = 0,
    int thisYearCountryCount = 0,
  }) {
    final countryCount = visits.length;

    final continentCount = visits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;

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

    return unlocked;
  }
}
