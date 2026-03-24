/// Reason an XP award was made.
enum XpReason { newCountry, regionCompleted, scanCompleted, share }

/// An individual XP award event.
class XpEvent {
  const XpEvent({
    required this.id,
    required this.reason,
    required this.amount,
    required this.awardedAt,
  });

  /// UUID v4 identifier.
  final String id;

  final XpReason reason;

  /// XP points awarded.
  final int amount;

  /// UTC timestamp of the award.
  final DateTime awardedAt;
}

/// The user's current XP state, derived by [XpNotifier].
class XpState {
  const XpState({
    required this.totalXp,
    required this.level,
    required this.levelLabel,
    required this.progressFraction,
    required this.xpToNextLevel,
  });

  final int totalXp;

  /// 1-indexed level (1–8).
  final int level;

  /// Human-readable level name.
  final String levelLabel;

  /// Progress within the current level as a fraction [0.0, 1.0].
  final double progressFraction;

  /// XP needed to reach the next level; 0 at max level.
  final int xpToNextLevel;

  static const zero = XpState(
    totalXp: 0,
    level: 1,
    levelLabel: 'Traveller',
    progressFraction: 0.0,
    xpToNextLevel: 100,
  );
}

// ── Level thresholds ──────────────────────────────────────────────────────────

/// XP required to reach each level (index = level - 1).
const kXpThresholds = [0, 100, 250, 500, 1000, 2000, 4000, 8000];

/// Label for each level (index = level - 1).
///
/// Names align with the identity-driven commerce tier system (ADR-091):
/// Traveller → Explorer → Navigator → Globetrotter → Pathfinder → (Voyager →
/// Pioneer) → Legend. Voyager and Pioneer bridge Pathfinder and Legend within
/// the 8-level XP progression.
const kLevelLabels = [
  'Traveller',
  'Explorer',
  'Navigator',
  'Globetrotter',
  'Pathfinder',
  'Voyager',
  'Pioneer',
  'Legend',
];

/// Computes [XpState] from a total XP value.
XpState xpStateFromTotal(int totalXp) {
  int level = 1;
  for (int i = kXpThresholds.length - 1; i >= 0; i--) {
    if (totalXp >= kXpThresholds[i]) {
      level = i + 1;
      break;
    }
  }

  final isMaxLevel = level == kXpThresholds.length;
  final levelStart = kXpThresholds[level - 1];
  final levelEnd = isMaxLevel ? null : kXpThresholds[level];

  final progressFraction = isMaxLevel
      ? 1.0
      : (totalXp - levelStart) / (levelEnd! - levelStart);

  final xpToNextLevel = isMaxLevel ? 0 : levelEnd! - totalXp;

  return XpState(
    totalXp: totalXp,
    level: level,
    levelLabel: kLevelLabels[level - 1],
    progressFraction: progressFraction.clamp(0.0, 1.0),
    xpToNextLevel: xpToNextLevel < 0 ? 0 : xpToNextLevel,
  );
}
