import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

VisitRepository _makeRepo() => VisitRepository(_makeDb());

(VisitRepository, TripRepository) _makeRepoWithTrips() {
  final db = _makeDb();
  return (VisitRepository(db), TripRepository(db));
}

(VisitRepository, RegionRepository) _makeRepoWithRegions() {
  final db = _makeDb();
  return (VisitRepository(db), RegionRepository(db));
}

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

    test('does not delete share_tokens (ADR-041)', () async {
      final repo = _makeRepo();
      await repo.saveShareToken('stable-token');
      await repo.clearAll();
      expect(await repo.getShareToken(), 'stable-token');
    });

    test('also wipes photo_date_records', () async {
      final (repo, _) = _makeRepoWithTrips();
      await repo.savePhotoDates([
        PhotoDateRecord(countryCode: 'FR', capturedAt: DateTime.utc(2023, 7, 14)),
      ]);
      await repo.clearAll();
      expect(await repo.loadPhotoDates(), isEmpty);
    });

    test('also wipes trips table', () async {
      final (repo, tripRepo) = _makeRepoWithTrips();
      await tripRepo.upsertAll([
        TripRecord(
          id: 'FR_2023-01-01T00:00:00.000Z',
          countryCode: 'FR',
          startedOn: DateTime.utc(2023, 1, 1),
          endedOn: DateTime.utc(2023, 3, 1),
          photoCount: 5,
          isManual: false,
        ),
      ]);
      await repo.clearAll();
      expect(await tripRepo.loadAll(), isEmpty);
    });

    test('also wipes region_visits table', () async {
      final (repo, regionRepo) = _makeRepoWithRegions();
      await regionRepo.upsertAll([
        RegionVisit(
          tripId: 'FR_2023-01-01T00:00:00.000Z',
          countryCode: 'FR',
          regionCode: 'FR-IDF',
          firstSeen: DateTime.utc(2023, 1, 5),
          lastSeen: DateTime.utc(2023, 1, 10),
          photoCount: 3,
        ),
      ]);
      await repo.clearAll();
      expect(await regionRepo.loadByCountry('FR'), isEmpty);
    });
  });

  // ── share token ───────────────────────────────────────────────────────────────

  group('getShareToken / saveShareToken', () {
    test('returns null initially', () async {
      final repo = _makeRepo();
      expect(await repo.getShareToken(), isNull);
    });

    test('saveShareToken persists and getShareToken returns saved value', () async {
      final repo = _makeRepo();
      await repo.saveShareToken('abc-123');
      expect(await repo.getShareToken(), 'abc-123');
    });

    test('saveShareToken overwrites previous value', () async {
      final repo = _makeRepo();
      await repo.saveShareToken('first-token');
      await repo.saveShareToken('second-token');
      expect(await repo.getShareToken(), 'second-token');
    });
  });

  // ── clearShareToken ───────────────────────────────────────────────────────────

  group('clearShareToken', () {
    test('removes the token so getShareToken returns null', () async {
      final repo = _makeRepo();
      await repo.saveShareToken('abc-123');
      await repo.clearShareToken();
      expect(await repo.getShareToken(), isNull);
    });

    test('is a no-op when no token exists', () async {
      final repo = _makeRepo();
      await repo.clearShareToken(); // should not throw
      expect(await repo.getShareToken(), isNull);
    });
  });

  // ── savePhotoDates / loadPhotoDates ───────────────────────────────────────

  group('savePhotoDates / loadPhotoDates', () {
    test('returns empty list when no records saved', () async {
      final repo = _makeRepo();
      expect(await repo.loadPhotoDates(), isEmpty);
    });

    test('round-trips a single record', () async {
      final repo = _makeRepo();
      final record = PhotoDateRecord(
        countryCode: 'FR',
        capturedAt: DateTime.utc(2023, 7, 14),
      );
      await repo.savePhotoDates([record]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded, hasLength(1));
      expect(loaded.first.countryCode, 'FR');
      expect(loaded.first.capturedAt, DateTime.utc(2023, 7, 14));
    });

    test('round-trips multiple records for different countries', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'FR', capturedAt: DateTime.utc(2023, 7, 14)),
        PhotoDateRecord(
            countryCode: 'JP', capturedAt: DateTime.utc(2022, 4, 2)),
      ]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded, hasLength(2));
      expect(loaded.map((r) => r.countryCode), containsAll(['FR', 'JP']));
    });

    test('duplicate {countryCode, capturedAt} is silently ignored (composite PK)',
        () async {
      final repo = _makeRepo();
      final record = PhotoDateRecord(
        countryCode: 'FR',
        capturedAt: DateTime.utc(2023, 7, 14),
      );
      await repo.savePhotoDates([record]);
      await repo.savePhotoDates([record]); // same row — no duplicate
      expect(await repo.loadPhotoDates(), hasLength(1));
    });

    test('same country, different capturedAt → two rows', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'FR', capturedAt: DateTime.utc(2023, 7, 14)),
        PhotoDateRecord(
            countryCode: 'FR', capturedAt: DateTime.utc(2023, 7, 28)),
      ]);
      expect(await repo.loadPhotoDates(), hasLength(2));
    });

    test('no-op for empty list', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([]);
      expect(await repo.loadPhotoDates(), isEmpty);
    });

    test('round-trips regionCode when present', () async {
      final repo = _makeRepo();
      final record = PhotoDateRecord(
        countryCode: 'US',
        capturedAt: DateTime.utc(2023, 6, 1),
        regionCode: 'US-CA',
      );
      await repo.savePhotoDates([record]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded.first.regionCode, 'US-CA');
    });

    test('regionCode is null when not provided', () async {
      final repo = _makeRepo();
      final record = PhotoDateRecord(
        countryCode: 'JP',
        capturedAt: DateTime.utc(2022, 3, 10),
      );
      await repo.savePhotoDates([record]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded.first.regionCode, isNull);
    });

    test('round-trips assetId when present (schema v9, ADR-060)', () async {
      final repo = _makeRepo();
      const id = 'A1B2C3D4-0000-0000-0000-000000000001/L0/001';
      await repo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'GB',
          capturedAt: DateTime.utc(2024, 5, 1),
          assetId: id,
        ),
      ]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded.first.assetId, id);
    });

    test('assetId is null when not provided', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([
        PhotoDateRecord(countryCode: 'JP', capturedAt: DateTime.utc(2024, 1, 1)),
      ]);
      final loaded = await repo.loadPhotoDates();
      expect(loaded.first.assetId, isNull);
    });

    test('records with and without regionCode coexist', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'FR',
            capturedAt: DateTime.utc(2023, 7, 14),
            regionCode: 'FR-IDF'),
        PhotoDateRecord(
            countryCode: 'AU', capturedAt: DateTime.utc(2023, 8, 1)),
      ]);
      final loaded = await repo.loadPhotoDates();
      final fr = loaded.firstWhere((r) => r.countryCode == 'FR');
      final au = loaded.firstWhere((r) => r.countryCode == 'AU');
      expect(fr.regionCode, 'FR-IDF');
      expect(au.regionCode, isNull);
    });
  });

  // ── clearPhotoDates ───────────────────────────────────────────────────────

  group('clearPhotoDates', () {
    test('deletes all photo date records', () async {
      final repo = _makeRepo();
      await repo.savePhotoDates([
        PhotoDateRecord(
            countryCode: 'FR', capturedAt: DateTime.utc(2023, 7, 14)),
      ]);
      await repo.clearPhotoDates();
      expect(await repo.loadPhotoDates(), isEmpty);
    });

    test('is a no-op when table is empty', () async {
      final repo = _makeRepo();
      await repo.clearPhotoDates(); // should not throw
      expect(await repo.loadPhotoDates(), isEmpty);
    });
  });

  // ── saveBootstrapCompletedAt / loadBootstrapCompletedAt ───────────────────

  group('saveBootstrapCompletedAt / loadBootstrapCompletedAt', () {
    test('returns null before bootstrap runs', () async {
      final repo = _makeRepo();
      expect(await repo.loadBootstrapCompletedAt(), isNull);
    });

    test('persists the bootstrap timestamp', () async {
      final repo = _makeRepo();
      final ts = DateTime.utc(2024, 3, 18, 12);
      await repo.saveBootstrapCompletedAt(ts);
      final loaded = await repo.loadBootstrapCompletedAt();
      expect(loaded, ts);
    });

    test('overwrites existing value on repeated call', () async {
      final repo = _makeRepo();
      await repo.saveBootstrapCompletedAt(DateTime.utc(2024, 1, 1));
      final ts2 = DateTime.utc(2024, 6, 1);
      await repo.saveBootstrapCompletedAt(ts2);
      expect(await repo.loadBootstrapCompletedAt(), ts2);
    });

    test('clearAll nulls bootstrapCompletedAt', () async {
      final repo = _makeRepo();
      await repo.saveBootstrapCompletedAt(DateTime.utc(2024, 3, 18));
      await repo.clearAll();
      // scanMetadata row is deleted by clearAll, so bootstrap flag is gone
      expect(await repo.loadBootstrapCompletedAt(), isNull);
    });
  });
}
