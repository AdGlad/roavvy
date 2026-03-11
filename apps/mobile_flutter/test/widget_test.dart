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

// Builds ScanScreen with an in-memory repository and a mock MethodChannel handler.
Future<void> pumpApp(
  WidgetTester tester, {
  required Future<Object?> Function(MethodCall) handler,
  VisitRepository? repository,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('roavvy/photo_scan'),
    handler,
  );
  await tester.pumpWidget(
    MaterialApp(home: ScanScreen(repository: repository ?? _makeRepo())),
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
      const stats = ScanStats(inspected: 100, withLocation: 60, geocodeSuccesses: 55);
      expect(stats.withoutLocation, 40);
    });

    test('all-zero case is valid', () {
      const stats = ScanStats(inspected: 0, withLocation: 0, geocodeSuccesses: 0);
      expect(stats.withoutLocation, 0);
    });

    test('fromMap parses channel payload', () {
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

  // ── ScanResult unit tests ──────────────────────────────────────────────────

  group('ScanResult', () {
    test('fromMap parses countries list', () {
      final result = ScanResult.fromMap({
        'inspected': 10,
        'withLocation': 8,
        'geocodeSuccesses': 7,
        'countries': [
          {'code': 'GB', 'name': 'United Kingdom', 'photoCount': 5},
          {'code': 'JP', 'name': 'Japan', 'photoCount': 3},
        ],
      });
      expect(result.stats.inspected, 10);
      expect(result.countries.length, 2);
      expect(result.countries.first.code, 'GB');
      expect(result.countries.last.photoCount, 3);
    });

    test('fromMap handles missing countries key', () {
      final result = ScanResult.fromMap({
        'inspected': 5,
        'withLocation': 0,
        'geocodeSuccesses': 0,
      });
      expect(result.countries, isEmpty);
    });
  });

  // ── DetectedCountry unit tests ─────────────────────────────────────────────

  group('DetectedCountry', () {
    test('fromMap parses correctly', () {
      final c = DetectedCountry.fromMap({'code': 'FR', 'name': 'France', 'photoCount': 12});
      expect(c.code, 'FR');
      expect(c.name, 'France');
      expect(c.photoCount, 12);
    });

    test('fromMap defaults photoCount to 0 when absent', () {
      final c = DetectedCountry.fromMap({'code': 'DE', 'name': 'Germany'});
      expect(c.photoCount, 0);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('ScanScreen — initial state', () {
    testWidgets('shows permission button and disabled scan button', (tester) async {
      await pumpApp(tester, handler: (_) async => null);
      expect(find.text('Request Permission'), findsOneWidget);
      expect(find.text('Scan 500 Most Recent Photos'), findsOneWidget);
      final scanBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Scan 500 Most Recent Photos'),
      );
      expect(scanBtn.onPressed, isNull);
    });
  });

  group('ScanScreen — after scan with results', () {
    testWidgets('shows stats card with all six rows', (tester) async {
      await pumpApp(tester, handler: (call) async {
        if (call.method == 'requestPermission') return 3; // authorized
        if (call.method == 'scanPhotos') {
          return {
            'inspected': 100,
            'withLocation': 72,
            'geocodeSuccesses': 8,
            'countries': [
              {'code': 'US', 'name': 'United States', 'photoCount': 50},
              {'code': 'GB', 'name': 'United Kingdom', 'photoCount': 22},
            ],
          };
        }
        return null;
      });

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.text('100'), findsOneWidget); // assets scanned
      expect(find.text('72'), findsOneWidget);  // with location
      expect(find.text('28'), findsOneWidget);  // without location
      expect(find.text('8'), findsOneWidget);   // geocode successes
      expect(find.text('64'), findsOneWidget);  // geocode failures (72 - 8)
      expect(find.text('2'), findsOneWidget);   // unique countries
    });

    testWidgets('shows country list with ISO codes', (tester) async {
      await pumpApp(tester, handler: (call) async {
        if (call.method == 'requestPermission') return 3;
        if (call.method == 'scanPhotos') {
          return {
            'inspected': 100,
            'withLocation': 72,
            'geocodeSuccesses': 8,
            'countries': [
              {'code': 'US', 'name': 'United States', 'photoCount': 50},
              {'code': 'GB', 'name': 'United Kingdom', 'photoCount': 22},
            ],
          };
        }
        return null;
      });

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

    testWidgets('shows Review & Edit button after scan', (tester) async {
      await pumpApp(tester, handler: (call) async {
        if (call.method == 'requestPermission') return 3;
        if (call.method == 'scanPhotos') {
          return {
            'inspected': 10,
            'withLocation': 5,
            'geocodeSuccesses': 2,
            'countries': [
              {'code': 'JP', 'name': 'Japan', 'photoCount': 5},
            ],
          };
        }
        return null;
      });

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Review & Edit'), findsOneWidget);
    });

    testWidgets('shows empty hint when scan returns no countries', (tester) async {
      await pumpApp(tester, handler: (call) async {
        if (call.method == 'requestPermission') return 3;
        if (call.method == 'scanPhotos') {
          return {
            'inspected': 50,
            'withLocation': 0,
            'geocodeSuccesses': 0,
            'countries': <Map>[],
          };
        }
        return null;
      });

      await tester.tap(find.text('Request Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan 500 Most Recent Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Last scan'), findsOneWidget);
      expect(find.textContaining('No geotagged photos'), findsOneWidget);
    });
  });
}
