import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/heritage/unesco_nearby_service.dart';
import 'package:mobile_flutter/features/heritage/world_heritage_lookup_service.dart';

/// Minimal JSON that initialises the lookup service for unit tests.
///
/// Sites:
///   A  — (0.000, 0.000) — exactly at origin
///   B  — (0.100, 0.000) — ~11.1 km north  (siteId "B")
///   B2 — (0.090, 0.000) — ~10.0 km north, same siteId "B" → transboundary
///          twin; should win deduplication as it is closer to origin
///   C  — (5.000, 5.000) — ~789 km from origin
const _testJson = '''
[
  {
    "siteId": "A",
    "name": "Site A",
    "countryCode": "XX",
    "latitude": 0.0,
    "longitude": 0.0,
    "category": "cultural",
    "region": "Test Region",
    "inscriptionYear": 2000
  },
  {
    "siteId": "B",
    "name": "Site B",
    "countryCode": "XX",
    "latitude": 0.1,
    "longitude": 0.0,
    "category": "natural",
    "region": "Test Region",
    "inscriptionYear": 2001
  },
  {
    "siteId": "B",
    "name": "Site B (twin)",
    "countryCode": "YY",
    "latitude": 0.09,
    "longitude": 0.0,
    "category": "natural",
    "region": "Test Region",
    "inscriptionYear": 2001
  },
  {
    "siteId": "C",
    "name": "Site C",
    "countryCode": "ZZ",
    "latitude": 5.0,
    "longitude": 5.0,
    "category": "mixed",
    "region": "Test Region",
    "inscriptionYear": 2005
  }
]
''';

double _haversineKm(
    double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

void main() {
  setUpAll(() {
    WorldHeritageLookupService.init(_testJson);
  });

  const service = UnescoNearbyService();

  group('UnescoNearbyService.sitesWithin', () {
    test('returns only site A when radius is 5 km from origin', () {
      // A is at origin (0 km); B is ~10–11 km away; C is ~789 km away.
      final results = service.sitesWithin(0, 0, 5, {});
      expect(results.map((r) => r.site.siteId), equals(['A']));
    });

    test('returns A and B (deduped) within 100 km, sorted nearest first', () {
      final results = service.sitesWithin(0, 0, 100, {});
      expect(results.length, 2);
      expect(results[0].site.siteId, 'A');
      expect(results[1].site.siteId, 'B');
    });

    test('includes site C only when radius covers ~789 km', () {
      final results = service.sitesWithin(0, 0, 1000, {});
      final ids = results.map((r) => r.site.siteId).toList();
      expect(ids, contains('C'));
    });

    test('deduplicates transboundary sites — keeps nearest entry', () {
      // siteId "B" has two entries: lat 0.100 and lat 0.090 (closer).
      final results = service.sitesWithin(0, 0, 100, {});
      final bResults = results.where((r) => r.site.siteId == 'B').toList();
      expect(bResults.length, 1);
      // The kept entry should be closer than the (0.100, 0) one.
      final distToFar = _haversineKm(0, 0, 0.1, 0);
      expect(bResults[0].distanceKm, lessThan(distToFar));
    });

    test('marks sites as visited when siteId in visitedIds', () {
      final results = service.sitesWithin(0, 0, 100, {'A'});
      final a = results.firstWhere((r) => r.site.siteId == 'A');
      final b = results.firstWhere((r) => r.site.siteId == 'B');
      expect(a.isVisited, isTrue);
      expect(b.isVisited, isFalse);
    });

    test('visited flag does not filter sites out', () {
      // Both sites are within radius; visited flag should not exclude them.
      final results = service.sitesWithin(0, 0, 100, {'A', 'B'});
      expect(results.length, 2);
    });

    test('results are sorted by distanceKm ascending', () {
      final results = service.sitesWithin(0, 0, 1000, {});
      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].distanceKm,
            lessThanOrEqualTo(results[i + 1].distanceKm));
      }
    });

    test('distanceKm is non-negative', () {
      final results = service.sitesWithin(0, 0, 1000, {});
      for (final r in results) {
        expect(r.distanceKm, greaterThanOrEqualTo(0));
      }
    });

    test('bearingLabel is one of the 8-point compass points', () {
      const valid = {
        'North',
        'North-East',
        'East',
        'South-East',
        'South',
        'South-West',
        'West',
        'North-West',
      };
      final results = service.sitesWithin(0, 0, 1000, {});
      for (final r in results) {
        expect(valid, contains(r.bearingLabel));
      }
    });

    test('walk/cycle/drive time strings are non-empty', () {
      final results = service.sitesWithin(0, 0, 1000, {});
      for (final r in results) {
        expect(r.walkTime, isNotEmpty);
        expect(r.cycleTime, isNotEmpty);
        expect(r.driveTime, isNotEmpty);
      }
    });

    test('site exactly at user location is within any radius including 0', () {
      // Site A is at (0, 0), same as user — distance 0 km, not > 0, so included.
      final results = service.sitesWithin(0, 0, 0, {});
      expect(results.map((r) => r.site.siteId), contains('A'));
    });
  });
}
