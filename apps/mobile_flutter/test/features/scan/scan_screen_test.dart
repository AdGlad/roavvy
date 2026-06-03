// T4.5 — ScanScreen widget tests
//
// Only the initial (pre-scan) resting state is tested here.
// The photo platform channel is never invoked because:
//   - autoStart is false (default)
//   - no prior scan data → lastScanAt is null → permission check is skipped

import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/heritage_repository.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/scan/scan_screen.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

/// Stub geodata bytes — real bytes are not needed for testing pre-scan UI.
final _emptyBytes = Uint8List(0);

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final db = _makeDb();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      roavvyDatabaseProvider.overrideWithValue(db),
      visitRepositoryProvider.overrideWithValue(VisitRepository(db)),
      achievementRepositoryProvider.overrideWithValue(AchievementRepository(db)),
      tripRepositoryProvider.overrideWithValue(TripRepository(db)),
      regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
      heritageRepositoryProvider.overrideWithValue(HeritageRepository(db)),
      polygonsProvider.overrideWithValue(const []),
      geodataBytesProvider.overrideWithValue(_emptyBytes),
      regionGeodataBytesProvider.overrideWithValue(_emptyBytes),
      currentUidProvider.overrideWithValue(null),
    ],
    child: const MaterialApp(home: ScanScreen()),
  ));

  // Wait for _loadPersisted() to complete (sets _loading = false)
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('ScanScreen — initial state (pre-scan)', () {
    testWidgets('shows "Scan" in the app bar', (tester) async {
      await _pump(tester);

      expect(find.text('Scan'), findsWidgets); // app bar title
    });

    testWidgets('"Scan my photo library" button is present', (tester) async {
      await _pump(tester);

      expect(find.text('Scan my photo library'), findsOneWidget);
    });

    testWidgets('"Scan my photo library" button is disabled without permission',
        (tester) async {
      await _pump(tester);

      final btn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Scan my photo library'),
          matching: find.byType(FilledButton),
        ),
      );
      // Permission is null → canScan is false → button is disabled
      expect(btn.onPressed, isNull);
    });

    testWidgets('no progress indicator visible in idle state', (tester) async {
      await _pump(tester);

      // The loading indicator disappears after _loadPersisted completes
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
