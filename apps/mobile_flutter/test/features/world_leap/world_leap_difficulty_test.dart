// Difficulty grades (1–3), reintroduced after the M173-era usability rework
// replaced the old 1–5 picker with a single fixed landing tolerance. Verifies
// setDifficulty clamps to [1, 3] and actually changes how close a landing
// must be to the target centroid to count as a hit — a lenient grade accepts
// an overshoot that a strict grade rejects.
//
// Landing outcome is driven entirely through the public API: updateAim +
// launch(), with a countryLookup stub that always resolves to a neutral
// country code different from both the current and target country, so the
// hit/miss decision is forced through the tolerance-radius path (the "landed
// just over a border but still close to the target" case), not an exact
// country-code match.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_flutter/features/world_leap/application/world_leap_controller.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_state.dart';
import 'package:mobile_flutter/features/world_leap/data/repositories/world_leap_run_repository.dart';
import 'package:mobile_flutter/features/world_leap/domain/models/world_leap_run.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_country_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_geo_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_heritage_bonus_service.dart';
import 'package:mobile_flutter/features/world_leap/domain/services/world_leap_scoring_service.dart';
import 'package:mobile_flutter/features/world_leap/application/world_leap_daily_service.dart';
import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';

class _FakeDailyService implements IWorldLeapDailyService {
  @override
  Future<({String code, String name})?> getStartCountry(String date) async =>
      (code: 'US', name: 'United States');

  @override
  Future<bool> hasExistingRun(String userId, String date) async => false;
}

class _FakeRunRepository implements IWorldLeapRunRepository {
  @override
  Future<WorldLeapRun?> loadRun(String userId, String date) async => null;

  @override
  Future<void> saveRun(WorldLeapRun run) async {}

  @override
  Future<void> saveRunLocal(WorldLeapRun run) async {}

  @override
  Future<void> syncRunToFirestore(WorldLeapRun run) async {}

  @override
  Stream<WorldLeapRun?> watchRun(String userId, String date) =>
      const Stream.empty();

  @override
  Future<void> clearLocalRun() async {}

  @override
  Future<void> deleteRun(String userId, String date) async {}
}

Future<WorldLeapController> _buildController(WorldLeapGeoService geo) async {
  final controller = WorldLeapController(
    userId: 'test-user',
    date: '2026-01-01',
    dailyService: _FakeDailyService(),
    repository: _FakeRunRepository(),
    geo: geo,
    countryService: const WorldLeapCountryService(),
    scoring:
        WorldLeapScoringService(WorldLeapHeritageBonusService(const [], geo)),
    // Always resolves to a neutral country distinct from current/target, so
    // the hit/miss decision is forced through the difficulty-tolerance path
    // rather than an exact country-code match.
    countryLookup: (lat, lon) => (code: 'ZZ', name: 'Neutral'),
  );
  await controller.initialize();
  return controller;
}

/// Fires a launch that lands [overshootKm] beyond the target centroid, along
/// the exact bearing from the current origin to the target — i.e. "just
/// missed, past the target in the right direction".
Future<void> _launchOvershootingTargetBy(
  WorldLeapController controller,
  WorldLeapGeoService geo,
  double overshootKm,
) async {
  final origin = controller.currentOrigin;
  final target = controller.targetLocation!;
  final bearing = geo.initialBearingDeg(
    lat1: origin.lat,
    lon1: origin.lon,
    lat2: target.lat,
    lon2: target.lon,
  );
  final targetDistKm = geo.greatCircleDistanceKm(
    lat1: origin.lat,
    lon1: origin.lon,
    lat2: target.lat,
    lon2: target.lon,
  );
  final distanceKm = targetDistKm + overshootKm;
  final power =
      (distanceKm / WorldLeapConfig.maxLaunchDistanceKm).clamp(0.0, 1.0);
  controller.updateAim(bearingDeg: bearing, power: power);
  await controller.launch();
}

void main() {
  group('WorldLeapController difficulty', () {
    test('defaults to grade 1 (Easy)', () async {
      final geo = WorldLeapGeoService();
      final controller = await _buildController(geo);
      expect(controller.difficulty, 1);
      controller.dispose();
    });

    test('setDifficulty clamps to [1, 3]', () async {
      final geo = WorldLeapGeoService();
      final controller = await _buildController(geo);

      controller.setDifficulty(0);
      expect(controller.difficulty, 1);

      controller.setDifficulty(5);
      expect(controller.difficulty, 3);

      controller.setDifficulty(2);
      expect(controller.difficulty, 2);

      controller.dispose();
    });

    test('setDifficulty notifies listeners on real change, not on a no-op',
        () async {
      final geo = WorldLeapGeoService();
      final controller = await _buildController(geo);

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setDifficulty(1); // already 1 — no-op
      expect(notifyCount, 0);

      controller.setDifficulty(3);
      expect(notifyCount, 1);

      controller.dispose();
    });

    test(
      'grade 1 (Easy, 500km) accepts an overshoot that grade 3 (Hard, 50km) '
      'rejects',
      () async {
        final geo = WorldLeapGeoService();

        final easyController = await _buildController(geo);
        easyController.setDifficulty(1);
        await _launchOvershootingTargetBy(easyController, geo, 300);
        await Future<void>.delayed(
          const Duration(milliseconds: WorldLeapConfig.launchAnimationMs + 50),
        );
        expect(
          easyController.state,
          isA<WorldLeapStateLanded>(),
          reason: 'a 300km overshoot should be within the 500km Easy '
              'tolerance',
        );
        easyController.dispose();

        final hardController = await _buildController(geo);
        hardController.setDifficulty(3);
        await _launchOvershootingTargetBy(hardController, geo, 300);
        await Future<void>.delayed(
          const Duration(milliseconds: WorldLeapConfig.launchAnimationMs + 50),
        );
        expect(
          hardController.state,
          isA<WorldLeapStateFailed>(),
          reason: 'a 300km overshoot should exceed the 50km Hard tolerance',
        );
        hardController.dispose();
      },
    );
  });
}
