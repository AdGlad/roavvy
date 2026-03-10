import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/scan/scan_mapper.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  final now = DateTime.utc(2025, 3, 10, 12, 0, 0);

  List<CountryVisit> map(List<DetectedCountry> detected) =>
      toCountryVisits(detected, now: now);

  group('toCountryVisits', () {
    test('empty input produces empty output', () {
      expect(map([]), isEmpty);
    });

    test('maps country code correctly', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'GB', 'name': 'United Kingdom', 'photoCount': 10}),
      ]);
      expect(result.single.countryCode, 'GB');
    });

    test('source is always auto', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'JP', 'name': 'Japan', 'photoCount': 5}),
      ]);
      expect(result.single.source, VisitSource.auto);
    });

    test('updatedAt is set to the provided now timestamp', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'FR', 'name': 'France', 'photoCount': 3}),
      ]);
      expect(result.single.updatedAt, now);
    });

    test('firstSeen and lastSeen are null (spike limitation)', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'DE', 'name': 'Germany', 'photoCount': 7}),
      ]);
      expect(result.single.firstSeen, isNull);
      expect(result.single.lastSeen, isNull);
    });

    test('isDeleted defaults to false — visits are active', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'US', 'name': 'United States', 'photoCount': 20}),
      ]);
      expect(result.single.isDeleted, isFalse);
      expect(result.single.isActive, isTrue);
    });

    test('multiple countries produce one CountryVisit each', () {
      final result = map([
        DetectedCountry.fromMap({'code': 'GB', 'name': 'United Kingdom', 'photoCount': 10}),
        DetectedCountry.fromMap({'code': 'JP', 'name': 'Japan', 'photoCount': 5}),
        DetectedCountry.fromMap({'code': 'US', 'name': 'United States', 'photoCount': 3}),
      ]);
      expect(result.length, 3);
      expect(result.map((v) => v.countryCode).toSet(), {'GB', 'JP', 'US'});
    });

    test('output feeds into effectiveVisits without loss', () {
      final detected = [
        DetectedCountry.fromMap({'code': 'GB', 'name': 'United Kingdom', 'photoCount': 10}),
        DetectedCountry.fromMap({'code': 'JP', 'name': 'Japan', 'photoCount': 5}),
      ];
      final visits = map(detected);
      final effective = effectiveVisits(visits);
      // all auto visits with no manual overrides — all should be active
      expect(effective.length, 2);
      expect(effective.map((v) => v.countryCode).toSet(), {'GB', 'JP'});
    });

    test('manual tombstone in existing visits suppresses auto from scan', () {
      // Simulates: user previously removed GB; a new scan detects GB again.
      // The tombstone must win.
      final fromScan = map([
        DetectedCountry.fromMap({'code': 'GB', 'name': 'United Kingdom', 'photoCount': 10}),
        DetectedCountry.fromMap({'code': 'JP', 'name': 'Japan', 'photoCount': 5}),
      ]);
      final manualTombstone = CountryVisit(
        countryCode: 'GB',
        source: VisitSource.manual,
        isDeleted: true,
        updatedAt: now,
      );
      final effective = effectiveVisits([...fromScan, manualTombstone]);
      final codes = effective.map((v) => v.countryCode).toSet();
      expect(codes, {'JP'});
      expect(codes.contains('GB'), isFalse);
    });

    test('TravelSummary built from mapped visits has correct country count', () {
      final visits = map([
        DetectedCountry.fromMap({'code': 'GB', 'name': 'United Kingdom', 'photoCount': 10}),
        DetectedCountry.fromMap({'code': 'JP', 'name': 'Japan', 'photoCount': 5}),
        DetectedCountry.fromMap({'code': 'US', 'name': 'United States', 'photoCount': 3}),
      ]);
      final summary = TravelSummary.fromVisits(effectiveVisits(visits), now: now);
      expect(summary.countryCount, 3);
      expect(summary.visitedCodes, ['GB', 'JP', 'US']);
      expect(summary.earliestVisit, isNull); // spike limitation — no dates yet
    });
  });
}
