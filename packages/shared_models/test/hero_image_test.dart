import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  group('HeroLabels.fromJson', () {
    test('parses all fields', () {
      final labels = HeroLabels.fromJson({
        'primaryScene': 'beach',
        'secondaryScene': 'coast',
        'activity': ['boat'],
        'mood': ['sunset', 'golden_hour'],
        'subjects': ['people'],
        'landmark': null,
        'labelConfidence': 0.82,
      });

      expect(labels.primaryScene, 'beach');
      expect(labels.secondaryScene, 'coast');
      expect(labels.activity, ['boat']);
      expect(labels.mood, ['sunset', 'golden_hour']);
      expect(labels.subjects, ['people']);
      expect(labels.landmark, isNull);
      expect(labels.confidence, closeTo(0.82, 0.001));
    });

    test('returns empty lists for missing array fields', () {
      final labels = HeroLabels.fromJson({});
      expect(labels.primaryScene, isNull);
      expect(labels.activity, isEmpty);
      expect(labels.mood, isEmpty);
      expect(labels.subjects, isEmpty);
      expect(labels.confidence, 0.0);
    });
  });

  group('HeroAnalysisResult.fromJson', () {
    test('parses complete result', () {
      final result = HeroAnalysisResult.fromJson({
        'assetId': 'E7E2F912-1234',
        'tripId': 'GR_2024-07-01T00:00:00.000Z',
        'capturedAt': '2024-07-12T10:30:00Z',
        'pixelWidth': 4032,
        'pixelHeight': 3024,
        'hasGps': true,
        'qualityScore': 0.71,
        'labels': {
          'primaryScene': 'beach',
          'mood': ['sunset'],
          'labelConfidence': 0.82,
        },
      });

      expect(result.assetId, 'E7E2F912-1234');
      expect(result.tripId, 'GR_2024-07-01T00:00:00.000Z');
      expect(result.capturedAt.year, 2024);
      expect(result.capturedAt.month, 7);
      expect(result.pixelWidth, 4032);
      expect(result.hasGps, isTrue);
      expect(result.qualityScore, closeTo(0.71, 0.001));
      expect(result.labels.primaryScene, 'beach');
      expect(result.labels.mood, ['sunset']);
    });
  });

  group('HeroImage', () {
    final hero = HeroImage(
      id: 'hero_trip1',
      assetId: 'asset123',
      tripId: 'trip1',
      countryCode: 'GR',
      capturedAt: DateTime.utc(2024, 7, 12),
      heroScore: 55.0,
      rank: 1,
      isUserSelected: false,
      createdAt: DateTime.utc(2024, 7, 12),
      updatedAt: DateTime.utc(2024, 7, 12),
    );

    test('isTombstone is false for rank 1', () {
      expect(hero.isTombstone, isFalse);
    });

    test('isTombstone is true for rank -1', () {
      final tombstone = hero.copyWith(rank: -1);
      expect(tombstone.isTombstone, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = hero.copyWith(heroScore: 80.0);
      expect(updated.assetId, hero.assetId);
      expect(updated.tripId, hero.tripId);
      expect(updated.heroScore, 80.0);
    });

    test('equality based on id+assetId+tripId', () {
      final same = hero.copyWith(heroScore: 99.0);
      expect(hero, equals(same));
    });
  });
}
