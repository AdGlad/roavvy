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

  // ── Geographic sequence model ─────────────────────────────────────────────

  test('two consecutive same-country photos → one trip (no gap rule)', () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 7, 1)),
      _rec('FR', _d(2023, 7, 30)),
    ]);
    expect(trips, hasLength(1));
    expect(trips.first.photoCount, 2);
    expect(trips.first.startedOn, _d(2023, 7, 1));
    expect(trips.first.endedOn, _d(2023, 7, 30));
  });

  test('long gap in same country without intervening country → still one trip',
      () {
    final trips = inferTrips([
      _rec('FR', _d(2023, 1, 1)),
      _rec('FR', _d(2023, 12, 31)), // 364 days, no other country between
    ]);
    expect(trips, hasLength(1));
    expect(trips.first.photoCount, 2);
  });

  test('JP → US → JP produces two JP trips and one US trip', () {
    final trips = inferTrips([
      _rec('JP', _d(2022, 4, 1)),
      _rec('JP', _d(2022, 4, 10)),
      _rec('US', _d(2022, 5, 1)),
      _rec('US', _d(2022, 5, 15)),
      _rec('JP', _d(2022, 6, 1)),
      _rec('JP', _d(2022, 6, 10)),
    ]);
    expect(trips, hasLength(3));
    final jpTrips = trips.where((t) => t.countryCode == 'JP').toList();
    final usTrips = trips.where((t) => t.countryCode == 'US').toList();
    expect(jpTrips, hasLength(2));
    expect(usTrips, hasLength(1));
    expect(jpTrips[0].startedOn, _d(2022, 4, 1));
    expect(jpTrips[0].endedOn, _d(2022, 4, 10));
    expect(jpTrips[1].startedOn, _d(2022, 6, 1));
    expect(jpTrips[1].endedOn, _d(2022, 6, 10));
  });

  test('country change is the only trip boundary', () {
    // Two FR photos separated by a US photo → two separate FR trips.
    final trips = inferTrips([
      _rec('FR', _d(2023, 7, 1)),
      _rec('US', _d(2023, 7, 2)),
      _rec('FR', _d(2023, 7, 15)),
    ]);
    expect(trips, hasLength(3));
    final frTrips = trips.where((t) => t.countryCode == 'FR').toList();
    expect(frTrips, hasLength(2));
    expect(frTrips[0].photoCount, 1);
    expect(frTrips[1].photoCount, 1);
  });

  // ── startedOn / endedOn ──────────────────────────────────────────────────

  test('startedOn equals earliest capturedAt in the run', () {
    final trips = inferTrips([
      _rec('JP', _d(2022, 4, 10)),
      _rec('JP', _d(2022, 4, 5)), // earlier — input order should not matter
      _rec('JP', _d(2022, 4, 15)),
    ]);
    expect(trips, hasLength(1));
    expect(trips.first.startedOn, _d(2022, 4, 5));
  });

  test('endedOn equals latest capturedAt in the run', () {
    final trips = inferTrips([
      _rec('JP', _d(2022, 4, 5)),
      _rec('JP', _d(2022, 4, 10)),
      _rec('JP', _d(2022, 4, 15)),
    ]);
    expect(trips.first.endedOn, _d(2022, 4, 15));
  });

  test('photoCount equals the number of photos in the run', () {
    final trips = inferTrips([
      _rec('DE', _d(2023, 8, 1)),
      _rec('DE', _d(2023, 8, 5)),
      _rec('DE', _d(2023, 8, 10)),
    ]);
    expect(trips.first.photoCount, 3);
  });

  // ── Multiple countries ────────────────────────────────────────────────────

  test('three distinct countries in sequence each produce one trip', () {
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
    final expected = 'FR_${DateTime.utc(2023, 7, 14).toIso8601String()}';
    expect(trips.first.id, expected);
  });

  test('two trips in the same country have distinct ids', () {
    // JP → US → JP: two JP trips with different startedOn.
    final trips = inferTrips([
      _rec('JP', _d(2022, 1, 1)),
      _rec('US', _d(2022, 6, 1)),
      _rec('JP', _d(2023, 1, 1)),
    ]);
    final jpTrips = trips.where((t) => t.countryCode == 'JP').toList();
    expect(jpTrips, hasLength(2));
    expect(jpTrips.map((t) => t.id).toSet(), hasLength(2));
  });

  // ── Large input ──────────────────────────────────────────────────────────

  test('5 countries visited in two separate trips each → 10 trips total', () {
    // Each country visited twice, separated by a different country each time.
    // Sequence: FR→DE→JP→US→GB→FR→DE→JP→US→GB, 10 photos per leg.
    final countries = ['FR', 'DE', 'JP', 'US', 'GB'];
    final records = <PhotoDateRecord>[];

    // Visit 1: Jan 2022 (countries in order, 10 photos each).
    for (var ci = 0; ci < countries.length; ci++) {
      for (var d = 1; d <= 10; d++) {
        records.add(_rec(countries[ci], DateTime.utc(2022, 1 + ci, d)));
      }
    }
    // Visit 2: Jan 2023 (same country order, 10 photos each).
    for (var ci = 0; ci < countries.length; ci++) {
      for (var d = 1; d <= 10; d++) {
        records.add(_rec(countries[ci], DateTime.utc(2023, 1 + ci, d)));
      }
    }

    final trips = inferTrips(records);
    expect(trips, hasLength(10));
    for (final c in countries) {
      final countryTrips = trips.where((t) => t.countryCode == c).toList();
      expect(countryTrips, hasLength(2), reason: 'Expected 2 trips for $c');
      expect(
        countryTrips.fold<int>(0, (sum, t) => sum + t.photoCount),
        20,
        reason: 'Expected 20 photos total for $c',
      );
    }
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
      // FR → DE → FR: two separate FR trips.
      final records = [
        _rec('FR', _d(2022, 1, 5), regionCode: 'FR-IDF'),
        _rec('DE', _d(2022, 6, 1)), // intervening country creates trip boundary
        _rec('FR', _d(2023, 7, 10), regionCode: 'FR-ARA'),
      ];
      final trips = inferTrips(records);
      final frTrips = trips.where((t) => t.countryCode == 'FR').toList();
      expect(frTrips, hasLength(2));

      final result = inferRegionVisits(records, trips);
      expect(result, hasLength(2));

      final idf = result.firstWhere((r) => r.regionCode == 'FR-IDF');
      final ara = result.firstWhere((r) => r.regionCode == 'FR-ARA');
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
