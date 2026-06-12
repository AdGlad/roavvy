import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/stats/widgets/travel_heatmap_card.dart';
import 'package:shared_models/shared_models.dart';

EffectiveVisitedCountry _visit(String code, DateTime? firstSeen) =>
    EffectiveVisitedCountry(
      countryCode: code,
      hasPhotoEvidence: firstSeen != null,
      firstSeen: firstSeen,
    );

void main() {
  group('buildHeatmapData', () {
    test('empty visits returns empty map', () {
      expect(buildHeatmapData([]), isEmpty);
    });

    test('visit without firstSeen is ignored', () {
      final data = buildHeatmapData([_visit('FR', null)]);
      expect(data, isEmpty);
    });

    test('single visit creates one bucket', () {
      final data = buildHeatmapData([
        _visit('JP', DateTime.utc(2023, 7, 15)),
      ]);
      expect(data, hasLength(1));
      expect(data[(2023, 7)], equals(['JP']));
    });

    test('two visits in same month go into same bucket', () {
      final data = buildHeatmapData([
        _visit('FR', DateTime.utc(2022, 3, 1)),
        _visit('IT', DateTime.utc(2022, 3, 28)),
      ]);
      expect(data, hasLength(1));
      expect(data[(2022, 3)], containsAll(['FR', 'IT']));
    });

    test('visits in different months produce separate buckets', () {
      final data = buildHeatmapData([
        _visit('FR', DateTime.utc(2022, 3, 1)),
        _visit('JP', DateTime.utc(2022, 7, 10)),
      ]);
      expect(data, hasLength(2));
      expect(data[(2022, 3)], equals(['FR']));
      expect(data[(2022, 7)], equals(['JP']));
    });

    test('visits spanning multiple years produce correct buckets', () {
      final data = buildHeatmapData([
        _visit('FR', DateTime.utc(2020, 6, 1)),
        _visit('JP', DateTime.utc(2023, 6, 1)),
      ]);
      expect(data[(2020, 6)], equals(['FR']));
      expect(data[(2023, 6)], equals(['JP']));
    });
  });

  group('dominantContinent', () {
    test('empty codes returns null', () {
      expect(dominantContinent([]), isNull);
    });

    test('unknown country codes return null', () {
      expect(dominantContinent(['XX', 'ZZ']), isNull);
    });

    test('single European country returns Europe', () {
      // FR → Europe
      expect(dominantContinent(['FR']), equals('Europe'));
    });

    test('majority continent wins', () {
      // FR, IT, DE → Europe (3) vs JP (Asia, 1)
      expect(dominantContinent(['FR', 'IT', 'DE', 'JP']), equals('Europe'));
    });

    test('alphabetical tiebreak: Africa before Asia', () {
      // One Africa (ZA), one Asia (JP) → Africa wins alphabetically
      expect(dominantContinent(['ZA', 'JP']), equals('Africa'));
    });

    test('North America before South America on tiebreak', () {
      // US → North America, BR → South America
      expect(dominantContinent(['US', 'BR']), equals('North America'));
    });
  });
}
