// lib/features/world_leap/presentation/widgets/world_leap_tutorial_overlay.dart
//
// First-time / on-demand "How to Play" tutorial for World Leap. Shown
// automatically the first time the lobby is opened, and re-openable at any
// time via the lobby's "How to Play" link.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTutorialSeenKey = 'world_leap_tutorial_seen';

/// Whether the player has already dismissed the tutorial at least once.
Future<bool> hasSeenWorldLeapTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kTutorialSeenKey) ?? false;
}

Future<void> _markWorldLeapTutorialSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTutorialSeenKey, true);
}

/// Shows the "How to Play" dialog. Marks the tutorial as seen as soon as it's
/// opened — first showing (auto) and later on-demand openings both count, so
/// it never auto-shows again once the player has seen it once.
Future<void> showWorldLeapTutorial(
  BuildContext context, {
  required bool beginnerMode,
}) {
  unawaited(_markWorldLeapTutorialSeen());
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => WorldLeapTutorialDialog(beginnerMode: beginnerMode),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class WorldLeapTutorialDialog extends StatelessWidget {
  const WorldLeapTutorialDialog({super.key, required this.beginnerMode});

  final bool beginnerMode;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .reduceMotion;

    return Dialog(
      backgroundColor: const Color(0xFF0F1522),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How to Play',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _TutorialIllustration(
                beginnerMode: beginnerMode,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(height: 20),
              const _Step(
                number: 1,
                text:
                    'Drag on the highlighted country to aim. You launch in '
                    'the OPPOSITE direction from your drag — just like a '
                    'real slingshot.',
              ),
              const SizedBox(height: 12),
              _Step(
                number: 2,
                text: beginnerMode
                    ? 'Release to lock in your aim. Re-aim as many times as '
                          'you like, then tap FIRE when ready.'
                    : 'Release to fire immediately — letting go launches '
                          'your shot right away.',
              ),
              const SizedBox(height: 12),
              const _Step(
                number: 3,
                text:
                    'Hit the highlighted target country before the timer '
                    'runs out. Landing closer to the bullseye scores more '
                    'points.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Animated illustration ─────────────────────────────────────────────────────

/// Loops: pull back → hold (beginner: FIRE prompt) → release → arcing flight
/// to the target, then resets. Under reduce-motion, freezes on a single
/// representative pulled-back frame instead of looping.
class _TutorialIllustration extends StatefulWidget {
  const _TutorialIllustration({
    required this.beginnerMode,
    required this.reduceMotion,
  });

  final bool beginnerMode;
  final bool reduceMotion;

  @override
  State<_TutorialIllustration> createState() => _TutorialIllustrationState();
}

class _TutorialIllustrationState extends State<_TutorialIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.reduceMotion) {
      _ctrl.value = 0.2; // static mid-pull frame — depicts the mechanic, no motion
    } else {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _TutorialSlingshotPainter(
            t: _ctrl.value,
            beginnerMode: widget.beginnerMode,
          ),
        ),
      ),
    );
  }
}

class _TutorialSlingshotPainter extends CustomPainter {
  _TutorialSlingshotPainter({required this.t, required this.beginnerMode});

  final double t;
  final bool beginnerMode;

  static const _pullOffset = Offset(44, 32);
  static const _launchDir = Offset(-104, -74); // opposite of pull

  static double _pull(double t) {
    if (t < 0.35) return Curves.easeOut.transform(t / 0.35);
    if (t < 0.55) return 1.0;
    return 0.0;
  }

  static double _flight(double t) {
    if (t < 0.55) return 0.0;
    if (t < 0.92) return Curves.easeIn.transform((t - 0.55) / 0.37);
    return 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = Offset(size.width * 0.55, size.height * 0.62);
    final target = anchor + _launchDir;
    final pull = _pull(t);
    final flight = _flight(t);

    // Target marker (fixed).
    final flagPainter = TextPainter(
      text: const TextSpan(text: '🎯', style: TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    )..layout();
    flagPainter.paint(
      canvas,
      target - Offset(flagPainter.width / 2, flagPainter.height / 2),
    );

    // Anchor ring — the source country.
    canvas.drawCircle(
      anchor,
      14,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (pull > 0.01) {
      final dragPoint = anchor + _pullOffset * pull;
      canvas.drawLine(
        anchor,
        dragPoint,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            Colors.amber,
            pull,
          )!.withValues(alpha: 0.85)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        dragPoint,
        7,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );

      // Trajectory preview dots, toward the launch direction.
      final dotPaint = Paint()..color = Colors.amber.withValues(alpha: 0.8);
      for (var i = 1; i <= 4; i++) {
        final p = anchor + _launchDir * (pull * i / 6);
        canvas.drawCircle(p, 3, dotPaint);
      }
    }

    // Beginner-mode "FIRE" prompt during the hold window.
    if (beginnerMode && t >= 0.38 && t < 0.55) {
      final pulse = (0.5 + 0.5 * math.sin((t - 0.38) * 40)).clamp(0.0, 1.0);
      final firePainter = TextPainter(
        text: TextSpan(
          text: 'FIRE',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: 0.6 + 0.4 * pulse),
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      firePainter.paint(canvas, anchor + const Offset(-14, 40));
    }

    // Projectile flight — a small arc from anchor to target.
    if (flight > 0.0) {
      final lerp = Offset.lerp(anchor, target, flight)!;
      final bow = -math.sin(flight * math.pi) * 28;
      final projectile = lerp + Offset(0, bow);
      if (flight < 1.0) {
        canvas.drawCircle(
          projectile,
          12,
          Paint()..color = Colors.amber.withValues(alpha: 0.25),
        );
      }
      canvas.drawCircle(projectile, 8, Paint()..color = Colors.amber);
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialSlingshotPainter old) =>
      old.t != t || old.beginnerMode != beginnerMode;
}
