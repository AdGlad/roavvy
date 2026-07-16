// lib/features/world_leap/presentation/widgets/world_leap_hud.dart
//
// Orientation-aware HUD for World Leap.
//   Portrait  → compact 2-row pill at top-left (minimal footprint).
//   Landscape → narrow right-side panel (completely outside catapult zone).

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../application/world_leap_controller.dart';
import '../../application/world_leap_state.dart';
import '../../domain/models/world_leap_run.dart';

// ── Package-private helpers ───────────────────────────────────────────────────

int _streakOf(WorldLeapRun run) =>
    run.launches.isEmpty ? 0 : run.launches.last.scoreBreakdown.comboStreak;

WorldLeapRun? runFromState(WorldLeapState state) => switch (state) {
      WorldLeapStateAiming(:final run) => run,
      WorldLeapStateLaunching(:final run) => run,
      WorldLeapStateLanded(:final run) => run,
      WorldLeapStateFailed(:final run) => run,
      WorldLeapStateComplete(:final run) => run,
      WorldLeapStateLocked(:final run) => run,
      _ => null,
    };

// ── Shared constants ──────────────────────────────────────────────────────────

const _kPanelBg = Color(0xCC0A0F1A);       // near-black, 80% opaque
const _kTargetRedLight = Color(0xFFFF8A80);
const _kAccent = Colors.amber;

// ── Widget ────────────────────────────────────────────────────────────────────

class WorldLeapHud extends StatefulWidget {
  final WorldLeapController controller;
  final VoidCallback? onEndGame;

  const WorldLeapHud({
    super.key,
    required this.controller,
    this.onEndGame,
  });

  @override
  State<WorldLeapHud> createState() => _WorldLeapHudState();
}

class _WorldLeapHudState extends State<WorldLeapHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeat;

  @override
  void initState() {
    super.initState();
    _heartbeat = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _heartbeat.dispose();
    super.dispose();
  }

  void _updateHeartbeat(int remaining, int limit) {
    if (remaining <= 0) {
      _heartbeat.stop();
      return;
    }
    // Accelerate: slow at start, fast at last 5s.
    final t = 1.0 - (remaining - 1) / (limit - 1).toDouble().clamp(1, 999);
    final bps = 0.5 + 1.5 * t;
    final ms = (1000 / bps).round();
    if ((_heartbeat.duration?.inMilliseconds ?? 0) != ms) {
      _heartbeat.duration = Duration(milliseconds: ms);
    }
    if (!_heartbeat.isAnimating) _heartbeat.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final run = runFromState(state);
          if (run == null) return const SizedBox.shrink();

          final isAiming = state is WorldLeapStateAiming;
          final showEnd = isAiming || state is WorldLeapStateLanded;
          final timeRemaining = widget.controller.timeRemaining;
          final limit = widget.controller.timeLimitSeconds;
          final targetName = widget.controller.targetCountryName;
          final distKm = widget.controller.targetDistanceKm;
          final bearing = widget.controller.targetBearingDeg;
          final urgent = isAiming && timeRemaining <= 5 && timeRemaining > 0;

          if (isAiming && timeRemaining > 0) {
            _updateHeartbeat(timeRemaining, limit);
          } else {
            _heartbeat.stop();
            _heartbeat.reset();
          }

          if (orientation == Orientation.landscape) {
            return _LandscapePanel(
              run: run,
              isAiming: isAiming,
              showEnd: showEnd,
              timeRemaining: timeRemaining,
              urgent: urgent,
              targetName: targetName,
              distKm: distKm,
              bearing: bearing,
              heartbeat: _heartbeat,
              onEnd: widget.onEndGame ?? widget.controller.endRun,
            );
          }

          return _PortraitBar(
            run: run,
            isAiming: isAiming,
            showEnd: showEnd,
            timeRemaining: timeRemaining,
            urgent: urgent,
            targetName: targetName,
            distKm: distKm,
            bearing: bearing,
            heartbeat: _heartbeat,
            onEnd: widget.onEndGame ?? widget.controller.endRun,
          );
        },
      ),
    );
  }
}

// ── Portrait: compact top-left pill ──────────────────────────────────────────

class _PortraitBar extends StatelessWidget {
  final WorldLeapRun run;
  final bool isAiming;
  final bool showEnd;
  final int timeRemaining;
  final bool urgent;
  final String? targetName;
  final double? distKm;
  final double? bearing;
  final AnimationController heartbeat;
  final VoidCallback onEnd;

