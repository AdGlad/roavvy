// T4 — MerchDesignEntryScreen + _DesignEntryBanner widget tests (M140)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart';
import 'package:mobile_flutter/features/merch/merch_design_entry_screen.dart';
import 'package:mobile_flutter/features/merch/merch_shop_screen.dart';
import 'package:shared_models/shared_models.dart';

class _FakeAchievementRepository implements AchievementRepository {
  @override
  Future<List<String>> loadAll() async => [];

  @override
  Future<List<UnlockedAchievementRow>> loadAllRows() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fixture helpers ────────────────────────────────────────────────────────────

EffectiveVisitedCountry _visit(String code) => EffectiveVisitedCountry(
  countryCode: code,
  hasPhotoEvidence: true,
  photoCount: 1,
);

List<EffectiveVisitedCountry> _visits(List<String> codes) =>
    codes.map(_visit).toList();

Widget _pumpShopScreen({
  required List<EffectiveVisitedCountry> visits,
  int continentCount = 2,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUidProvider.overrideWithValue('uid-test'),
      effectiveVisitsProvider.overrideWith(
        (_) => Future<List<EffectiveVisitedCountry>>.value(visits),
      ),
      continentCountProvider.overrideWith(
        (_) => Future<int>.value(continentCount),
      ),
      tripListProvider.overrideWith(
        (_) => Future<List<TripRecord>>.value([]),
      ),
      achievementRepositoryProvider.overrideWithValue(
        _FakeAchievementRepository(),
      ),
      merchCartProvider.overrideWith((_) => Stream.value([])),
      merchCartCountProvider.overrideWith((_) => 0),
    ],
    child: const MaterialApp(home: MerchShopScreen()),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('_DesignEntryBanner', () {
    testWidgets('renders country and continent count from providers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpShopScreen(visits: _visits(['GB', 'FR', 'DE']), continentCount: 1),
      );
      await tester.pump(); // settle providers

      expect(find.text('Ready to design your next shirt?'), findsOneWidget);
      expect(find.textContaining('3 countries'), findsWidgets);
      expect(find.textContaining('1 continent'), findsWidgets);
    });

    testWidgets('"Design a shirt →" tap opens MerchDesignEntryScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpShopScreen(visits: _visits(['GB', 'FR'])),
      );
      await tester.pump();

      await tester.tap(find.text('Design a shirt →'));
      await tester.pumpAndSettle();

      expect(find.byType(MerchDesignEntryScreen), findsOneWidget);
    });
  });

  group('MerchDesignEntryScreen', () {
    testWidgets('Europe chip updates CTA to show filtered country count', (
      tester,
    ) async {
      // FR is in Europe, JP is in Asia.
      final visits = [
        EffectiveVisitedCountry(
          countryCode: 'FR',
          hasPhotoEvidence: true,
          photoCount: 1,
        ),
        EffectiveVisitedCountry(
          countryCode: 'JP',
          hasPhotoEvidence: true,
          photoCount: 1,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveVisitsProvider.overrideWith(
              (_) => Future<List<EffectiveVisitedCountry>>.value(visits),
            ),
            tripListProvider.overrideWith(
              (_) => Future<List<TripRecord>>.value([]),
            ),
          ],
          child: const MaterialApp(home: MerchDesignEntryScreen()),
        ),
      );
      await tester.pump();

      // Initially all 2 countries selected.
      expect(find.textContaining('Design with 2 countries'), findsOneWidget);

      // Tap "Europe" chip — should select only FR.
      await tester.tap(find.text('Europe'));
      await tester.pump();

      expect(find.textContaining('Design with 1 country'), findsOneWidget);
    });
  });
}
