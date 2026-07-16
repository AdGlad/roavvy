// T5 — MerchShopScreen redesign widget tests (M145/M169)
//
// Covers:
//   1. MerchIdentityHeader renders identity name and stats from mock providers
//   2. MerchReadyToDesignSection shows shimmer cards while loading
//   3. MerchCollectionsSection shows correct number of dynamic collections
//   4. MerchShopScreen renders primary sections in scroll order

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/features/merch/merch_shop_screen.dart';
import 'package:mobile_flutter/features/merch/merch_cart_screen.dart';
import 'package:mobile_flutter/features/merch/merch_orders_screen.dart';
import 'package:mobile_flutter/features/merch/widgets/merch_identity_header.dart';
import 'package:mobile_flutter/features/merch/widgets/merch_ready_to_design_section.dart';
import 'package:mobile_flutter/features/merch/widgets/merch_collections_section.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeAchievementRepository implements AchievementRepository {
  @override
  Future<List<String>> loadAll() async => [];

  @override
  Future<List<UnlockedAchievementRow>> loadAllRows() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _visits5 = List.generate(
  5,
  (i) => EffectiveVisitedCountry(
    countryCode: ['FR', 'DE', 'ES', 'IT', 'GB'][i],
    hasPhotoEvidence: true,
    firstSeen: DateTime(2025, 3, 1),
    lastSeen: DateTime(2025, 3, 1),
  ),
);

// ── Provider overrides ────────────────────────────────────────────────────────

List<Override> _baseOverrides() {
  return [
    effectiveVisitsProvider.overrideWith((ref) async => _visits5),
    continentCountProvider.overrideWith((ref) async => 2),
    tripListProvider.overrideWith((ref) async => <TripRecord>[]),
    earliestVisitYearProvider.overrideWith((ref) async => 2023),
    achievementRepositoryProvider.overrideWithValue(_FakeAchievementRepository()),
    currentUidProvider.overrideWithValue(null),
    merchCartProvider.overrideWith((ref) => Stream.value([])),
    merchOrdersProvider.overrideWith((ref) async => <MerchOrderSummary>[]),
  ];
}

Widget _wrap(Widget child, {List<Override>? overrides}) => ProviderScope(
      overrides: overrides ?? _baseOverrides(),
      child: MaterialApp(home: child),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MerchIdentityHeader', () {
    testWidgets('renders identity name and stats once providers resolve',
        (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: MerchIdentityHeader())));
      // Let FutureProviders resolve.
      await tester.pumpAndSettle();

      // Identity emoji + displayName must appear (resolved from 5 countries).
      // TravelIdentityInfo will emit some non-empty displayName.
      expect(find.byType(MerchIdentityHeader), findsOneWidget);
      // Stats label contains "5 countries".
      expect(find.textContaining('5 countries'), findsOneWidget);
      // Should show the "since 2023" part.
      expect(find.textContaining('since 2023'), findsOneWidget);
    });

    testWidgets('shows shimmer while loading', (tester) async {
      // Override with providers that never resolve (no pending timers).
      final overrides = [
        effectiveVisitsProvider.overrideWith(
          (ref) => Completer<List<EffectiveVisitedCountry>>().future,
        ),
        continentCountProvider.overrideWith(
          (ref) => Completer<int>().future,
        ),
        tripListProvider.overrideWith(
          (ref) => Completer<List<TripRecord>>().future,
        ),
        earliestVisitYearProvider.overrideWith(
          (ref) => Completer<int?>().future,
        ),
        achievementRepositoryProvider
            .overrideWithValue(_FakeAchievementRepository()),
      ];
      await tester.pumpWidget(_wrap(
        const Scaffold(body: MerchIdentityHeader()),
        overrides: overrides,
      ));
      // Only one frame — providers haven't resolved yet.
      await tester.pump();

      // Shimmer placeholder containers are rendered.
      expect(find.byType(MerchIdentityHeader), findsOneWidget);
      // No real stats text yet.
      expect(find.textContaining('countries'), findsNothing);
    });
  });

  group('MerchReadyToDesignSection', () {
    testWidgets('shows shimmer cards while data is loading', (tester) async {
      final overrides = [
        effectiveVisitsProvider.overrideWith(
          (ref) => Completer<List<EffectiveVisitedCountry>>().future,
        ),
        tripListProvider.overrideWith(
          (ref) => Completer<List<TripRecord>>().future,
        ),
        achievementRepositoryProvider
            .overrideWithValue(_FakeAchievementRepository()),
      ];
      await tester.pumpWidget(_wrap(
        const Scaffold(body: MerchReadyToDesignSection()),
        overrides: overrides,
      ));
      await tester.pump();

      // Shimmer: 3 placeholder containers shown in a horizontal ListView.
      final listViews = find.byType(ListView);
      expect(listViews, findsOneWidget);
      // 3 shimmer Container children.
      final containers = find.descendant(
        of: listViews,
        matching: find.byType(Container),
      );
      expect(containers, findsNWidgets(3));
    });

    testWidgets('shows design cards once data resolves', (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(body: MerchReadyToDesignSection())),
      );
      await tester.pumpAndSettle();

      // With 5 visits, at minimum the "Grand Tour" recommendation is shown.
      expect(find.textContaining('Grand Tour'), findsOneWidget);
      expect(find.text('Design →'), findsWidgets);
    });
  });

  group('MerchCollectionsSection', () {
    testWidgets('shows "All Countries" collection for non-empty visits',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(body: MerchCollectionsSection())),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Countries'), findsOneWidget);
    });

    testWidgets('shows year-based collection when current-year visits exist',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // All 5 visits have firstSeen in current year.
      final thisYear = DateTime.now().year;
      final currentYearVisits = List.generate(
        5,
        (i) => EffectiveVisitedCountry(
          countryCode: ['FR', 'DE', 'ES', 'IT', 'GB'][i],
          hasPhotoEvidence: true,
          firstSeen: DateTime(thisYear, 3, 1),
          lastSeen: DateTime(thisYear, 3, 1),
        ),
      );
      final overrides = [
        effectiveVisitsProvider.overrideWith((ref) async => currentYearVisits),
        continentCountProvider.overrideWith((ref) async => 2),
        tripListProvider.overrideWith((ref) async => <TripRecord>[]),
        earliestVisitYearProvider.overrideWith((ref) async => thisYear),
        achievementRepositoryProvider
            .overrideWithValue(_FakeAchievementRepository()),
        currentUidProvider.overrideWithValue(null),
        merchCartProvider.overrideWith((ref) => Stream.value([])),
        merchOrdersProvider.overrideWith((ref) async => <MerchOrderSummary>[]),
      ];
      await tester.pumpWidget(
        _wrap(const Scaffold(body: MerchCollectionsSection()), overrides: overrides),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('$thisYear Travels'), findsOneWidget);
    });
  });

  group('MerchShopScreen', () {
    testWidgets('renders design banner and collections section (M169)',
        (tester) async {
      await tester.pumpWidget(_wrap(const MerchShopScreen()));
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Shop'), findsOneWidget);

      // Design entry banner CTA text.
      expect(find.text('Design a shirt →'), findsOneWidget);

      // Collections section.
      expect(find.byType(MerchCollectionsSection), findsOneWidget);
    });
  });
}
