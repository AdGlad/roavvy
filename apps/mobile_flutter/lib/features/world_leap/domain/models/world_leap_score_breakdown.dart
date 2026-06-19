// lib/features/world_leap/domain/models/world_leap_score_breakdown.dart

import '../../world_leap_config.dart';

/// Itemised score breakdown for a single launch.
class WorldLeapScoreBreakdown {
  /// Always [WorldLeapConfig.baseCountryScore] on a successful landing.
  final int baseCountry;

  /// +1 per 100 km travelled.
  final int distanceBonus;

  /// 0, [WorldLeapConfig.longShotBonus1], or [WorldLeapConfig.longShotBonus2].
  final int longShotBonus;

  /// 0, 50, 100, or 250 depending on proximity to a UNESCO WHS.
  final int heritageBonus;

  /// Name of the nearest UNESCO site that triggered the bonus (if any).
  final String? heritageSiteName;

  /// [WorldLeapConfig.continentBonus] when first landing on a new continent
  /// this run; 0 otherwise.
  final int continentBonus;

  /// Bonus for hitting the target with time to spare: timeRemaining × 15 pts.
  final int speedBonus;

  const WorldLeapScoreBreakdown({
    required this.baseCountry,
    required this.distanceBonus,
    required this.longShotBonus,
    required this.heritageBonus,
    this.heritageSiteName,
    this.continentBonus = 0,
    this.speedBonus = 0,
  });

  int get total =>
      baseCountry + distanceBonus + longShotBonus + heritageBonus + continentBonus + speedBonus;

  bool get hasHeritageBonus => heritageBonus > 0;
  bool get hasLongShotBonus => longShotBonus > 0;
  bool get hasContinentBonus => continentBonus > 0;
  bool get hasSpeedBonus => speedBonus > 0;

  factory WorldLeapScoreBreakdown.zero() => const WorldLeapScoreBreakdown(
        baseCountry: 0,
        distanceBonus: 0,
        longShotBonus: 0,
        heritageBonus: 0,
        continentBonus: 0,
        speedBonus: 0,
      );

  Map<String, dynamic> toJson() => {
        'baseCountry': baseCountry,
        'distanceBonus': distanceBonus,
        'longShotBonus': longShotBonus,
        'heritageBonus': heritageBonus,
        'heritageSiteName': heritageSiteName,
        'continentBonus': continentBonus,
        'speedBonus': speedBonus,
        'total': total,
      };

  factory WorldLeapScoreBreakdown.fromJson(Map<String, dynamic> json) =>
      WorldLeapScoreBreakdown(
        baseCountry: (json['baseCountry'] as num?)?.toInt() ?? 0,
        distanceBonus: (json['distanceBonus'] as num?)?.toInt() ?? 0,
        longShotBonus: (json['longShotBonus'] as num?)?.toInt() ?? 0,
        heritageBonus: (json['heritageBonus'] as num?)?.toInt() ?? 0,
        heritageSiteName: json['heritageSiteName'] as String?,
        continentBonus: (json['continentBonus'] as num?)?.toInt() ?? 0,
        speedBonus: (json['speedBonus'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() =>
      'ScoreBreakdown(base=$baseCountry, dist=$distanceBonus, '
      'longShot=$longShotBonus, heritage=$heritageBonus, '
      'continent=$continentBonus, total=$total)';
}
