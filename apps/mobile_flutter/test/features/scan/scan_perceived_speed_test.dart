// M183 — Perceived speed (determinate progress) widget tests.
//
// Uses a StreamController<ScanEvent> (rather than pumpApp's
// Stream.fromIterable helper in widget_test.dart) so events can be added one
// at a time, with a pump() in between, to observe the header mid-scan —
// Stream.fromIterable drains too fast against an in-memory batchResolver to
// reliably catch an intermediate frame.

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

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Pumps [ScanScreen] wired to [controller] instead of a fixed event list,
/// grants permission, and taps "Scan my photo library" so the caller can
/// then feed events one at a time via [controller].
Future<void> _startScan(
  WidgetTester tester,
  StreamController<ScanEvent> controller,
) async {
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

  final db = _makeDb();
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
          batchResolver:
              (_) async =>
                  const BatchResult(accum: {}, photoDates: [], photoGps: []),
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
  await tester.pump(); // let _scan() start listening on controller.stream
}

List<PhotoRecord> _dummyPhotos(int n) => List.generate(
  n,
  (_) => const PhotoRecord(lat: 51.5, lng: -0.1),
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('ScanScreen — determinate progress (M183)', () {
    testWidgets(
      'shows determinate bar + "N of M memories" once ScanStartedEvent '
      'arrives, updating as batches land',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = StreamController<ScanEvent>();
        addTearDown(() => controller.close());
        await _startScan(tester, controller);

        controller.add(const ScanStartedEvent(estimatedTotal: 1000));
        await tester.pump();

        // Before any photos are processed the counter is suppressed in
        // favour of the warm-up headline (T4) — but the bar is already
        // determinate at 0%, seeded by the estimate.
        expect(find.textContaining('memories'), findsNothing);
        expect(find.textContaining('Warming up'), findsOneWidget);
        final barBefore = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(barBefore.value, 0.0);

        controller.add(ScanBatchEvent(photos: _dummyPhotos(300)));
        await tester.pump();

        expect(
          find.textContaining('Reading 300 of 1,000 memories'),
          findsOneWidget,
        );
        final barAfter = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(barAfter.value, closeTo(0.3, 0.001));
      },
    );

    testWidgets(
      'caps the bar at 99% even if processed reaches the estimate before '
      'the scan actually finishes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = StreamController<ScanEvent>();
        addTearDown(() => controller.close());
        await _startScan(tester, controller);

        controller.add(const ScanStartedEvent(estimatedTotal: 100));
        await tester.pump();
        controller.add(ScanBatchEvent(photos: _dummyPhotos(100)));
        await tester.pump();

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(bar.value, closeTo(0.99, 0.001));
      },
    );

    testWidgets(
      'falls back to an indeterminate bar when no ScanStartedEvent arrives',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = StreamController<ScanEvent>();
        addTearDown(() => controller.close());
        await _startScan(tester, controller);

        controller.add(ScanBatchEvent(photos: _dummyPhotos(50)));
        await tester.pump();

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        );
        expect(bar.value, isNull);
        expect(find.textContaining('memories'), findsNothing);
      },
    );

    testWidgets('shows warm-up copy before any photos are processed', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StreamController<ScanEvent>();
      addTearDown(() => controller.close());
      await _startScan(tester, controller);

      controller.add(const ScanStartedEvent(estimatedTotal: 1000));
      await tester.pump();

      expect(find.textContaining('Warming up'), findsOneWidget);
    });

    testWidgets(
      'phase headline advances with percent complete once an estimate is '
      'known',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = StreamController<ScanEvent>();
        addTearDown(() => controller.close());
        await _startScan(tester, controller);

        controller.add(const ScanStartedEvent(estimatedTotal: 100));
        await tester.pump();

        // <33% — still "Discovering".
        controller.add(ScanBatchEvent(photos: _dummyPhotos(10)));
        await tester.pump();
        expect(find.textContaining('Discovering your world'), findsOneWidget);

        // 33-80% — "Building your travel story".
        controller.add(ScanBatchEvent(photos: _dummyPhotos(40)));
        await tester.pump();
        expect(
          find.textContaining('Building your travel story'),
          findsOneWidget,
        );

        // >80% — "Almost there".
        controller.add(ScanBatchEvent(photos: _dummyPhotos(40)));
        await tester.pump();
        expect(find.textContaining('Almost there'), findsOneWidget);
      },
    );
  });
}
