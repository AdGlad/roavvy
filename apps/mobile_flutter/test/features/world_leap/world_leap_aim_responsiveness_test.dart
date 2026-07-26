// Regression coverage for "aim sometimes stops responding — tap the screen
// and nothing happens, often after the first shot":
//
// 1. isWithinTapRadius: the pure tap-tolerance helper WorldLeapMapWidgetState
//    uses to accept a touch near the current-country origin marker even when
//    exact point-in-polygon containment misses (a small country's on-screen
//    footprint can be only a few pixels wide once the camera zooms out to
//    also frame a distant target).
// 2. SlingshotWidget: a state transition away from Aiming that happens
//    WHILE a pointer is still down (its up/cancel event is never delivered,
//    because build() removes the Listener from the tree once state leaves
//    Aiming) must not leave _trackingPointer stuck — otherwise every future
//    onPointerDown's "already tracking" guard silently swallows all touches
//    for the rest of the game.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import 'package:mobile_flutter/features/world_leap/presentation/widgets/slingshot_widget.dart';
import 'package:mobile_flutter/features/world_leap/presentation/widgets/world_leap_map_widget.dart';
import 'package:mobile_flutter/features/world_leap/world_leap_config.dart';

void main() {
  group('isWithinTapRadius', () {
    test('true when the tap is exactly at the origin', () {
      expect(
        isWithinTapRadius(
            const Offset(100, 100), const math.Point(100, 100), 40),
        isTrue,
      );
    });

    test('true when the tap is inside the radius', () {
      expect(
        isWithinTapRadius(
            const Offset(120, 100), const math.Point(100, 100), 40),
        isTrue,
      );
    });

    test('false when the tap is outside the radius', () {
      expect(
        isWithinTapRadius(
            const Offset(150, 100), const math.Point(100, 100), 40),
        isFalse,
      );
    });

    test('boundary is inclusive', () {
      // Exactly 40px away (dx=40, dy=0) — distance == radius.
      expect(
        isWithinTapRadius(
            const Offset(140, 100), const math.Point(100, 100), 40),
        isTrue,
      );
    });

    test('diagonal distance uses true Euclidean distance, not axis deltas',
        () {
      // dx=30, dy=30 → distance ≈ 42.4, just outside a 40px radius even
      // though each individual axis delta is within it.
      expect(
        isWithinTapRadius(
            const Offset(130, 130), const math.Point(100, 100), 40),
        isFalse,
      );
    });
  });

  group('SlingshotWidget — stuck pointer after a mid-drag state exit', () {
    late WorldLeapController controller;

    Future<void> pumpHarness(WidgetTester tester, {bool beginnerMode = false}) async {
      // Wrapped in a ListenableBuilder on the controller, mirroring how
      // world_leap_screen.dart actually mounts SlingshotWidget: the parent
      // rebuilds (reconstructing a fresh SlingshotWidget) on every
      // notifyListeners(), which is what normally forces build() to
      // re-evaluate its `state is! WorldLeapStateAiming` guard and restore
      // the Listener each new turn — a bare, unwrapped SlingshotWidget
      // wouldn't reflect that and would give a false picture of production
      // behaviour.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SlingshotWidget(
                controller: controller,
                beginnerMode: beginnerMode,
                maxDragPixels: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() async {
      final geo = WorldLeapGeoService();
      controller = WorldLeapController(
        userId: 'test-user',
        date: '2026-01-01',
        dailyService: _FakeDailyService(),
        repository: _FakeRunRepository(),
        geo: geo,
        countryService: const WorldLeapCountryService(),
        scoring: WorldLeapScoringService(
            WorldLeapHeritageBonusService(const [], geo)),
        // Always resolves to a neutral country so launch() succeeds via the
        // difficulty-tolerance path regardless of exact target — mirrors
        // world_leap_difficulty_test.dart's approach.
        countryLookup: (lat, lon) => (code: 'ZZ', name: 'Neutral'),
      );
      await controller.initialize();
    });

    // No tearDown-based dispose: the test below disposes synchronously at
    // the end of its body — addTearDown/tearDown callbacks run after
    // Flutter's pending-timer invariant check, too late to cancel the
    // countdown timer in time (see world_leap_beginner_mode_test.dart for
    // the same pattern).

    testWidgets(
      'a fresh touch after returning to Aiming is accepted even if the '
      'previous drag never received onPointerUp',
      (tester) async {
        await pumpHarness(tester);

        const anchor = Offset(200, 400);

        // Start a drag but DO NOT release it — simulates the finger still
        // being down when something external ends the shot.
        final stuckGesture = await tester.startGesture(anchor);
        await stuckGesture.moveTo(anchor + const Offset(60, 40));
        await tester.pump();
        expect(controller.state, isA<WorldLeapStateAiming>());

        // Force the state away from Aiming WITHOUT going through
        // SlingshotWidget's own release handling (_endTracking), so its
        // internal _trackingPointer is never reset by the normal path —
        // reproducing "something ends the shot while the finger is still
        // down". A real overshoot-but-within-tolerance launch reaches
        // WorldLeapStateLanded, matching the real game's success path.
        final geo = WorldLeapGeoService();
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
        final power = ((targetDistKm + 100) / WorldLeapConfig.maxLaunchDistanceKm)
            .clamp(0.0, 1.0);
        controller.updateAim(bearingDeg: bearing, power: power);
        // Fire-and-forget, matching world_leap_beginner_mode_test.dart's
        // pattern: launch()'s internal Future.delayed only resolves once
        // tester.pump(duration) below drives flutter_test's fake clock
        // forward. Awaiting it directly here would deadlock — nothing
        // would ever advance that clock.
        unawaited(controller.launch()); // emits Launching synchronously
        await tester.pump(); // let the widget rebuild (SizedBox.shrink())

        await tester.pump(
          const Duration(milliseconds: WorldLeapConfig.launchAnimationMs + 50),
        );
        expect(controller.state, isA<WorldLeapStateLanded>());

        // Back to Aiming for the next shot — the normal flow.
        controller.dismissScorePanel();
        await tester.pump();
        expect(controller.state, isA<WorldLeapStateAiming>());

        // A brand-new touch must be accepted — not silently swallowed by a
        // _trackingPointer left stuck from the never-released first drag.
        final freshGesture = await tester.startGesture(anchor);
        await freshGesture.moveTo(anchor + const Offset(30, 20));
        await tester.pump();

        final s = controller.state;
        expect(s, isA<WorldLeapStateAiming>());
        s as WorldLeapStateAiming;
        expect(
          s.power,
          isNotNull,
          reason:
              'the fresh touch should have updated aim — a stuck tracking '
              'pointer from the previous drag would silently ignore it',
        );
        expect(s.power, greaterThan(0));

        // Cancel rather than release — releasing would fire a second launch
        // whose Future.delayed would still be pending at teardown; the aim
        // update above is already the assertion this test cares about.
        await freshGesture.cancel();
        await stuckGesture.cancel();
        await tester.pump();

        // Dispose synchronously (cancels the countdown timer started by
        // dismissScorePanel()) — addTearDown/tearDown callbacks run after
        // Flutter's pending-timer invariant check, too late to help.
        controller.dispose();
      },
    );
  });
}

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
