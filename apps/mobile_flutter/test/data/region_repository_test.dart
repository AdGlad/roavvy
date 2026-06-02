import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/region_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

RoavvyDatabase _makeDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return RoavvyDatabase(NativeDatabase.memory());
}

RegionRepository _makeRepo() => RegionRepository(_makeDb());

(VisitRepository, RegionRepository) _makeRepoWithVisits() {
  final db = _makeDb();
  return (VisitRepository(db), RegionRepository(db));
}

TripRecord _trip({
  String id = 'FR_2023-01-01T00:00:00.000Z',
  String countryCode = 'FR',
  DateTime? startedOn,
  DateTime? endedOn,
}) =>
    TripRecord(
      id: id,
      countryCode: countryCode,
      startedOn: startedOn ?? DateTime.utc(2023, 1, 1),
      endedOn: endedOn ?? DateTime.utc(2023, 1, 31),
      photoCount: 1,
      isManual: false,
    );

RegionVisit _visit({
  String tripId = 'FR_2023-01-01T00:00:00.000Z',
  String countryCode = 'FR',
  String regionCode = 'FR-IDF',
  DateTime? firstSeen,
  DateTime? lastSeen,
  int photoCount = 3,
}) =>
    RegionVisit(
      tripId: tripId,
      countryCode: countryCode,
      regionCode: regionCode,
      firstSeen: firstSeen ?? DateTime.utc(2023, 1, 5),
      lastSeen: lastSeen ?? DateTime.utc(2023, 1, 10),
      photoCount: photoCount,
    );

