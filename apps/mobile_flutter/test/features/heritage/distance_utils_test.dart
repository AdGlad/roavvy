import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/heritage/distance_utils.dart';

void main() {
  group('DistanceUtils.haversineKm', () {
    test('returns 0 for identical points', () {
      expect(DistanceUtils.haversineKm(51.5, -0.1, 51.5, -0.1), 0.0);
    });

    test('London to Paris is ~341 km', () {
      final km =
          DistanceUtils.haversineKm(51.5074, -0.1278, 48.8566, 2.3522);
      expect(km, closeTo(341, 5));
    });

    test('Sydney to Melbourne is ~714 km', () {
      final km =
          DistanceUtils.haversineKm(-33.8688, 151.2093, -37.8136, 144.9631);
      expect(km, closeTo(714, 10));
    });

    test('short distance (1 km) is accurate', () {
      // ~1 km north of equator (0°, 0°) to (0.009°, 0°) ≈ 1.0 km
      final km = DistanceUtils.haversineKm(0.0, 0.0, 0.009, 0.0);
      expect(km, closeTo(1.0, 0.05));
    });
  });

  group('DistanceUtils.bearingDeg', () {
    test('north: (0,0) to (1,0) is 0°', () {
      expect(DistanceUtils.bearingDeg(0, 0, 1, 0), closeTo(0, 0.5));
    });

    test('east: (0,0) to (0,1) is ~90°', () {
      expect(DistanceUtils.bearingDeg(0, 0, 0, 1), closeTo(90, 1));
    });

    test('south: (1,0) to (0,0) is ~180°', () {
      expect(DistanceUtils.bearingDeg(1, 0, 0, 0), closeTo(180, 1));
    });

    test('west: (0,1) to (0,0) is ~270°', () {
      expect(DistanceUtils.bearingDeg(0, 1, 0, 0), closeTo(270, 1));
    });

    test('result is always in [0, 360)', () {
      for (final pair in [
        [10.0, 20.0, -10.0, -20.0],
        [-33.0, 151.0, 51.0, -0.1],
      ]) {
        final b = DistanceUtils.bearingDeg(pair[0], pair[1], pair[2], pair[3]);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThan(360));
      }
    });
  });

  group('DistanceUtils.bearingLabel', () {
    test('0° is North', () => expect(DistanceUtils.bearingLabel(0), 'North'));
    test('45° is North-East',
        () => expect(DistanceUtils.bearingLabel(45), 'North-East'));
    test('90° is East', () => expect(DistanceUtils.bearingLabel(90), 'East'));
    test('135° is South-East',
        () => expect(DistanceUtils.bearingLabel(135), 'South-East'));
    test('180° is South',
        () => expect(DistanceUtils.bearingLabel(180), 'South'));
    test('225° is South-West',
        () => expect(DistanceUtils.bearingLabel(225), 'South-West'));
    test('270° is West', () => expect(DistanceUtils.bearingLabel(270), 'West'));
    test('315° is North-West',
        () => expect(DistanceUtils.bearingLabel(315), 'North-West'));
    test('359° is North',
        () => expect(DistanceUtils.bearingLabel(359), 'North'));
  });

  group('DistanceUtils.travelTime', () {
    test('5 km at 5 km/h = 1 h (exactly 60 min rounds to hours)', () {
      expect(DistanceUtils.travelTime(5, 5), '1 h');
    });

    test('2.5 km at 5 km/h = 30 min', () {
      expect(DistanceUtils.travelTime(2.5, 5), '30 min');
    });

    test('100 km at 50 km/h = 2 h', () {
      expect(DistanceUtils.travelTime(100, 50), '2 h');
    });

    test('110 km at 50 km/h = 2 h 12 min', () {
      expect(DistanceUtils.travelTime(110, 50), '2 h 12 min');
    });

    test('0 km is 0 min', () {
      expect(DistanceUtils.travelTime(0, 50), '0 min');
    });

    test('zero speed returns em-dash', () {
      expect(DistanceUtils.travelTime(10, 0), '—');
    });

    test('negative speed returns em-dash', () {
      expect(DistanceUtils.travelTime(10, -5), '—');
    });
  });
}
