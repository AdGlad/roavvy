// lib/features/shared/quokka/quokka_sprite.dart
//
// Roavvy quokka mascot — sprite-based animation widget.
// Each state shows one of the AI-generated PNG poses with Flutter motion
// layered on top (bounce, sway, scale) to bring the static image to life.
//
// Usage:
//   QuokkaSprite(state: QuokkaState.celebrate, size: 160)
//   QuokkaSprite(state: QuokkaState.idle, size: 120, loop: true)

import 'package:flutter/widgets.dart';

enum QuokkaState {
  idle,
  wave,
  dance,
  celebrate,
  walk,
  point,
  think;

  String get _asset => switch (this) {
        QuokkaState.idle      => 'assets/mascot/quokka_idle.png',
        QuokkaState.wave      => 'assets/mascot/quokka_wave.png',
        QuokkaState.dance     => 'assets/mascot/quokka_dance.png',
        QuokkaState.celebrate => 'assets/mascot/quokka_celebrate.png',
        QuokkaState.walk      => 'assets/mascot/quokka_walk.png',
        QuokkaState.point     => 'assets/mascot/quokka_point.png',
        QuokkaState.think     => 'assets/mascot/quokka_think.png',
      };

  bool get loops => switch (this) {
        QuokkaState.idle  => true,
        QuokkaState.dance => true,
        QuokkaState.walk  => true,
        QuokkaState.point => true,
        QuokkaState.think => true,
        _                 => false,
      };

  Duration get duration => switch (this) {
        QuokkaState.idle      => const Duration(milliseconds: 2800),
        QuokkaState.wave      => const Duration(milliseconds: 1200),
        QuokkaState.dance     => const Duration(milliseconds: 700),
        QuokkaState.celebrate => const Duration(milliseconds: 900),
        QuokkaState.walk      => const Duration(milliseconds: 600),
        QuokkaState.point     => const Duration(milliseconds: 2000),
        QuokkaState.think     => const Duration(milliseconds: 3000),
      };
}

/// Displays the Roavvy quokka mascot in the given [state].
///
/// Each state shows a high-quality AI-generated PNG pose with Flutter
/// motion layered on top to animate it.
///
/// One-shot states (wave, celebrate) call [onComplete] when the motion
/// settles. Loop states (idle, dance, walk, point, think) run indefinitely.
class QuokkaSprite extends StatefulWidget {
  const QuokkaSprite({
    super.key,
    required this.state,
    this.size = 140,
    this.onComplete,
  });

  final QuokkaState state;
  final double size;
  final VoidCallback? onComplete;

  @override
  State<QuokkaSprite> createState() => _QuokkaSpriteState();
}

class _QuokkaSpriteState extends State<QuokkaSprite>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late _MotionSpec _spec;

  @override
  void initState() {
    super.initState();
    _spec = _specFor(widget.state);
    _ctrl = AnimationController(vsync: this, duration: _spec.duration);
    _start();
  }

  @override
  void didUpdateWidget(QuokkaSprite old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _ctrl.stop();
      _spec = _specFor(widget.state);
      _ctrl.duration = _spec.duration;
      _ctrl.reset();
      _start();
    }
  }

  void _start() {
    if (widget.state.loops) {
      _ctrl.repeat(reverse: _spec.reverses);
    } else {
      _ctrl.forward().whenComplete(() => widget.onComplete?.call());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _spec.curve.transform(_ctrl.value);
        final scaleVal = 1.0 + (_spec.scaleDelta * _sin(t));
        final yVal     = _spec.yDelta * _sin(t);
        final xVal     = _spec.xDelta * _sin(t);
        final rotVal   = _spec.rotDelta * _sin(t);

        return Transform.scale(
          scale: scaleVal,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(xVal, yVal),
            child: Transform.rotate(
              angle: rotVal,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        widget.state._asset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  // Half-sine oscillator: returns 0→1→0 over the [0,1] range.
  double _sin(double t) => (1 - (1 - 2 * t).abs());
}

// ── Motion specs ─────────────────────────────────────────────────────────────

class _MotionSpec {
  const _MotionSpec({
    required this.duration,
    this.curve = Curves.easeInOut,
    this.scaleDelta = 0,
    this.yDelta = 0,
    this.xDelta = 0,
    this.rotDelta = 0,
    this.reverses = true,
  });

  final Duration duration;
  final Curve curve;
  final double scaleDelta; // fraction, e.g. 0.02 = ±2%
  final double yDelta;     // pixels
  final double xDelta;     // pixels
  final double rotDelta;   // radians
  final bool reverses;
}

_MotionSpec _specFor(QuokkaState s) => switch (s) {
      // Idle: gentle breathing — subtle scale + tiny float
      QuokkaState.idle => const _MotionSpec(
          duration: Duration(milliseconds: 2800),
          curve: Curves.easeInOut,
          scaleDelta: 0.022,
          yDelta: -2.5,
        ),

      // Wave: whole body sways gently left-right, once
      QuokkaState.wave => const _MotionSpec(
          duration: Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
          rotDelta: -0.06,
          yDelta: -3,
          reverses: false,
        ),

      // Dance: fast bouncy hop up/down
      QuokkaState.dance => const _MotionSpec(
          duration: Duration(milliseconds: 700),
          curve: Curves.easeOut,
          yDelta: -10,
          scaleDelta: 0.04,
        ),

      // Celebrate: big pop then settles
      QuokkaState.celebrate => const _MotionSpec(
          duration: Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          scaleDelta: 0.12,
          yDelta: -14,
          rotDelta: 0.04,
          reverses: false,
        ),

      // Walk: gentle side-to-side sway + bob
      QuokkaState.walk => const _MotionSpec(
          duration: Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          xDelta: 3.5,
          yDelta: -4,
          rotDelta: 0.03,
        ),

      // Point: very subtle pulse, mostly static
      QuokkaState.point => const _MotionSpec(
          duration: Duration(milliseconds: 2000),
          curve: Curves.easeInOut,
          scaleDelta: 0.012,
          yDelta: -1.5,
        ),

      // Think: slow dreamy sway
      QuokkaState.think => const _MotionSpec(
          duration: Duration(milliseconds: 3000),
          curve: Curves.easeInOut,
          rotDelta: 0.04,
          yDelta: -2,
        ),
    };
