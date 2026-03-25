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
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/data/xp_repository.dart';
import 'package:mobile_flutter/features/scan/scan_screen.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

/// Pumps [ScanScreen] with an in-memory repository and optional mocks.
///
/// [methodHandler] handles MethodChannel calls (requestPermission).
/// [scanEvents] is the list of [ScanEvent]s the injected [ScanScreen.scanStarter]
///   will emit. Bypasses EventChannel entirely so no platform-channel wiring is
///   needed in tests.
/// [batchResolver] is passed to [ScanScreen] so tests can inject country results.
Future<void> pumpApp(
  WidgetTester tester, {
  required Future<Object?> Function(MethodCall) methodHandler,
  List<ScanEvent>? scanEvents,
  VisitRepository? repository,
  AchievementRepository? achievementRepository,
  Future<BatchResult> Function(List<PhotoRecord>)? batchResolver,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('roavvy/photo_scan'),
    methodHandler,
  );

  Stream<ScanEvent> Function({int limit})? scanStarter;
  if (scanEvents != null) {
    final events = scanEvents;
    scanStarter = ({int limit = 2000}) => Stream.fromIterable(events);
  }

  final db = _makeDb();
  final visitRepo = repository ?? VisitRepository(db);
  final achievementRepo = achievementRepository ?? AchievementRepository(db);
  final tripRepo = TripRepository(db);
  final regionRepo = RegionRepository(db);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visitRepositoryProvider.overrideWithValue(visitRepo),
        achievementRepositoryProvider.overrideWithValue(achievementRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
        regionRepositoryProvider.overrideWithValue(regionRepo),
        xpRepositoryProvider.overrideWithValue(XpRepository(db)),
        currentUidProvider.overrideWithValue(null),
        polygonsProvider.overrideWithValue(const []),
      ],
      child: MaterialApp(
        home: ScanScreen(
          batchResolver: batchResolver,
          scanStarter: scanStarter,
          syncService: const NoOpSyncService(),
        ),
      ),
    ),
  );
  // Wait for _loadPersisted() to finish so the loading spinner clears.
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('roavvy/photo_scan'), null);
  });

  // ── ScanStats unit tests ───────────────────────────────────────────────────

  group('ScanStats', () {
    test('withoutLocation is derived correctly', () {
      const stats =
          ScanStats(inspected: 100, withLocation: 60, geocodeSuccesses: 55);
      expect(stats.withoutLocation, 40);
    });

    test('geocodeFailures is derived correctly', () {
      const stats =
          ScanStats(inspected: 100, withLocation: 60, geocodeSuccesses: 55);
      expect(stats.geocodeFailures, 5);
    });

    test('all-zero case is valid', () {
      const stats =
          ScanStats(inspected: 0, withLocation: 0, geocodeSuccesses: 0);
      expect(stats.withoutLocation, 0);
    });

    test('fromMap parses legacy channel payload', () {
      final stats = ScanStats.fromMap({
        'inspected': 50,
        'withLocation': 30,
        'geocodeSuccesses': 28,
      });
      expect(stats.inspected, 50);
      expect(stats.withLocation, 30);
      expect(stats.withoutLocation, 20);
      expect(stats.geocodeSuccesses, 28);
    });
  });

  // ── ScanEvent unit tests ───────────────────────────────────────────────────

  group('ScanBatchEvent', () {
    test('parses photos list from map', () {
      final event = ScanEvent.fromMap({
        'type': 'batch',
        'photos': [
          {'lat': 51.5, 'lng': -0.12, 'capturedAt': '2023-08-14T10:22:00Z'},
          {'lat': 40.7, 'lng': -74.0},
        ],
      });
      expect(event, isA<ScanBatchEvent>());
      final batch = event as ScanBatchEvent;
      expect(batch.photos.length, 2);
      expect(batch.photos[0].lat, 51.5);
      expect(batch.photos[0].lng, -0.12);
      expect(batch.photos[0].capturedAt, isNotNull);
      expect(batch.photos[1].capturedAt, isNull);
    });
  });

  group('ScanDoneEvent', () {
    test('parses counters from map', () {
      final event = ScanEvent.fromMap({
        'type': 'done',
        'inspected': 500,
        'withLocation': 320,
      });
      expect(event, isA<ScanDoneEvent>());
      final done = event as ScanDoneEvent;
      expect(done.inspected, 500);
      expect(done.withLocation, 320);
    });

    test('defaults missing counters to zero', () {
      final event = ScanEvent.fromMap({'type': 'done'});
      final done = event as ScanDoneEvent;
      expect(done.inspected, 0);
      expect(done.withLocation, 0);
    });
  });

  group('PhotoRecord', () {
    test('parses lat/lng/capturedAt', () {
      final r = PhotoRecord.fromMap(
          {'lat': 48.85, 'lng': 2.35, 'capturedAt': '2024-06-01T12:00:00Z'});
      expect(r.lat, 48.85);
      expect(r.lng, 2.35);
      expect(r.capturedAt, DateTime.utc(2024, 6, 1, 12));
    });

    test('capturedAt is null when absent', () {
      final r = PhotoRecord.fromMap({'lat': 0.0, 'lng': 0.0});
      expect(r.capturedAt, isNull);
    });
  });

  // ── resolveBatch unit tests ────────────────────────────────────────────────

  group('resolveBatch', () {
    test('accumulates photos by country code', () {
      final photos = [
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: DateTime.utc(2023, 1, 1)),
        PhotoRecord(lat: 51.6, lng: -0.2, capturedAt: DateTime.utc(2023, 6, 1)),
        PhotoRecord(lat: 40.7, lng: -74.0, capturedAt: DateTime.utc(2022, 3, 1)),
      ];
      // Simple resolver: lat > 45 → GB, else → US
      final result = resolveBatch(photos, (lat, lng) => lat > 45 ? 'GB' : 'US');
      expect(result.accum['GB']!.photoCount, 2);
      expect(result.accum['US']!.photoCount, 1);
    });

    test('firstSeen and lastSeen are set from capturedAt', () {
      final t1 = DateTime.utc(2022, 1, 1);
      final t2 = DateTime.utc(2023, 6, 15);
      final photos = [
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: t2),
        PhotoRecord(lat: 51.6, lng: -0.2, capturedAt: t1),
      ];
      final result = resolveBatch(photos, (_, __) => 'GB');
      expect(result.accum['GB']!.firstSeen, t1);
      expect(result.accum['GB']!.lastSeen, t2);
    });

    test('skips photos when resolver returns null', () {
      final photos = [
        PhotoRecord(lat: 0.0, lng: 0.0),
        PhotoRecord(lat: 51.5, lng: -0.1),
      ];
      final result = resolveBatch(photos, (lat, _) => lat > 45 ? 'GB' : null);
      expect(result.accum.containsKey('GB'), isTrue);
      expect(result.accum.length, 1);
    });

    test('photoDates contains one entry per resolved photo with capturedAt', () {
      final t1 = DateTime.utc(2023, 1, 1);
      final t2 = DateTime.utc(2023, 6, 1);
      final photos = [
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: t1),
        PhotoRecord(lat: 51.6, lng: -0.2, capturedAt: t2),
        PhotoRecord(lat: 40.7, lng: -74.0), // null capturedAt — excluded
      ];
      final result = resolveBatch(photos, (lat, _) => lat > 45 ? 'GB' : 'US');
      expect(result.photoDates, hasLength(2));
      expect(result.photoDates.every((r) => r.countryCode == 'GB'), isTrue);
    });

    test('photoDates excludes photos where resolver returns null', () {
      final photos = [
        PhotoRecord(lat: 0.0, lng: 0.0, capturedAt: DateTime.utc(2023, 1, 1)),
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: DateTime.utc(2023, 2, 1)),
      ];
      final result = resolveBatch(photos, (lat, _) => lat > 45 ? 'GB' : null);
      expect(result.photoDates, hasLength(1));
      expect(result.photoDates.first.countryCode, 'GB');
    });

    test('deduplicates resolver calls for photos in the same 0.5° bucket', () {
      var callCount = 0;
      final photos = [
        // These two snap to the same 0.5° bucket
        PhotoRecord(lat: 51.1, lng: -0.1),
        PhotoRecord(lat: 51.2, lng: -0.2),
        // This one is in a different bucket
        PhotoRecord(lat: 40.7, lng: -74.0),
      ];
      resolveBatch(photos, (lat, lng) {
        callCount++;
        return 'XX';
      });
      expect(callCount, 2); // two unique buckets, not three photos
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('ScanScreen — initial state', () {
    testWidgets('shows permission button and disabled scan button', (tester) async {
      await pumpApp(tester, methodHandler: (_) async => null);
      expect(find.text('Grant Access'), findsOneWidget);
      expect(find.text('Scan my photo library'), findsOneWidget);
      final scanBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Scan my photo library'),
      );
      expect(scanBtn.onPressed, isNull);
    });
  });

  group('ScanScreen — after scan with results', () {
    testWidgets('shows stats card after scan completes', (tester) async {
      // Pre-populate GB + US so the scan finds no new countries and
      // ScanSummaryScreen is not pushed (ADR-059).
      final repo = _makeRepo();
      await repo.saveInferred(InferredCountryVisit(
          countryCode: 'GB', inferredAt: DateTime.utc(2025), photoCount: 45));
      await repo.saveInferred(InferredCountryVisit(
          countryCode: 'US', inferredAt: DateTime.utc(2025), photoCount: 30));

      await pumpApp(
        tester,
        repository: repo,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3; // authorized
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [
            PhotoRecord(lat: 51.5, lng: -0.12),
            PhotoRecord(lat: 40.7, lng: -74.0),
          ]),
          const ScanDoneEvent(inspected: 120, withLocation: 90),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {
            'GB': CountryAccum(photoCount: 45),
            'US': CountryAccum(photoCount: 30),
          },
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.text('120'), findsOneWidget); // photos scanned
      expect(find.text('90'), findsOneWidget);  // with location
      expect(find.text('2'), findsOneWidget);   // countries detected
    });

    testWidgets('shows country list with ISO codes', (tester) async {
      // Pre-populate US + GB so the scan finds no new countries.
      final repo = _makeRepo();
      await repo.saveInferred(InferredCountryVisit(
          countryCode: 'US', inferredAt: DateTime.utc(2025), photoCount: 50));
      await repo.saveInferred(InferredCountryVisit(
          countryCode: 'GB', inferredAt: DateTime.utc(2025), photoCount: 22));

      await pumpApp(
        tester,
        repository: repo,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [
            PhotoRecord(lat: 40.7, lng: -74.0, capturedAt: DateTime.utc(2023, 6, 1)),
            PhotoRecord(lat: 51.5, lng: -0.12, capturedAt: DateTime.utc(2022, 3, 15)),
          ]),
          const ScanDoneEvent(inspected: 100, withLocation: 72),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {
            'US': CountryAccum(photoCount: 50),
            'GB': CountryAccum(photoCount: 22),
          },
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text('2 countries visited'), findsOneWidget);
      expect(find.text('US'), findsOneWidget);
      expect(find.text('50 photos'), findsOneWidget);
      expect(find.text('GB'), findsOneWidget);
      expect(find.text('22 photos'), findsOneWidget);
    });

    testWidgets('shows Review & Edit button after scan returns countries',
        (tester) async {
      // Pre-populate JP so the scan finds no new countries.
      final repo = _makeRepo();
      await repo.saveInferred(InferredCountryVisit(
          countryCode: 'JP', inferredAt: DateTime.utc(2025), photoCount: 5));

      await pumpApp(
        tester,
        repository: repo,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 35.7, lng: 139.7)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {'JP': CountryAccum(photoCount: 5)},
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text('Review & Edit'), findsOneWidget);
    });

    testWidgets('shows empty hint when scan returns no geotagged photos',
        (tester) async {
      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [const ScanDoneEvent(inspected: 50, withLocation: 0)],
        batchResolver: (_) async => BatchResult(accum: {}, photoDates: []),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.textContaining('No geotagged photos'), findsOneWidget);
    });
  });

  // ── Task 13: Post-scan result summary ─────────────────────────────────────

  group('ScanScreen — post-scan result summary', () {
    testWidgets('shows "You\'re up to date" when no new countries found',
        (tester) async {
      final repo = _makeRepo();
      // Pre-populate GB so it already exists in the pre-scan snapshot.
      await repo.clearAndSaveAllInferred([
        InferredCountryVisit(
          countryCode: 'GB',
          inferredAt: DateTime.utc(2024),
          photoCount: 10,
        ),
      ]);

      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3; // authorized
          return null;
        },
        repository: repo,
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 51.5, lng: -0.12)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {'GB': CountryAccum(photoCount: 5)},
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text("You're up to date"), findsOneWidget);
    });

    testWidgets('pushes ScanSummaryScreen when a new country is detected',
        (tester) async {
      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 51.5, lng: -0.12)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {'GB': CountryAccum(photoCount: 5)},
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      // ScanSummaryScreen is pushed (ADR-059); shows new-country summary.
      expect(find.textContaining('new country discovered'), findsOneWidget);
      expect(find.text('United Kingdom'), findsWidgets);
    });

    testWidgets('preserves empty hint and no result banner when no geotagged photos',
        (tester) async {
      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [const ScanDoneEvent(inspected: 20, withLocation: 0)],
        batchResolver: (_) async => BatchResult(accum: {}, photoDates: []),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No geotagged photos'), findsOneWidget);
      expect(find.text("You're up to date"), findsNothing);
    });
  });

  // ── Task 25: Achievement SnackBar ──────────────────────────────────────────

  group('ScanScreen — post-scan navigation', () {
    testWidgets('ScanSummaryScreen is pushed when new country found (ADR-059)',
        (tester) async {
      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 51.5, lng: -0.12)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {'GB': CountryAccum(photoCount: 5)},
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      // ScanSummaryScreen is pushed with the new country (ADR-059).
      // SnackBars are no longer shown — achievements appear in ScanSummaryScreen.
      expect(find.textContaining('new country discovered'), findsOneWidget);
    });

    testWidgets('no SnackBar when achievement already unlocked', (tester) async {
      final db = _makeDb();
      final visitRepo = VisitRepository(db);
      final achievementRepo = AchievementRepository(db);

      // Pre-unlock countries_1 and mark clean (simulating prior sync).
      await achievementRepo.upsertAll({'countries_1'}, DateTime.utc(2025));
      await achievementRepo.markClean('countries_1', DateTime.utc(2025));

      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        repository: visitRepo,
        achievementRepository: achievementRepo,
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 51.5, lng: -0.12)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => BatchResult(
          accum: {'GB': CountryAccum(photoCount: 5)},
          photoDates: [],
        ),
      );

      await tester.tap(find.text('Grant Access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan my photo library'));
      await tester.pumpAndSettle();

      expect(find.text('🏆 First Stamp'), findsNothing);
    });
  });
}
