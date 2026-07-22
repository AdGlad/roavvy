// lib/features/shared/quokka/quokka_animation.dart
//
// Roavvy mascot Lottie animations.
// Use [QuokkaAnimation] anywhere in the app.

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

enum QuokkaAnim {
  idle,
  wave,
  dance,
  celebrate,
  walk,
  point,
  think;

  String get _asset => switch (this) {
        QuokkaAnim.idle      => 'assets/lottie/quokka_idle.json',
        QuokkaAnim.wave      => 'assets/lottie/quokka_wave.json',
        QuokkaAnim.dance     => 'assets/lottie/quokka_dance.json',
        QuokkaAnim.celebrate => 'assets/lottie/quokka_celebrate.json',
        QuokkaAnim.walk      => 'assets/lottie/quokka_walk.json',
        QuokkaAnim.point     => 'assets/lottie/quokka_point.json',
        QuokkaAnim.think     => 'assets/lottie/quokka_think.json',
      };

  // True for looping animations, false for one-shot.
  bool get loops => switch (this) {
        QuokkaAnim.idle  => true,
        QuokkaAnim.walk  => true,
        QuokkaAnim.think => true,
        _                => false,
      };
}

/// Displays the Roavvy quokka mascot playing a [QuokkaAnim] animation.
///
/// One-shot animations (wave, dance, celebrate, point) call [onComplete] when
/// they finish. Looping animations (idle, walk, think) run indefinitely.
///
/// ```dart
/// QuokkaAnimation(
///   anim: QuokkaAnim.celebrate,
///   size: 160,
///   onComplete: () => setState(() => _celebrating = false),
/// )
/// ```
class QuokkaAnimation extends StatefulWidget {
  const QuokkaAnimation({
    super.key,
    required this.anim,
    this.size = 120,
    this.onComplete,
  });

  final QuokkaAnim anim;
  final double size;
  final VoidCallback? onComplete;

  @override
  State<QuokkaAnimation> createState() => _QuokkaAnimationState();
}

class _QuokkaAnimationState extends State<QuokkaAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(QuokkaAnimation old) {
    super.didUpdateWidget(old);
    if (old.anim != widget.anim) {
      _ctrl.reset();
      if (widget.anim.loops) {
        _ctrl.repeat();
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _ctrl.duration = composition.duration;
    if (widget.anim.loops) {
      _ctrl.repeat();
    } else {
      _ctrl.forward().whenComplete(() {
        widget.onComplete?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        widget.anim._asset,
        controller: _ctrl,
        onLoaded: _onLoaded,
        fit: BoxFit.contain,
        // Use RenderCache.raster for animated quokka to avoid per-frame
        // Flutter layer recomposition.
        renderCache: RenderCache.raster,
      ),
    );
  }
}
