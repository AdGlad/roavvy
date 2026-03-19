import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:shared_models/shared_models.dart';

TripRepository _makeRepo() =>
    TripRepository(RoavvyDatabase(NativeDatabase.memory()));

final _t0 = DateTime.utc(2023, 1, 1);
final _t1 = DateTime.utc(2023, 6, 15);
final _t2 = DateTime.utc(2023, 12, 31);

TripRecord _inferred(
  String id,
  String countryCode, {
  DateTime? startedOn,
  DateTime? endedOn,
  int photoCount = 1,
}) =>
    TripRecord(
      id: id,
      countryCode: countryCode,
      startedOn: startedOn ?? _t0,
      endedOn: endedOn ?? _t1,
      photoCount: photoCount,
      isManual: false,
    );

TripRecord _manual(String id, String countryCode) => TripRecord(
      id: id,
      countryCode: countryCode,
      startedOn: _t0,
      endedOn: _t1,
      photoCount: 0,
      isManual: true,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── upsertAll ────────────────────────────────────────────────────────────

  group('upsertAll', () {
    test('inserts a new trip', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR')]);
      final rows = await repo.loadAll();
      expect(rows, hasLength(1));
      expect(rows.first.id, 'FR_2023-01-01');
      expect(rows.first.countryCode, 'FR');
    });

    test('insertOrReplace updates endedOn and photoCount on re-inference',
        () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR', photoCount: 5)]);
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR', endedOn: _t2, photoCount: 8),
      ]);
      final rows = await repo.loadAll();
      expect(rows, hasLength(1));
      expect(rows.first.endedOn, _t2);
      expect(rows.first.photoCount, 8);
    });

    test('no-op for empty list', () async {
      final repo = _makeRepo();
      await repo.upsertAll([]);
      expect(await repo.loadAll(), isEmpty);
    });

    test('inserts multiple trips', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR'),
        _inferred('JP_2023-01-01', 'JP'),
        _manual('manual_abc12345', 'DE'),
      ]);
      expect(await repo.loadAll(), hasLength(3));
    });

    test('manual trip isManual round-trips correctly', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_manual('manual_abc12345', 'DE')]);
      final rows = await repo.loadAll();
      expect(rows.first.isManual, isTrue);
    });

    test('inferred trip isManual is false', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR')]);
      final rows = await repo.loadAll();
      expect(rows.first.isManual, isFalse);
    });
  });

  // ── loadByCountry ────────────────────────────────────────────────────────

  group('loadByCountry', () {
    test('returns only trips for the requested country', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR'),
        _inferred('JP_2023-01-01', 'JP'),
      ]);
      final rows = await repo.loadByCountry('FR');
      expect(rows, hasLength(1));
      expect(rows.first.countryCode, 'FR');
    });

    test('returns empty list for unknown country', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR')]);
      expect(await repo.loadByCountry('DE'), isEmpty);
    });

    test('returns most recent trip first', () async {
      final repo = _makeRepo();
      final older = _inferred('FR_2022-01-01', 'FR',
          startedOn: DateTime.utc(2022, 1, 1),
          endedOn: DateTime.utc(2022, 3, 1));
      final newer = _inferred('FR_2023-06-01', 'FR',
          startedOn: DateTime.utc(2023, 6, 1),
          endedOn: DateTime.utc(2023, 6, 30));
      await repo.upsertAll([older, newer]);
      final rows = await repo.loadByCountry('FR');
      expect(rows.first.startedOn.year, 2023);
      expect(rows.last.startedOn.year, 2022);
    });
  });

  // ── loadDirty ────────────────────────────────────────────────────────────

  group('loadDirty', () {
    test('newly inserted rows are dirty', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR')]);
      expect(await repo.loadDirty(), hasLength(1));
    });

    test('marked-clean rows are excluded', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR'),
        _inferred('JP_2023-01-01', 'JP'),
      ]);
      await repo.markClean('FR_2023-01-01', DateTime.utc(2023, 7, 1));
      final dirty = await repo.loadDirty();
      expect(dirty, hasLength(1));
      expect(dirty.first.countryCode, 'JP');
    });

    test('re-upsert marks clean row dirty again', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR')]);
      await repo.markClean('FR_2023-01-01', DateTime.utc(2023, 7, 1));
      expect(await repo.loadDirty(), isEmpty);

      await repo.upsertAll([_inferred('FR_2023-01-01', 'FR', photoCount: 10)]);
      expect(await repo.loadDirty(), hasLength(1));
    });
  });

  // ── markClean ────────────────────────────────────────────────────────────

  group('markClean', () {
    test('no-op for unknown id (does not throw)', () async {
      final repo = _makeRepo();
      await repo.markClean('nonexistent', DateTime.utc(2023, 7, 1));
      expect(await repo.loadDirty(), isEmpty);
    });
  });

  // ── delete ───────────────────────────────────────────────────────────────

  group('delete', () {
    test('removes the trip with the given id', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR'),
        _inferred('JP_2023-01-01', 'JP'),
      ]);
      await repo.delete('FR_2023-01-01');
      final rows = await repo.loadAll();
      expect(rows, hasLength(1));
      expect(rows.first.countryCode, 'JP');
    });

    test('no-op for unknown id (does not throw)', () async {
      final repo = _makeRepo();
      await repo.delete('nonexistent'); // should not throw
      expect(await repo.loadAll(), isEmpty);
    });
  });

  // ── clearAll ─────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('deletes all trips including manual ones', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _inferred('FR_2023-01-01', 'FR'),
        _manual('manual_abc12345', 'DE'),
      ]);
      await repo.clearAll();
      expect(await repo.loadAll(), isEmpty);
    });

    test('is a no-op when table is already empty', () async {
      final repo = _makeRepo();
      await repo.clearAll(); // should not throw
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
