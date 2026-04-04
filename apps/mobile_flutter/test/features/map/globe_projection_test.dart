// M60 — GlobeProjection unit tests (ADR-116)
//
// These tests cover the pure-Dart projection math without Flutter widget infra.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/map/globe_projection.dart';

void main() {
  const size = Size(400, 400);
  const centre = Offset(200, 200);
  const radius = 200.0; // scale 1.0, shortestSide/2 = 200

  group('GlobeProjection — project', () {
    test('identity rotation: (0°,0°) projects to canvas centre', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      final pt = proj.project(0, 0, size);
      expect(pt, isNotNull);
      expect(pt!.dx, closeTo(centre.dx, 0.001));
      expect(pt.dy, closeTo(centre.dy, 0.001));
    });

    test('identity rotation: (0°,90°E) projects to right edge', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      final pt = proj.project(0, 90, size);
      expect(pt, isNotNull);
      expect(pt!.dx, closeTo(centre.dx + radius, 0.5));
      expect(pt.dy, closeTo(centre.dy, 0.5));
    });

    test('identity rotation: north pole (90°N) projects to top of globe', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      final pt = proj.project(90, 0, size);
      expect(pt, isNotNull);
      expect(pt!.dy, closeTo(centre.dy - radius, 0.5));
    });

    test('returns null for back-face point (0°, 180°) with identity rotation', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      // (0°, 180°) is directly behind the globe (z < 0).
      final pt = proj.project(0, 180, size);
      expect(pt, isNull);
    });

    test('scale=2 doubles the projected distance from centre', () {
      const proj1 = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      const proj2 = GlobeProjection(rotLat: 0, rotLng: 0, scale: 2.0);
      final pt1 = proj1.project(0, 45, size)!;
      final pt2 = proj2.project(0, 45, size)!;
      final d1 = (pt1 - centre).distance;
      final d2 = (pt2 - centre).distance;
      expect(d2, closeTo(d1 * 2, 0.5));
    });
  });

  group('GlobeProjection — isVisible', () {
    test('identity: (0°,0°) is visible', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0);
      expect(proj.isVisible(0, 0), isTrue);
    });

    test('identity: (0°,180°) is NOT visible (back face)', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0);
      expect(proj.isVisible(0, 180), isFalse);
    });

    test('identity: (0°,-180°) is also NOT visible', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0);
      expect(proj.isVisible(0, -180), isFalse);
    });
  });

  group('GlobeProjection — inverseProject', () {
    test('canvas centre inverse-projects to approximately (0°,0°) with identity', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      final result = proj.inverseProject(centre, size);
      expect(result, isNotNull);
      expect(result!.$1, closeTo(0, 1.0)); // lat
      expect(result.$2, closeTo(0, 1.0)); // lng
    });

    test('point outside globe circle returns null', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      // (0,0) is outside the globe circle centred at (200,200) with r=200.
      final result = proj.inverseProject(Offset.zero, size);
      expect(result, isNull);
    });

    test('bottom-right corner is outside globe circle', () {
      const proj = GlobeProjection(rotLat: 0, rotLng: 0, scale: 1.0);
      final result = proj.inverseProject(const Offset(399, 399), size);
      expect(result, isNull);
    });
  });

  group('GlobeProjection — splitAtAntimeridian', () {
    const proj = GlobeProjection();

    test('ring with no antimeridian crossing returns single-element list', () {
      final ring = [(0.0, -10.0), (10.0, 10.0), (0.0, 10.0)];
      final result = proj.splitAtAntimeridian(ring);
      expect(result.length, 1);
      expect(result.first, ring);
    });

    test('empty ring returns single-element list', () {
      final result = proj.splitAtAntimeridian([]);
      expect(result.length, 1);
    });

    test('ring crossing antimeridian produces two sub-rings', () {
      // Simplified USA-like ring that crosses ±180° (Alaska/Aleutian).
      final ring = [
        (60.0, 170.0),
        (60.0, -170.0), // crosses antimeridian here
        (55.0, -170.0),
        (55.0, 170.0),
      ];
      final result = proj.splitAtAntimeridian(ring);
      expect(result.length, 2);
      expect(result.every((r) => r.isNotEmpty), isTrue);
    });

    test('sub-rings from split have interpolated boundary vertices at ±180°', () {
      final ring = [
        (0.0, 170.0),
        (0.0, -170.0), // crosses antimeridian
        (10.0, -170.0),
        (10.0, 170.0),
      ];
      final result = proj.splitAtAntimeridian(ring);
      expect(result.length, 2);
      // Each sub-ring should contain a vertex at ±180° longitude.
      final allLngs = result.expand((r) => r).map((v) => v.$2).toList();
      expect(
        allLngs.any((lng) => (lng.abs() - 180).abs() < 0.001),
        isTrue,
        reason: 'Expected interpolated antimeridian vertex at ±180°',
      );
    });
  });

  group('GlobeProjection — copyWith', () {
    test('copyWith updates only specified fields', () {
      const proj = GlobeProjection(rotLat: 0.5, rotLng: 1.0, scale: 2.0);
      final updated = proj.copyWith(rotLng: 2.0);
      expect(updated.rotLat, closeTo(0.5, 0.001));
      expect(updated.rotLng, closeTo(2.0, 0.001));
      expect(updated.scale, closeTo(2.0, 0.001));
    });

    test('rotLat is clamped to [-π/2, π/2]', () {
      const proj = GlobeProjection();
      final updated = proj.copyWith(rotLat: math.pi);
      expect(updated.rotLat, closeTo(math.pi / 2, 0.001));
    });

    test('scale is clamped to [0.8, 8.0]', () {
      const proj = GlobeProjection();
      expect(proj.copyWith(scale: 0.1).scale, closeTo(0.8, 0.001));
      expect(proj.copyWith(scale: 100.0).scale, closeTo(8.0, 0.001));
    });
  });
}
