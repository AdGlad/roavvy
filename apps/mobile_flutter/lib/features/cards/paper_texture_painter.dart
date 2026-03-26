import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CustomPainter that draws a clean white passport page background.
///
/// Layers (bottom to top):
/// 1. Pure white base fill
/// 2. Faint grey micro-grain for paper feel (barely visible)
///
/// White background works optimally with [BlendMode.multiply] stamp
/// compositing — multiply on white leaves stamp ink colour unmodified
/// (ADR-097 Decision 9).
///
/// Static — [shouldRepaint] always returns false (ADR-096).
class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter();

  static const _kBase = Color(0xFFFFFFFF);
  static const _kGrainCount = 600;
  static const _kGrainSeed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. White base fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kBase,
    );

    // 2. Very subtle grain — barely perceptible on white
    final rng = math.Random(_kGrainSeed);
    for (var i = 0; i < _kGrainCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 1.0 + rng.nextDouble();
      final h = 1.0 + rng.nextDouble();
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()
          ..color = const Color.fromARGB(10, 180, 180, 180),
      );
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter _) => false;
}
