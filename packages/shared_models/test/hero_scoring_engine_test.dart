import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

HeroAnalysisResult _result({
  required String assetId,
  required String tripId,
  DateTime? capturedAt,
  String? primaryScene,
  String? secondaryScene,
  List<String> mood = const [],
  List<String> subjects = const [],
  List<String> activity = const [],
  String? landmark,
  double labelConfidence = 0.5,
  double qualityScore = 0.65,
  int pixelWidth = 1920,
  int pixelHeight = 1080,
  bool hasGps = true,
  double saliencyCenterScore = 0.5,
  int faceCount = 0,
  double colorRichnessScore = 0.5,
  int analysisResolution = 800,
}) {
  return HeroAnalysisResult(
    assetId: assetId,
    capturedAt: capturedAt ?? DateTime.utc(2024, 7, 12, 10),
    labels: HeroLabels(
      primaryScene: primaryScene,
      secondaryScene: secondaryScene,
      mood: mood,
      subjects: subjects,
      activity: activity,
      landmark: landmark,
      confidence: labelConfidence,
    ),
    qualityScore: qualityScore,
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
    hasGps: hasGps,
    tripId: tripId,
    saliencyCenterScore: saliencyCenterScore,
    faceCount: faceCount,
    colorRichnessScore: colorRichnessScore,
    analysisResolution: analysisResolution,
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
      // Vibrant golden-hour beach shot, high quality, centred, landmark.
      final best = _result(
        assetId: 'best',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 7),
        primaryScene: 'beach',
        mood: ['golden_hour'],
        landmark: 'acropolis',
        labelConfidence: 0.9,
        qualityScore: 1.0,
        pixelWidth: 4032,
        pixelHeight: 3024,
        hasGps: true,
        colorRichnessScore: 0.8,
        saliencyCenterScore: 0.9,
        analysisResolution: 800,
      );

      // Low-quality, flat, no labels.
      final worse = _result(
        assetId: 'worse',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 14),
        qualityScore: 0.3,
        pixelWidth: 800,
        pixelHeight: 600,
        hasGps: false,
        labelConfidence: 0.1,
        colorRichnessScore: 0.1,
        saliencyCenterScore: 0.2,
        analysisResolution: 600,
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
        qualityScore: 0.65,
        labelConfidence: 0.9,
        colorRichnessScore: 0.5,
        saliencyCenterScore: 0.5,
      );
      final lowConf = _result(
        assetId: 'lowConf',
        tripId: 'trip1',
        capturedAt: DateTime.utc(2024, 7, 12, 9),
        qualityScore: 0.65,
        labelConfidence: 0.3,
        colorRichnessScore: 0.5,
        saliencyCenterScore: 0.5,
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

    // ── Visual impact ──────────────────────────────────────────────────────────

    test('vibrant golden-hour scenic beats flat food-only photo', () {
      final scenic = _result(
        assetId: 'scenic',
        tripId: 'trip1',
        primaryScene: 'mountain',
        mood: ['golden_hour'],
        colorRichnessScore: 0.8,
        saliencyCenterScore: 0.8,
        labelConfidence: 0.8,
      );
      final foodOnly = _result(
        assetId: 'food',
        tripId: 'trip1',
        activity: ['food'],
        colorRichnessScore: 0.3,
        saliencyCenterScore: 0.4,
        labelConfidence: 0.5,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'IT',
        candidates: [foodOnly, scenic],
      );

      expect(heroes.first.assetId, 'scenic');
    });

    test('selfie-only shot penalised vs landscape shot', () {
      final landscape = _result(
        assetId: 'landscape',
        tripId: 'trip1',
        primaryScene: 'beach',
        colorRichnessScore: 0.6,
        saliencyCenterScore: 0.7,
      );
      final selfieOnly = _result(
        assetId: 'selfie',
        tripId: 'trip1',
        subjects: ['selfie'],
        colorRichnessScore: 0.5,
        saliencyCenterScore: 0.5,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'ES',
        candidates: [selfieOnly, landscape],
      );

      expect(heroes.first.assetId, 'landscape');
    });

    test('group photo in scenic context scores higher than solo portrait', () {
      final group = _result(
        assetId: 'group',
        tripId: 'trip1',
        primaryScene: 'mountain',
        faceCount: 3,
        colorRichnessScore: 0.6,
        saliencyCenterScore: 0.6,
      );
      final solo = _result(
        assetId: 'solo',
        tripId: 'trip1',
        primaryScene: 'mountain',
        faceCount: 1,
        colorRichnessScore: 0.6,
        saliencyCenterScore: 0.6,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'CH',
        candidates: [solo, group],
      );

      expect(heroes.first.assetId, 'group');
    });

    // ── Quality component ──────────────────────────────────────────────────────

    test('high-res photo analysed at 800px beats tiny-thumbnail analysis', () {
      final highRes = _result(
        assetId: 'highRes',
        tripId: 'trip1',
        qualityScore: 1.0,
        pixelWidth: 4032,
        pixelHeight: 3024,
        analysisResolution: 800,
      );
      final tinyCache = _result(
        assetId: 'tinyCache',
        tripId: 'trip1',
        qualityScore: 1.0,
        pixelWidth: 4032,
        pixelHeight: 3024,
        analysisResolution: 100, // only a tiny cached thumbnail was available
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'FR',
        candidates: [tinyCache, highRes],
      );

      expect(heroes.first.assetId, 'highRes');
    });

    // ── Travel scene ───────────────────────────────────────────────────────────

    test('landmark shot scores higher than plain city shot', () {
      final landmark = _result(
        assetId: 'landmark',
        tripId: 'trip1',
        primaryScene: 'city',
        landmark: 'eiffel_tower',
        labelConfidence: 0.8,
      );
      final street = _result(
        assetId: 'street',
        tripId: 'trip1',
        primaryScene: 'city',
        labelConfidence: 0.6,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'FR',
        candidates: [street, landmark],
      );

      expect(heroes.first.assetId, 'landmark');
    });

    test('hiking activity boosts travel scene score', () {
      final hike = _result(
        assetId: 'hike',
        tripId: 'trip1',
        primaryScene: 'mountain',
        activity: ['hiking'],
        labelConfidence: 0.7,
      );
      final generic = _result(
        assetId: 'generic',
        tripId: 'trip1',
        primaryScene: 'mountain',
        labelConfidence: 0.7,
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'NO',
        candidates: [generic, hike],
      );

      expect(heroes.first.assetId, 'hike');
    });

    // ── Uniqueness ─────────────────────────────────────────────────────────────

    test('GPS-tagged photo preferred over non-GPS at same visual quality', () {
      final gps = _result(
        assetId: 'gps',
        tripId: 'trip1',
        hasGps: true,
        colorRichnessScore: 0.5,
        saliencyCenterScore: 0.5,
        primaryScene: 'city',
      );
      final noGps = _result(
        assetId: 'noGps',
        tripId: 'trip1',
        hasGps: false,
        colorRichnessScore: 0.5,
        saliencyCenterScore: 0.5,
        primaryScene: 'city',
      );

      final heroes = _engine.rank(
        tripId: 'trip1',
        countryCode: 'DE',
        candidates: [noGps, gps],
      );

      expect(heroes.first.assetId, 'gps');
    });

    // ── HeroAnalysisResult.fromJson back-compat ────────────────────────────────

    test('fromJson defaults new fields when absent', () {
      final json = <Object?, Object?>{
        'assetId': 'a1',
        'capturedAt': '2024-07-12T10:00:00.000Z',
        'labels': <Object?, Object?>{},
        'qualityScore': 0.65,
        'pixelWidth': 1920,
        'pixelHeight': 1080,
        'hasGps': true,
        'tripId': 'trip1',
      };
      final result = HeroAnalysisResult.fromJson(json);
      expect(result.saliencyCenterScore, 0.5);
      expect(result.faceCount, 0);
      expect(result.colorRichnessScore, 0.5);
      expect(result.analysisResolution, 0);
    });

    test('fromJson parses new fields when present', () {
      final json = <Object?, Object?>{
        'assetId': 'a1',
        'capturedAt': '2024-07-12T10:00:00.000Z',
        'labels': <Object?, Object?>{},
        'qualityScore': 0.65,
        'pixelWidth': 1920,
        'pixelHeight': 1080,
        'hasGps': true,
        'tripId': 'trip1',
        'saliencyCenterScore': 0.82,
        'faceCount': 2,
        'colorRichnessScore': 0.73,
        'analysisResolution': 800,
      };
      final result = HeroAnalysisResult.fromJson(json);
      expect(result.saliencyCenterScore, closeTo(0.82, 0.001));
      expect(result.faceCount, 2);
      expect(result.colorRichnessScore, closeTo(0.73, 0.001));
      expect(result.analysisResolution, 800);
    });
  });
}
