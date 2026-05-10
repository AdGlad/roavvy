import 'package:shared_models/shared_models.dart';

/// Curated travel-inspired title phrases and structured subtitle builder for
/// merch artwork (M107, ADR-157).
///
/// Titles are emotional/whimsical and must NEVER include a country count.
/// Subtitles always follow the format: "Roavvy: N Countries • [context]".
abstract final class MerchTitleWordbank {
  // ── Title banks ─────────────────────────────────────────────────────────────

  static const _solo = [
    'Where It Began',
    'Point of Departure',
    'First Footprint',
    'The First Stamp',
    'New Horizons',
    'Beginning of the Road',
    'A Journey Starts Here',
    'Passport: Day One',
  ];

  static const _small = [
    'Opening Chapter',
    'Early Roads',
    'Setting Out',
    'Wanderlust Rising',
    'Roads Less Travelled',
    'The First Pages',
    'Off the Map',
    'Somewhere New',
  ];

  static const _medium = [
    'Wandering Far',
    'Roads Taken',
    'Somewhere Out There',
    'The Long Way Round',
    'Passport Pages',
    'Miles Apart',
    'Over the Horizon',
    'Distant Places',
    'The Ongoing Journey',
  ];

  static const _large = [
    'World Traveller',
    'Far and Away',
    'Boundless',
    'Endless Horizon',
    'The Grand Tour',
    'Across the World',
    'No Borders',
    'Life in Transit',
  ];

  static const _massive = [
    'Global Citizen',
    'The Whole World',
    'Stateless Heart',
    'Globe Trotter',
    'Seven Continents',
    'Limitless',
    'Citizen of Everywhere',
    'The Atlas',
  ];

  static const _continentPhrases = <String, List<String>>{
    'Europe': [
      'European Drift',
      'Old World Soul',
      'Continental Summer',
      'Through Europe',
      'Across the Channel',
      'European Calling',
    ],
    'Asia': [
      'Eastern Promise',
      'Far East Calling',
      'Asian Horizon',
      'Spice Routes',
      'Dragon Roads',
      'Orient Bound',
    ],
    'Africa': [
      'African Sunrise',
      'Savanna Soul',
      'Wild Continent',
      'African Trails',
      'Beyond the Desert',
      'Safari Dreams',
    ],
    'North America': [
      'New World Roads',
      'American Dream',
      'From Sea to Sea',
      'Continental Crossing',
      'North Bound',
    ],
    'South America': [
      'Latin Drift',
      'South of the Equator',
      'Andean Roads',
      'Jungle Calling',
      'South American Summer',
    ],
    'Oceania': [
      'Pacific Bound',
      'Down Under Dreams',
      'Island Hopping',
      'Southern Cross',
      'Oceanic Escape',
    ],
  };

  static const _regionPhrases = <String, List<String>>{
    'Mediterranean': [
      'Mediterranean Drift',
      'Aegean Summer',
      'Sea and Stamps',
      'Sun-Drenched Routes',
      'Blue Water Dreams',
    ],
    'SoutheastAsia': [
      'Southeast Bound',
      'Tiger Roads',
      'Tropical Calling',
      'Eastern Escape',
      'Monsoon Routes',
    ],
  };

  static const _yearPhrases = [
    'Wanderings',
    'Chronicles',
    'Roads',
    'Adventures',
    'Travels',
    'Journeys',
    'Horizons',
    'Memories',
  ];

  static const _tripPhrases = [
    'Road Warrior',
    'The Journey Continues',
    'Many Roads',
    'Miles Covered',
    'Trip After Trip',
    'Always Moving',
    'Life on the Road',
    'Perpetual Nomad',
  ];

  // ── Pickers ──────────────────────────────────────────────────────────────────

  /// Picks an emotional, count-free title for a generic/country-count context.
  ///
  /// [seed] is incremented each time the user presses Regenerate, ensuring
  /// the phrase cycles through the bank without consecutive repeats.
  static String pickGeneric(int n, int seed) {
    final bank = n <= 1
        ? _solo
        : n <= 5
            ? _small
            : n <= 15
                ? _medium
                : n <= 30
                    ? _large
                    : _massive;
    return bank[seed.abs() % bank.length];
  }

  /// Picks a continent-specific title phrase.
  static String pickForContinent(String continent, int seed) {
    final bank = _continentPhrases[continent] ?? _large;
    return bank[seed.abs() % bank.length];
  }

  /// Picks a region-specific title phrase.
  static String pickForRegion(String regionKey, int seed) {
    final bank = _regionPhrases[regionKey] ?? _medium;
    return bank[seed.abs() % bank.length];
  }

  /// Picks a year-based title phrase. Year number is acceptable (not a count).
  static String pickForYear(int year, int seed) {
    final phrase = _yearPhrases[seed.abs() % _yearPhrases.length];
    return '$year $phrase';
  }

  /// Picks a trip-count title phrase.
  static String pickForTrips(int seed) =>
      _tripPhrases[seed.abs() % _tripPhrases.length];

  // ── Subtitle builder ─────────────────────────────────────────────────────────

  /// Builds the structured "Roavvy: N Countries • [context]" subtitle line.
  ///
  /// This is the artwork branding line that appears at the bottom of every
  /// merch card. It always starts with "Roavvy:" and always includes the
  /// country count.
  static String buildSubtitleLine(
    int countryCount, {
    String? continent,
    String? region,
    int? year,
    int? yearEnd,
    String? tripLabel,
  }) {
    final count =
        '$countryCount ${countryCount == 1 ? "Country" : "Countries"}';
    final parts = <String>['Roavvy: $count'];

    if (continent != null) parts.add(continent);
    if (region != null) parts.add(subRegionDisplayName(region));
    if (year != null) {
      if (yearEnd != null && yearEnd != year) {
        parts.add('$year\u2013$yearEnd');
      } else {
        parts.add('$year');
      }
    }
    if (tripLabel != null) parts.add(tripLabel);

    return parts.join(' \u2022 ');
  }
}
