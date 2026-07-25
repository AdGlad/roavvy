// M181 — Real photos in the discovery feed.
//
// firstRepresentativeAssetId is a pure function, directly unit-testable.
// The chip/cinematic thumbnail widgets themselves are private and always
// fall back to the flag emoji in the test environment (no real PhotoKit
// plugin registered), so these widget tests verify the surrounding
// integration doesn't regress: the scan still completes, the discovery feed
// still renders country names, and the first-country cinematic still fires
// with an entry that carries a representativeAssetId — the actual thumbnail
// bytes are covered by manual device QA per the milestone's Definition of
// Done ("manual QA on a real device with an iCloud-only photo").

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
import 'package:mobile_flutter/features/scan/scan_screen.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('firstRepresentativeAssetId', () {
    PhotoDateRecord d(String code, {String? assetId}) => PhotoDateRecord(
      countryCode: code,
      capturedAt: DateTime.utc(2023, 1, 1),
      assetId: assetId,
    );

    test('returns the first matching record with a non-null assetId', () {
      final dates = [
        d('US', assetId: 'us-1'),
        d('JP', assetId: 'jp-1'),
        d('JP', assetId: 'jp-2'),
      ];
      expect(firstRepresentativeAssetId(dates, 'JP'), 'jp-1');
    });

    test('skips records with a null assetId for the target country', () {
      final dates = [
        d('JP'), // no assetId
        d('JP', assetId: 'jp-2'),
      ];
      expect(firstRepresentativeAssetId(dates, 'JP'), 'jp-2');
    });

    test('returns null when no record matches the country', () {
      final dates = [d('US', assetId: 'us-1')];
      expect(firstRepresentativeAssetId(dates, 'JP'), isNull);
    });

    test('returns null for an empty list', () {
      expect(firstRepresentativeAssetId(const [], 'JP'), isNull);
    });

    test('preserves list order — first match wins even with duplicates', () {
      final dates = [
        d('JP', assetId: 'jp-first'),
        d('JP', assetId: 'jp-second'),
      ];
      expect(firstRepresentativeAssetId(dates, 'JP'), 'jp-first');
    });
  });

  group('ScanScreen — discovery feed with representative photos (M181)', () {
    RoavvyDatabase makeDb() => RoavvyDatabase(NativeDatabase.memory());

    Future<void> pumpScan(
      WidgetTester tester, {
      required List<ScanEvent> scanEvents,
      required Future<BatchResult> Function(List<PhotoRecord>) batchResolver,
    }) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('roavvy/photo_scan'), (
            call,
          ) async {
            if (call.method == 'requestPermission') return 3; // authorized
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('roavvy/photo_scan'),
              null,
            );
      });

      final db = makeDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roavvyDatabaseProvider.overrideWithValue(db),
            visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
            achievementRepositoryProvider.overrideWithValue(
              AchievementRepository(db),
            ),
            tripRepositoryProvider.overrideWithValue(TripRepository(db)),
            regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
            heritageRepositoryProvider.overrideWithValue(
              HeritageRepository(db),
            ),
            xpRepositoryProvider.overrideWithValue(XpRepository(db)),
            currentUidProvider.overrideWithValue(null),
            polygonsProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            home: ScanScreen(
              scanStarter: ({int limit = 2000}) => Stream.fromIterable(scanEvents),
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
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets(
      'scan with a photo-carrying discovery completes and renders the '
      'country in the feed without error',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpScan(
          tester,
          scanEvents: [
            ScanBatchEvent(
              photos: [PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-1')],
            ),
            const ScanDoneEvent(inspected: 1, withLocation: 1),
          ],
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

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Japan'), findsWidgets);
      },
    );

    testWidgets(
      'first-country cinematic fires with "Welcome to your world" for a '
      'fresh scan (no pre-existing countries)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // A StreamController (rather than pumpScan's Stream.fromIterable)
        // so the first batch is delivered strictly AFTER _ScanningView has
        // already mounted with an empty liveNewEntries list — the
        // cinematic trigger lives in didUpdateWidget, comparing against the
        // previous entry count, so it needs a genuine 0 -> 1 transition
        // rather than the entry being present at initial mount.
        final controller = StreamController<ScanEvent>();
        addTearDown(() => controller.close());

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('roavvy/photo_scan'),
              (call) async {
                if (call.method == 'requestPermission') return 3;
                return null;
              },
            );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('roavvy/photo_scan'),
                null,
              );
        });

        final db = RoavvyDatabase(NativeDatabase.memory());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roavvyDatabaseProvider.overrideWithValue(db),
              visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
              achievementRepositoryProvider.overrideWithValue(
                AchievementRepository(db),
              ),
              tripRepositoryProvider.overrideWithValue(TripRepository(db)),
              regionRepositoryProvider.overrideWithValue(
                RegionRepository(db),
              ),
              heritageRepositoryProvider.overrideWithValue(
                HeritageRepository(db),
              ),
              xpRepositoryProvider.overrideWithValue(XpRepository(db)),
              currentUidProvider.overrideWithValue(null),
              polygonsProvider.overrideWithValue(const []),
            ],
            child: MaterialApp(
              home: ScanScreen(
                scanStarter: ({int limit = 2000}) => controller.stream,
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
        // _ScanningView mounts now, with liveNewEntries still empty.
        await tester.pump();

        controller.add(
          ScanBatchEvent(
            photos: [PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-1')],
          ),
        );
        await tester.pump();
        // Let the cinematic's fade-in timer fire (M131).
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Welcome to your world'), findsOneWidget);
      },
    );
  });
}
