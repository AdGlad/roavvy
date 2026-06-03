import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/globe_replay/travel_replay_engine.dart';

void main() {
  group('ReplayPacingRules.arcDistanceDeg', () {
    test('same point returns 0', () {
      final d = ReplayPacingRules.arcDistanceDeg(48.8, 2.3, 48.8, 2.3);
      expect(d, closeTo(0.0, 0.01));
    });

    test('antipodal points return ~180', () {
      final d = ReplayPacingRules.arcDistanceDeg(0.0, 0.0, 0.0, 180.0);
      expect(d, closeTo(180.0, 1.0));
    });

    test('Paris to Berlin is short (<20°)', () {
      // Paris ~48.8°N 2.3°E, Berlin ~52.5°N 13.4°E
      final d = ReplayPacingRules.arcDistanceDeg(48.8, 2.3, 52.5, 13.4);
      expect(d, lessThan(20.0));
    });

    test('London to Bangkok is medium (20–90°)', () {
      // London ~51.5°N 0.1°W, Bangkok ~13.7°N 100.5°E
      final d = ReplayPacingRules.arcDistanceDeg(51.5, -0.1, 13.7, 100.5);
      expect(d, greaterThan(20.0));
      expect(d, lessThan(90.0));
    });

    test('Sydney to London is long (>90°)', () {
      // Sydney ~-33.9°S 151.2°E, London ~51.5°N 0.1°W
      final d = ReplayPacingRules.arcDistanceDeg(-33.9, 151.2, 51.5, -0.1);
      expect(d, greaterThan(90.0));
    });
  });

  group('ReplayPacingRules.compute — short arc', () {
    // France → Germany: short
    final leg = TravelLeg(
      fromCode: 'FR',
      toCode: 'DE',
      date: DateTime(2024, 6, 1),
      fromLat: 48.8,
      fromLng: 2.3,
      toLat: 52.5,
      toLng: 13.4,
    );

    test('flight duration is short', () {
      final p = ReplayPacingRules.compute(leg, 5);
      expect(p.flightMs, lessThanOrEqualTo(1000));
    });

    test('scaleDipAmount is small', () {
      final p = ReplayPacingRules.compute(leg, 5);
      expect(p.scaleDipAmount, lessThan(0.35));
    });
  });

  group('ReplayPacingRules.compute — long arc', () {
    // Australia → UK: long
    final leg = TravelLeg(
      fromCode: 'AU',
      toCode: 'GB',
      date: DateTime(2024, 8, 1),
      fromLat: -33.9,
      fromLng: 151.2,
      toLat: 51.5,
      toLng: -0.1,
    );

    test('flight duration is long', () {
      final p = ReplayPacingRules.compute(leg, 5);
      expect(p.flightMs, greaterThanOrEqualTo(2500));
    });

    test('scaleDipAmount is large', () {
      final p = ReplayPacingRules.compute(leg, 5);
      expect(p.scaleDipAmount, greaterThan(0.5));
    });

    test('peakScale is higher than short pacing', () {
      final shortLeg = TravelLeg(
        fromCode: 'FR',
        toCode: 'DE',
        date: DateTime(2024, 6, 1),
        fromLat: 48.8,
        fromLng: 2.3,
        toLat: 52.5,
        toLng: 13.4,
      );
      final longP = ReplayPacingRules.compute(leg, 5);
      final shortP = ReplayPacingRules.compute(shortLeg, 5);
      expect(longP.peakScale, greaterThan(shortP.peakScale));
    });
  });

  group('ReplayPacingRules.compute — flight compression for large scripts', () {
    final leg = TravelLeg(
      fromCode: 'AU',
      toCode: 'GB',
      date: DateTime(2024, 8, 1),
      fromLat: -33.9,
      fromLng: 151.2,
      toLat: 51.5,
      toLng: -0.1,
    );

    test('100-leg script caps flight duration', () {
      final p = ReplayPacingRules.compute(leg, 100);
      expect(
        p.flightMs,
        lessThanOrEqualTo(TravelReplayScriptBuilder.legDurationMs(100)),
      );
    });

    test('5-leg script is not artificially compressed', () {
      final p = ReplayPacingRules.compute(leg, 5);
      expect(
        p.flightMs,
        greaterThan(TravelReplayScriptBuilder.legDurationMs(100)),
      );
    });
  });

  group('ReplayPacingRules.legArcDistance — centroid fallback', () {
    test('falls back to centroids when GPS is null', () {
      // No GPS — uses kCountryCentroids for FR and DE
      final leg = TravelLeg(
        fromCode: 'FR',
        toCode: 'DE',
        date: DateTime(2024, 6, 1),
      );
      final d = ReplayPacingRules.legArcDistance(leg);
      expect(d, greaterThan(0.0));
      expect(d, lessThan(180.0));
    });

    test('uses GPS when available', () {
      final legGps = TravelLeg(
        fromCode: 'FR',
        toCode: 'AU',
        date: DateTime(2024, 6, 1),
        fromLat: 48.8,
        fromLng: 2.3,
        toLat: -33.9,
        toLng: 151.2,
      );
      final legCentroid = TravelLeg(
        fromCode: 'FR',
        toCode: 'AU',
        date: DateTime(2024, 6, 1),
      );
      // Both should classify as long; values close but GPS more precise
      final dGps = ReplayPacingRules.legArcDistance(legGps);
      final dCentroid = ReplayPacingRules.legArcDistance(legCentroid);
      expect(dGps, greaterThan(90.0));
      expect(dCentroid, greaterThan(90.0));
    });
  });

  group('ReplayPacingRules.buildPacingList', () {
    test('returns one LegPacing per leg', () {
      final script = TravelReplayScript(
        legs: [
          TravelLeg(
            fromCode: 'FR',
            toCode: 'DE',
            date: DateTime(2024, 6, 1),
            fromLat: 48.8,
            fromLng: 2.3,
            toLat: 52.5,
            toLng: 13.4,
          ),
          TravelLeg(
            fromCode: 'DE',
            toCode: 'AU',
            date: DateTime(2024, 8, 1),
            fromLat: 52.5,
            fromLng: 13.4,
            toLat: -33.9,
            toLng: 151.2,
          ),
        ],
        mode: TravelReplayMode.allTime,
        label: 'Test',
      );
      final pacing = ReplayPacingRules.buildPacingList(script);
      expect(pacing.length, 2);
      // First leg (FR→DE) is shorter than second (DE→AU)
      expect(pacing[0].flightMs, lessThan(pacing[1].flightMs));
    });

    test('empty script returns empty list', () {
      final script = TravelReplayScript(
        legs: const [],
        mode: TravelReplayMode.allTime,
        label: 'Empty',
      );
      expect(ReplayPacingRules.buildPacingList(script), isEmpty);
    });
  });
}
