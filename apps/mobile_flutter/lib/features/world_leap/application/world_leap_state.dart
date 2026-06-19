// lib/features/world_leap/application/world_leap_state.dart

import '../domain/models/world_leap_failure_reason.dart';
import '../domain/models/world_leap_launch.dart';
import '../domain/models/world_leap_run.dart';

/// Sealed state hierarchy for the World Leap game controller.
sealed class WorldLeapState {}

/// Initial state before the game is loaded.
final class WorldLeapStateIdle extends WorldLeapState {}

/// Fetching daily config / restoring run from storage.
final class WorldLeapStateLoading extends WorldLeapState {}

/// User already played today — show their completed run.
final class WorldLeapStateLocked extends WorldLeapState {
  final WorldLeapRun run;

  WorldLeapStateLocked({required this.run});
}

/// Ready to aim — player can pull the slingshot.
final class WorldLeapStateAiming extends WorldLeapState {
  final WorldLeapRun run;

  /// Current bearing in degrees (0–360). Null while not actively aiming.
  final double? bearingDeg;

  /// Current normalised power (0–1). Null while not actively aiming.
  final double? power;

  WorldLeapStateAiming({
    required this.run,
    this.bearingDeg,
    this.power,
  });
}

/// Projectile in flight — animation is playing.
final class WorldLeapStateLaunching extends WorldLeapState {
  final WorldLeapRun run;
  final double bearingDeg;
  final double power;

  WorldLeapStateLaunching({
    required this.run,
    required this.bearingDeg,
    required this.power,
  });
}

/// Successful landing — score panel shown before next turn.
final class WorldLeapStateLanded extends WorldLeapState {
  final WorldLeapRun run;

  /// The launch that just completed (for the score panel).
  final WorldLeapLaunch lastLaunch;

  WorldLeapStateLanded({
    required this.run,
    required this.lastLaunch,
  });
}

/// Landing failed (water, repeat country, same country, invalid).
final class WorldLeapStateFailed extends WorldLeapState {
  final WorldLeapRun run;
  final WorldLeapFailureReason reason;

  WorldLeapStateFailed({
    required this.run,
    required this.reason,
  });
}

/// Run is complete — all launches used or player ended the game.
final class WorldLeapStateComplete extends WorldLeapState {
  final WorldLeapRun run;

  WorldLeapStateComplete({required this.run});
}

/// Unrecoverable error.
final class WorldLeapStateError extends WorldLeapState {
  final String message;

  WorldLeapStateError({required this.message});
}
