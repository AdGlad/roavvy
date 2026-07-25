// M186 — Living Scan: Hero Reuse & Narrative Beats.
//
// heroAssetIdsByCountry is a pure function, directly unit-testable. The year
// chapter card and landmark ribbon render visible text (unlike the photo
// thumbnails, which always fall back in the test environment), so those are
// covered with real widget assertions. Hero *reuse* itself only affects
// which assetId a (private, always-fallback-in-tests) thumbnail requests —
// covered here as a regression test that the scan still completes cleanly
// when hero rows already exist in the DB.

import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/firestore_sync_service.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/heritage/world_heritage_lookup_service.dart';
import 'package:mobile_flutter/features/scan/hero_image_repository.dart';
import 'package:mobile_flutter/features/scan/scan_screen.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

HeroImage _hero(String country, String assetId, DateTime capturedAt) =>
    HeroImage(
      id: '$country-$assetId',
      assetId: assetId,
      tripId: '$country-trip',
      countryCode: country,
      capturedAt: capturedAt,
      heroScore: 1.0,
      rank: 1,
      isUserSelected: false,
      createdAt: capturedAt,
      updatedAt: capturedAt,
    );

// Synthetic heritage site at a fixed coordinate — WorldHeritageLookupService
// is a static singleton that must be explicitly initialised (it's normally
// seeded from a bundled asset at app startup, which doesn't run in isolated
// widget tests); a small fixture keeps the ribbon test deterministic instead
// of depending on the real dataset + real-world coordinates.
const _testWhsJson = '''
[
  {
    "siteId": "test-site",
    "name": "Test Landmark",
    "countryCode": "FR",
    "latitude": 48.8584,
    "longitude": 2.2945,
    "category": "cultural",
    "region": "Test Region",
    "inscriptionYear": 1991
  }
]
''';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    WorldHeritageLookupService.init(_testWhsJson);
  });

  group('heroAssetIdsByCountry', () {
    test('maps each country to its hero assetId', () {
      final heroes = [
        _hero('JP', 'jp-hero', DateTime.utc(2023, 1, 1)),
        _hero('US', 'us-hero', DateTime.utc(2023, 2, 1)),
      ];
      final map = heroAssetIdsByCountry(heroes);
      expect(map['JP'], 'jp-hero');
      expect(map['US'], 'us-hero');
    });

    test(
      'prefers the most recently captured hero when a country has several',
      () {
        final heroes = [
          _hero('JP', 'jp-old', DateTime.utc(2020, 1, 1)),
          _hero('JP', 'jp-new', DateTime.utc(2023, 1, 1)),
        ];
        final map = heroAssetIdsByCountry(heroes);
        expect(map['JP'], 'jp-new');
      },
    );

    test('empty input yields an empty map', () {
      expect(heroAssetIdsByCountry(const []), isEmpty);
    });

    test('a country with no hero has no entry', () {
      final map = heroAssetIdsByCountry([
        _hero('JP', 'jp-hero', DateTime.utc(2023, 1, 1)),
      ]);
      expect(map.containsKey('US'), isFalse);
    });
  });

  group('ScanScreen — narrative beats + hero reuse (M186)', () {
    Future<StreamController<ScanEvent>> startScan(
      WidgetTester tester, {
      required Future<BatchResult> Function(List<PhotoRecord>) batchResolver,
      RoavvyDatabase? db,
    }) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('roavvy/photo_scan'), (
            call,
          ) async {
            if (call.method == 'requestPermission') return 3;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('roavvy/photo_scan'),
              null,
            );
      });

      final controller = StreamController<ScanEvent>();
      addTearDown(() => controller.close());

      final resolvedDb = db ?? RoavvyDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roavvyDatabaseProvider.overrideWithValue(resolvedDb),
            visitRepositoryProvider.overrideWithValue(
              VisitRepository(resolvedDb),
            ),
            achievementRepositoryProvider.overrideWithValue(
              AchievementRepository(resolvedDb),
            ),
            tripRepositoryProvider.overrideWithValue(
              TripRepository(resolvedDb),
            ),
            regionRepositoryProvider.overrideWithValue(
              RegionRepository(resolvedDb),
            ),
            heritageRepositoryProvider.overrideWithValue(
              HeritageRepository(resolvedDb),
            ),
            xpRepositoryProvider.overrideWithValue(
              XpRepository(resolvedDb),
            ),
            currentUidProvider.overrideWithValue(null),
            polygonsProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            home: ScanScreen(
              scanStarter: ({int limit = 2000}) => controller.stream,
              batchResolver: batchResolver,
              syncService: const NoOpSyncService(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Grant Access'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Scan my photo library'));
      await tester.pump();
      return controller;
    }

    testWidgets(
      'year chapter card appears when a batch crosses into a new travel '
      'year',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Keyed on the batch's first assetId so the two batches below
        // resolve to genuinely different countries/years — required for
        // the JP trip to actually close out ("stabilise") and fire its
        // year/leg events (M132's oldest-first batching model only fires a
        // trip's events once the scan moves on to a different country).
        final controller = await startScan(
          tester,
          batchResolver: (photos) async {
            final isJp = photos.first.assetId == 'jp-1';
            return BatchResult(
              accum: {
                if (isJp) 'JP': const CountryAccum(photoCount: 1),
                if (!isJp) 'FR': const CountryAccum(photoCount: 1),
              },
              photoDates: [
                PhotoDateRecord(
                  countryCode: isJp ? 'JP' : 'FR',
                  capturedAt:
                      isJp ? DateTime.utc(2019, 1, 1) : DateTime.utc(2021, 6, 1),
                  assetId: photos.first.assetId,
                ),
              ],
              photoGps: [],
            );
          },
        );

        controller.add(
          ScanBatchEvent(
            photos: [PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-1')],
          ),
        );
        controller.add(
          ScanBatchEvent(
            photos: [PhotoRecord(lat: 48.8, lng: 2.3, assetId: 'fr-1')],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('2019'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'landmark name-drop ribbon appears for a newly detected heritage site',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Keyed on the batch's first assetId, matching the year-card test's
        // approach — the FR/heritage trip must close out ("stabilise") for
        // its heritage overlay (and thus the ribbon) to fire.
        final controller = await startScan(
          tester,
          batchResolver: (photos) async {
            final isFr = photos.first.assetId == 'fr-1';
            return BatchResult(
              accum: {
                if (isFr) 'FR': const CountryAccum(photoCount: 1),
                if (!isFr) 'JP': const CountryAccum(photoCount: 1),
              },
              photoDates: [
                PhotoDateRecord(
                  countryCode: isFr ? 'FR' : 'JP',
                  capturedAt: DateTime.utc(2023, 1, 1),
                  assetId: photos.first.assetId,
                ),
              ],
              // Near the synthetic Test Landmark seeded in setUpAll — only
              // the FR batch resolves close enough to match.
              photoGps: isFr
                  ? [
                      PhotoGpsRecord(
                        countryCode: 'FR',
                        capturedAt: DateTime.utc(2023, 1, 1),
                        lat: 48.8584,
                        lng: 2.2945,
                      ),
                    ]
                  : const [],
            );
          },
        );

        controller.add(
          ScanBatchEvent(
            photos: [
              PhotoRecord(lat: 48.8584, lng: 2.2945, assetId: 'fr-1'),
            ],
          ),
        );
        controller.add(
          ScanBatchEvent(
            photos: [PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-1')],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.textContaining("You've been to"), findsWidgets);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'scan completes without error when an existing hero already exists '
      'for a newly-discovered country (hero-reuse path exercised)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final db = RoavvyDatabase(NativeDatabase.memory());
        await HeroImageRepository(db).upsertHeroesForTrip('JP-trip', [
          _hero('JP', 'jp-existing-hero', DateTime.utc(2020, 1, 1)),
        ]);

        final controller = await startScan(
          tester,
          db: db,
          batchResolver:
              (_) async => BatchResult(
                accum: {'JP': const CountryAccum(photoCount: 1)},
                photoDates: [
                  PhotoDateRecord(
                    countryCode: 'JP',
                    capturedAt: DateTime.utc(2023, 1, 1),
                    assetId: 'jp-1',
                  ),
                ],
                photoGps: [],
              ),
        );

        controller.add(
          ScanBatchEvent(
            photos: [PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-1')],
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Japan'), findsWidgets);

        // Let the first-country cinematic's fade-in Future.delayed (M131)
        // fire before unmounting, then unmount so the globe's repeating
        // spin/pulse AnimationControllers dispose their timers before the
        // test framework's pending-timer invariant check runs at teardown.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
