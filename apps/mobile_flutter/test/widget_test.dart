import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/photo_scan_channel.dart';
import 'package:mobile_flutter/scan_screen.dart';

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

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
  Future<Map<String, CountryAccum>> Function(List<PhotoRecord>)? batchResolver,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('roavvy/photo_scan'),
    methodHandler,
  );

  Stream<ScanEvent> Function({int limit})? scanStarter;
  if (scanEvents != null) {
    final events = scanEvents;
    scanStarter = ({int limit = 500}) => Stream.fromIterable(events);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: ScanScreen(
        repository: repository ?? _makeRepo(),
        batchResolver: batchResolver,
        scanStarter: scanStarter,
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
      expect(result['GB']!.photoCount, 2);
      expect(result['US']!.photoCount, 1);
    });

    test('firstSeen and lastSeen are set from capturedAt', () {
      final t1 = DateTime.utc(2022, 1, 1);
      final t2 = DateTime.utc(2023, 6, 15);
      final photos = [
        PhotoRecord(lat: 51.5, lng: -0.1, capturedAt: t2),
        PhotoRecord(lat: 51.6, lng: -0.2, capturedAt: t1),
      ];
      final result = resolveBatch(photos, (_, __) => 'GB');
      expect(result['GB']!.firstSeen, t1);
      expect(result['GB']!.lastSeen, t2);
    });

    test('skips photos when resolver returns null', () {
      final photos = [
        PhotoRecord(lat: 0.0, lng: 0.0),
        PhotoRecord(lat: 51.5, lng: -0.1),
      ];
      final result = resolveBatch(photos, (lat, _) => lat > 45 ? 'GB' : null);
      expect(result.containsKey('GB'), isTrue);
      expect(result.length, 1);
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
      expect(find.text('Request Permission'), findsOneWidget);
      expect(find.text('Scan 500 Most Recent Photos'), findsOneWidget);
      final scanBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Scan 500 Most Recent Photos'),
      );
      expect(scanBtn.onPressed, isNull);
    });
  });

  group('ScanScreen — after scan with results', () {
    testWidgets('shows stats card after scan completes', (tester) async {
      // Use values that produce unique numbers across all six stat rows:
      // inspected=120, withLocation=90, withoutLocation=30,
      // geocodeSuccesses=75, geocodeFailures=15, countryCount=2
      await pumpApp(
        tester,
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
        batchResolver: (_) async => {
          'GB': CountryAccum(photoCount: 45),
          'US': CountryAccum(photoCount: 30),
        },
      );

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.text('120'), findsOneWidget); // assets scanned
      expect(find.text('90'), findsOneWidget);  // with location
      expect(find.text('30'), findsOneWidget);  // without location (120-90)
      expect(find.text('75'), findsOneWidget);  // geocode successes (45+30)
      expect(find.text('15'), findsOneWidget);  // geocode failures (90-75)
      expect(find.text('2'), findsOneWidget);   // unique countries
    });

    testWidgets('shows country list with ISO codes', (tester) async {
      await pumpApp(
        tester,
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
        batchResolver: (_) async => {
          'US': CountryAccum(photoCount: 50),
          'GB': CountryAccum(photoCount: 22),
        },
      );

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('2 countries visited'), findsOneWidget);
      expect(find.text('US'), findsOneWidget);
      expect(find.text('50 photos'), findsOneWidget);
      expect(find.text('GB'), findsOneWidget);
      expect(find.text('22 photos'), findsOneWidget);
    });

    testWidgets('shows Review & Edit button after scan returns countries',
        (tester) async {
      await pumpApp(
        tester,
        methodHandler: (call) async {
          if (call.method == 'requestPermission') return 3;
          return null;
        },
        scanEvents: [
          ScanBatchEvent(photos: [PhotoRecord(lat: 35.7, lng: 139.7)]),
          const ScanDoneEvent(inspected: 10, withLocation: 5),
        ],
        batchResolver: (_) async => {
          'JP': CountryAccum(photoCount: 5),
        },
      );

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
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
        batchResolver: (_) async => {},
      );

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.textContaining('No geotagged photos'), findsOneWidget);
    });
  });
}
