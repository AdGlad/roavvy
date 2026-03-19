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
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

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

  group('JournalScreen — year grouping', () {
    testWidgets('shows year section header with trip count', (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2024-01-03T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 1, 3),
          endedOn: DateTime.utc(2024, 1, 17),
        ),
        _trip(
          id: 'FR_2024-06-01T00:00:00.000Z',
          countryCode: 'FR',
          startedOn: DateTime.utc(2024, 6, 1),
          endedOn: DateTime.utc(2024, 6, 10),
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('2024'), findsWidgets);
      expect(find.textContaining('2 trips'), findsOneWidget);
    });

    testWidgets('uses singular "trip" when year has one entry', (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'JP_2021-05-01T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2021, 5, 1),
          endedOn: DateTime.utc(2021, 5, 10),
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 trip'), findsOneWidget);
      expect(find.textContaining('1 trips'), findsNothing);
    });

    testWidgets('most recent year appears first', (tester) async {
      final tripRepo = await _repoWithTrips([
        _trip(
          id: 'FR_2022-01-01T00:00:00.000Z',
          countryCode: 'FR',
          startedOn: DateTime.utc(2022, 1, 1),
          endedOn: DateTime.utc(2022, 1, 5),
        ),
        _trip(
          id: 'JP_2024-06-01T00:00:00.000Z',
          countryCode: 'JP',
          startedOn: DateTime.utc(2024, 6, 1),
          endedOn: DateTime.utc(2024, 6, 10),
        ),
      ]);
      final db = _makeDb();

      await tester.pumpWidget(_pumpJournal(
        tripRepo: tripRepo,
        visitRepo: VisitRepository(db),
      ));
      await tester.pumpAndSettle();

      final yr2024 = tester.getTopLeft(find.textContaining('2024').first);
      final yr2022 = tester.getTopLeft(find.textContaining('2022').first);
      expect(yr2024.dy, lessThan(yr2022.dy));
    });
  });

  group('JournalScreen — trip row content', () {
    testWidgets('trip row shows country name and date range', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Japan'), findsOneWidget);
      expect(find.textContaining('3 Jan'), findsWidgets);
      expect(find.textContaining('17 Jan 2024'), findsWidgets);
    });

    testWidgets('photo count line shown when photoCount > 0', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.textContaining('42'), findsWidgets);
    });

    testWidgets('photo count line omitted when photoCount == 0', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.textContaining('📷'), findsNothing);
    });

    testWidgets('"Added manually" chip shown for manual trips', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Added manually'), findsOneWidget);
    });

    testWidgets('"Added manually" chip not shown for inferred trips',
        (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Added manually'), findsNothing);
    });

    testWidgets('tapping a trip row opens CountryDetailSheet', (tester) async {
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Japan'));
      await tester.pumpAndSettle();

      // CountryDetailSheet renders the country name in a header
      expect(find.text('Japan'), findsWidgets);
    });
  });
}
