import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

HeroAnalysisResult _result({
  required String assetId,
  required String tripId,
  DateTime? capturedAt,
  String? primaryScene,
  List<String> mood = const [],
  List<String> subjects = const [],
  String? landmark,
  double labelConfidence = 0.5,
  double qualityScore = 0.5,
  int pixelWidth = 1920,
  int pixelHeight = 1080,
  bool hasGps = true,
}) {
  return HeroAnalysisResult(
    assetId: assetId,
    capturedAt: capturedAt ?? DateTime.utc(2024, 7, 12, 10),
    labels: HeroLabels(
      primaryScene: primaryScene,
      mood: mood,
      subjects: subjects,
      landmark: landmark,
      confidence: labelConfidence,
    ),
    qualityScore: qualityScore,
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
    hasGps: hasGps,
    tripId: tripId,
  );
}

const _engine = HeroScoringEngine();

void main() {
  group('HeroScoringEngine', () {
    test('returns empty list for empty input', () {
      expect(
        _engine.rank(
          tripId: 'trip1',
          countryCode: 'GR',
          candidates: const [],
        ),
        isEmpty,
      );
    });

    test('single candidate becomes rank 1 with id hero_tripId', () {
      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: [_result(assetId: 'asset1', tripId: 'trip1')],
      );
      expect(heroes, hasLength(1));
      expect(heroes.first.rank, 1);
      expect(heroes.first.id, 'hero_trip1');
      expect(heroes.first.assetId, 'asset1');
    });

    test('best-scored candidate is rank 1', () {
      // High-quality candidate (large image, GPS, landmark, sunset)
      final best = _result(
        assetId: 'best',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 7),
        primaryScene: 'beach',
        mood: ['sunset'],
        landmark: 'acropolis',
        labelConfidence: 0.9,
        qualityScore: 1.0,
        pixelWidth: 4032,
        pixelHeight: 3024,
        hasGps: true,
      );

      // Low-quality candidate (small, no GPS, no labels)
      final worse = _result(
        assetId: 'worse',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 14),
        qualityScore: 0.2,
        pixelWidth: 800,
        pixelHeight: 600,
        hasGps: false,
        labelConfidence: 0.1,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: [worse, best],
      );

      expect(heroes.first.rank, 1);
      expect(heroes.first.assetId, 'best');
    });

    test('up to 3 candidates are returned', () {
      final candidates = List.generate(
        5,
        (i) => _result(
          assetId: 'asset$i',
          tripId: 'trip1',
          capturedAt: DateTime.utc(2024, 7, 12 + i),
        ),
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: candidates,
      );

      expect(heroes.length, lessThanOrEqualTo(3));
    });

    test('rank 2 and 3 have correct ids', () {
      final candidates = List.generate(
        3,
        (i) => _result(
          assetId: 'asset$i',
          tripId: 'trip1',
          capturedAt: DateTime.utc(2024, 7, 12 + i),
        ),
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: candidates,
      );

      expect(heroes[0].id, 'hero_trip1');
      expect(heroes[1].id, 'hero_trip1_2');
      expect(heroes[2].id, 'hero_trip1_3');
    });

    test('tie-broken by labelConfidence', () {
      final highConf = _result(
        assetId: 'highConf',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 8),
        qualityScore: 0.5,
        pixelWidth: 1920,
        pixelHeight: 1080,
        labelConfidence: 0.9,
      );
      final lowConf = _result(
        assetId: 'lowConf',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 9),
        qualityScore: 0.5,
        pixelWidth: 1920,
        pixelHeight: 1080,
        labelConfidence: 0.3,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: [lowConf, highConf],
      );

      expect(heroes.first.assetId, 'highConf');
    });

    test('isUserSelected defaults to false', () {
      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'GR',
        candidates: [_result(assetId: 'a1', tripId: 'trip1')],
      );
      expect(heroes.first.isUserSelected, isFalse);
    });

    test('countryCode is preserved from parameter', () {
      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'JP',
        candidates: [_result(assetId: 'a1', tripId: 'trip1')],
      );
      expect(heroes.first.countryCode, 'JP');
    });
  });
}
