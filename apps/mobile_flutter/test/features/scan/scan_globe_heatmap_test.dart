// M182 — Living Scan: Globe Heat Map.
//
// GlobePainter is public even though _ScanGlobeWidget (which constructs it)
// is private, so these tests find the CustomPaint rendering the scan globe
// and inspect its .painter directly — no golden images needed, matching the
// milestone's own T6 wording ("golden-free tests"). A StreamController (not
// Stream.fromIterable) keeps the scan open so it can be inspected mid-scan,
// before it completes and the globe view is replaced.

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
import 'package:mobile_flutter/features/map/globe_painter.dart';
import 'package:mobile_flutter/features/scan/scan_screen.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

GlobePainter? _findScanGlobePainter(WidgetTester tester) {
  final candidates = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((cp) => cp.painter)
      .whereType<GlobePainter>();
  return candidates.isEmpty ? null : candidates.first;
}

Future<StreamController<ScanEvent>> _startScan(
  WidgetTester tester, {
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

  final controller = StreamController<ScanEvent>();
  addTearDown(() => controller.close());

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
        heritageRepositoryProvider.overrideWithValue(HeritageRepository(db)),
        xpRepositoryProvider.overrideWithValue(XpRepository(db)),
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

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('Scan globe heat map (M182)', () {
    testWidgets(
      'GlobePainter has a null photoHeatmap before any batch has arrived',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _startScan(
          tester,
          batchResolver:
              (_) async =>
                  const BatchResult(accum: {}, photoDates: [], photoGps: []),
        );

        expect(tester.takeException(), isNull);
        final painter = _findScanGlobePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.photoHeatmap, isNull);
      },
    );

    testWidgets(
      'GlobePainter receives a non-null photoHeatmap once a batch with GPS '
      'points has been processed',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = await _startScan(
          tester,
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
                photoGps: [
                  PhotoGpsRecord(
                    countryCode: 'JP',
                    capturedAt: DateTime.utc(2023, 1, 1),
                    lat: 35.6,
                    lng: 139.7,
                  ),
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
        final painter = _findScanGlobePainter(tester);
        expect(painter, isNotNull);
        expect(painter!.photoHeatmap, isNotNull);

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
