// lib/features/world_leap/application/world_leap_analytics_service.dart

import 'package:flutter/foundation.dart';

import '../domain/models/world_leap_launch.dart';
import '../domain/models/world_leap_run.dart';
import 'world_leap_state.dart';

// ── Analytics abstraction ─────────────────────────────────────────────────────

/// Abstraction over an analytics backend — injectable for tests.
abstract class IAnalyticsLogger {
  Future<void> logEvent(String name, Map<String, Object> parameters);
}

/// Debug implementation that prints events to the console.
class DebugAnalyticsLogger implements IAnalyticsLogger {
  const DebugAnalyticsLogger();

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    debugPrint('[WorldLeap] $name: $parameters');
  }
}

// ── Event name constants (package-private) ────────────────────────────────────

const String kEventGameStarted = 'wl_game_started';
const String kEventLaunched    = 'wl_launched';
const String kEventLanded      = 'wl_landed';
const String kEventFailed      = 'wl_failed';
const String kEventCompleted   = 'wl_completed';

// ── Service ───────────────────────────────────────────────────────────────────

class WorldLeapAnalyticsService {
  WorldLeapAnalyticsService(this._logger);
  final IAnalyticsLogger _logger;

  /// Logged when a new run begins (after initialize completes with a fresh run).
  Future<void> logGameStarted({
    required String date,
    required String startCountryCode,
  }) =>
      _logger.logEvent(kEventGameStarted, {
        'date': date,
        'start_country': startCountryCode,
      });

  /// Logged on every successful launch.
  Future<void> logLaunched(WorldLeapLaunch launch) =>
      _logger.logEvent(kEventLaunched, {
        'launch_number': launch.launchNumber,
        'from_country': launch.fromCountryCode,
        'to_country': launch.toCountryCode,
        'bearing': launch.bearing.round(),
        'distance_km': launch.distanceKm.round(),
        'score': launch.score,
        'has_heritage_bonus': launch.scoreBreakdown.hasHeritageBonus ? 1 : 0,
        'has_long_shot_bonus': launch.scoreBreakdown.hasLongShotBonus ? 1 : 0,
      });

  /// Logged when a run ends in failure.
  Future<void> logFailed({
    required WorldLeapRun run,
    required String failureReason,
  }) =>
      _logger.logEvent(kEventFailed, {
        'reason': failureReason,
        'countries_visited': run.countryCount,
        'total_score': run.totalScore,
        'date': run.date,
      });

  /// Logged when a run ends successfully (player taps End Game).
  Future<void> logCompleted(WorldLeapRun run) =>
      _logger.logEvent(kEventCompleted, {
        'countries_visited': run.countryCount,
        'total_score': run.totalScore,
        'longest_launch_km': run.longestLaunchKm.round(),
        'date': run.date,
      });

  /// Convenience dispatcher — call from a WorldLeapController listener.
  Future<void> logForState(WorldLeapState state) async {
    switch (state) {
      case WorldLeapStateLanded(:final lastLaunch):
        await logLaunched(lastLaunch);
      case WorldLeapStateFailed(:final run, :final reason):
        await logFailed(run: run, failureReason: reason.name);
      case WorldLeapStateComplete(:final run):
        await logCompleted(run);
      default:
        break;
    }
  }
}
