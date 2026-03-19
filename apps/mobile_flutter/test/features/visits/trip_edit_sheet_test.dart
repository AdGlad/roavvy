import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/features/visits/trip_edit_sheet.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

Widget _wrap(Widget child, {TripRepository? tripRepo}) {
  final db = _makeDb();
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo ?? TripRepository(db)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

final _t0 = DateTime(2023, 7, 14);
final _t1 = DateTime(2023, 7, 28);

TripRecord _manualTrip({DateTime? start, DateTime? end}) {
  final s = (start ?? _t0).toUtc();
  return TripRecord(
    id: 'manual_abc123',
    countryCode: 'GB',
    startedOn: s,
    endedOn: (end ?? _t1).toUtc(),
    photoCount: 0,
    isManual: true,
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('TripEditSheet — add mode', () {
    testWidgets('shows Add trip title', (tester) async {
      await tester.pumpWidget(
        _wrap(const TripEditSheet(countryCode: 'GB')),
      );
      expect(find.text('Add trip'), findsOneWidget);
    });

    testWidgets('shows Tap to select placeholders for unset dates',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TripEditSheet(countryCode: 'GB')),
      );
      expect(find.text('Tap to select'), findsNWidgets(2));
    });

    testWidgets('shows Start date and End date labels', (tester) async {
      await tester.pumpWidget(
        _wrap(const TripEditSheet(countryCode: 'GB')),
      );
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
    });

    testWidgets('Cancel pops without saving', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(_wrap(const TripEditSheet(countryCode: 'GB'), tripRepo: repo));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(await repo.loadAll(), isEmpty);
    });

    testWidgets('Save without start date shows validation error', (tester) async {
      await tester.pumpWidget(
        _wrap(const TripEditSheet(countryCode: 'GB')),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Save without end date shows validation error', (tester) async {
      await tester.pumpWidget(
        _wrap(TripEditSheet(
          countryCode: 'GB',
          initialStartDate: _t0,
        )),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please select an end date'), findsOneWidget);
    });

    testWidgets('end before start shows validation error', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t1, // later
            initialEndDate: _t0,   // earlier → invalid
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        find.text('End date must be on or after start date'),
        findsOneWidget,
      );
      expect(await repo.loadAll(), isEmpty);
    });

    testWidgets('valid dates: no error shown', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t0,
            initialEndDate: _t1,
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please select a start date'), findsNothing);
      expect(find.text('End date must be on or after start date'), findsNothing);
    });

    testWidgets('same start and end date is valid (1-day trip)', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t0,
            initialEndDate: _t0, // same day
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await repo.loadAll(), hasLength(1));
    });

    testWidgets('valid save writes isManual=true to repository', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t0,
            initialEndDate: _t1,
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final trips = await repo.loadAll();
      expect(trips, hasLength(1));
      expect(trips.first.isManual, isTrue);
      expect(trips.first.countryCode, 'GB');
    });

    testWidgets('valid save writes correct date range', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t0,
            initialEndDate: _t1,
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final trip = (await repo.loadAll()).first;
      expect(trip.startedOn, DateTime.utc(_t0.year, _t0.month, _t0.day));
      expect(trip.endedOn, DateTime.utc(_t1.year, _t1.month, _t1.day));
    });

    testWidgets('saved trip id starts with manual_', (tester) async {
      final repo = TripRepository(_makeDb());
      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            initialStartDate: _t0,
            initialEndDate: _t1,
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await repo.loadAll()).first.id, startsWith('manual_'));
    });
  });

  group('TripEditSheet — edit mode', () {
    testWidgets('shows Edit trip title', (tester) async {
      await tester.pumpWidget(
        _wrap(TripEditSheet(countryCode: 'GB', existingTrip: _manualTrip())),
      );
      expect(find.text('Edit trip'), findsOneWidget);
    });

    testWidgets('pre-populates start and end dates', (tester) async {
      await tester.pumpWidget(
        _wrap(TripEditSheet(countryCode: 'GB', existingTrip: _manualTrip())),
      );
      expect(find.text('14 Jul 2023'), findsOneWidget);
      expect(find.text('28 Jul 2023'), findsOneWidget);
    });

    testWidgets('save in edit mode reuses existing trip id', (tester) async {
      final repo = TripRepository(_makeDb());
      final original = _manualTrip();
      await repo.upsertAll([original]);

      await tester.pumpWidget(
        _wrap(
          TripEditSheet(
            countryCode: 'GB',
            existingTrip: original,
            initialStartDate: _t0,
            initialEndDate: _t1,
          ),
          tripRepo: repo,
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final trips = await repo.loadAll();
      expect(trips, hasLength(1));
      expect(trips.first.id, original.id);
    });
  });
}
