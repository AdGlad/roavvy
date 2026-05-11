import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'travel_replay_engine.dart';

// ── Opacity helper ─────────────────────────────────────────────────────────────

/// Bell-curve opacity from [overlayProgress] (0.0–1.0).
/// Peaks at 0.5 (full opacity), fades in from 0 and out to 0.
/// Uses sin(π × t) so the rise and fall are smooth.
double replayOverlayOpacity(double overlayProgress) =>
    math.sin(math.pi * overlayProgress).clamp(0.0, 1.0);

// ── Achievement overlay ────────────────────────────────────────────────────────

/// Cinematic achievement reveal card shown during the [ReplayPhase.overlay]
/// phase for a [ReplayAchievementEvent] (M110).
///
/// Positioned in the lower third of the screen, above the leg label.
/// Fades in/out driven by [overlayProgress] via [replayOverlayOpacity].
class ReplayAchievementOverlay extends StatelessWidget {
  const ReplayAchievementOverlay({
    super.key,
    required this.event,
    required this.overlayProgress,
  });

  final ReplayAchievementEvent event;

  /// 0.0–1.0 from [TravelReplayController.overlayProgress].
  final double overlayProgress;

  @override
  Widget build(BuildContext context) {
    final opacity = replayOverlayOpacity(overlayProgress);
    return Opacity(
      opacity: opacity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon.
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700), size: 32),
              const SizedBox(height: 8),
              // "Achievement Unlocked" label.
              Text(
                'Achievement Unlocked',
                style: TextStyle(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              // Achievement title.
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              // Achievement subtitle.
              Text(
                event.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat overlay ──────────────────────────────────────────────────────────────

/// Minimal cinematic stat pill shown during [ReplayPhase.overlay]
/// for a [ReplayStatEvent] (M110).
///
/// Displays a single stat (value + label) bottom-anchored above the leg label.
/// Does not obscure the globe arc.
class ReplayStatOverlay extends StatelessWidget {
  const ReplayStatOverlay({
    super.key,
    required this.event,
    required this.overlayProgress,
  });

  final ReplayStatEvent event;
  final double overlayProgress;

  @override
  Widget build(BuildContext context) {
    final opacity = replayOverlayOpacity(overlayProgress);
    return Opacity(
      opacity: opacity,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                event.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