void main() {
  // ── upsertAll / loadByCountry ─────────────────────────────────────────────

  group('upsertAll / loadByCountry', () {
    test('returns empty list when no records', () async {
      final repo = _makeRepo();
      expect(await repo.loadByCountry('FR'), isEmpty);
    });

    test('round-trips a single visit', () async {
      final repo = _makeRepo();
      final v = _visit();
      await repo.upsertAll([v]);
      final loaded = await repo.loadByCountry('FR');
      expect(loaded, hasLength(1));
      expect(loaded.first.tripId, v.tripId);
      expect(loaded.first.regionCode, 'FR-IDF');
      expect(loaded.first.countryCode, 'FR');
      expect(loaded.first.photoCount, 3);
      expect(loaded.first.firstSeen, DateTime.utc(2023, 1, 5));
      expect(loaded.first.lastSeen, DateTime.utc(2023, 1, 10));
    });

    test('multiple regions for same country returned', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(regionCode: 'FR-IDF'),
        _visit(regionCode: 'FR-ARA'),
      ]);
      final loaded = await repo.loadByCountry('FR');
      expect(loaded, hasLength(2));
      expect(loaded.map((r) => r.regionCode), containsAll(['FR-IDF', 'FR-ARA']));
    });

    test('loadByCountry does not return other countries', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(countryCode: 'FR', regionCode: 'FR-IDF'),
        _visit(
            tripId: 'US_2023-01-01T00:00:00.000Z',
            countryCode: 'US',
            regionCode: 'US-CA'),
      ]);
      final loaded = await repo.loadByCountry('FR');
      expect(loaded, hasLength(1));
      expect(loaded.first.countryCode, 'FR');
    });

    test('duplicate upsert (same tripId + regionCode) replaces existing row', () async {
      final repo = _makeRepo();
      await repo.upsertAll([_visit(photoCount: 2)]);
      await repo.upsertAll([_visit(photoCount: 5)]);
      final loaded = await repo.loadByCountry('FR');
      expect(loaded, hasLength(1));
      expect(loaded.first.photoCount, 5);
    });

    test('no-op for empty list', () async {
      final repo = _makeRepo();
      await repo.upsertAll([]);
      expect(await repo.loadByCountry('FR'), isEmpty);
    });
  });

  // ── loadByTrip ────────────────────────────────────────────────────────────

  group('loadByTrip', () {
    test('returns empty list when no records', () async {
      final repo = _makeRepo();
      expect(await repo.loadByTrip('FR_2023-01-01T00:00:00.000Z'), isEmpty);
    });

    test('returns only visits for the given tripId', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(tripId: 'FR_2023-01-01T00:00:00.000Z', regionCode: 'FR-IDF'),
        _visit(
            tripId: 'US_2023-06-01T00:00:00.000Z',
            countryCode: 'US',
            regionCode: 'US-CA'),
      ]);
      final loaded = await repo.loadByTrip('FR_2023-01-01T00:00:00.000Z');
      expect(loaded, hasLength(1));
      expect(loaded.first.regionCode, 'FR-IDF');
    });

    test('returns all regions for a multi-region trip', () async {
      final repo = _makeRepo();
      const tripId = 'US_2023-06-01T00:00:00.000Z';
      await repo.upsertAll([
        _visit(tripId: tripId, countryCode: 'US', regionCode: 'US-CA'),
        _visit(tripId: tripId, countryCode: 'US', regionCode: 'US-NV'),
        _visit(tripId: tripId, countryCode: 'US', regionCode: 'US-AZ'),
      ]);
      final loaded = await repo.loadByTrip(tripId);
      expect(loaded, hasLength(3));
      expect(loaded.map((r) => r.regionCode),
          containsAll(['US-CA', 'US-NV', 'US-AZ']));
    });
  });

  // ── deleteByTrip ──────────────────────────────────────────────────────────

  group('deleteByTrip', () {
    test('removes all visits for the given tripId', () async {
      final repo = _makeRepo();
      const tripId = 'FR_2023-01-01T00:00:00.000Z';
      await repo.upsertAll([
        _visit(tripId: tripId, regionCode: 'FR-IDF'),
        _visit(tripId: tripId, regionCode: 'FR-ARA'),
      ]);
      await repo.deleteByTrip(tripId);
      expect(await repo.loadByTrip(tripId), isEmpty);
    });

    test('does not delete visits for other trips', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(
            tripId: 'FR_2023-01-01T00:00:00.000Z',
            regionCode: 'FR-IDF'),
        _visit(
            tripId: 'US_2023-06-01T00:00:00.000Z',
            countryCode: 'US',
            regionCode: 'US-CA'),
      ]);
      await repo.deleteByTrip('FR_2023-01-01T00:00:00.000Z');
      final remaining =
          await repo.loadByTrip('US_2023-06-01T00:00:00.000Z');
      expect(remaining, hasLength(1));
      expect(remaining.first.regionCode, 'US-CA');
    });

    test('is a no-op when tripId has no rows', () async {
      final repo = _makeRepo();
      await repo.deleteByTrip('nonexistent');
      expect(await repo.loadByCountry('FR'), isEmpty);
    });
  });

  // ── countUnique ───────────────────────────────────────────────────────────

  group('countUnique', () {
    test('returns 0 when table is empty', () async {
      final repo = _makeRepo();
      expect(await repo.countUnique(), 0);
    });

    test('counts distinct region codes', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(regionCode: 'FR-IDF'),
        _visit(regionCode: 'FR-ARA'),
      ]);
      expect(await repo.countUnique(), 2);
    });

    test('does not double-count the same region code across trips', () async {
      final repo = _makeRepo();
      // Same region visited on two different trips
      await repo.upsertAll([
        _visit(
            tripId: 'FR_2023-01-01T00:00:00.000Z', regionCode: 'FR-IDF'),
        _visit(
            tripId: 'FR_2024-01-01T00:00:00.000Z', regionCode: 'FR-IDF'),
      ]);
      expect(await repo.countUnique(), 1);
    });
  });

  // ── loadRegionCodesForTrip ────────────────────────────────────────────────

  group('loadRegionCodesForTrip', () {
    test('returns empty list when no photo_date_records exist', () async {
      final (_, regionRepo) = _makeRepoWithVisits();
      expect(await regionRepo.loadRegionCodesForTrip(_trip()), isEmpty);
    });

    test('returns region codes for photos within trip date range', () async {
      final (visitRepo, regionRepo) = _makeRepoWithVisits();
      await visitRepo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 10),
          regionCode: 'FR-IDF',
        ),
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 20),
          regionCode: 'FR-ARA',
        ),
      ]);
      final codes = await regionRepo.loadRegionCodesForTrip(_trip());
      expect(codes, hasLength(2));
      expect(codes, containsAll(['FR-IDF', 'FR-ARA']));
    });

    test('excludes photos outside the trip date range', () async {
      final (visitRepo, regionRepo) = _makeRepoWithVisits();
      await visitRepo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 15), // inside
          regionCode: 'FR-IDF',
        ),
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 3, 1), // outside (after endedOn)
          regionCode: 'FR-ARA',
        ),
      ]);
      final codes = await regionRepo.loadRegionCodesForTrip(_trip());
      expect(codes, hasLength(1));
      expect(codes.first, 'FR-IDF');
    });

    test('excludes photos with null regionCode', () async {
      final (visitRepo, regionRepo) = _makeRepoWithVisits();
      await visitRepo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 10),
          regionCode: 'FR-IDF',
        ),
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 15),
          // no regionCode
        ),
      ]);
      final codes = await regionRepo.loadRegionCodesForTrip(_trip());
      expect(codes, hasLength(1));
      expect(codes.first, 'FR-IDF');
    });

    test('deduplicates region codes when multiple photos share the same region',
        () async {
      final (visitRepo, regionRepo) = _makeRepoWithVisits();
      await visitRepo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 5),
          regionCode: 'FR-IDF',
        ),
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 12),
          regionCode: 'FR-IDF',
        ),
      ]);
      final codes = await regionRepo.loadRegionCodesForTrip(_trip());
      expect(codes, hasLength(1));
      expect(codes.first, 'FR-IDF');
    });

    test('excludes photos from other countries', () async {
      final (visitRepo, regionRepo) = _makeRepoWithVisits();
      await visitRepo.savePhotoDates([
        PhotoDateRecord(
          countryCode: 'FR',
          capturedAt: DateTime.utc(2023, 1, 10),
          regionCode: 'FR-IDF',
        ),
        PhotoDateRecord(
          countryCode: 'DE',
          capturedAt: DateTime.utc(2023, 1, 10),
          regionCode: 'DE-BY',
        ),
      ]);
      final codes = await regionRepo.loadRegionCodesForTrip(_trip());
      expect(codes, hasLength(1));
      expect(codes.first, 'FR-IDF');
    });
  });

  // ── clearAll ──────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('deletes all region visits', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(regionCode: 'FR-IDF'),
        _visit(
            tripId: 'US_2023-06-01T00:00:00.000Z',
            countryCode: 'US',
            regionCode: 'US-CA'),
      ]);
      await repo.clearAll();
      expect(await repo.loadByCountry('FR'), isEmpty);
      expect(await repo.loadByCountry('US'), isEmpty);
    });

    test('is a no-op when table is empty', () async {
      final repo = _makeRepo();
      await repo.clearAll(); // should not throw
      expect(await repo.loadByCountry('FR'), isEmpty);
    });
  });

  // T3.11 — Region repository continent rollup ───────────────────────────────

  group('RegionRepository — continent rollup via country code', () {
    test('visits with known Europe country codes (GB, FR, DE) are stored and retrievable', () async {
      final repo = _makeRepo();
      // GB, FR, DE all map to 'Europe' in kCountryContinent.
      await repo.upsertAll([
        _visit(tripId: 'GB_2023-01-01T00:00:00.000Z', countryCode: 'GB', regionCode: 'GB-ENG'),
        _visit(tripId: 'FR_2023-01-01T00:00:00.000Z', countryCode: 'FR', regionCode: 'FR-IDF'),
        _visit(tripId: 'DE_2023-01-01T00:00:00.000Z', countryCode: 'DE', regionCode: 'DE-BE'),
      ]);

      final all = await repo.loadAll();
      final countryCodes = all.map((v) => v.countryCode).toSet();
      expect(countryCodes, containsAll(['GB', 'FR', 'DE']));

      // Verify continent lookup doesn't crash (kCountryContinent used externally).
      for (final v in all) {
        final continent = kCountryContinent[v.countryCode];
        expect(continent, isNotNull,
            reason: '${v.countryCode} should have a known continent');
      }
    });

    test('mixed-continent visits produce correct per-country groupings', () async {
      final repo = _makeRepo();
      // Europe: GB, France; Asia: JP; Americas: US
      await repo.upsertAll([
        _visit(tripId: 'GB_2023-01-01T00:00:00.000Z', countryCode: 'GB', regionCode: 'GB-ENG'),
        _visit(tripId: 'JP_2023-01-01T00:00:00.000Z', countryCode: 'JP', regionCode: 'JP-13'),
        _visit(tripId: 'US_2023-01-01T00:00:00.000Z', countryCode: 'US', regionCode: 'US-NY'),
      ]);

      final gbVisits = await repo.loadByCountry('GB');
      final jpVisits = await repo.loadByCountry('JP');
      final usVisits = await repo.loadByCountry('US');

      expect(gbVisits, hasLength(1));
      expect(jpVisits, hasLength(1));
      expect(usVisits, hasLength(1));

      // Continent lookups for each.
      expect(kCountryContinent['GB'], 'Europe');
      expect(kCountryContinent['JP'], 'Asia');
      expect(kCountryContinent['US'], 'North America');
    });

    test('unknown or unmapped country code in a visit does not crash the repository', () async {
      final repo = _makeRepo();
      // 'XX' is not in kCountryContinent — verify the repository handles it gracefully.
      await repo.upsertAll([
        _visit(tripId: 'XX_2023-01-01T00:00:00.000Z', countryCode: 'XX', regionCode: 'XX-01'),
      ]);

      // Repository operation should not throw.
      final visits = await repo.loadByCountry('XX');
      expect(visits, hasLength(1));

      // kCountryContinent returns null for unknown codes — not a crash.
      expect(kCountryContinent['XX'], isNull);
    });

    test('loadAll returns visits across all continents without filtering', () async {
      final repo = _makeRepo();
      await repo.upsertAll([
        _visit(tripId: 'GB_2023-01-01T00:00:00.000Z', countryCode: 'GB', regionCode: 'GB-ENG'),
        _visit(tripId: 'ZA_2023-01-01T00:00:00.000Z', countryCode: 'ZA', regionCode: 'ZA-WC'),
        _visit(tripId: 'AU_2023-01-01T00:00:00.000Z', countryCode: 'AU', regionCode: 'AU-NSW'),
      ]);

      final all = await repo.loadAll();
      // All three visits from Europe, Africa, and Oceania should be returned.
      expect(all, hasLength(3));
    });
  });
}
