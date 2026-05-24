/// Categories used to group achievements in the Stats dashboard (M97).
enum AchievementCategory { countries, continents, trips, thisYear, heritageSites }

/// Merch product suggestion type attached to an unlocked achievement (M97).
enum MerchTriggerType { flagGrid, passportStamp, timeline, country, milestone }

/// A travel achievement that can be unlocked by the user.
///
/// Achievements are defined at compile time in [kAchievements] and evaluated
/// by [AchievementEngine.evaluate]. They are never stored here — only the
/// unlocked IDs are persisted (ADR-034).
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.progressTarget,
    this.merch,
    this.continentScope,
    this.regionScope,
  });

  /// Stable identifier used for persistence and Firestore sync.
  /// Never change an ID once shipped — doing so orphans existing unlock records.
  final String id;

  /// Short display name shown in the UI (e.g. "Globetrotter").
  final String title;

  /// One-sentence explanation of how to unlock this achievement.
  final String description;

  /// Groups the achievement for the tabbed gallery (ADR-148).
  final AchievementCategory category;

  /// The threshold value at which this achievement unlocks.
  ///
  /// Interpretation depends on [category]:
  /// - [AchievementCategory.countries]: distinct country count
  /// - [AchievementCategory.continents]: distinct continent count or, when
  ///   [continentScope] is set, countries within that continent
  /// - [AchievementCategory.trips]: total trip count (or stamp count when
  ///   [merch] is [MerchTriggerType.passportStamp], where stamps ≈ trips × 2)
  /// - [AchievementCategory.thisYear]: countries first visited in the current year
  final int progressTarget;

  /// Optional merch product suggestion shown when this achievement is unlocked.
  /// Null means no merch CTA is shown for this achievement.
  final MerchTriggerType? merch;

  /// When non-null, this achievement is scoped to a specific continent.
  ///
  /// Values match the continent strings in [kCountryContinent]:
  /// 'Africa', 'Asia', 'Europe', 'North America', 'South America', 'Oceania'.
  ///
  /// [MerchContext] filters visited countries to only those in this continent
  /// when generating merchandise options (ADR-152).
  final String? continentScope;

  /// When non-null, this achievement is scoped to a sub-continental region.
  ///
  /// Values match the region keys in [kCountrySubRegion]:
  /// 'Mediterranean', 'SoutheastAsia'.
  ///
  /// [MerchContext] filters visited countries to only those in this region
  /// when generating merchandise options (ADR-152).
  final String? regionScope;

  @override
  bool operator ==(Object other) =>
      other is Achievement &&
      other.id == id &&
      other.title == title &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, title, description);

  @override
  String toString() => 'Achievement($id)';
}

