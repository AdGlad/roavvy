import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_score_breakdown.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_heritage_bonus_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_scoring_service.dart';
import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

WorldLeapScoringService _scoringWithSites(List<WhsSite> sites) {
  final geo = WorldLeapGeoService();
  final heritage = WorldLeapHeritageBonusService(sites, geo);
  return WorldLeapScoringService(heritage);
}

WorldLeapScoringService _noHeritageScoringService() =>
    _scoringWithSites(const []);

// Paris UNESCO site used across heritage tests
const _parisLat = 48.8566;
const _parisLon = 2.3522;

void main() {
  group('base country score', () {
    test('always awards baseCountryScore on success', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 500,
        landingLat: 0,
        landingLon: 0,
      );
      expect(result.baseCountry, WorldLeapConfig.baseCountryScore);
    });
  });

  group('distance bonus', () {
    test('500 km → 5 pts (1 per 100 km)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.distanceBonus, 5);
    });

    test('1000 km → 10 pts', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 1000, landingLat: 0, landingLon: 0,
      );
      expect(result.distanceBonus, 10);
    });

    test('99 km → 0 pts (floor rounds down)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 99, landingLat: 0, landingLon: 0,
      );
      expect(result.distanceBonus, 0);
    });

    test('12000 km → 120 pts distance bonus', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 12000, landingLat: 0, landingLon: 0,
      );
      expect(result.distanceBonus, 120);
    });
  });

  group('long-shot bonus', () {
    test('7999 km → no long-shot bonus', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 7999, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, 0);
    });

    test('exactly 8000 km → +200 (tier 1)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 8000, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, WorldLeapConfig.longShotBonus1);
    });

    test('8001 km → +200 (tier 1)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 8001, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, WorldLeapConfig.longShotBonus1);
    });

    test('11999 km → +200 (still tier 1)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 11999, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, WorldLeapConfig.longShotBonus1);
    });

    test('exactly 12000 km → +500 (tier 2)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 12000, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, WorldLeapConfig.longShotBonus2);
    });

    test('12001 km → +500 (tier 2)', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 12001, landingLat: 0, landingLon: 0,
      );
      expect(result.longShotBonus, WorldLeapConfig.longShotBonus2);
    });
  });

  group('heritage bonus', () {
    test('no sites → zero heritage bonus', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.heritageBonus, 0);
      expect(result.heritageSiteName, isNull);
    });

    test('site > 100 km away → zero bonus', () {
      final svc = _scoringWithSites([
        WhsSite(name: 'Test Site', lat: _parisLat, lon: _parisLon),
      ]);
      // London is ~340 km from Paris — outside tier 1
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 51.5074, landingLon: -0.1278,
      );
      expect(result.heritageBonus, 0);
    });

    test('site within 100 km → tier 1 bonus (+50)', () {
      final svc = _scoringWithSites([
        // Site 60 km north of origin
        WhsSite(name: 'NearSite', lat: 0.54, lon: 0),
      ]);
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.heritageBonus, WorldLeapConfig.heritageTier1Bonus);
      expect(result.heritageSiteName, 'NearSite');
    });

    test('site within 50 km → tier 2 bonus (+100)', () {
      final svc = _scoringWithSites([
        // Site ~33 km from origin
        WhsSite(name: 'CloseSite', lat: 0.30, lon: 0),
      ]);
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.heritageBonus, WorldLeapConfig.heritageTier2Bonus);
    });

    test('site within 10 km → tier 3 bonus (+250)', () {
      final svc = _scoringWithSites([
        // Site ~5.5 km from origin
        WhsSite(name: 'DirectHit', lat: 0.05, lon: 0),
      ]);
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.heritageBonus, WorldLeapConfig.heritageTier3Bonus);
    });

    test('nearest site wins when multiple sites present', () {
      final svc = _scoringWithSites([
        WhsSite(name: 'Far', lat: 5.0, lon: 0),   // ~555 km
        WhsSite(name: 'Close', lat: 0.05, lon: 0), // ~5.5 km
      ]);
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.heritageSiteName, 'Close');
      expect(result.heritageBonus, WorldLeapConfig.heritageTier3Bonus);
    });
  });

  group('continent bonus', () {
    test('isNewContinent=true → +250', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
        isNewContinent: true,
      );
      expect(result.continentBonus, WorldLeapConfig.continentBonus);
    });

    test('isNewContinent=false (default) → 0', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(result.continentBonus, 0);
    });

    test('hasContinentBonus reflects bonus presence', () {
      final svc = _noHeritageScoringService();
      final withBonus = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
        isNewContinent: true,
      );
      final withoutBonus = svc.computeScore(
        distanceKm: 500, landingLat: 0, landingLon: 0,
      );
      expect(withBonus.hasContinentBonus, isTrue);
      expect(withoutBonus.hasContinentBonus, isFalse);
    });
  });

  group('score total', () {
    test('total = base + dist + longShot + heritage + continent', () {
      final svc = _scoringWithSites([
        WhsSite(name: 'Hit', lat: 0.05, lon: 0), // tier 3: +250
      ]);
      // 12000 km: longShot2=+500, dist=+120
      final result = svc.computeScore(
        distanceKm: 12000,
        landingLat: 0,
        landingLon: 0,
        isNewContinent: true,
      );
      // 100 + 120 + 500 + 250 + 250 = 1220
      expect(result.total, 1220);
    });

    test('minimum score (short hop, no bonuses) = 100 + dist', () {
      final svc = _noHeritageScoringService();
      final result = svc.computeScore(
        distanceKm: 200, landingLat: 0, landingLon: 0,
      );
      expect(result.total, 102); // 100 + 2
    });

    test('score accumulates correctly across three jumps', () {
      final svc = _noHeritageScoringService();
      int runTotal = 0;
      for (final km in [500.0, 1000.0, 2000.0]) {
        final r = svc.computeScore(
          distanceKm: km, landingLat: 0, landingLon: 0,
        );
        runTotal += r.total;
      }
      // (100+5) + (100+10) + (100+20) = 335
      expect(runTotal, 335);
    });
  });

  group('WorldLeapScoreBreakdown serialisation', () {
    test('round-trips through toJson/fromJson', () {
      final svc = _scoringWithSites([
        WhsSite(name: 'RoundTrip', lat: 0.05, lon: 0),
      ]);
      final original = svc.computeScore(
        distanceKm: 12001, landingLat: 0, landingLon: 0,
        isNewContinent: true,
      );
      final restored = WorldLeapScoreBreakdown.fromJson(original.toJson());
      expect(restored.baseCountry, original.baseCountry);
      expect(restored.distanceBonus, original.distanceBonus);
      expect(restored.longShotBonus, original.longShotBonus);
      expect(restored.heritageBonus, original.heritageBonus);
      expect(restored.heritageSiteName, original.heritageSiteName);
      expect(restored.continentBonus, original.continentBonus);
      expect(restored.total, original.total);
    });
  });
}
