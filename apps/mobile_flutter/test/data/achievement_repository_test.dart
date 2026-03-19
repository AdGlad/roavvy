import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/achievement_repository.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';

AchievementRepository _makeRepo() =>
    AchievementRepository(RoavvyDatabase(NativeDatabase.memory()));

final _t0 = DateTime.utc(2025, 1, 1);
final _t1 = DateTime.utc(2025, 6, 1);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── upsertAll ─────────────────────────────────────────────────────────────

  group('upsertAll', () {
    test('inserts a single achievement', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      final all = await repo.loadAll();
      expect(all, contains('countries_1'));
    });

    test('inserts multiple achievements in one call', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1', 'countries_5', 'continents_3'}, _t0);
      final all = await repo.loadAll();
      expect(all, containsAll(['countries_1', 'countries_5', 'continents_3']));
    });

    test('is idempotent — re-upsert does not duplicate or throw', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      await repo.upsertAll({'countries_1'}, _t1); // second call with different time
      final all = await repo.loadAll();
      expect(all.where((id) => id == 'countries_1'), hasLength(1));
    });

    test('empty set is a no-op', () async {
      final repo = _makeRepo();
      await repo.upsertAll({}, _t0);
      expect(await repo.loadAll(), isEmpty);
    });

    test('new rows start with isDirty = 1', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      final dirty = await repo.loadDirty();
      expect(dirty, hasLength(1));
      expect(dirty.first.achievementId, 'countries_1');
    });
  });

  // ── loadAll ───────────────────────────────────────────────────────────────

  group('loadAll', () {
    test('returns empty list when no achievements', () async {
      final repo = _makeRepo();
      expect(await repo.loadAll(), isEmpty);
    });

    test('returns all achievement IDs', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1', 'countries_5'}, _t0);
      final all = await repo.loadAll();
      expect(all, hasLength(2));
      expect(all, containsAll(['countries_1', 'countries_5']));
    });
  });

  // ── loadDirty ─────────────────────────────────────────────────────────────

  group('loadDirty', () {
    test('returns only dirty rows', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1', 'countries_5'}, _t0);
      await repo.markClean('countries_1', _t1);
      final dirty = await repo.loadDirty();
      expect(dirty.map((r) => r.achievementId), equals(['countries_5']));
    });

    test('returns empty when all rows are clean', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      await repo.markClean('countries_1', _t1);
      expect(await repo.loadDirty(), isEmpty);
    });
  });

  // ── loadAllRows ───────────────────────────────────────────────────────────

  group('loadAllRows', () {
    test('returns empty list when no achievements', () async {
      final repo = _makeRepo();
      expect(await repo.loadAllRows(), isEmpty);
    });

    test('returns rows with id and unlockedAt', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      final rows = await repo.loadAllRows();
      expect(rows, hasLength(1));
      expect(rows.first.achievementId, 'countries_1');
      expect(rows.first.unlockedAt.toUtc(), _t0);
    });

    test('returns all unlocked rows', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1', 'countries_5'}, _t0);
      final rows = await repo.loadAllRows();
      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r.achievementId),
        containsAll(['countries_1', 'countries_5']),
      );
    });
  });

  // ── markClean ─────────────────────────────────────────────────────────────

  group('markClean', () {
    test('sets isDirty = 0 and records syncedAt', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1'}, _t0);
      await repo.markClean('countries_1', _t1);
      final dirty = await repo.loadDirty();
      expect(dirty, isEmpty);
    });

    test('does not affect other rows', () async {
      final repo = _makeRepo();
      await repo.upsertAll({'countries_1', 'countries_5'}, _t0);
      await repo.markClean('countries_1', _t1);
      final dirty = await repo.loadDirty();
      expect(dirty.map((r) => r.achievementId), contains('countries_5'));
    });
  });
}
