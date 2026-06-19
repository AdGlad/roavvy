// lib/features/world_leap/domain/services/world_leap_scoring_service.dart

import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';
import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_score_breakdown.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_heritage_bonus_service.dart';

/// Computes [WorldLeapScoreBreakdown] for a single successful launch.
class WorldLeapScoringService {
  final WorldLeapHeritageBonusService _heritage;

  WorldLeapScoringService(this._heritage);

  /// Computes all score components for a landing at [landingLat]/[landingLon]
  /// after travelling [distanceKm].
  ///
  /// Pass [isNewContinent] = true when this landing is the first time the
  /// player has reached this continent in the current run.
  /// Points per second remaining when the player hits the target.
  static const int pointsPerSecond = 15;

  WorldLeapScoreBreakdown computeScore({
    required double distanceKm,
    required double landingLat,
    required double landingLon,
    bool isNewContinent = false,
    int timeRemaining = 0,
    int comboStreak = 0,
  }) {
    final base = WorldLeapConfig.baseCountryScore;

    final distBonus =
        (distanceKm / 100).floor() * WorldLeapConfig.pointsPer100Km;

    final int longShotBonus;
    if (distanceKm >= WorldLeapConfig.longShotThreshold2Km) {
      longShotBonus = WorldLeapConfig.longShotBonus2;
    } else if (distanceKm >= WorldLeapConfig.longShotThreshold1Km) {
      longShotBonus = WorldLeapConfig.longShotBonus1;
    } else {
      longShotBonus = 0;
    }

    final heritage = _heritage.bonusAt(landingLat, landingLon);

    final continentBonus =
        isNewContinent ? WorldLeapConfig.continentBonus : 0;

    final speedBonus = timeRemaining > 0 ? timeRemaining * pointsPerSecond : 0;

    final double comboMultiplier;
    if (comboStreak >= 8) {
      comboMultiplier = 3.0;
    } else if (comboStreak >= 5) {
      comboMultiplier = 2.0;
    } else if (comboStreak >= 3) {
      comboMultiplier = 1.5;
    } else {
      comboMultiplier = 1.0;
    }

    return WorldLeapScoreBreakdown(
      baseCountry: base,
      distanceBonus: distBonus,
      longShotBonus: longShotBonus,
      heritageBonus: heritage.bonus,
      heritageSiteName: heritage.siteName,
      continentBonus: continentBonus,
      speedBonus: speedBonus,
      comboStreak: comboStreak,
      comboMultiplier: comboMultiplier,
    );
  }
}
