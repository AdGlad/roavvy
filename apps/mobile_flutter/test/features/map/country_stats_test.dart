import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/features/map/country_stats.dart';

TripRecord _trip({
  required DateTime start,
  required DateTime end,
  int photos = 10,
  bool isManual = false,
}) =>
    TripRecord(
      id: start.toIso8601String(),
      countryCode: 'JP',
      startedOn: start,
      endedOn: end,
      photoCount: photos,
      isManual: isManual,
    );

void main() {
  group('CountryStats.compute', () {
    test('totalDays sums correctly across multiple trips', () {
      final trips = [
        _trip(
          start: DateTime(2023, 3, 1),
          end: DateTime(2023, 3, 10),
          photos: 50,
        ), // 10 days
        _trip(
          start: DateTime(2023, 8, 5),
          end: DateTime(2023, 8, 16),
          photos: 30,
        ), // 12 days
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 47,
        visitedHeritageSites: 0,
        totalHeritageSites: 25,
        visit: null,
      );
      expect(stats.totalDays, 22);
      expect(stats.totalPhotos, 80);
      expect(stats.tripCount, 2);
    });

    test('single day trip counts as 1 day', () {
      final trips = [
        _trip(start: DateTime(2022, 6, 15), end: DateTime(2022, 6, 15)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      expect(stats.totalDays, 1);
    });

    test('firstVisitYear uses earliest trip startedOn', () {
      final trips = [
        _trip(start: DateTime(2022, 9, 1), end: DateTime(2022, 9, 14)),
        _trip(start: DateTime(2018, 11, 20), end: DateTime(2018, 12, 7)),
        _trip(start: DateTime(2024, 3, 3), end: DateTime(2024, 3, 21)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 47,
        visitedHeritageSites: 0,
        totalHeritageSites: 25,
        visit: null,
      );
      expect(stats.firstVisitYear, 2018);
      expect(stats.lastVisitYear, 2024);
    });

    test('firstVisitYear falls back to visit.firstSeen when no trips', () {
      final visit = EffectiveVisitedCountry(
        countryCode: 'JP',
        hasPhotoEvidence: true,
        firstSeen: DateTime.utc(2019, 5, 1),
        lastSeen: DateTime.utc(2019, 5, 14),
      );
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {},
        totalRegions: 47,
        visitedHeritageSites: 0,
        totalHeritageSites: 25,
        visit: visit,
      );
      expect(stats.firstVisitYear, 2019);
    });

    test('visitedRegions reflects Set size', () {
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {'JP-13', 'JP-27', 'JP-01'},
        totalRegions: 47,
        visitedHeritageSites: 3,
        totalHeritageSites: 25,
        visit: null,
      );
      expect(stats.visitedRegions, 3);
      expect(stats.totalRegions, 47);
    });

    test('heritage counts pass through correctly', () {
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 3,
        totalHeritageSites: 25,
        visit: null,
      );
      expect(stats.visitedHeritageSites, 3);
      expect(stats.totalHeritageSites, 25);
      expect(stats.allSitesVisited, isFalse);
    });

    test('allSitesVisited is true when counts match and total > 0', () {
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 3,
        totalHeritageSites: 3,
        visit: null,
      );
      expect(stats.allSitesVisited, isTrue);
    });

    test('allSitesVisited is false when totalHeritageSites is 0', () {
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      expect(stats.allSitesVisited, isFalse);
    });
  });

  group('CountryStats.narrativeText', () {
    test('no trips → add-trips message', () {
      final stats = CountryStats.compute(
        trips: [],
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      expect(
        stats.narrativeText('Japan'),
        contains("add trips to see your full story"),
      );
    });

    test('1 trip uses singular phrasing', () {
      final trips = [
        _trip(start: DateTime(2018, 11, 20), end: DateTime(2018, 12, 6)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      final text = stats.narrativeText('Japan');
      expect(text, contains('Japan'));
      expect(text, contains('First and only visit'));
      expect(text, isNot(contains('trips')));
    });

    test('multiple trips uses plural phrasing with "First adventure"', () {
      final trips = [
        _trip(start: DateTime(2018, 11, 1), end: DateTime(2018, 11, 10)),
        _trip(start: DateTime(2022, 3, 5), end: DateTime(2022, 3, 20)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      final text = stats.narrativeText('Japan');
      expect(text, contains('2 trips'));
      expect(text, contains('First adventure'));
      expect(text, contains('2018'));
    });

    test('allSitesVisited appends UNESCO sentence', () {
      final trips = [
        _trip(start: DateTime(2020, 6, 1), end: DateTime(2020, 6, 10)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 3,
        totalHeritageSites: 3,
        visit: null,
      );
      expect(
        stats.narrativeText('Japan'),
        contains("You've visited every UNESCO site"),
      );
    });

    test('Winter season for November trip', () {
      final trips = [
        _trip(start: DateTime(2018, 11, 1), end: DateTime(2018, 11, 5)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      expect(stats.narrativeText('Japan'), contains('Autumn'));
    });

    test('Spring season for April trip', () {
      final trips = [
        _trip(start: DateTime(2022, 4, 1), end: DateTime(2022, 4, 5)),
      ];
      final stats = CountryStats.compute(
        trips: trips,
        visitedRegionCodes: {},
        totalRegions: 0,
        visitedHeritageSites: 0,
        totalHeritageSites: 0,
        visit: null,
      );
      expect(stats.narrativeText('Japan'), contains('Spring'));
    });
  });
}
