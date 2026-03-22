import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/features/map/region_progress_notifier.dart';
import 'package:shared_models/shared_models.dart';

EffectiveVisitedCountry _visit(String code) => EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: true,
    );

void main() {
  group('Region.fromContinentString', () {
    test('parses all six continent strings', () {
      expect(Region.fromContinentString('Africa'), Region.africa);
      expect(Region.fromContinentString('Asia'), Region.asia);
      expect(Region.fromContinentString('Europe'), Region.europe);
      expect(Region.fromContinentString('North America'), Region.northAmerica);
      expect(Region.fromContinentString('South America'), Region.southAmerica);
      expect(Region.fromContinentString('Oceania'), Region.oceania);
    });

    test('returns null for unrecognised string', () {
      expect(Region.fromContinentString('Antarctica'), isNull);
      expect(Region.fromContinentString(''), isNull);
    });
  });

  group('Region.displayName', () {
    test('returns human-readable names', () {
      expect(Region.northAmerica.displayName, 'North America');
      expect(Region.southAmerica.displayName, 'South America');
      expect(Region.europe.displayName, 'Europe');
    });
  });

  group('computeRegionProgress', () {
    test('returns six entries covering all regions', () {
      final result = computeRegionProgress([]);
      expect(result.length, 6);
      final regions = result.map((r) => r.region).toSet();
      expect(regions, containsAll(Region.values));
    });

    test('totalCount is non-zero for all regions', () {
      final result = computeRegionProgress([]);
      for (final data in result) {
        expect(data.totalCount, greaterThan(0),
            reason: '${data.region} should have countries');
      }
    });

    test('visitedCount is 0 when no visits', () {
      final result = computeRegionProgress([]);
      expect(result.every((r) => r.visitedCount == 0), isTrue);
    });

    test('counts GB as a Europe visit', () {
      final result = computeRegionProgress([_visit('GB')]);
      final europe = result.firstWhere((r) => r.region == Region.europe);
      expect(europe.visitedCount, 1);
    });

    test('counts JP as an Asia visit', () {
      final result = computeRegionProgress([_visit('JP')]);
      final asia = result.firstWhere((r) => r.region == Region.asia);
      expect(asia.visitedCount, 1);
    });

    test('does not count unknown ISO codes', () {
      final result = computeRegionProgress([_visit('ZZ')]);
      expect(result.every((r) => r.visitedCount == 0), isTrue);
    });

    test('ratio is clamped to 0.0 when totalCount is 0', () {
      // Construct a synthetic data object directly to hit the guard.
      const data = RegionProgressData(
        region: Region.africa,
        centroid: LatLng(2.0, 21.0),
        visitedCount: 0,
        totalCount: 0,
      );
      expect(data.ratio, 0.0);
    });

    test('isComplete is true only when all countries visited', () {
      // Find a small region: visit all its countries.
      final result = computeRegionProgress([]);
      final oceania = result.firstWhere((r) => r.region == Region.oceania);
      final total = oceania.totalCount;

      // Build a list of Oceanian ISO codes from kCountryContinent.
      final oceanianCodes = kCountryContinent.entries
          .where((e) => e.value == 'Oceania')
          .map((e) => e.key)
          .toList();

      final allVisited = computeRegionProgress(
        oceanianCodes.map(_visit).toList(),
      );
      final completedOceania =
          allVisited.firstWhere((r) => r.region == Region.oceania);
      expect(completedOceania.visitedCount, total);
      expect(completedOceania.isComplete, isTrue);
    });

    test('remaining decreases as countries are visited', () {
      final before = computeRegionProgress([]);
      final europe = before.firstWhere((r) => r.region == Region.europe);
      final remainingBefore = europe.remaining;

      final after = computeRegionProgress([_visit('GB'), _visit('FR')]);
      final europeAfter = after.firstWhere((r) => r.region == Region.europe);
      expect(europeAfter.remaining, remainingBefore - 2);
    });

    test('centroid for each region matches kRegionCentroids', () {
      final result = computeRegionProgress([]);
      for (final data in result) {
        expect(data.centroid, kRegionCentroids[data.region]);
      }
    });
  });
}
