import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/app_tab.dart';
import 'package:mobile_flutter/core/commerce/commerce_flag.dart';
import 'package:mobile_flutter/core/notification_service.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/memory/memory_anniversary_photo.dart';
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart';
import 'package:mobile_flutter/features/shell/main_shell.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps [MainShell] with provider overrides for all four screens.
///
/// [polygonsProvider] is overridden with [] so MapScreen never calls
/// [loadPolygons()]. All repositories use an in-memory DB.
Widget _pumpShell({bool commerce = false, AppTab initialTab = AppTab.map}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      commerceBuildProvider.overrideWithValue(commerce),
      commerceRemoteSwitchProvider.overrideWithValue(true),
      // No Firestore in tests: the cart badge reads a fixed count.
      merchCartCountProvider.overrideWithValue(0),
      roavvyDatabaseProvider.overrideWithValue(db),
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
      achievementRepositoryProvider.overrideWithValue(
        AchievementRepository(db),
      ),
      tripRepositoryProvider.overrideWithValue(TripRepository(db)),
      regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
      xpRepositoryProvider.overrideWithValue(XpRepository(db)),
      polygonsProvider.overrideWithValue(const []),
      // No Firebase in tests — treat user as signed out
      currentUidProvider.overrideWithValue(null),
      // Prevent photo_manager platform channel calls in tests
      todaysMemoriesProvider.overrideWith(
        (ref) => Future<List<MemoryAnniversaryPhoto>>.value([]),
      ),
    ],
    child: MaterialApp(home: MainShell(initialTab: initialTab)),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> pump(
    WidgetTester tester, {
    bool commerce = false,
    bool landscape = false,
    AppTab initialTab = AppTab.map,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize =
        landscape ? const Size(1100, 600) : const Size(600, 1100);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _pumpShell(commerce: commerce, initialTab: initialTab),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  int selectedBarIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  group('MainShell — commerce off (ADR-180)', () {
    testWidgets('phone: four tabs, no Shop', (tester) async {
      await pump(tester);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 4);
      for (final label in ['Map', 'Journey', 'Stats', 'Play']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Shop'), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
    });

    testWidgets('landscape rail: four tabs, no Shop', (tester) async {
      await pump(tester, landscape: true);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 4);
      expect(find.text('Shop'), findsNothing);
    });

    testWidgets('tab:shop lands on Map', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Stats').last);
      await tester.pump();
      expect(selectedBarIndex(tester), 2);

      NotificationService.instance.pendingTab.value = AppTab.shop;
      await tester.pump();
      expect(selectedBarIndex(tester), 0);
    });

    testWidgets('tab:stats and tab:play land on their tabs', (tester) async {
      await pump(tester);
      NotificationService.instance.pendingTab.value = AppTab.stats;
      await tester.pump();
      expect(selectedBarIndex(tester), 2);

      NotificationService.instance.pendingTab.value = AppTab.play;
      await tester.pump();
      expect(selectedBarIndex(tester), 3); // Play moves up when Shop is gone
    });

    testWidgets('initialTab Shop opens on Map', (tester) async {
      await pump(tester, initialTab: AppTab.shop);
      expect(selectedBarIndex(tester), 0);
    });
  });

  group('MainShell — commerce on', () {
    testWidgets('phone: five tabs including Shop', (tester) async {
      await pump(tester, commerce: true);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 5);
      expect(find.text('Shop'), findsOneWidget);
    });

    testWidgets('landscape rail: five tabs including Shop', (tester) async {
      await pump(tester, commerce: true, landscape: true);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 5);
    });

    testWidgets('tab:shop and tab:play land on their tabs', (tester) async {
      await pump(tester, commerce: true);
      NotificationService.instance.pendingTab.value = AppTab.shop;
      await tester.pump();
      expect(selectedBarIndex(tester), 3);

      NotificationService.instance.pendingTab.value = AppTab.play;
      await tester.pump();
      expect(selectedBarIndex(tester), 4);
    });
  });
}
