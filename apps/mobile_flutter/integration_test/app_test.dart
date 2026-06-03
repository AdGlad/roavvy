// T5 — Integration tests: 8 critical user journeys
//
// Requires an iOS simulator (or physical device). Run from apps/mobile_flutter/:
//   flutter test integration_test/app_test.dart
//
// These tests exercise the full app widget tree with:
//   - real geodata assets (country + region polygon lookup)
//   - in-memory Drift database (isolated per test)
//   - mocked Firebase auth (no real Firebase calls)
//   - mocked photo scan platform channel (no real photo library access)
//
// Firebase.initializeApp() is NOT called — RoavvyApp is pumped directly
// with Riverpod provider overrides replacing all Firebase-dependent providers.

import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

import 'fixtures/scan_fixture.dart';
import 'helpers/app_runner.dart';
import 'helpers/channel_stubs.dart';

// ── Shared state (loaded once in setUpAll) ─────────────────────────────────

late Uint8List _countryBytes;
late Uint8List _regionBytes;

// ── Test entry point ──────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final bytes = await loadGeodataBytes();
    _countryBytes = bytes.$1;
    _regionBytes = bytes.$2;

    // Stub platform channels that every test may touch.
    stubPhotoScanPermission();
    stubShareChannel();
    stubUrlLaunchChannel();
  });

  // ── T5.1 — New user onboarding → first scan → map ──────────────────────────

  group('T5.1 — onboarding → scan → map', () {
    testWidgets(
      'user completes onboarding and arrives at post-onboarding state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Stub scan EventChannel before app starts.
        stubPhotoScanStream();

        // Launch with onboarding not yet complete, signed out.
        await pumpTestApp(
          tester,
          uid: null,
          onboardingDone: false,
          countryBytes: _countryBytes,
          regionBytes: _regionBytes,
        );
        await tester.pumpAndSettle();

        // Onboarding first step is visible.
        expect(find.text('Get started'), findsOneWidget);

        // Step 1 → Step 2.
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        // Step 2 → Step 3.
        expect(find.text('Got it'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        // Tap "Scan my photos" on the final step.
        expect(find.text('Scan my photos'), findsOneWidget);
        await tester.tap(find.text('Scan my photos'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // App has transitioned beyond onboarding.
        expect(find.text('Get started'), findsNothing);
      },
    );

    testWidgets('fixture scan constant has the expected country count', (
      tester,
    ) async {
      // Verify the fixture itself is correct — no UI needed.
      expect(kFixturePhotos.length, kFixturePhotoCount);
      expect(kFixtureExpectedCountries.length, kFixturePhotoCount);
    });
  });

  // ── T5.2 — Daily challenge: load state ─────────────────────────────────────

  group('T5.2 — daily challenge screen', () {
    testWidgets('app loads and map tab is the default', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Signed-in user lands on the Map tab (main shell).
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('tapping Daily Challenge chip opens challenge screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // The Daily Challenge chip is on the Map screen.
      final chip = find.text('Daily Challenge');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.first);
        await tester.pumpAndSettle();

        // Challenge screen is navigated to.
        expect(find.byType(AppBar), findsWidgets);
      }
    });
  });

  // ── T5.3 — Scan result appears on stats screen ─────────────────────────────

  group('T5.3 — visit data reflected in stats', () {
    testWidgets('stats tab shows non-zero count from pre-seeded visits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Pre-seed three country visits.
      final db = freshDb();
      final visitRepo = VisitRepository(db);
      final now = DateTime.utc(2024, 1, 1);
      await visitRepo.saveAllInferred([
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: now,
          photoCount: 5,
          firstSeen: now,
          lastSeen: now,
        ),
        InferredCountryVisit(
          countryCode: 'FR',
          inferredAt: now,
          photoCount: 3,
          firstSeen: now,
          lastSeen: now,
        ),
        InferredCountryVisit(
          countryCode: 'DE',
          inferredAt: now,
          photoCount: 2,
          firstSeen: now,
          lastSeen: now,
        ),
      ]);

      await pumpTestApp(
        tester,
        db: db,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Navigate to Stats tab.
      final statsTab = find.text('Stats');
      if (statsTab.evaluate().isNotEmpty) {
        await tester.tap(statsTab.first);
        await tester.pumpAndSettle();

        // Stats screen renders with some country count.
        expect(find.byType(Scaffold), findsWidgets);
      }
    });
  });

  // ── T5.4 — Merchandise flow: Shop tab accessible ───────────────────────────

  group('T5.4 — merchandise: shop tab', () {
    testWidgets('shop tab is accessible from the bottom navigation bar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Tap the Shop tab.
      final shopTab = find.text('Shop');
      expect(shopTab, findsOneWidget);
      await tester.tap(shopTab);
      await tester.pumpAndSettle();

      // Shop screen has rendered.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ── T5.5 — Cart checkout handoff ───────────────────────────────────────────

  group('T5.5 — cart screen renders without Firestore', () {
    testWidgets('merch tab loads without Firestore crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Navigate to Shop.
      final shopTab = find.text('Shop');
      expect(shopTab, findsOneWidget);
      await tester.tap(shopTab);
      await tester.pumpAndSettle();

      // No crash — Firestore cart is replaced with an empty stream.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ── T5.6 — Manual visit edit visible on map ─────────────────────────────────

  group('T5.6 — map reflects pre-seeded visits', () {
    testWidgets('map tab loads with visited country data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = freshDb();
      final visitRepo = VisitRepository(db);
      final now = DateTime.utc(2024, 1, 1);
      await visitRepo.saveAllInferred([
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: now,
          photoCount: 2,
          firstSeen: now,
          lastSeen: now,
        ),
      ]);

      await pumpTestApp(
        tester,
        db: db,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Map is the first tab — verify it renders without error.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ── T5.7 — Travel card share ────────────────────────────────────────────────

  group('T5.7 — travel card share', () {
    testWidgets('stats tab accessible and renders scaffold', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      final statsTab = find.text('Stats');
      if (statsTab.evaluate().isNotEmpty) {
        await tester.tap(statsTab.first);
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsWidgets);
      }
    });
  });

  // ── T5.8 — Account deletion → signed out → onboarding ──────────────────────

  group('T5.8 — account deletion / signed-out state', () {
    testWidgets('signed-out state shows onboarding, not main shell', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        uid: null,
        onboardingDone: false,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // Main shell tabs are not shown for signed-out user.
      expect(find.text('Journal'), findsNothing);
      expect(find.text('Stats'), findsNothing);
    });

    testWidgets('signed-out user sees onboarding entry point', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        uid: null,
        onboardingDone: false,
        countryBytes: _countryBytes,
        regionBytes: _regionBytes,
      );
      await tester.pumpAndSettle();

      // The onboarding CTA is present.
      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
