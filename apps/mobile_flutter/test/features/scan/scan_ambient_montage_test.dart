// M184 — Living Scan: Ambient Photo Montage.
//
// extendMontageQueue is a pure function, directly unit-testable. _ScanMontage
// itself is private and (like M181's _ScanPhotoThumbnail) always falls back
// in the test environment since no real PhotoKit plugin is registered, so
// its cycling/Ken-Burns/reduce-motion behaviour isn't visually distinguishable
// here — these widget tests instead verify the surrounding scan flow doesn't
// regress with the montage wired in, both below and above the sparse-library
// threshold.

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

  group('extendMontageQueue', () {
    PhotoDateRecord d(String? assetId) => PhotoDateRecord(
      countryCode: 'JP',
      capturedAt: DateTime.utc(2023, 1, 1),
      assetId: assetId,
    );

    test('appends assetIds in order', () {
      final queue = <String>[];
      extendMontageQueue([d('a'), d('b'), d('c')], queue);
      expect(queue, ['a', 'b', 'c']);
    });

    test('ignores records with a null assetId', () {
      final queue = <String>[];
      extendMontageQueue([d('a'), d(null), d('b')], queue);
      expect(queue, ['a', 'b']);
    });

    test('trims to the cap, keeping the most recent entries', () {
      final queue = <String>[];
      extendMontageQueue(
        [for (var i = 0; i < 5; i++) d('id$i')],
        queue,
        cap: 3,
      );
      expect(queue, ['id2', 'id3', 'id4']);
    });

    test('accumulates and trims across multiple calls', () {
      final queue = <String>[];
      extendMontageQueue([d('a'), d('b')], queue, cap: 3);
      expect(queue, ['a', 'b']);
      extendMontageQueue([d('c'), d('d')], queue, cap: 3);
      expect(queue, ['b', 'c', 'd']);
    });

    test('default cap matches kMontageQueueCap', () {
      final queue = <String>[];
      extendMontageQueue(
        [for (var i = 0; i < kMontageQueueCap + 10; i++) d('id$i')],
        queue,
      );
      expect(queue.length, kMontageQueueCap);
      expect(queue.last, 'id${kMontageQueueCap + 9}');
    });

    test('no-op for an empty batch', () {
      final queue = <String>['existing'];
      extendMontageQueue(const [], queue);
      expect(queue, ['existing']);
    });
  });

  group('ScanScreen — ambient montage integration (M184)', () {
    Future<void> pumpScan(
      WidgetTester tester, {
      required List<ScanEvent> scanEvents,
      required Future<BatchResult> Function(List<PhotoRecord>) batchResolver,
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
              scanStarter:
                  ({int limit = 2000}) => Stream.fromIterable(scanEvents),
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
      'scan completes without error when few photos are collected '
      '(below the sparse threshold — montage renders nothing)',
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
      },
    );

    testWidgets(
      'scan completes without error when many photos accumulate '
      '(above the sparse threshold — montage is active)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final photos = [
          for (var i = 0; i < 10; i++)
            PhotoRecord(lat: 35.6, lng: 139.7, assetId: 'jp-$i'),
        ];

        await pumpScan(
          tester,
          scanEvents: [
            ScanBatchEvent(photos: photos),
            const ScanDoneEvent(inspected: 10, withLocation: 10),
          ],
          batchResolver:
              (_) async => BatchResult(
                accum: {'JP': const CountryAccum(photoCount: 10)},
                photoDates: [
                  for (var i = 0; i < 10; i++)
                    PhotoDateRecord(
                      countryCode: 'JP',
                      capturedAt: DateTime.utc(2023, 1, 1),
                      assetId: 'jp-$i',
                    ),
                ],
                photoGps: [],
              ),
        );
        // Let at least one montage advance tick fire.
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
