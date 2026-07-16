// lib/features/world_leap/presentation/screens/world_leap_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile_flutter/features/world_leap/application/world_leap_providers.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_state.dart';
import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_camera_mode.dart';
import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_map_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/slingshot_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/quokka_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_hud.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_score_panel.dart';
import 'world_leap_result_screen.dart';

// ── Landing particle burst ────────────────────────────────────────────────────

class _ParticleBurst extends StatefulWidget {
  const _ParticleBurst({super.key});

  @override
  State<_ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<_ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _colors = [
    Color(0xFFFFD600),
    Color(0xFFFF6D00),
    Color(0xFF00E676),
    Color(0xFF40C4FF),
    Color(0xFFEA80FC),
    Color(0xFFFF1744),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ParticlePainter(t: _ctrl.value, colors: _colors),
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t;
  final List<Color> colors;

  static const _count = 12;
  static const _speed = 160.0; // max pixels from center at t=1

  _ParticlePainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final dist = _speed * Curves.easeOut.transform(t);
    final alpha = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    final radius = (6.0 * (1.0 - t * 0.5)).clamp(1.0, 8.0);
    for (var i = 0; i < _count; i++) {
      final angle = (2 * math.pi / _count) * i;
      // Vary distance slightly per particle for natural spread
      final d = dist * (0.7 + 0.3 * ((i * 7) % _count) / _count);
      final x = cx + d * math.cos(angle);
      final y = cy + d * math.sin(angle);
      paint.color = colors[i % colors.length].withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ── Floating score burst ──────────────────────────────────────────────────────

/// Animates a `+N pts` label + accuracy word upward then fades it out.
/// Gets a fresh [key] on each landing so the animation restarts each shot.
class _FloatingScoreLabel extends StatefulWidget {
  final int points;
  final int stars; // 1–3

  const _FloatingScoreLabel({super.key, required this.points, required this.stars});

  @override
  State<_FloatingScoreLabel> createState() => _FloatingScoreLabelState();
}

class _FloatingScoreLabelState extends State<_FloatingScoreLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.8)).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
    );
    // Fade in fast, hold, then fade out
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _label => switch (widget.stars) {
        3 => 'BULLSEYE!',
        2 => 'GREAT SHOT!',
        _ => 'NICE!',
      };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${widget.points} pts',
                    style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Combo milestone banner ─────────────────────────────────────────────────────

/// Slides in from the top, holds, then slides out when a combo tier is reached.
class _ComboBanner extends StatefulWidget {
  final double multiplier;

  const _ComboBanner({super.key, required this.multiplier});

  @override
  State<_ComboBanner> createState() => _ComboBannerState();
}

