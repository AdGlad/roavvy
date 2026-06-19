import 'dart:math';

import 'package:flutter/material.dart';

// ── Starfield ─────────────────────────────────────────────────────────────────

class _StarData {
  const _StarData(this.x, this.y, this.size, this.opacity);
  final double x, y, size, opacity;
}

// Generated once at startup — seeded so layout is deterministic.
final _kStars = _buildStars(320, seed: 0xC0FFEE);

List<_StarData> _buildStars(int count, {required int seed}) {
  final rng = Random(seed);
  return List.generate(count, (_) {
    // Weight toward small stars (realistic distribution).
    final isBright = rng.nextDouble() < 0.12;
    return _StarData(
      rng.nextDouble(),
      rng.nextDouble(),
      isBright ? 1.0 + rng.nextDouble() * 1.2 : 0.3 + rng.nextDouble() * 0.7,
      isBright ? 0.6 + rng.nextDouble() * 0.4 : 0.25 + rng.nextDouble() * 0.55,
    );
  });
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF030D1A),
    );
    final paint = Paint();
    for (final s in _kStars) {
      paint.color = Color.fromRGBO(255, 252, 238, s.opacity);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter _) => false;
}

/// Full-screen deep-space starfield. Place as the first child in a [Stack].
/// Uses [RepaintBoundary] so it never triggers repaints of siblings.
class StarfieldBackground extends StatelessWidget {
  const StarfieldBackground({super.key});

  static const _painter = _StarfieldPainter();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _painter,
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Aurora ────────────────────────────────────────────────────────────────────

// Each band: (relY centre, relH height, color, peak alpha, phase offset rad)
const _kAuroraBands = [
  // Northern lights — top of screen (Arctic latitudes on the map)
  (0.055, 0.16, Color(0xFF00E5CC), 0.14, 0.0),   // teal
  (0.090, 0.13, Color(0xFF00C853), 0.10, 1.3),   // emerald green
  (0.045, 0.09, Color(0xFF651FFF), 0.07, 2.6),   // violet
  // Southern lights — bottom of screen (Antarctic latitudes)
  (0.945, 0.14, Color(0xFF00BFA5), 0.09, 0.7),   // cyan-teal
  (0.965, 0.09, Color(0xFF00897B), 0.06, 2.0),   // deep teal
];

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.t);
  final double t; // 0–1 animation phase

  @override
  void paint(Canvas canvas, Size sz) {
    for (final (relY, relH, color, maxA, phase) in _kAuroraBands) {
      // Gentle vertical drift driven by a slow sine wave.
      final yc =
          sz.height * relY + sin(t * pi * 2 + phase) * sz.height * 0.012;
      final bh = sz.height * relH;
      final rect = Rect.fromLTWH(0, yc - bh / 2, sz.width, bh);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: maxA),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Animated aurora borealis + australis overlay.
///
/// Renders horizontal gradient bands at the top (Arctic) and bottom
/// (Antarctic) of the screen at very low opacity. Wrap in [IgnorePointer]
/// is included — does not intercept touches.
///
/// Cycle duration: 16 s. [RepaintBoundary] isolates repaints from siblings.
class AuroraOverlay extends StatefulWidget {
  const AuroraOverlay({super.key});

  @override
  State<AuroraOverlay> createState() => _AuroraOverlayState();
}

class _AuroraOverlayState extends State<AuroraOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _AuroraPainter(_ctrl.value),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
