import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CustomPainter that draws a procedural parchment background.
///
/// Layers (bottom to top):
/// 1. Warm parchment base fill (0xFFF5ECD7)
/// 2. ~1000 seeded micro-rects for paper grain
/// 3. Two faint horizontal fold lines at 30% and 70% canvas height
/// 4. Radial gradient darkening in all four corners (aging effect)
///
/// Static — [shouldRepaint] always returns false (ADR-096).
class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter();

  static const _kBase = Color(0xFFF5ECD7);
  static const _kGrainCount = 1000;
  static const _kGrainSeed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kBase,
    );

    // 2. Grain
    final rng = math.Random(_kGrainSeed);
    for (var i = 0; i < _kGrainCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 1.0 + rng.nextDouble();
      final h = 1.0 + rng.nextDouble();
      // ±8 lightness variation — shift r/g/b slightly
      final delta = (rng.nextInt(17) - 8);
      final grainColor = Color.fromARGB(
        30,
        (0xF5 + delta).clamp(0, 255),
        (0xEC + delta).clamp(0, 255),
        (0xD7 + delta).clamp(0, 255),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = grainColor,
      );
    }

    // 3. Fold lines at 30% and 70%
    final foldPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 0.3;
    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.30),
      foldPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.70),
      foldPaint,
    );

    // 4. Corner aging: radial gradient, 20% of smallest dimension radius
    final cornerRadius = math.min(size.width, size.height) * 0.20;
    final cornerPositions = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    for (final pos in cornerPositions) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              (pos.dx / size.width) * 2 - 1,
              (pos.dy / size.height) * 2 - 1,
            ),
            radius: cornerRadius / math.min(size.width, size.height),
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter _) => false;
}