  const _PortraitBar({
    required this.run,
    required this.isAiming,
    required this.showEnd,
    required this.timeRemaining,
    required this.urgent,
    required this.targetName,
    required this.distKm,
    required this.bearing,
    required this.heartbeat,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Only apply bottom=false so we don't push into usable space.
      bottom: false,
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 10, top: 6, right: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: country · score · shot# · streak ───────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌍', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      run.currentCountryName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  _dot(),
                  Text(
                    '${run.totalScore}',
                    style: const TextStyle(
                        color: _kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(' pts',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 11)),
                  _dot(),
                  Text('#${run.countryCount}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  if (_streakOf(run) >= 2) ...[
                    _dot(),
                    _StreakBadge(streak: _streakOf(run)),
                  ],
                ],
              ),
              // ── Row 2: target · distance · timer · end ─────────────────────
              if (isAiming && targetName != null || showEnd) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAiming && targetName != null) ...[
                      const Text('🎯', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          targetName!,
                          style: const TextStyle(
                              color: _kTargetRedLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (distKm != null && bearing != null) ...[
                        const SizedBox(width: 4),
                        Transform.rotate(
                          angle: bearing! * math.pi / 180.0,
                          child: const Icon(Icons.arrow_upward,
                              color: _kTargetRedLight, size: 13),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${(distKm! / 1000).toStringAsFixed(1)}k',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                      if (timeRemaining > 0) _dot(),
                    ],
                    if (isAiming && timeRemaining > 0)
                      _TimerChip(
                          remaining: timeRemaining,
                          urgent: urgent,
                          heartbeat: heartbeat),
                    if (showEnd) ...[
                      const SizedBox(width: 6),
                      _EndButton(onEnd: onEnd),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Text('·',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
}

// ── Landscape: right-side panel ───────────────────────────────────────────────

class _LandscapePanel extends StatelessWidget {
  final WorldLeapRun run;
  final bool isAiming;
  final bool showEnd;
  final int timeRemaining;
  final bool urgent;
  final String? targetName;
  final double? distKm;
  final double? bearing;
  final AnimationController heartbeat;
  final VoidCallback onEnd;

  const _LandscapePanel({
    required this.run,
    required this.isAiming,
    required this.showEnd,
    required this.timeRemaining,
    required this.urgent,
    required this.targetName,
    required this.distKm,
    required this.bearing,
    required this.heartbeat,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false, // right side; keep left clear for catapult
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 152,
          margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country
              Row(children: [
                const Text('🌍', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    run.currentCountryName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              // Score + count + streak
              Row(children: [
                Text('${run.totalScore}',
                    style: const TextStyle(
                        color: _kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const Text(' pts',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                Text('#${run.countryCount}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ]),
              if (_streakOf(run) >= 2) ...[
                const SizedBox(height: 4),
                _StreakBadge(streak: _streakOf(run), large: true),
              ],

              // ── Target ────────────────────────────────────────────────────
              if (isAiming && targetName != null) ...[
                const SizedBox(height: 8),
                Container(
                  height: 0.5,
                  color: Colors.white12,
                ),
                const SizedBox(height: 8),
                const Text('TARGET',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Row(children: [
                  const Text('🎯', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      targetName!,
                      style: const TextStyle(
                          color: _kTargetRedLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ]),
                if (distKm != null && bearing != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Transform.rotate(
                      angle: bearing! * math.pi / 180.0,
                      child: const Icon(Icons.arrow_upward,
                          color: _kTargetRedLight, size: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(distKm! / 1000).toStringAsFixed(1)}k km',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ]),
                ],
              ],

              // ── Timer ─────────────────────────────────────────────────────
              if (isAiming && timeRemaining > 0) ...[
                const SizedBox(height: 8),
                Container(height: 0.5, color: Colors.white12),
                const SizedBox(height: 8),
                _TimerChip(
                    remaining: timeRemaining,
                    urgent: urgent,
                    heartbeat: heartbeat,
                    large: true),
              ],

              // ── End button ────────────────────────────────────────────────
              if (showEnd) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _EndButton(onEnd: onEnd, expanded: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _TimerChip extends StatelessWidget {
  final int remaining;
  final bool urgent;
  final AnimationController heartbeat;
  final bool large;

  const _TimerChip({
    required this.remaining,
    required this.urgent,
    required this.heartbeat,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: heartbeat,
      builder: (context, _) {
        final pulse = urgent ? heartbeat.value : 0.0;
        final scale = 1.0 + pulse * 0.2;
        final color = Color.lerp(
          Colors.white70,
          const Color(0xFFFF1744),
          urgent ? pulse : 0.0,
        )!;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: large ? 6 : 4, vertical: large ? 4 : 2),
            decoration: BoxDecoration(
              color: urgent
                  ? Color.lerp(Colors.transparent,
                      const Color(0x55FF1744), pulse)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer,
                    size: large ? 15 : 13, color: color),
                const SizedBox(width: 3),
                Text(
                  '${remaining}s',
                  style: TextStyle(
                    color: color,
                    fontSize: large ? 15 : 12,
                    fontWeight:
                        urgent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EndButton extends StatelessWidget {
  final VoidCallback onEnd;
  final bool expanded;

  const _EndButton({required this.onEnd, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Text(
          expanded ? 'End Game' : 'End',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Streak fire badge ─────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  final bool large;

  const _StreakBadge({required this.streak, this.large = false});

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 13.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 8 : 5, vertical: large ? 3 : 2),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Colors.deepOrange.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: fontSize - 1)),
          const SizedBox(width: 3),
          Text(
            '×$streak',
            style: TextStyle(
              color: Colors.deepOrangeAccent,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
