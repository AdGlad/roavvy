// lib/features/world_leap/domain/models/world_leap_run.dart

import 'package:shared_models/shared_models.dart';

import 'world_leap_failure_reason.dart';
import 'world_leap_launch.dart';
import '../../world_leap_config.dart';

/// A complete World Leap run for a given user on a given date.
/// Document ID in Firestore: {userId}_{YYYYMMDD}
class WorldLeapRun {
  /// Composite ID: {userId}_{date}
  final String id;

  final String userId;

  /// ISO date string: YYYY-MM-DD
  final String date;

  final String startCountryCode;
  final String startCountryName;

  /// Ordered list of successful launches.
  final List<WorldLeapLaunch> launches;

  final int totalScore;

  /// Number of unique countries successfully landed in.
  int get countryCount => launches.length;

  /// Whether the run has ended (success path exhausted or failure).
  final bool isComplete;

  /// Null until the run ends in failure.
  final WorldLeapFailureReason? failureReason;

  final DateTime? completedAt;

  /// The ISO code of the current target country the player must hit.
  final String? targetCountryCode;

  /// Display name of the current target country.
  final String? targetCountryName;

  /// Current time limit per shot in seconds. Starts at [WorldLeapConfig.countdownStartSeconds]
  /// and decreases by 1 on each successful hit (floor [WorldLeapConfig.countdownMinSeconds]).
  final int timeLimitSeconds;

  const WorldLeapRun({
    required this.id,
    required this.userId,
    required this.date,
    required this.startCountryCode,
    required this.startCountryName,
    this.launches = const [],
    this.totalScore = 0,
    this.isComplete = false,
    this.failureReason,
    this.completedAt,
    this.targetCountryCode,
    this.targetCountryName,
    this.timeLimitSeconds = WorldLeapConfig.countdownStartSeconds,
  });

  /// The ISO-3166-1 alpha-2 code of the country the player is currently in.
  String get currentCountryCode =>
      launches.isEmpty ? startCountryCode : launches.last.toCountryCode;

  String get currentCountryName =>
      launches.isEmpty ? startCountryName : launches.last.toCountryName;

  /// All country codes visited during this run (including start).
  Set<String> get visitedCountryCodes => {
        startCountryCode,
        ...launches.map((l) => l.toCountryCode),
      };

  /// All continent names visited during this run (including the start country's
  /// continent, if known).
  Set<String> get visitedContinents => {
        if (kCountryContinent[startCountryCode] case final c?) c,
        for (final l in launches)
          if (kCountryContinent[l.toCountryCode] case final c?) c,
      };

  double get longestLaunchKm => launches.isEmpty
      ? 0.0
      : launches.map((l) => l.distanceKm).reduce((a, b) => a > b ? a : b);

  WorldLeapRun copyWith({
    List<WorldLeapLaunch>? launches,
    int? totalScore,
    bool? isComplete,
    WorldLeapFailureReason? failureReason,
    DateTime? completedAt,
    String? targetCountryCode,
    String? targetCountryName,
    int? timeLimitSeconds,
    bool clearTarget = false,
  }) =>
      WorldLeapRun(
        id: id,
        userId: userId,
        date: date,
        startCountryCode: startCountryCode,
        startCountryName: startCountryName,
        launches: launches ?? this.launches,
        totalScore: totalScore ?? this.totalScore,
        isComplete: isComplete ?? this.isComplete,
        failureReason: failureReason ?? this.failureReason,
        completedAt: completedAt ?? this.completedAt,
        targetCountryCode:
            clearTarget ? null : (targetCountryCode ?? this.targetCountryCode),
        targetCountryName:
            clearTarget ? null : (targetCountryName ?? this.targetCountryName),
        timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': date,
        'startCountryCode': startCountryCode,
        'startCountryName': startCountryName,
        'launches': launches.map((l) => l.toJson()).toList(),
        'totalScore': totalScore,
        'isComplete': isComplete,
        'failureReason': failureReason?.toJson(),
        'completedAt': completedAt?.toIso8601String(),
        'targetCountryCode': targetCountryCode,
        'targetCountryName': targetCountryName,
        'timeLimitSeconds': timeLimitSeconds,
      };

  factory WorldLeapRun.fromJson(Map<String, dynamic> json) => WorldLeapRun(
        id: json['id'] as String,
        userId: json['userId'] as String,
        date: json['date'] as String,
        startCountryCode: json['startCountryCode'] as String,
        startCountryName: json['startCountryName'] as String? ?? '',
        launches: (json['launches'] as List<dynamic>? ?? [])
            .map((e) => WorldLeapLaunch.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
        isComplete: json['isComplete'] as bool? ?? false,
        failureReason: json['failureReason'] != null
            ? WorldLeapFailureReasonX.fromJson(json['failureReason'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        targetCountryCode: json['targetCountryCode'] as String?,
        targetCountryName: json['targetCountryName'] as String?,
        timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ??
            WorldLeapConfig.countdownStartSeconds,
      );

  /// Generates the Firestore document ID for a given user and date.
  static String documentId(String userId, String date) =>
      '${userId}_$date';
}
