import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';

void main() {
  final geo = WorldLeapGeoService();

  group('destinationPoint', () {
    test('due north from equator', () {
      // From (0, 0) bearing north 1111.95 km ≈ 10° of latitude
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: 0,
        bearingDeg: 0,
        distanceKm: 1111.95,
      );
      expect(dest.lat, closeTo(10.0, 0.1));
      expect(dest.lon, closeTo(0.0, 0.01));
    });

    test('due east from equator wraps longitude correctly', () {
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: 0,
        bearingDeg: 90,
        distanceKm: 1111.95,
      );
      expect(dest.lat, closeTo(0.0, 0.1));
      expect(dest.lon, closeTo(10.0, 0.1));
    });

    test('due south from equator', () {
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: 0,
        bearingDeg: 180,
        distanceKm: 1111.95,
      );
      expect(dest.lat, closeTo(-10.0, 0.1));
      expect(dest.lon, closeTo(0.0, 0.01));
    });

    test('due west from prime meridian', () {
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: 0,
        bearingDeg: 270,
        distanceKm: 1111.95,
      );
      expect(dest.lat, closeTo(0.0, 0.1));
      expect(dest.lon, closeTo(-10.0, 0.1));
    });

    test('lon wraps past 180', () {
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: 175,
        bearingDeg: 90,
        distanceKm: 1111.95,
      );
      expect(dest.lon, lessThanOrEqualTo(180.0));
      expect(dest.lon, greaterThanOrEqualTo(-180.0));
    });

    test('lon wraps past -180', () {
      final dest = geo.destinationPoint(
        startLat: 0,
        startLon: -175,
        bearingDeg: 270,
        distanceKm: 1111.95,
      );
      expect(dest.lon, lessThanOrEqualTo(180.0));
      expect(dest.lon, greaterThanOrEqualTo(-180.0));
    });

    test('zero distance returns start point', () {
      final dest = geo.destinationPoint(
        startLat: 48.8566,
        startLon: 2.3522,
        bearingDeg: 45,
        distanceKm: 0,
      );
      expect(dest.lat, closeTo(48.8566, 0.001));
      expect(dest.lon, closeTo(2.3522, 0.001));
    });

    test('real-world: Sydney bearing north 5000 km lands near Philippines', () {
      final dest = geo.destinationPoint(
        startLat: -33.87,
        startLon: 151.21,
        bearingDeg: 0,
        distanceKm: 5000,
      );
      expect(dest.lat, closeTo(11.1, 1.0));
      expect(dest.lon, closeTo(151.21, 1.0));
    });
  });

  group('greatCircleDistanceKm', () {
    test('same point returns 0', () {
      final d = geo.greatCircleDistanceKm(
        lat1: 51.5, lon1: -0.1, lat2: 51.5, lon2: -0.1,
      );
      expect(d, closeTo(0.0, 0.01));
    });

    test('London to Paris ≈ 340 km', () {
      final d = geo.greatCircleDistanceKm(
        lat1: 51.5074, lon1: -0.1278,
        lat2: 48.8566, lon2: 2.3522,
      );
      expect(d, closeTo(340, 10));
    });

    test('London to New York ≈ 5570 km', () {
      final d = geo.greatCircleDistanceKm(
        lat1: 51.5074, lon1: -0.1278,
        lat2: 40.7128, lon2: -74.0060,
      );
      expect(d, closeTo(5570, 50));
    });

    test('Sydney to London ≈ 16993 km', () {
      final d = geo.greatCircleDistanceKm(
        lat1: -33.87, lon1: 151.21,
        lat2: 51.51, lon2: -0.13,
      );
      expect(d, closeTo(16993, 100));
    });

    test('anti-meridian crossing: Fiji to Samoa', () {
      final d = geo.greatCircleDistanceKm(
        lat1: -18.17, lon1: 178.44,
        lat2: -13.76, lon2: -172.10,
      );
      expect(d, closeTo(1100, 100));
    });
  });

  group('trajectoryPoints', () {
    test('returns exactly count points', () {
      final pts = geo.trajectoryPoints(
        fromLat: 0, fromLon: 0,
        bearingDeg: 0,
        distanceKm: 1000,
        count: 10,
      );
      expect(pts.length, 10);
    });

    test('last point equals destinationPoint', () {
      final dest = geo.destinationPoint(
        startLat: 0, startLon: 0,
        bearingDeg: 45,
        distanceKm: 5000,
      );
      final pts = geo.trajectoryPoints(
        fromLat: 0, fromLon: 0,
        bearingDeg: 45,
        distanceKm: 5000,
        count: 20,
      );
      expect(pts.last.lat, closeTo(dest.lat, 0.001));
      expect(pts.last.lon, closeTo(dest.lon, 0.001));
    });

    test('first point is partway along the arc', () {
      final pts = geo.trajectoryPoints(
        fromLat: 0, fromLon: 0,
        bearingDeg: 0,
        distanceKm: 1000,
        count: 5,
      );
      // First point is at 200 km ≈ 1.8° lat
      expect(pts.first.lat, closeTo(1.8, 0.2));
    });

    test('points are monotonically increasing distance from start (north bearing)', () {
      final pts = geo.trajectoryPoints(
        fromLat: 0, fromLon: 0,
        bearingDeg: 0,
        distanceKm: 2000,
        count: 10,
      );
      for (int i = 1; i < pts.length; i++) {
        expect(pts[i].lat, greaterThan(pts[i - 1].lat));
      }
    });

    test('count 1 returns single destination point', () {
      final dest = geo.destinationPoint(
        startLat: 10, startLon: 20,
        bearingDeg: 90,
        distanceKm: 3000,
      );
      final pts = geo.trajectoryPoints(
        fromLat: 10, fromLon: 20,
        bearingDeg: 90,
        distanceKm: 3000,
        count: 1,
      );
      expect(pts.length, 1);
      expect(pts.first.lat, closeTo(dest.lat, 0.001));
      expect(pts.first.lon, closeTo(dest.lon, 0.001));
    });
  });

  group('initialBearingDeg', () {
    test('bearing from equator point due east is 90°', () {
      final b = geo.initialBearingDeg(
        lat1: 0, lon1: 0, lat2: 0, lon2: 10,
      );
      expect(b, closeTo(90.0, 1.0));
    });

    test('bearing from equator point due north is 0°', () {
      final b = geo.initialBearingDeg(
        lat1: 0, lon1: 0, lat2: 10, lon2: 0,
      );
      expect(b, closeTo(0.0, 1.0));
    });

    test('bearing from London to New York is roughly west (270° range)', () {
      final b = geo.initialBearingDeg(
        lat1: 51.5, lon1: -0.1,
        lat2: 40.7, lon2: -74.0,
      );
      // Great circle from London to NYC heads west-northwest
      expect(b, greaterThan(250));
      expect(b, lessThan(295));
    });
  });
}
