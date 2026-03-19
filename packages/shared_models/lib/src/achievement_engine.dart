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
  /// The returned [Set] contains only the IDs defined in [kAchievements].
  static Set<String> evaluate(List<EffectiveVisitedCountry> visits) {
    final countryCount = visits.length;

    final continentCount = visits
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;

    final unlocked = <String>{};

    if (countryCount >= 1) unlocked.add('countries_1');
    if (countryCount >= 5) unlocked.add('countries_5');
    if (countryCount >= 10) unlocked.add('countries_10');
    if (countryCount >= 25) unlocked.add('countries_25');
    if (countryCount >= 50) unlocked.add('countries_50');
    if (countryCount >= 100) unlocked.add('countries_100');
    if (continentCount >= 3) unlocked.add('continents_3');
    if (continentCount >= 6) unlocked.add('continents_all');

    return unlocked;
  }
}
