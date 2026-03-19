import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

PhotoDateRecord _rec(String code, DateTime capturedAt, {String? regionCode}) =>
    PhotoDateRecord(countryCode: code, capturedAt: capturedAt, regionCode: regionCode);

DateTime _d(int year, int month, int day) => DateTime.utc(year, month, day);

void main() {
  // ── Edge cases ───────────────────────────────────────────────────────────

  test('empty input returns empty list', () {
    expect(inferTrips([]), isEmpty);
  });

  test('single photo produces one trip', () {
    final trips = inferTrips([_rec('FR', _d(2023, 7, 14))]);
    expect(trips, hasLength(1));
    expect(trips.first.countryCode, 'FR');
    expect(trips.first.startedOn, _d(2023, 7, 14));
    expect(trips.first.endedOn, _d(2023, 7, 14));
    expect(trips.first.photoCount, 1);
    expect(trips.first.isManual, isFalse);
  });

  // ── Gap boundary ─────────────────────────────────────────────────────────

  test('two photos in same country 29 days apart → 1 trip', () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 7, 1)),
      _rec('FR', _d(2023, 7, 30)), // 29 days later
    ]);
    expect(trips, hasLength(1));
    expect(trips.first.photoCount, 2);
    expect(trips.first.startedOn, _d(2023, 7, 1));
    expect(trips.first.endedOn, _d(2023, 7, 30));
  });

  test('two photos in same country exactly 30 days apart → 2 trips (boundary)',
      () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 7, 1)),
      _rec('FR', _d(2023, 7, 31)), // exactly 30 days later
    ]);
    expect(trips, hasLength(2));
  });

  test('two photos in same country 60 days apart → 2 trips', () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 1, 1)),
      _rec('FR', _d(2023, 3, 2)), // ~60 days later
    ]);
    expect(trips, hasLength(2));
    expect(trips.first.photoCount, 1);
    expect(trips.last.photoCount, 1);
  });

  // ── startedOn / endedOn ──────────────────────────────────────────────────

  test('startedOn equals earliest capturedAt in the cluster', () {
    final trips = inferTrips([
      _rec('JP', _d(2022, 4, 10)),
      _rec('JP', _d(2022, 4, 5)), // earlier — input order should not matter
      _rec('JP', _d(2022, 4, 15)),
    ]);
    expect(trips, hasLength(1));
    expect(trips.first.startedOn, _d(2022, 4, 5));
  });

  test('endedOn equals latest capturedAt in the cluster', () {
    final trips = inferTrips([
      _rec('JP', _d(2022, 4, 5)),
      _rec('JP', _d(2022, 4, 10)),
      _rec('JP', _d(2022, 4, 15)),
    ]);
    expect(trips.first.endedOn, _d(2022, 4, 15));
  });

  test('photoCount equals the number of photos in the cluster', () {
    final trips = inferTrips([
      _rec('DE', _d(2023, 8, 1)),
      _rec('DE', _d(2023, 8, 5)),
      _rec('DE', _d(2023, 8, 10)),
    ]);
    expect(trips.first.photoCount, 3);
  });

  // ── Multiple countries ────────────────────────────────────────────────────

  test('photos from different countries do not contaminate each other', () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 7, 1)),
      _rec('DE', _d(2023, 7, 2)), // same time window, different country
      _rec('FR', _d(2023, 7, 15)),
    ]);
    expect(trips, hasLength(2));
    final fr = trips.firstWhere((t) => t.countryCode == 'FR');
    final de = trips.firstWhere((t) => t.countryCode == 'DE');
    expect(fr.photoCount, 2);
    expect(de.photoCount, 1);
  });

  test('three countries each produce independent trips', () {
    final trips = inferTrips([
      _rec('GB', _d(2020, 1, 10)),
      _rec('US', _d(2021, 6, 1)),
      _rec('AU', _d(2022, 12, 25)),
    ]);
    expect(trips, hasLength(3));
    expect(trips.map((t) => t.countryCode), containsAll(['GB', 'US', 'AU']));
  });

  // ── Trip ID ──────────────────────────────────────────────────────────────

  test('trip id is natural key derived from countryCode + startedOn', () {
    final trips = inferTrips([_rec('FR', _d(2023, 7, 14))]);
    final expected =
        'FR_${DateTime.utc(2023, 7, 14).toIso8601String()}';
    expect(trips.first.id, expected);
  });

  test('two clusters in the same country have distinct ids', () {
    final trips = inferTrips([
      _rec('FR', _d(2022, 1, 1)),
      _rec('FR', _d(2023, 7, 1)), // > 30 days apart → new trip
    ]);
    expect(trips.map((t) => t.id).toSet(), hasLength(2));
  });

  // ── Large input ──────────────────────────────────────────────────────────

  test('100 photos in 5 countries with 2 trips each → 10 trips total', () {
    final records = <PhotoDateRecord>[];
    final countries = ['FR', 'DE', 'JP', 'US', 'GB'];
    for (final c in countries) {
      // Trip 1: Jan 2022
      for (var d = 1; d <= 10; d++) {
        records.add(_rec(c, DateTime.utc(2022, 1, d)));
      }
      // Trip 2: Sep 2022 (>30 days gap from Jan)
      for (var d = 1; d <= 10; d++) {
        records.add(_rec(c, DateTime.utc(2022, 9, d)));
      }
    }
    final trips = inferTrips(records);
    expect(trips, hasLength(10));
    for (final c in countries) {
      final countryTrips = trips.where((t) => t.countryCode == c).toList();
      expect(countryTrips, hasLength(2), reason: 'Expected 2 trips for $c');
      expect(
          countryTrips.fold<int>(0, (sum, t) => sum + t.photoCount), 20,
          reason: 'Expected 20 photos total for $c');
    }
  });

  // ── Custom gap ───────────────────────────────────────────────────────────

  test('custom gap = 7 days splits photos 8 days apart into 2 trips', () {
    final trips = inferTrips(
      [
        _rec('FR', _d(2023, 7, 1)),
        _rec('FR', _d(2023, 7, 9)), // 8 days > 7-day gap
      ],
      gap: const Duration(days: 7),
    );
    expect(trips, hasLength(2));
  });

  test('custom gap = 7 days keeps photos 6 days apart in 1 trip', () {
    final trips = inferTrips(
      [
        _rec('FR', _d(2023, 7, 1)),
        _rec('FR', _d(2023, 7, 7)), // 6 days < 7-day gap
      ],
      gap: const Duration(days: 7),
    );
    expect(trips, hasLength(1));
  });

  // ── inferRegionVisits ─────────────────────────────────────────────────────

  group('inferRegionVisits', () {
    test('empty records returns empty list', () {
      final trips = inferTrips([_rec('FR', _d(2023, 7, 1))]);
      expect(inferRegionVisits([], trips), isEmpty);
    });

    test('empty trips returns empty list', () {
      expect(
        inferRegionVisits(
          [_rec('FR', _d(2023, 7, 1), regionCode: 'FR-IDF')],
          [],
        ),
        isEmpty,
      );
    });

    test('records with null regionCode are excluded', () {
      final trip = inferTrips([_rec('FR', _d(2023, 7, 1))]).first;
      final result = inferRegionVisits(
        [_rec('FR', _d(2023, 7, 1))], // no regionCode
        [trip],
      );
      expect(result, isEmpty);
    });

    test('single record with regionCode produces one RegionVisit', () {
      final trip = inferTrips([_rec('FR', _d(2023, 7, 1))]).first;
      final result = inferRegionVisits(
        [_rec('FR', _d(2023, 7, 1), regionCode: 'FR-IDF')],
        [trip],
      );
      expect(result, hasLength(1));
      expect(result.first.tripId, trip.id);
      expect(result.first.countryCode, 'FR');
      expect(result.first.regionCode, 'FR-IDF');
      expect(result.first.photoCount, 1);
      expect(result.first.firstSeen, _d(2023, 7, 1));
      expect(result.first.lastSeen, _d(2023, 7, 1));
    });

    test('multiple photos in same region accumulate photoCount', () {
      final records = [
        _rec('FR', _d(2023, 7, 1), regionCode: 'FR-IDF'),
        _rec('FR', _d(2023, 7, 5), regionCode: 'FR-IDF'),
        _rec('FR', _d(2023, 7, 10), regionCode: 'FR-IDF'),
      ];
      final trip = inferTrips(records).first;
      final result = inferRegionVisits(records, [trip]);
      expect(result, hasLength(1));
      expect(result.first.photoCount, 3);
      expect(result.first.firstSeen, _d(2023, 7, 1));
      expect(result.first.lastSeen, _d(2023, 7, 10));
    });

    test('two regions in same trip produce two RegionVisits', () {
      final records = [
        _rec('US', _d(2023, 6, 1), regionCode: 'US-CA'),
        _rec('US', _d(2023, 6, 5), regionCode: 'US-NV'),
        _rec('US', _d(2023, 6, 10), regionCode: 'US-AZ'),
      ];
      final trip = inferTrips(records).first;
      final result = inferRegionVisits(records, [trip]);
      expect(result, hasLength(3));
      expect(result.map((r) => r.regionCode),
          containsAll(['US-CA', 'US-NV', 'US-AZ']));
      for (final rv in result) {
        expect(rv.tripId, trip.id);
        expect(rv.photoCount, 1);
      }
    });

    test('records assigned to correct trip when country has two trips', () {
      final records = [
        _rec('FR', _d(2022, 1, 5), regionCode: 'FR-IDF'),
        _rec('FR', _d(2023, 7, 10), regionCode: 'FR-ARA'), // > 30 days gap → new trip
      ];
      final trips = inferTrips(records);
      expect(trips, hasLength(2));

      final result = inferRegionVisits(records, trips);
      expect(result, hasLength(2));

      final idf = result.firstWhere((r) => r.regionCode == 'FR-IDF');
      final ara = result.firstWhere((r) => r.regionCode == 'FR-ARA');
      // Each region visit must reference a different trip.
      expect(idf.tripId, isNot(equals(ara.tripId)));
    });

    test('records outside all trip windows are excluded', () {
      // Trip covers July 2023; record is in January 2022 (no matching trip).
      final trip = inferTrips([_rec('FR', _d(2023, 7, 1))]).first;
      final result = inferRegionVisits(
        [_rec('FR', _d(2022, 1, 1), regionCode: 'FR-IDF')],
        [trip],
      );
      expect(result, isEmpty);
    });

    test('mixed null and non-null regionCode — only non-null contribute', () {
      final records = [
        _rec('DE', _d(2023, 8, 1), regionCode: 'DE-BE'),
        _rec('DE', _d(2023, 8, 5)), // null regionCode
        _rec('DE', _d(2023, 8, 10), regionCode: 'DE-BE'),
      ];
      final trip = inferTrips(records).first;
      final result = inferRegionVisits(records, [trip]);
      expect(result, hasLength(1));
      expect(result.first.photoCount, 2); // only the 2 with regionCode
    });
  });
}
