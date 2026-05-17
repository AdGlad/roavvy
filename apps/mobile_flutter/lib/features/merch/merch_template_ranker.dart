import 'package:shared_models/shared_models.dart';

/// Classification of how many countries/stamps are in scope for a merch context.
///
/// Used by [MerchTemplateRanker] and [MerchStory] to select appropriate
/// template rankings and story copy (ADR-154).
enum MerchDensityClass {
  /// 1 country / 1–2 stamps.
  solo,

  /// 2–5 countries / 3–8 stamps.
  small,

  /// 6–15 countries / 9–24 stamps.
  medium,

  /// 16–50 countries / 25–74 stamps.
  large,

  /// 51+ countries / 75+ stamps.
  massive,
}

/// A single template ranked for a given merch context.
///
/// [priority] is lower for higher priority (shown first). [exclude] means the
/// template should be omitted from the gallery entirely.
typedef MerchTemplateRank = ({
  CardTemplateType template,
  String label,
  int priority,
  bool exclude,
});

/// Ranks [CardTemplateType] values for a given travel context, producing a
/// curated rather than exhaustive list of merch gallery options (ADR-154).
///
/// All methods are pure — no side effects, no state.
class MerchTemplateRanker {
  const MerchTemplateRanker._();

  // ── Density classification ─────────────────────────────────────────────────

  /// Classifies a country count into a density tier.
  static MerchDensityClass densityFor(int codeCount) {
    if (codeCount <= 1) return MerchDensityClass.solo;
    if (codeCount <= 5) return MerchDensityClass.small;
    if (codeCount <= 15) return MerchDensityClass.medium;
    if (codeCount <= 50) return MerchDensityClass.large;
    return MerchDensityClass.massive;
  }

  /// Classifies a stamp count into a density tier.
  static MerchDensityClass densityForStamps(int stampCount) {
    if (stampCount <= 2) return MerchDensityClass.solo;
    if (stampCount <= 8) return MerchDensityClass.small;
    if (stampCount <= 24) return MerchDensityClass.medium;
    if (stampCount <= 74) return MerchDensityClass.large;
    return MerchDensityClass.massive;
  }

  /// Maximum number of non-excluded template groups to show for a density class.
  static int maxForDensity(MerchDensityClass density) => switch (density) {
        MerchDensityClass.solo => 4,
        MerchDensityClass.small => 5,
        MerchDensityClass.medium => 6,
        MerchDensityClass.large => 5,
        MerchDensityClass.massive => 4,
      };

  // ── Main ranking entry point ───────────────────────────────────────────────

  /// Returns all [CardTemplateType]s with ranking metadata for the given
  /// context. Items with [MerchTemplateRank.exclude] == true should be omitted.
  /// Callers should cap at [maxForDensity] non-excluded items.
  ///
  /// The list is sorted by [MerchTemplateRank.priority] (ascending).
  static List<MerchTemplateRank> rankFor({
    Achievement? achievement,
    required int codeCount,
    int tripCount = 0,
    int stampCount = 0,
  }) {
    final density = densityFor(codeCount);

    if (achievement != null) {
      if (achievement.continentScope != null) {
        return _continentExplorerRanks(codeCount);
      }
      if (achievement.regionScope != null) {
        return _regionRanks(codeCount);
      }
      if (achievement.category == AchievementCategory.trips &&
          achievement.merch == MerchTriggerType.passportStamp) {
        return _passportMilestoneRanks(density);
      }
      if (achievement.category == AchievementCategory.thisYear) {
        return _yearRanks(density);
      }
    }

    return _densityRanks(density);
  }

  // ── Density-based rankings ─────────────────────────────────────────────────

