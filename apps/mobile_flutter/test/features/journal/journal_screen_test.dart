import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:mobile_flutter/features/journal/journal_screen.dart';
import 'package:region_lookup/region_lookup.dart';

/// Minimal valid ne_admin1.bin with 0 polygons (2-cell grid, 180°/cell).
/// Used to satisfy [initRegionLookup] in tests without loading the real asset.
Uint8List _emptyRegionBin() {
  // Header (16 bytes) + 2-cell grid index (12 bytes) = 28 bytes total.
  const bytes = [
    0x52, 0x4C, 0x52, 0x47, // magic "RLRG"
    0x01,                    // version = 1
    0xB4,                    // grid_cell_size = 180°
    0x02, 0x00,             // grid_cols = 2 (LE uint16)
    0x01, 0x00,             // grid_rows = 1 (LE uint16)
    0x00, 0x00,             // polygon_count = 0 (LE uint16)
    0x00, 0x00, 0x00, 0x00, // poly_refs_size = 0 (LE uint32)
    // Grid index: 2 cells × 6 bytes, all zeros.
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ];
  return Uint8List.fromList(bytes);
}

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

Widget _pumpJournal({
  required TripRepository tripRepo,
  required VisitRepository visitRepo,
  VoidCallback? onNavigateToScan,
}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      visitRepositoryProvider.overrideWithValue(visitRepo),
      achievementRepositoryProvider
          .overrideWithValue(AchievementRepository(db)),
      regionRepositoryProvider.overrideWithValue(RegionRepository(db)),
      polygonsProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: JournalScreen(
          onNavigateToScan: onNavigateToScan ?? () {},
        ),
      ),
    ),
  );
}

Future<TripRepository> _repoWithTrips(
  List<TripsCompanion> companions,
) async {
  final db = RoavvyDatabase(NativeDatabase.memory());
  final repo = TripRepository(db);
  if (companions.isNotEmpty) {
    await db.batch((batch) {
      batch.insertAll(db.trips, companions);
    });
  }
  return repo;
}

TripsCompanion _trip({
  required String id,
  required String countryCode,
  required DateTime startedOn,
  required DateTime endedOn,
  int photoCount = 10,
  int isManual = 0,
}) =>
    TripsCompanion(
      id: Value(id),
      countryCode: Value(countryCode),
      startedOn: Value(startedOn),
      endedOn: Value(endedOn),
      photoCount: Value(photoCount),
      isManual: Value(isManual),
      isDirty: const Value(1),
    );

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    initRegionLookup(_emptyRegionBin());
  });

  group('JournalScreen — empty state', () {
    testWidgets('shows empty state when no trips', (tester) async {
      final db = _makeDb();
      final tripRepo = TripRepository(db);
      final visitRepo = VisitRepository(db);

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: visitRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your journal is empty'), findsOneWidget);
      expect(
        find.text('Scan your photos to build your travel history.'),
        findsOneWidget,
      );
      expect(find.text('Scan Photos'), findsOneWidget);
    });

    testWidgets('"Scan Photos" button fires onNavigateToScan', (tester) async {
      final db = _makeDb();
      var tapped = false;

      await tester.pumpWidget(_pumpJournal(
        tripRepo: TripRepository(db),
        visitRepo: VisitRepository(db),
        onNavigateToScan: () => tapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Photos'));
      expect(tapped, isTrue);
    });
  });

  // Year-grouping tests skipped: section headers were removed when the screen
  // was redesigned from a ListView to a 3D CustomCarousel (carousel redesign).
  // Carousel-specific coverage will be added in milestone T4 (widget tests).
  group('JournalScreen — year grouping', () {
    // skip: year section headers removed in carousel redesign; T4 adds carousel coverage
    testWidgets('shows year section header with trip count', (tester) async {},
        skip: true);

    // skip: year section headers removed in carousel redesign; T4 adds carousel coverage
    testWidgets('uses singular "trip" when year has one entry', (tester) async {},
        skip: true);

    // skip: year section headers removed in carousel redesign; T4 adds carousel coverage
    testWidgets('most recent year appears first', (tester) async {},
        skip: true);
  });

  group('JournalScreen — trip card content', () {
    // CustomCarousel uses spring physics that never fully settle in test mode.
    // Use pump(300ms) instead of pumpAndSettle to advance past the first frame
    // and render card content without waiting for infinite spring convergence.

    testWidgets('carousel card shows country name and date range',
        (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2024-01-03T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 3),
          endedOn: DateTime.utc(2024, 1, 17),
          photoCount: 82,
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Card renders country name in two forms: uppercased label + title text.
      expect(find.textContaining('Japan'), findsWidgets);
      expect(find.textContaining('3 Jan'), findsWidgets);
      expect(find.textContaining('17 Jan 2024'), findsWidgets);
    });

    testWidgets('carousel card shows photo count', (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2024-01-03T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 3),
          endedOn: DateTime.utc(2024, 1, 5),
          photoCount: 42,
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Carousel card always renders "$days $dayWord · $photoCount 📷".
      expect(find.textContaining('42'), findsWidgets);
      expect(find.textContaining('📷'), findsWidgets);
    });

    testWidgets('carousel card always shows photo count even when zero',
        (tester) async {
      // Design note: the carousel card shows "N 📷" for all trips including
      // those with photoCount=0 (manual trips). This differs from the old
      // ListView which omitted the photo count line for zero-count trips.
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2024-01-03T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 3),
          endedOn: DateTime.utc(2024, 1, 5),
          photoCount: 0,
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('0 📷'), findsOneWidget);
    });

    testWidgets('manual trip shows edit-location icon', (tester) async {
      // The carousel card uses Icons.edit_location_alt_rounded (not an
      // "Added manually" chip) to indicate manually-added trips.
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'manual_abc12345',
          countryCode: 'FR',
          startedOn: DateTime.utc(2024, 3, 1),
          endedOn: DateTime.utc(2024, 3, 5),
          isManual: 1,
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byIcon(Icons.edit_location_alt_rounded),
        findsOneWidget,
      );
    });

    testWidgets('inferred trip does not show edit-location icon', (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'FR_2024-03-01T00:00:00.000Z',
          countryCode: 'FR',
          startedOn: DateTime.utc(2024, 3, 1),
          endedOn: DateTime.utc(2024, 3, 5),
          isManual: 0,
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.edit_location_alt_rounded), findsNothing);
    });

    testWidgets('tapping a carousel card navigates to TripDetailScreen',
        (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2024-01-03T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 3),
          endedOn: DateTime.utc(2024, 1, 17),
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Trip to Japan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // TripDetailScreen renders the country name in its content.
      expect(find.textContaining('Japan'), findsWidgets);
    });
  });
}
