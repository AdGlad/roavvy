// M25.1 — the Studio's production front door, in the Shop.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart';
import 'package:mobile_flutter/features/merch/merch_shop_screen.dart';
import 'package:mobile_flutter/features/merch/shopify_pricing_repository.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_app.dart';
import 'package:mobile_flutter/features/studio_v2/studio_v2_screen.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roavvy_integration_test.dart' show roavvyTrips, roavvyVisits;

class _FakeAchievementRepository implements AchievementRepository {
  @override
  Future<List<String>> loadAll() async => [];

  @override
  Future<List<UnlockedAchievementRow>> loadAllRows() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget shop({
  List<TripRecord>? trips,
  List<EffectiveVisitedCountry>? visits,
  String? uid = 'uid-alice',
}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((_) => Stream<User?>.value(null)),
    currentUidProvider.overrideWithValue(uid),
    effectiveVisitsProvider.overrideWith((_) async => visits ?? roavvyVisits()),
    tripListProvider.overrideWith((_) async => trips ?? roavvyTrips()),
    continentCountProvider.overrideWith((_) async => 2),
    achievementRepositoryProvider.overrideWithValue(
      _FakeAchievementRepository(),
    ),
    merchCartProvider.overrideWith((_) => Stream.value([])),
    merchCartCountProvider.overrideWith((_) => 0),
    shopifyPricingProvider.overrideWith((_) async => throw 'no network'),
  ],
  child: const MaterialApp(home: MerchShopScreen()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the Shop offers what Roavvy already made', () {
    testWidgets('Designed for You is there, in a release build too', (
      tester,
    ) async {
      await tester.pumpWidget(shop());
      await tester.pump();

      expect(find.byKey(const Key('shop-designed-for-you')), findsOneWidget);
      expect(find.text('Designed for You'), findsOneWidget);
      expect(find.text('See your designs'), findsOneWidget);
      // It speaks about the customer's travels, not about a tool.
      expect(find.textContaining('Made from your 2 countries'), findsOneWidget);
      expect(find.textContaining('configur'), findsNothing);
    });

    testWidgets('the debug flask is gone — the real entry replaced it', (
      tester,
    ) async {
      await tester.pumpWidget(shop());
      await tester.pump();
      expect(find.byIcon(Icons.science_outlined), findsNothing);
      expect(
        kDebugMode,
        isTrue,
        reason: 'tests run in debug, where the old entry used to appear',
      );
    });

    testWidgets('nothing travelled, nothing promised', (tester) async {
      await tester.pumpWidget(shop(trips: const [], visits: const []));
      await tester.pump();
      expect(find.byKey(const Key('shop-designed-for-you')), findsNothing);
      // …and the from-scratch banner still serves that customer.
      expect(find.text('Ready to design your next shirt?'), findsOneWidget);
    });

    testWidgets('opening the Shop starts no Studio session', (tester) async {
      // The Shop is built at launch inside the shell's IndexedStack; a session
      // generates its opening designs, which is not work to do for a tab
      // nobody has tapped.
      await tester.pumpWidget(shop());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StudioV2App), findsNothing);
      expect(find.byType(StudioV2Screen), findsNothing);
    });
  });

  group('Shop → Studio', () {
    testWidgets('the card opens Instant on the real travel', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(shop());
      await tester.pump();
      await tester.tap(find.byKey(const Key('shop-designed-for-you')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.byKey(const Key('v2-instant-deck')), findsOneWidget);

      final screen = tester.widget<StudioV2Screen>(
        find.byType(StudioV2Screen),
      );
      // Real Roavvy travel, through the M25 mapping — never the fixtures.
      expect(screen.controller.allTravelledCodes.toSet(), {'pt', 'ma'});
      expect(screen.controller.allTravelledCodes, isNot(contains('us')));
      expect(
        (screen.controller.yearLo, screen.controller.yearHi),
        (2019, 2024),
      );
    });

    testWidgets('and gives the Shop back', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(shop());
      await tester.pump();
      await tester.tap(find.byKey(const Key('shop-designed-for-you')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.tap(find.byKey(const Key('v2-instant-exit')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('shop-designed-for-you')), findsOneWidget);
      expect(find.byKey(const Key('v2-instant-deck')), findsNothing);
    });
  });
}
