import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Applies sub-pixel geometric imperfection to stamp shapes (ADR-097 Decision 2).
///
/// Real rubber stamps are not mathematically perfect — circles have slight
/// vertex wobble, rectangles have varying corner radii. This class simulates
/// that imperfection deterministically from a seed.
///
/// No external packages; uses only [dart:math].
class StampShapeDistorter {
  StampShapeDistorter._();

  static const int _kCirclePoints = 72;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns a 72-point polygon [Path] approximating a circle with vertex jitter.
  ///
  /// Each vertex is offset radially by `±[distortion] * [radius]` where
  /// distortion is sampled from [Random(seed)] in range [0.005, 0.025].
  /// Same [seed] → same path on all calls.
  static Path distortedCircle(Offset centre, double radius, int seed) {
    final rng = math.Random(seed ^ 0xC1C1);
    final path = Path();

    for (var i = 0; i < _kCirclePoints; i++) {
      final angle = 2 * math.pi * i / _kCirclePoints;
      final distortion = 0.005 + rng.nextDouble() * 0.020; // [0.005, 0.025]
      final offset = (rng.nextBool() ? 1 : -1) * distortion * radius;
      final r = radius + offset;

      final x = centre.dx + r * math.cos(angle);
      final y = centre.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Returns an [RRect] with corner radius and border width varied by [seed].
  ///
  /// Each corner radius is independently varied by ±1–2px.
  /// The returned [RRect] represents the outer boundary; callers can use
  /// the same seed offset for an inner boundary to simulate double-border.
  static RRect distortedRect(Rect bounds, double nominalCornerRadius, int seed) {
    final rng = math.Random(seed ^ 0xDECF);

    // Each corner varied independently by ±1–2px
    final tl = (nominalCornerRadius + (rng.nextDouble() * 4 - 2)).clamp(0.0, nominalCornerRadius * 2);
    final tr = (nominalCornerRadius + (rng.nextDouble() * 4 - 2)).clamp(0.0, nominalCornerRadius * 2);
    final bl = (nominalCornerRadius + (rng.nextDouble() * 4 - 2)).clamp(0.0, nominalCornerRadius * 2);
    final br = (nominalCornerRadius + (rng.nextDouble() * 4 - 2)).clamp(0.0, nominalCornerRadius * 2);

    return RRect.fromRectAndCorners(
      bounds,
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomLeft: Radius.circular(bl),
      bottomRight: Radius.circular(br),
    );
  }

  /// Returns a border stroke width varied by ±15% from [nominalWidth].
  ///
  /// Different sides of a rectangle use offsets [0–3] to each get an
  /// independent variation.
  static double distortedBorderWidth(
    double nominalWidth,
    int seed,
    int sideIndex,
  ) {
    final rng = math.Random(seed ^ (0xBD00 + sideIndex));
    final variation = (rng.nextDouble() * 2 - 1) * 0.15; // ±15%
    return (nominalWidth * (1 + variation)).clamp(0.5, nominalWidth * 2);
  }

  /// Returns a [Path] with each vertex in [vertices] independently jittered
  /// by up to ±[jitter] pixels.
  ///
  /// Simulates rubber stamp pressure imperfection on polygon shapes.
  /// Same [seed] → same result on all calls.
  static Path distortedPolygon(
      List<Offset> vertices, int seed, double jitter) {
    final rng = math.Random(seed ^ 0xF1F1);
    final path = Path();
    for (var i = 0; i < vertices.length; i++) {
      final jx = (rng.nextDouble() * 2 - 1) * jitter;
      final jy = (rng.nextDouble() * 2 - 1) * jitter;
      final p = vertices[i] + Offset(jx, jy);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }
}
