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
  });

  /// Stable identifier used for persistence and Firestore sync.
  /// Never change an ID once shipped — doing so orphans existing unlock records.
  final String id;

  /// Short display name shown in the UI (e.g. "Globetrotter").
  final String title;

  /// One-sentence explanation of how to unlock this achievement.
  final String description;

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

/// The full catalogue of achievements the app can award (ADR-034).
///
/// IDs must remain stable across releases — changing an ID orphans existing
/// unlock records in Drift and Firestore.
const List<Achievement> kAchievements = [
  Achievement(
    id: 'countries_1',
    title: 'First Stamp',
    description: 'Visited your first country.',
  ),
  Achievement(
    id: 'countries_5',
    title: 'Frequent Flyer',
    description: 'Visited 5 countries.',
  ),
  Achievement(
    id: 'countries_10',
    title: 'Seasoned Traveller',
    description: 'Visited 10 countries.',
  ),
  Achievement(
    id: 'countries_25',
    title: 'Globetrotter',
    description: 'Visited 25 countries.',
  ),
  Achievement(
    id: 'countries_50',
    title: 'World Explorer',
    description: 'Visited 50 countries.',
  ),
  Achievement(
    id: 'countries_100',
    title: 'Century Club',
    description: 'Visited 100 countries.',
  ),
  Achievement(
    id: 'continents_3',
    title: 'Continental Drift',
    description: 'Visited countries on 3 or more continents.',
  ),
  Achievement(
    id: 'continents_all',
    title: 'All Six',
    description: 'Visited countries on all 6 inhabited continents.',
  ),
];
