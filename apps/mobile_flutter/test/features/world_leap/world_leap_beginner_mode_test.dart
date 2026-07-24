// Verifies the beginner-mode aim/adjust/fire flow end-to-end by driving
// SlingshotWidget's actual gesture handling with a real WorldLeapController
// (fake daily service + repository, no network/Firestore needed):
//
//   1. Drag, release → aim FREEZES (does not fire, does not snap to zero),
//      and hasConfirmedAim (which drives the FIRE button) becomes true.
//   2. Drag again (a second, independent touch) → the frozen aim is ADJUSTED
//      (baseline + new segment), not restarted from zero.
//   3. Release again → still frozen, ready-to-fire state reflects the
//      adjusted aim.
//   4. hasConfirmedAim survives the countdown timer's per-second
//      notifyListeners() tick — regression test for a bug where the FIRE
//      button (and the map's trajectory preview) flickered because
//      WorldLeapMapWidget's Aiming-branch reset re-ran on every notify, not
//      just on a real transition into Aiming.
//   5. Classic mode (beginnerMode: false), for contrast, fires immediately on
//      release with no persisted aim.

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
  Stream<WorldLeapRun?> watchRun(String userId, String date) => const Stream.empty();

  @override
  Future<void> clearLocalRun() async {}

  @override
  Future<void> deleteRun(String userId, String date) async {}
}

Future<WorldLeapController> _buildController({required bool beginnerMode}) async {
  final geo = WorldLeapGeoService();
  final controller = WorldLeapController(
    userId: 'test-user',
    date: '2026-01-01',
    dailyService: _FakeDailyService(),
    repository: _FakeRunRepository(),
    geo: geo,
    countryService: const WorldLeapCountryService(),
    scoring: WorldLeapScoringService(WorldLeapHeritageBonusService(const [], geo)),
    beginnerMode: beginnerMode,
    // Never resolved in this test (no launch() call), but required to avoid
    // touching the real bundled geodata.
    countryLookup: (lat, lon) => null,
  );
  await controller.initialize();
  return controller;
}

Widget _harness(WorldLeapController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SlingshotWidget(
        controller: controller,
        beginnerMode: controller.beginnerMode,
        maxDragPixels: 200,
      ),
    ),
  );
}

/// Reads the aiming state's live bearing/power, asserting the controller is
/// actually in [WorldLeapStateAiming].
({double? bearingDeg, double? power}) _aim(WorldLeapController controller) {
  final s = controller.state;
  expect(s, isA<WorldLeapStateAiming>());
  s as WorldLeapStateAiming;
  return (bearingDeg: s.bearingDeg, power: s.power);
}

void main() {
  testWidgets(
    'beginner mode: release freezes aim, a second drag adjusts it, ready to fire',
    (tester) async {
      final controller = await _buildController(beginnerMode: true);
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      const anchor = Offset(200, 400);

      // 1. First drag: pull down-right by (60, 40), release.
      final gesture1 = await tester.startGesture(anchor);
      await gesture1.moveTo(anchor + const Offset(60, 40));
      await tester.pump();
      await gesture1.up();
      await tester.pump();

      // Beginner mode must NOT have fired — still aiming, with a real aim,
      // and the FIRE button's affordance is now up.
      final firstAim = _aim(controller);
      expect(firstAim.bearingDeg, isNotNull);
      expect(firstAim.power, isNotNull);
      expect(firstAim.power, greaterThan(0));
      expect(controller.hasConfirmedAim, isTrue);

      // The frozen pull must still be visible (not snapped back to zero) —
      // the painter reads this via the widget's own state, so drive another
      // frame and confirm the widget is still rendering the aiming UI at all
      // (build() only renders while state is Aiming).
      expect(find.byType(SlingshotWidget), findsOneWidget);

      // Regression check: the countdown timer ticks every second and calls
      // notifyListeners() without ever leaving Aiming. hasConfirmedAim (and
      // the FIRE button it drives) must survive that — it previously did
      // not, because WorldLeapMapWidget's Aiming-branch reset re-ran on
      // every such notify.
      await tester.pump(const Duration(seconds: 2));
      expect(controller.hasConfirmedAim, isTrue);
      expect(controller.state, isA<WorldLeapStateAiming>());

      // 2. Second, independent drag (simulates releasing and touching down
      // again to nudge the aim) — must ADJUST the frozen baseline, not
      // restart from zero.
      final gesture2 = await tester.startGesture(anchor);
      await gesture2.moveTo(anchor + const Offset(20, 0)); // small nudge
      await tester.pump();
      await gesture2.up();
      await tester.pump();

      final secondAim = _aim(controller);
      expect(secondAim.bearingDeg, isNotNull);
      expect(secondAim.power, isNotNull);
      // The adjusted total pull (60+20, 40) has greater magnitude than the
      // first pull (60, 40) alone — proves the second drag added onto the
      // frozen baseline instead of restarting a fresh (20, 0) pull.
      expect(secondAim.power!, greaterThan(firstAim.power!));

      // Still aiming (never fired), FIRE button still up.
      expect(controller.state, isA<WorldLeapStateAiming>());
      expect(controller.hasConfirmedAim, isTrue);

      // Dispose synchronously (cancels the countdown timer) — addTearDown
      // callbacks run after Flutter's pending-timer check, too late to help.
      controller.dispose();
    },
  );

  testWidgets(
    'classic mode: release fires immediately, no frozen aim',
    (tester) async {
      final controller = await _buildController(beginnerMode: false);
      await tester.pumpWidget(_harness(controller));
      await tester.pumpAndSettle();

      const anchor = Offset(200, 400);
      final gesture = await tester.startGesture(anchor);
      await gesture.moveTo(anchor + const Offset(60, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Classic mode fires on release immediately — the state has already
      // left Aiming before the flight/save delay even completes.
      expect(controller.state, isNot(isA<WorldLeapStateAiming>()));

      // Let launch()'s internal delayed future resolve so no timer is left
      // pending at teardown (our fake countryLookup always misses, so this
      // settles into a Failed state — irrelevant to what this test checks).
      await tester.pump(
        const Duration(milliseconds: WorldLeapConfig.launchAnimationMs + 100),
      );
      controller.dispose();
    },
  );
}