  static List<MerchTemplateRank> _densityRanks(MerchDensityClass density) =>
      switch (density) {
        MerchDensityClass.solo => [
            _rank(CardTemplateType.passport, 1),
            _rank(CardTemplateType.badge, 2),
            _rank(CardTemplateType.typography, 3),
            _rank(CardTemplateType.grid, 4),
            _rank(CardTemplateType.heart, 5),
            _rank(CardTemplateType.timeline, 6),
            _excluded(CardTemplateType.wordCloud),
            _excluded(CardTemplateType.frontRibbon),
          ],
        MerchDensityClass.small => [
            _rank(CardTemplateType.passport, 1),
            _rank(CardTemplateType.grid, 2),
            _rank(CardTemplateType.badge, 3),
            _rank(CardTemplateType.heart, 4),
            _rank(CardTemplateType.typography, 5),
            _rank(CardTemplateType.timeline, 6),
            _excluded(CardTemplateType.wordCloud),
            _excluded(CardTemplateType.frontRibbon),
          ],
        MerchDensityClass.medium => [
            _rank(CardTemplateType.grid, 1),
            _rank(CardTemplateType.passport, 2),
            _rank(CardTemplateType.heart, 3),
            _rank(CardTemplateType.wordCloud, 4),
            _rank(CardTemplateType.timeline, 5),
            _rank(CardTemplateType.typography, 6),
            _rank(CardTemplateType.badge, 7),
            _excluded(CardTemplateType.frontRibbon),
          ],
        MerchDensityClass.large => [
            _rank(CardTemplateType.grid, 1),
            _rank(CardTemplateType.heart, 2),
            _rank(CardTemplateType.wordCloud, 3),
            _rank(CardTemplateType.timeline, 4),
            _rank(CardTemplateType.typography, 5),
            _rank(CardTemplateType.passport, 6),
            _excluded(CardTemplateType.badge),
            _excluded(CardTemplateType.frontRibbon),
          ],
        MerchDensityClass.massive => [
            _rank(CardTemplateType.wordCloud, 1),
            _rank(CardTemplateType.grid, 2),
            _rank(CardTemplateType.heart, 3),
            _rank(CardTemplateType.typography, 4),
            _rank(CardTemplateType.timeline, 5),
            _excluded(CardTemplateType.badge),
            _excluded(CardTemplateType.passport),
            _excluded(CardTemplateType.frontRibbon),
          ],
      };

  // ── Achievement-type-specific rankings ─────────────────────────────────────

  static List<MerchTemplateRank> _continentExplorerRanks(int codeCount) {
    final badgeExcluded = codeCount > 15;
    return [
      badgeExcluded
          ? _excluded(CardTemplateType.badge)
          : _rank(CardTemplateType.badge, 1),
      _rank(CardTemplateType.grid, 2),
      _rank(CardTemplateType.wordCloud, 3),
      _rank(CardTemplateType.typography, 4),
      _rank(CardTemplateType.heart, 5),
      _rank(CardTemplateType.passport, 6),
      _rank(CardTemplateType.timeline, 7),
      _excluded(CardTemplateType.frontRibbon),
    ];
  }

  static List<MerchTemplateRank> _regionRanks(int codeCount) {
    final badgeExcluded = codeCount > 15;
    return [
      _rank(CardTemplateType.passport, 1),
      badgeExcluded
          ? _excluded(CardTemplateType.badge)
          : _rank(CardTemplateType.badge, 2),
      _rank(CardTemplateType.wordCloud, 3),
      _rank(CardTemplateType.typography, 4),
      _rank(CardTemplateType.grid, 5),
      _rank(CardTemplateType.heart, 6),
      _rank(CardTemplateType.timeline, 7),
      _excluded(CardTemplateType.frontRibbon),
    ];
  }

  static List<MerchTemplateRank> _passportMilestoneRanks(
      MerchDensityClass density) {
    return [
      _rank(CardTemplateType.passport, 1),
      _rank(CardTemplateType.timeline, 2),
      _rank(CardTemplateType.grid, 3),
      _rank(CardTemplateType.wordCloud, 4),
      _rank(CardTemplateType.heart, 5),
      _excluded(CardTemplateType.badge),
      _excluded(CardTemplateType.typography),
      _excluded(CardTemplateType.frontRibbon),
    ];
  }

  static List<MerchTemplateRank> _yearRanks(MerchDensityClass density) {
    return [
      _rank(CardTemplateType.timeline, 1),
      _rank(CardTemplateType.typography, 2),
      _rank(CardTemplateType.wordCloud, 3),
      _rank(CardTemplateType.grid, 4),
      _rank(CardTemplateType.heart, 5),
      _rank(CardTemplateType.passport, 6),
      _excluded(CardTemplateType.badge),
      _excluded(CardTemplateType.frontRibbon),
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static MerchTemplateRank _rank(CardTemplateType template, int priority) => (
        template: template,
        label: _labelFor(template),
        priority: priority,
        exclude: false,
      );

  static MerchTemplateRank _excluded(CardTemplateType template) => (
        template: template,
        label: _labelFor(template),
        priority: 99,
        exclude: true,
      );

  static String _labelFor(CardTemplateType template) => switch (template) {
        CardTemplateType.passport => 'Passport',
        CardTemplateType.grid => 'Flags',
        CardTemplateType.timeline => 'Tour Dates',
        CardTemplateType.heart => 'Heart Flags',
        CardTemplateType.frontRibbon => 'Ribbon',
        CardTemplateType.typography => 'Typography',
        CardTemplateType.badge => 'Explorer Badge',
        CardTemplateType.wordCloud => 'Word Cloud',
      };
}
