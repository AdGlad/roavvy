import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

// ── Country flag emoji helper ──────────────────────────────────────────────────

String _emojiFlag(String code) {
  final upper = code.toUpperCase();
  final a = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([a, b]);
}

// ── CountryDiscoveryOverlay ────────────────────────────────────────────────────

/// Full-screen overlay shown during [ReplayPhase.flagReveal].
///
/// Renders a large emoji flag centred on the screen with a scale-in +
/// slight-bounce animation, a subtle glow, and a short star-confetti burst.
///
/// [revealProgress] is 0.0 → 1.0 from the controller.
/// [confettiCtrl] must already be play()-ed by the parent when this widget
/// is first shown.
class CountryDiscoveryOverlay extends StatelessWidget {
  const CountryDiscoveryOverlay({
    super.key,
    required this.countryCode,
    required this.revealProgress,
    required this.confettiCtrl,
    required this.confettiColors,
  });

  final String countryCode;

  /// 0.0 – 1.0 linear progress from the animation controller.
  final double revealProgress;

  final ConfettiController confettiCtrl;
  final List<Color> confettiColors;

  @override
  Widget build(BuildContext context) {
    // Scale-in with elastic bounce: grows from 0 → 1.08 → 1.0
    final elasticT = Curves.elasticOut.transform(
      revealProgress.clamp(0.0, 1.0),
    );
    final scale = elasticT * 1.0;

    // Opacity: quick fade-in (first 20%) then stay visible
    final opacity = (revealProgress * 5.0).clamp(0.0, 1.0);

    // Hold opacity: fade out last 15% of reveal phase
    final holdOpacity =
        revealProgress > 0.85
            ? ((1.0 - revealProgress) / 0.15).clamp(0.0, 1.0)
            : 1.0;
    final finalOpacity = opacity * holdOpacity;

    return IgnorePointer(
      child: Stack(
        children: [
          // Dimmed globe backdrop (subtle)
          Opacity(
            opacity:
                (revealProgress * 2.0).clamp(0.0, 0.3) *
                (revealProgress > 0.85
                    ? ((1.0 - revealProgress) / 0.15).clamp(0.0, 1.0)
                    : 1.0),
            child: Container(color: Colors.black),
          ),

          // Confetti emitter — centred
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.1),
              child: ConfettiWidget(
                confettiController: confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.6,
                numberOfParticles: 8,
                gravity: 0.4,
                maxBlastForce: 28,
                minBlastForce: 10,
                minimumSize: const Size(6, 6),
                maximumSize: const Size(12, 12),
                colors:
                    confettiColors.isNotEmpty
                        ? confettiColors
                        : const [Colors.amber, Colors.white],
                createParticlePath: _drawStar,
              ),
            ),
          ),

          // Large emoji flag
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.1),
              child: Opacity(
                opacity: finalOpacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: 0.15 * finalOpacity,
                          ),
                          blurRadius: 40,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _emojiFlag(countryCode),
                        style: const TextStyle(fontSize: 88),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FlagFlightOverlay ─────────────────────────────────────────────────────────

/// Full-screen overlay shown during [ReplayPhase.flagFlight].
///
/// Animates the emoji flag from the centre of the screen down to the bottom
/// flag-collection row, shrinking from large → small.
///
/// [flightProgress] is 0.0 → 1.0 from the controller.
class FlagFlightOverlay extends StatelessWidget {
  const FlagFlightOverlay({
    super.key,
    required this.countryCode,
    required this.flightProgress,
  });

  final String countryCode;

  /// 0.0 – 1.0 linear progress.
  final double flightProgress;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInCubic.transform(flightProgress.clamp(0.0, 1.0));

    // Vertical position: 0 = screen centre, 1 = near bottom (row area)
    final dy = _lerp(-0.10, 0.72, t);

    // Scale: flag shrinks from large to small as it reaches the row
    final scale = _lerp(1.0, 0.22, t);

    // Opacity: fades out in the last 20%
    final opacity = t > 0.8 ? ((1.0 - t) / 0.2).clamp(0.0, 1.0) : 1.0;

    return IgnorePointer(
      child: Align(
        alignment: Alignment(0, dy),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Text(
              _emojiFlag(countryCode),
              style: const TextStyle(fontSize: 88),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ── Row slot pulse ─────────────────────────────────────────────────────────────

/// Wraps the last flag in the collection row with a brief radial pulse glow.
/// Controlled by a [ConfettiController]-free approach using an [AnimationController].
class SlotPulse extends StatefulWidget {
  const SlotPulse({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Increment this each time you want the pulse to re-fire.
  final int trigger;

  @override
  State<SlotPulse> createState() => _SlotPulseState();
}

class _SlotPulseState extends State<SlotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(SlotPulse old) {
    super.didUpdateWidget(old);
    if (widget.trigger != _lastTrigger) {
      _lastTrigger = widget.trigger;
      _ctrl.forward(from: 0);
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
        final scale = 1.0 + 0.35 * _anim.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

// ── Star confetti path ─────────────────────────────────────────────────────────

Path _drawStar(Size size) {
  const points = 5;
  final path = Path();
  final cx = size.width / 2;
  final cy = size.height / 2;
  final outerR = math.min(cx, cy);
  final innerR = outerR * 0.45;
  final angle = -math.pi / 2;

  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerR : innerR;
    final a = angle + (i * math.pi / points);
    final x = cx + r * math.cos(a);
    final y = cy + r * math.sin(a);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}