/// The full catalogue of achievements the app can award (ADR-034, ADR-148).
///
/// IDs must remain stable across releases — changing an ID orphans existing
/// unlock records in Drift and Firestore.
const List<Achievement> kAchievements = [
  // ── Country count ────────────────────────────────────────────────────────
  Achievement(
    id: 'countries_1',
    title: 'First Stamp',
    description: 'Visited your first country.',
    category: AchievementCategory.countries,
    progressTarget: 1,
    merch: MerchTriggerType.country,
  ),
  Achievement(
    id: 'countries_3',
    title: 'Triple Stamp',
    description: 'Visited 3 countries.',
    category: AchievementCategory.countries,
    progressTarget: 3,
  ),
  Achievement(
    id: 'countries_5',
    title: 'Frequent Flyer',
    description: 'Visited 5 countries.',
    category: AchievementCategory.countries,
    progressTarget: 5,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_10',
    title: 'Seasoned Traveller',
    description: 'Visited 10 countries.',
    category: AchievementCategory.countries,
    progressTarget: 10,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_15',
    title: 'Well Travelled',
    description: 'Visited 15 countries.',
    category: AchievementCategory.countries,
    progressTarget: 15,
  ),
  Achievement(
    id: 'countries_20',
    title: 'Passport Regular',
    description: 'Visited 20 countries.',
    category: AchievementCategory.countries,
    progressTarget: 20,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_25',
    title: 'Globetrotter',
    description: 'Visited 25 countries.',
    category: AchievementCategory.countries,
    progressTarget: 25,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_30',
    title: 'Borderless',
    description: 'Visited 30 countries.',
    category: AchievementCategory.countries,
    progressTarget: 30,
  ),
  Achievement(
    id: 'countries_40',
    title: 'Horizon Chaser',
    description: 'Visited 40 countries.',
    category: AchievementCategory.countries,
    progressTarget: 40,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_50',
    title: 'World Explorer',
    description: 'Visited 50 countries.',
    category: AchievementCategory.countries,
    progressTarget: 50,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_75',
    title: 'Pathfinder',
    description: 'Visited 75 countries.',
    category: AchievementCategory.countries,
    progressTarget: 75,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_100',
    title: 'Century Club',
    description: 'Visited 100 countries.',
    category: AchievementCategory.countries,
    progressTarget: 100,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_125',
    title: 'Grand Tourist',
    description: 'Visited 125 countries.',
    category: AchievementCategory.countries,
    progressTarget: 125,
  ),
  Achievement(
    id: 'countries_150',
    title: 'Marathon Traveller',
    description: 'Visited 150 countries.',
    category: AchievementCategory.countries,
    progressTarget: 150,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'countries_195',
    title: 'World Complete',
    description: 'Visited all 195 countries.',
    category: AchievementCategory.countries,
    progressTarget: 195,
    merch: MerchTriggerType.flagGrid,
  ),

  // ── Continent count ──────────────────────────────────────────────────────
  Achievement(
    id: 'continents_2',
    title: 'Two Worlds',
    description: 'Visited countries on 2 continents.',
    category: AchievementCategory.continents,
    progressTarget: 2,
  ),
  Achievement(
    id: 'continents_3',
    title: 'Continental Drift',
    description: 'Visited countries on 3 or more continents.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    merch: MerchTriggerType.milestone,
  ),
  Achievement(
    id: 'continents_4',
    title: 'Four Corners',
    description: 'Visited countries on 4 continents.',
    category: AchievementCategory.continents,
    progressTarget: 4,
  ),
  Achievement(
    id: 'continents_5',
    title: 'Five Continent Traveller',
    description: 'Visited countries on 5 continents.',
    category: AchievementCategory.continents,
    progressTarget: 5,
    merch: MerchTriggerType.milestone,
  ),
  Achievement(
    id: 'continents_all',
    title: 'All Six',
    description: 'Visited countries on all 6 inhabited continents.',
    category: AchievementCategory.continents,
    progressTarget: 6,
    merch: MerchTriggerType.milestone,
  ),

  // ── Trip count ───────────────────────────────────────────────────────────
  Achievement(
    id: 'trips_1',
    title: 'First Trip',
    description: 'Logged your first trip.',
    category: AchievementCategory.trips,
    progressTarget: 1,
  ),
  Achievement(
    id: 'trips_3',
    title: 'Regular Traveller',
    description: 'Logged 3 trips.',
    category: AchievementCategory.trips,
    progressTarget: 3,
  ),
  Achievement(
    id: 'trips_5',
    title: 'Jet Setter',
    description: 'Logged 5 trips.',
    category: AchievementCategory.trips,
    progressTarget: 5,
    merch: MerchTriggerType.timeline,
  ),
  Achievement(
    id: 'trips_10',
    title: 'Miles Ahead',
    description: 'Logged 10 trips.',
    category: AchievementCategory.trips,
    progressTarget: 10,
    merch: MerchTriggerType.timeline,
  ),
  Achievement(
    id: 'trips_25',
    title: 'Frequent Departure',
    description: 'Logged 25 trips.',
    category: AchievementCategory.trips,
    progressTarget: 25,
    merch: MerchTriggerType.timeline,
  ),
  Achievement(
    id: 'trips_50',
    title: 'Always Moving',
    description: 'Logged 50 trips.',
    category: AchievementCategory.trips,
    progressTarget: 50,
    merch: MerchTriggerType.timeline,
  ),

  // ── Continent explorers ──────────────────────────────────────────────────
  // Scoped to countries within a specific continent (ADR-152).
  // progressTarget = number of countries in that continent, not continent count.
  Achievement(
    id: 'continent_europe_3',
    title: 'Europe Initiate',
    description: 'Visited 3 countries in Europe.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'Europe',
  ),
  Achievement(
    id: 'continent_europe_5',
    title: 'Europe Explorer',
    description: 'Visited 5 countries in Europe.',
    category: AchievementCategory.continents,
    progressTarget: 5,
    continentScope: 'Europe',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_europe_10',
    title: 'European Adventurer',
    description: 'Visited 10 countries in Europe.',
    category: AchievementCategory.continents,
    progressTarget: 10,
    continentScope: 'Europe',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_asia_3',
    title: 'Asia Initiate',
    description: 'Visited 3 countries in Asia.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'Asia',
  ),
  Achievement(
    id: 'continent_asia_5',
    title: 'Asia Explorer',
    description: 'Visited 5 countries in Asia.',
    category: AchievementCategory.continents,
    progressTarget: 5,
    continentScope: 'Asia',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_africa_3',
    title: 'Africa Explorer',
    description: 'Visited 3 countries in Africa.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'Africa',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_north_america_3',
    title: 'North America Explorer',
    description: 'Visited 3 countries in North America.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'North America',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_south_america_3',
    title: 'South America Explorer',
    description: 'Visited 3 countries in South America.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'South America',
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'continent_oceania_3',
    title: 'Oceania Explorer',
    description: 'Visited 3 countries in Oceania.',
    category: AchievementCategory.continents,
    progressTarget: 3,
    continentScope: 'Oceania',
    merch: MerchTriggerType.flagGrid,
  ),

  // ── Region explorers ─────────────────────────────────────────────────────
  // Scoped to sub-continental regions via [kCountrySubRegion] (ADR-152).
  Achievement(
    id: 'region_mediterranean',
    title: 'Mediterranean Explorer',
    description: 'Visited 5 Mediterranean countries.',
    category: AchievementCategory.continents,
    progressTarget: 5,
    regionScope: 'Mediterranean',
    merch: MerchTriggerType.passportStamp,
  ),
  Achievement(
    id: 'region_southeast_asia',
    title: 'Southeast Asia Explorer',
    description: 'Visited 5 countries in Southeast Asia.',
    category: AchievementCategory.continents,
    progressTarget: 5,
    regionScope: 'SoutheastAsia',
    merch: MerchTriggerType.flagGrid,
  ),

  // ── Passport stamp milestones ────────────────────────────────────────────
  // Approximates stamp count as tripCount × 2 (entry + exit per trip).
  Achievement(
    id: 'passport_10',
    title: '10 Stamps',
    description: 'Collected 10 passport stamps across your trips.',
    category: AchievementCategory.trips,
    progressTarget: 5,
    merch: MerchTriggerType.passportStamp,
  ),
  Achievement(
    id: 'passport_25',
    title: '25 Stamps',
    description: 'Collected 25 passport stamps across your trips.',
    category: AchievementCategory.trips,
    progressTarget: 13,
    merch: MerchTriggerType.passportStamp,
  ),
  Achievement(
    id: 'passport_50',
    title: 'Stamp Collector',
    description: 'Collected 50 passport stamps across your trips.',
    category: AchievementCategory.trips,
    progressTarget: 25,
    merch: MerchTriggerType.passportStamp,
  ),

  // ── World Heritage Sites (M119, ADR-163–166) ─────────────────────────────
  // Count-based — keyed on total visited WHS count.
  Achievement(
    id: 'whs_1',
    title: 'First Heritage Site',
    description: 'Visited your first UNESCO World Heritage Site.',
    category: AchievementCategory.heritageSites,
    progressTarget: 1,
  ),
  Achievement(
    id: 'whs_5',
    title: 'Heritage Explorer',
    description: 'Visited 5 UNESCO World Heritage Sites.',
    category: AchievementCategory.heritageSites,
    progressTarget: 5,
  ),
  Achievement(
    id: 'whs_10',
    title: 'Heritage Hunter',
    description: 'Visited 10 UNESCO World Heritage Sites.',
    category: AchievementCategory.heritageSites,
    progressTarget: 10,
  ),
  Achievement(
    id: 'whs_25',
    title: 'Heritage Enthusiast',
    description: 'Visited 25 UNESCO World Heritage Sites.',
    category: AchievementCategory.heritageSites,
    progressTarget: 25,
  ),
  Achievement(
    id: 'whs_50',
    title: 'Heritage Scholar',
    description: 'Visited 50 UNESCO World Heritage Sites.',
    category: AchievementCategory.heritageSites,
    progressTarget: 50,
  ),
  Achievement(
    id: 'whs_100',
    title: 'World Heritage Legend',
    description: 'Visited 100 UNESCO World Heritage Sites.',
    category: AchievementCategory.heritageSites,
    progressTarget: 100,
  ),

  // Category-based — one per UNESCO category.
  Achievement(
    id: 'whs_natural_1',
    title: 'Natural Wonder',
    description: 'Visited a UNESCO Natural World Heritage Site.',
    category: AchievementCategory.heritageSites,
    progressTarget: 1,
  ),
  Achievement(
    id: 'whs_cultural_1',
    title: 'Cultural Explorer',
    description: 'Visited a UNESCO Cultural World Heritage Site.',
    category: AchievementCategory.heritageSites,
    progressTarget: 1,
  ),
  Achievement(
    id: 'whs_mixed_1',
    title: 'Mixed Heritage',
    description: 'Visited a UNESCO Mixed World Heritage Site.',
    category: AchievementCategory.heritageSites,
    progressTarget: 1,
  ),

  // ── This year ────────────────────────────────────────────────────────────
  Achievement(
    id: 'year_countries_3',
    title: 'Year Tripper',
    description: 'Visited 3 countries in a single calendar year.',
    category: AchievementCategory.thisYear,
    progressTarget: 3,
  ),
  Achievement(
    id: 'year_countries_5',
    title: 'Year Explorer',
    description: 'Visited 5 countries in a single calendar year.',
    category: AchievementCategory.thisYear,
    progressTarget: 5,
    merch: MerchTriggerType.flagGrid,
  ),
  Achievement(
    id: 'year_countries_10',
    title: 'Big Year',
    description: 'Visited 10 countries in a single calendar year.',
    category: AchievementCategory.thisYear,
    progressTarget: 10,
    merch: MerchTriggerType.flagGrid,
  ),
];
