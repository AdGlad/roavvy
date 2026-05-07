/// Categories used to group achievements in the Stats dashboard (M97).
enum AchievementCategory { countries, continents, trips, thisYear }

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
  /// - [AchievementCategory.continents]: distinct continent count
  /// - [AchievementCategory.trips]: total trip count
  /// - [AchievementCategory.thisYear]: countries first visited in the current year
  final int progressTarget;

  /// Optional merch product suggestion shown when this achievement is unlocked.
  /// Null means no merch CTA is shown for this achievement.
  final MerchTriggerType? merch;

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
