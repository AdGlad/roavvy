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

  /// Number of consecutive successful hits at the time of this shot (including this one).
  final int comboStreak;

  /// Score multiplier applied to the base subtotal (1.0, 1.5, 2.0, or 3.0).
  final double comboMultiplier;

  const WorldLeapScoreBreakdown({
    required this.baseCountry,
    required this.distanceBonus,
    required this.longShotBonus,
    required this.heritageBonus,
    this.heritageSiteName,
    this.continentBonus = 0,
    this.speedBonus = 0,
    this.comboStreak = 0,
    this.comboMultiplier = 1.0,
  });

  /// Pre-multiplier subtotal.
  int get _baseSubtotal =>
      baseCountry + distanceBonus + longShotBonus + heritageBonus + continentBonus + speedBonus;

  /// Extra points from the combo multiplier (0 when multiplier is 1.0).
  int get comboBonus =>
      comboMultiplier > 1.0 ? ((_baseSubtotal * comboMultiplier) - _baseSubtotal).round() : 0;

  int get total => _baseSubtotal + comboBonus;

  /// Star rating (1–3) based on time remaining when the target was hit.
  /// Derived from speedBonus (= timeRemaining × 15).
  int get stars {
    if (speedBonus > 150) return 3; // > 10 s
    if (speedBonus >= 75) return 2; // 5–10 s
    if (speedBonus > 0) return 1;   // < 5 s but hit
    return 1;                        // no time bonus — still 1 star for hitting
  }

  bool get hasHeritageBonus => heritageBonus > 0;
  bool get hasLongShotBonus => longShotBonus > 0;
  bool get hasContinentBonus => continentBonus > 0;
  bool get hasSpeedBonus => speedBonus > 0;
  bool get hasComboBonus => comboBonus > 0;

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
        'comboStreak': comboStreak,
        'comboMultiplier': comboMultiplier,
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
        comboStreak: (json['comboStreak'] as num?)?.toInt() ?? 0,
        comboMultiplier: (json['comboMultiplier'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  String toString() =>
      'ScoreBreakdown(base=$baseCountry, dist=$distanceBonus, '
      'longShot=$longShotBonus, heritage=$heritageBonus, '
      'continent=$continentBonus, combo=$comboStreak×$comboMultiplier, total=$total)';
}
