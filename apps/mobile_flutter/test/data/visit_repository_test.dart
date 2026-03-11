import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

VisitRepository _makeRepo() =>
    VisitRepository(RoavvyDatabase(NativeDatabase.memory()));

final _t0 = DateTime.utc(2025, 1, 1);
final _t1 = DateTime.utc(2025, 6, 1);
final _t2 = DateTime.utc(2025, 12, 31);

InferredCountryVisit _inferred(
  String code, {
  int photoCount = 1,
  DateTime? firstSeen,
  DateTime? lastSeen,
}) =>
    InferredCountryVisit(
      countryCode: code,
      inferredAt: _t0,
      photoCount: photoCount,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
    );

UserAddedCountry _added(String code) =>
    UserAddedCountry(countryCode: code, addedAt: _t0);

UserRemovedCountry _removed(String code) =>
    UserRemovedCountry(countryCode: code, removedAt: _t0);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // ── saveInferred ────────────────────────────────────────────────────────────

  group('saveInferred', () {
    test('inserts a new inferred visit', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB', photoCount: 5));
      final rows = await repo.loadInferred();
      expect(rows, hasLength(1));
      expect(rows.first.countryCode, 'GB');
      expect(rows.first.photoCount, 5);
    });

    test('upsert accumulates photoCount', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB', photoCount: 5));
      await repo.saveInferred(_inferred('GB', photoCount: 3));
      final rows = await repo.loadInferred();
      expect(rows.single.photoCount, 8);
    });

    test('upsert keeps earliest firstSeen', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB', firstSeen: _t1));
      await repo.saveInferred(_inferred('GB', firstSeen: _t0));
      final rows = await repo.loadInferred();
      expect(rows.single.firstSeen, _t0);
    });

    test('upsert keeps latest lastSeen', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB', lastSeen: _t0));
      await repo.saveInferred(_inferred('GB', lastSeen: _t2));
      final rows = await repo.loadInferred();
      expect(rows.single.lastSeen, _t2);
    });

    test('null firstSeen does not overwrite a stored value', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB', firstSeen: _t1));
      await repo.saveInferred(_inferred('GB', firstSeen: null));
      final rows = await repo.loadInferred();
      expect(rows.single.firstSeen, _t1);
    });
  });

  // ── saveAllInferred ──────────────────────────────────────────────────────────

  group('saveAllInferred', () {
    test('inserts multiple countries in one call', () async {
      final repo = _makeRepo();
      await repo.saveAllInferred([
        _inferred('GB', photoCount: 10),
        _inferred('JP', photoCount: 5),
      ]);
      final rows = await repo.loadInferred();
      expect(rows, hasLength(2));
    });
  });

  // ── saveAdded ────────────────────────────────────────────────────────────────

  group('saveAdded', () {
    test('records a user addition', () async {
      final repo = _makeRepo();
      await repo.saveAdded(_added('DE'));
      expect(await repo.loadAdded(), hasLength(1));
    });

    test('cancels an existing removal for the same code', () async {
      final repo = _makeRepo();
      await repo.saveRemoved(_removed('DE'));
      expect(await repo.loadRemoved(), hasLength(1));

      await repo.saveAdded(_added('DE'));
      expect(await repo.loadRemoved(), isEmpty);
      expect(await repo.loadAdded(), hasLength(1));
    });
  });

  // ── saveRemoved ──────────────────────────────────────────────────────────────

  group('saveRemoved', () {
    test('records a user removal', () async {
      final repo = _makeRepo();
      await repo.saveRemoved(_removed('FR'));
      expect(await repo.loadRemoved(), hasLength(1));
    });

    test('cancels an existing addition for the same code', () async {
      final repo = _makeRepo();
      await repo.saveAdded(_added('FR'));
      expect(await repo.loadAdded(), hasLength(1));

      await repo.saveRemoved(_removed('FR'));
      expect(await repo.loadAdded(), isEmpty);
      expect(await repo.loadRemoved(), hasLength(1));
    });
  });

  // ── loadEffective ────────────────────────────────────────────────────────────

  group('loadEffective', () {
    test('returns empty list when no data', () async {
      final repo = _makeRepo();
      expect(await repo.loadEffective(), isEmpty);
    });

    test('inferred country appears in effective set', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB'));
      final eff = await repo.loadEffective();
      expect(eff.map((e) => e.countryCode), contains('GB'));
    });

    test('removed country is suppressed from effective set', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB'));
      await repo.saveRemoved(_removed('GB'));
      expect(await repo.loadEffective(), isEmpty);
    });

    test('added country appears even without inferred evidence', () async {
      final repo = _makeRepo();
      await repo.saveAdded(_added('ZZ'));
      final eff = await repo.loadEffective();
      expect(eff.map((e) => e.countryCode), contains('ZZ'));
      expect(eff.single.hasPhotoEvidence, isFalse);
    });

    test('photoCount is carried through to effective record', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('JP', photoCount: 42));
      final eff = await repo.loadEffective();
      expect(eff.single.photoCount, 42);
    });
  });

  // ── clearInferred ────────────────────────────────────────────────────────────

  group('clearInferred', () {
    test('deletes only inferred rows', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB'));
      await repo.saveAdded(_added('FR'));
      await repo.clearInferred();
      expect(await repo.loadInferred(), isEmpty);
      expect(await repo.loadAdded(), hasLength(1));
    });
  });

  // ── clearAll ─────────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('wipes all three tables', () async {
      final repo = _makeRepo();
      await repo.saveInferred(_inferred('GB'));
      await repo.saveAdded(_added('FR'));
      await repo.saveRemoved(_removed('JP'));
      await repo.clearAll();
      expect(await repo.loadInferred(), isEmpty);
      expect(await repo.loadAdded(), isEmpty);
      expect(await repo.loadRemoved(), isEmpty);
    });
  });
}
