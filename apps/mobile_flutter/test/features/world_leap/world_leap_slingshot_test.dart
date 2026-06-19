import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/slingshot_widget.dart';

void main() {
  group('computeBearing', () {
    test('drag straight up (north) → 0°', () {
      expect(computeBearing(0, -100), closeTo(0.0, 0.01));
    });

    test('drag straight right (east) → 90°', () {
      expect(computeBearing(100, 0), closeTo(90.0, 0.01));
    });

    test('drag straight down (south) → 180°', () {
      expect(computeBearing(0, 100), closeTo(180.0, 0.01));
    });

    test('drag straight left (west) → 270°', () {
      expect(computeBearing(-100, 0), closeTo(270.0, 0.01));
    });

    test('drag upper-right (northeast) → 45°', () {
      expect(computeBearing(100, -100), closeTo(45.0, 0.5));
    });

    test('drag lower-right (southeast) → 135°', () {
      expect(computeBearing(100, 100), closeTo(135.0, 0.5));
    });

    test('drag lower-left (southwest) → 225°', () {
      expect(computeBearing(-100, 100), closeTo(225.0, 0.5));
    });

    test('drag upper-left (northwest) → 315°', () {
      expect(computeBearing(-100, -100), closeTo(315.0, 0.5));
    });

    test('result is always in [0, 360)', () {
      for (final angle in List.generate(36, (i) => i * 10.0)) {
        final rad = angle * math.pi / 180;
        final dx = math.sin(rad) * 100;
        final dy = -math.cos(rad) * 100;
        final bearing = computeBearing(dx, dy);
        expect(bearing, greaterThanOrEqualTo(0));
        expect(bearing, lessThan(360));
      }
    });
  });

  group('computePower', () {
    test('zero drag → 0.0', () {
      expect(computePower(0, 0, 200), closeTo(0.0, 0.001));
    });

    test('drag equal to maxPixels → 1.0', () {
      expect(computePower(200, 0, 200), closeTo(1.0, 0.001));
    });

    test('drag beyond maxPixels → clamped to 1.0', () {
      expect(computePower(400, 0, 200), closeTo(1.0, 0.001));
    });

    test('drag = half maxPixels → 0.5', () {
      expect(computePower(100, 0, 200), closeTo(0.5, 0.001));
    });

    test('diagonal drag uses euclidean distance', () {
      // 3-4-5 triangle: dx=60, dy=80 → distance=100, maxPixels=200
      expect(computePower(60, 80, 200), closeTo(0.5, 0.001));
    });

    test('negative maxPixels → 0.0', () {
      expect(computePower(100, 0, -1), closeTo(0.0, 0.001));
    });

    test('power is never negative', () {
      expect(computePower(0, 0, 200), greaterThanOrEqualTo(0.0));
    });
  });

  group('computeTrajectoryDots', () {
    const anchor = Offset(200, 400);

    test('zero delta → empty list', () {
      final dots = computeTrajectoryDots(
        anchor: anchor, dx: 0, dy: 0,
        count: 10, maxDragPixels: 200,
      );
      expect(dots, isEmpty);
    });

    test('returns exactly count dots', () {
      final dots = computeTrajectoryDots(
        anchor: anchor, dx: 100, dy: 0,
        count: 20, maxDragPixels: 200,
      );
      expect(dots.length, 20);
    });

    test('last dot ends at anchor + delta when delta <= maxDragPixels', () {
      final dots = computeTrajectoryDots(
        anchor: anchor, dx: 80, dy: 0,
        count: 10, maxDragPixels: 200,
      );
      expect(dots.last.dx, closeTo(anchor.dx + 80, 0.01));
      expect(dots.last.dy, closeTo(anchor.dy, 0.01));
    });

    test('first dot is 1/count fraction along the delta', () {
      final dots = computeTrajectoryDots(
        anchor: anchor, dx: 100, dy: 0,
        count: 5, maxDragPixels: 200,
      );
      expect(dots.first.dx, closeTo(anchor.dx + 20, 0.01));
    });

    test('dots use raw dx/dy fractions regardless of maxDragPixels', () {
      // maxDragPixels only gates the zero-check; dot positions use raw dx/dy.
      // dx=400 > maxDragPixels=200 — still returns count dots using raw delta.
      final dots = computeTrajectoryDots(
        anchor: anchor, dx: 400, dy: 0,
        count: 10, maxDragPixels: 200,
      );
      expect(dots.length, 10);
      // last dot is at anchor + full dx
      expect(dots.last.dx, closeTo(anchor.dx + 400, 0.01));
    });
  });
}
