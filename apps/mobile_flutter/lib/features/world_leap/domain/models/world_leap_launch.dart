// lib/features/world_leap/domain/models/world_leap_launch.dart

import 'world_leap_score_breakdown.dart';

/// The result of a single Roavvy launch within a run.
class WorldLeapLaunch {
  /// 1-based index within the run.
  final int launchNumber;

  final String fromCountryCode;
  final String fromCountryName;
  final String toCountryCode;
  final String toCountryName;

  /// Compass bearing in degrees (0–360).
  final double bearing;

  /// Normalised launch power (0.0–1.0).
  final double power;

  /// Great-circle distance in kilometres.
  final double distanceKm;

  final double landingLat;
  final double landingLon;

  final WorldLeapScoreBreakdown scoreBreakdown;

  final DateTime timestamp;

  /// True when this landing was the first time this continent was visited
  /// in the run (triggering a continent bonus).
  final bool newContinent;

  const WorldLeapLaunch({
    required this.launchNumber,
    required this.fromCountryCode,
    required this.fromCountryName,
    required this.toCountryCode,
    required this.toCountryName,
    required this.bearing,
    required this.power,
    required this.distanceKm,
    required this.landingLat,
    required this.landingLon,
    required this.scoreBreakdown,
    required this.timestamp,
    this.newContinent = false,
  });

  int get score => scoreBreakdown.total;

  Map<String, dynamic> toJson() => {
        'launchNumber': launchNumber,
        'fromCountryCode': fromCountryCode,
        'fromCountryName': fromCountryName,
        'toCountryCode': toCountryCode,
        'toCountryName': toCountryName,
        'bearing': bearing,
        'power': power,
        'distanceKm': distanceKm,
        'landingLat': landingLat,
        'landingLon': landingLon,
        'scoreBreakdown': scoreBreakdown.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'newContinent': newContinent,
      };

  factory WorldLeapLaunch.fromJson(Map<String, dynamic> json) =>
      WorldLeapLaunch(
        launchNumber: (json['launchNumber'] as num).toInt(),
        fromCountryCode: json['fromCountryCode'] as String,
        fromCountryName: json['fromCountryName'] as String,
        toCountryCode: json['toCountryCode'] as String,
        toCountryName: json['toCountryName'] as String,
        bearing: (json['bearing'] as num).toDouble(),
        power: (json['power'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        landingLat: (json['landingLat'] as num).toDouble(),
        landingLon: (json['landingLon'] as num).toDouble(),
        scoreBreakdown: WorldLeapScoreBreakdown.fromJson(
            json['scoreBreakdown'] as Map<String, dynamic>),
        timestamp: DateTime.parse(json['timestamp'] as String),
        newContinent: json['newContinent'] as bool? ?? false,
      );
}
