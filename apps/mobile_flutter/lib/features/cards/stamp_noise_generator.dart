import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Procedural ink noise for passport stamp realism (ADR-097 Decision 1).
///
/// All effects are deterministic — same [seed] produces the same noise.
/// Uses a blotchy cluster approach: a base radial fade plus scattered ink-wear
/// spots, giving a more authentic worn-stamp appearance than a smooth gradient.
class StampNoiseGenerator {
  StampNoiseGenerator._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Apply a blotchy ink-wear opacity mask to the current canvas layer.
  ///
  /// Uses [BlendMode.dstIn] to vary the alpha of whatever was drawn before
  /// this call. Should be called after all geometry for a single stamp has
  /// been drawn onto an offscreen canvas.
  ///
  /// [bounds] — the stamp bounding box in the offscreen canvas coordinate space.
  /// [intensity] — scaled from [StampAgeEffect.noiseIntensity]; 0=min, 1.4=max.
  static void applyNoiseMask(
    Canvas canvas,
    Rect bounds,
    int seed, {
    double intensity = 1.0,
  }) {
    final rng = math.Random(seed ^ 0xCAFE);
    final centre = bounds.center;
    final shortSide = bounds.shortestSide;

    // 1. Base radial fade: strong centre opacity, lighter at edges
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: const [
            Color(0xF0FFFFFF), // 0.94 at centre
            Color(0xC4FFFFFF), // 0.77 at edge
          ],
          stops: const [0.45, 1.0],
        ).createShader(
            Rect.fromCircle(center: centre, radius: shortSide * 0.6)),
    );

    // 2. Blotchy wear spots: ink-void circles scattered across the stamp.
    //    Each spot is transparent at its core and fades to opaque at its edge,
    //    simulating areas where the ink has lifted off the page.
    final spotCount = (3 + rng.nextInt(4)).clamp(0, 6);
    for (var i = 0; i < spotCount; i++) {
      final x = bounds.left + rng.nextDouble() * bounds.width;
      final y = bounds.top + rng.nextDouble() * bounds.height;
      final spotR = shortSide * (0.07 + rng.nextDouble() * 0.13 * intensity);
      final voidDepth =
          ((0.25 + rng.nextDouble() * 0.45) * intensity).clamp(0.0, 0.85);

      // Transparent at centre → fully opaque at edge (BlendMode.dstIn removes
      // ink where the source alpha is low)
      canvas.drawCircle(
        Offset(x, y),
        spotR,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = RadialGradient(
            colors: [
              Color.fromARGB(
                  (voidDepth * 0.2 * 255).round().clamp(0, 255), 255, 255, 255),
              const Color(0xFFFFFFFF),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: spotR)),
      );
    }
  }

  /// Recommended MaskFilter blur sigma for ink bleed simulation.
  ///
  /// Returns a value in [1.0, 3.0] based on [seed].
  static double bleedSigma(int seed) {
    final rng = math.Random(seed ^ 0xBEEF);
    return 1.0 + rng.nextDouble() * 2.0;
  }
}