class _ComboBannerState extends State<_ComboBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // 350ms in, hold 1100ms, 350ms out → 1800ms total
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 60),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -1))
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _label {
    final m = widget.multiplier;
    final formatted = m == m.truncateToDouble() ? '×${m.toInt()}' : '×$m';
    return 'COMBO $formatted!';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slide,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepOrange.shade900.withValues(alpha: 0.95),
                  Colors.orange.shade700.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Text(
                _label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Difficulty button ─────────────────────────────────────────────────────────

class _DifficultyButton extends StatelessWidget {
  final int difficulty; // 1–5
  final VoidCallback onTap;

  const _DifficultyButton({required this.difficulty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = WorldLeapConfig.difficultyLabels[difficulty - 1];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Tooltip(
          message: label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'D',
                style: TextStyle(color: Colors.white54, fontSize: 9, height: 1.1),
              ),
              Text(
                '$difficulty',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camera mode toggle button ─────────────────────────────────────────────────

class _CameraToggleButton extends StatelessWidget {
  final WorldLeapCameraMode mode;
  final VoidCallback onTap;

  const _CameraToggleButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = mode != WorldLeapCameraMode.stationary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          _iconFor(mode),
          color: isActive ? Colors.white : Colors.white60,
          size: 20,
        ),
      ),
    );
  }

  IconData _iconFor(WorldLeapCameraMode m) => switch (m) {
        WorldLeapCameraMode.stationary => Icons.location_on_outlined,
        WorldLeapCameraMode.birdseye => Icons.satellite_alt_outlined,
        WorldLeapCameraMode.pov => Icons.flight,
      };
}

class WorldLeapScreen extends ConsumerStatefulWidget {
  const WorldLeapScreen({super.key});

  @override
  ConsumerState<WorldLeapScreen> createState() => _WorldLeapScreenState();
}

class _WorldLeapScreenState extends ConsumerState<WorldLeapScreen>
    with TickerProviderStateMixin {
  final _geo = WorldLeapGeoService();
  final _mapKey = GlobalKey<WorldLeapMapWidgetState>();

  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeAnimation;
  WorldLeapState? _prevState;

  final _slingshotActive = ValueNotifier<bool>(false);
  final _cameraMode = ValueNotifier<WorldLeapCameraMode>(WorldLeapCameraMode.stationary);
  final _difficulty = ValueNotifier<int>(1);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(8, 4)), weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(8, 4), end: const Offset(-8, -3)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-8, -3), end: const Offset(6, -5)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(6, -5), end: const Offset(-4, 3)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-4, 3), end: Offset.zero),
          weight: 3),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    // Orientation is now managed globally — no lock/unlock needed here.
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _slingshotActive.dispose();
    _cameraMode.dispose();
    _difficulty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncController = ref.watch(worldLeapControllerProvider);

    return asyncController.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start World Leap:\n$e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (controller) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final currentState = controller.state;

              // Detect state transitions and trigger shake.
              final newState = currentState;
              if (_prevState is! WorldLeapStateLaunching &&
                  newState is WorldLeapStateLaunching) {
                _shakeController.forward(from: 0);
              } else if (_prevState is! WorldLeapStateLanded &&
                  newState is WorldLeapStateLanded) {
                _shakeController.forward(from: 0);
              }
              _prevState = newState;

              // Controller-level error (e.g. missing daily doc, network failure)
              if (currentState is WorldLeapStateError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      currentState.message,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // Terminal states → result screen
              if (currentState is WorldLeapStateFailed ||
                  currentState is WorldLeapStateComplete ||
                  currentState is WorldLeapStateLocked) {
                final run = currentState is WorldLeapStateFailed
                    ? currentState.run
                    : currentState is WorldLeapStateComplete
                        ? currentState.run
                        : (currentState as WorldLeapStateLocked).run;
                return WorldLeapResultScreen(
                  run: run,
                  onPlayAgain: () => controller.resetRun(),
                  onDone: () => Navigator.of(context).pop(),
                );
              }

              // Loading / idle
              if (currentState is WorldLeapStateLoading ||
                  currentState is WorldLeapStateIdle) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              // Active game
              final isLandscape = MediaQuery.orientationOf(context) ==
                  Orientation.landscape;
              return AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: _shakeAnimation.value,
                  child: child,
                ),
                child: Stack(
                  children: [
                    // Background map
                    ValueListenableBuilder<WorldLeapCameraMode>(
                      valueListenable: _cameraMode,
                      builder: (context, mode, _) => WorldLeapMapWidget(
                        key: _mapKey,
                        controller: controller,
                        geo: _geo,
                        slingshotActive: _slingshotActive,
                        cameraMode: mode,
                      ),
                    ),

                    // Slingshot gesture layer — only activates when touch
                    // starts on the source country; all other touches pan map.
                    SlingshotWidget(
                      controller: controller,
                      hitTestFn: (pos) =>
                          _mapKey.currentState?.isInCurrentCountry(pos) ??
                          false,
                      onActiveChanged: (v) => _slingshotActive.value = v,
                    ),

                    // Zoom buttons + camera mode + difficulty
                    // Portrait: bottom-right. Landscape: bottom-left (right side is HUD panel).
                    Positioned(
                      bottom: isLandscape ? 12 : 170,
                      right: isLandscape ? null : 16,
                      left: isLandscape ? 16 : null,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_cameraMode, _difficulty]),
                        builder: (context, _) => Column(
                          children: [
                            _ZoomButton(
                              icon: Icons.add,
                              onTap: () => _mapKey.currentState?.zoomIn(),
                            ),
                            const SizedBox(height: 8),
                            _ZoomButton(
                              icon: Icons.remove,
                              onTap: () => _mapKey.currentState?.zoomOut(),
                            ),
                            const SizedBox(height: 8),
                            _CameraToggleButton(
                              mode: _cameraMode.value,
                              onTap: () => _cameraMode.value = _cameraMode.value.next,
                            ),
                            const SizedBox(height: 8),
                            _DifficultyButton(
                              difficulty: _difficulty.value,
                              onTap: () {
                                final next = (_difficulty.value % 5) + 1;
                                _difficulty.value = next;
                                controller.setDifficulty(next);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quokka mascot — purely decorative, must never absorb touches.
                    // Without IgnorePointer the ConfettiWidget's CustomPaint
                    // silently blocks swipes across a large screen area.
                    Positioned(
                      bottom: isLandscape ? 8 : 80,
                      left: isLandscape ? 70 : 16,
                      child: IgnorePointer(
                        child: QuokkaWidget(controller: controller),
                      ),
                    ),

                    // HUD — orientation-aware (portrait=top pill, landscape=right panel)
                    WorldLeapHud(controller: controller),

                    // Score panel (Landed state)
                    if (currentState is WorldLeapStateLanded)
                      WorldLeapScorePanel(
                        launch: currentState.lastLaunch,
                        onDismiss: controller.dismissScorePanel,
                      ),

                    // Particle burst on landing
                    if (currentState is WorldLeapStateLanded)
                      _ParticleBurst(
                        key: ValueKey('particles_${currentState.lastLaunch.scoreBreakdown.comboStreak}'),
                      ),

                    // Floating score burst — fresh widget per landing via key
                    if (currentState is WorldLeapStateLanded)
                      _FloatingScoreLabel(
                        key: ValueKey('score_${currentState.lastLaunch.scoreBreakdown.comboStreak}'),
                        points: currentState.lastLaunch.scoreBreakdown.total,
                        stars: currentState.lastLaunch.scoreBreakdown.stars,
                      ),

                    // Combo milestone banner — only when multiplier > 1
                    if (currentState is WorldLeapStateLanded &&
                        currentState.lastLaunch.scoreBreakdown.comboMultiplier > 1.0)
                      _ComboBanner(
                        key: ValueKey('combo_${currentState.lastLaunch.scoreBreakdown.comboStreak}'),
                        multiplier: currentState.lastLaunch.scoreBreakdown.comboMultiplier,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
