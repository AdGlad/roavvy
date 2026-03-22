import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/providers.dart';
import 'package:mobile_flutter/data/db/roavvy_database.dart';
import 'package:mobile_flutter/data/trip_repository.dart';
import 'package:mobile_flutter/data/visit_repository.dart';
import 'package:shared_models/shared_models.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

RoavvyDatabase _makeDb() => RoavvyDatabase(NativeDatabase.memory());

TripRecord _trip(String id, String countryCode, int year) => TripRecord(
      id: id,
      countryCode: countryCode,
      startedOn: DateTime.utc(year),
      endedOn: DateTime.utc(year, 12, 31),
      photoCount: 1,
      isManual: false,
    );

InferredCountryVisit _inferred(String countryCode, int year) =>
    InferredCountryVisit(
      countryCode: countryCode,
      inferredAt: DateTime.utc(year),
      photoCount: 1,
      firstSeen: DateTime.utc(year),
      lastSeen: DateTime.utc(year, 12, 31),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ── yearFilterProvider ─────────────────────────────────────────────────

  group('yearFilterProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(yearFilterProvider), isNull);
    });

    test('can be set to a year', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(yearFilterProvider.notifier).state = 2018;
      expect(container.read(yearFilterProvider), 2018);
    });

    test('can be reset to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(yearFilterProvider.notifier).state = 2018;
      container.read(yearFilterProvider.notifier).state = null;
      expect(container.read(yearFilterProvider), isNull);
    });
  });

  // ── earliestVisitYearProvider ──────────────────────────────────────────

  group('earliestVisitYearProvider', () {
    test('returns null when no trips exist', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final container = ProviderContainer(overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(earliestVisitYearProvider.future);
      expect(result, isNull);
    });

    test('returns the minimum trip startedOn year', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await TripRepository(db).upsertAll([
        _trip('FR_2020', 'FR', 2020),
        _trip('JP_2015', 'JP', 2015),
        _trip('DE_2018', 'DE', 2018),
      ]);

      final container = ProviderContainer(overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(earliestVisitYearProvider.future);
      expect(result, 2015);
    });

    test('returns correct year for a single trip', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await TripRepository(db).upsertAll([_trip('AU_2019', 'AU', 2019)]);

      final container = ProviderContainer(overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(earliestVisitYearProvider.future);
      expect(result, 2019);
    });
  });

  // ── filteredEffectiveVisitsProvider ───────────────────────────────────

  group('filteredEffectiveVisitsProvider', () {
    late RoavvyDatabase db;
    late VisitRepository visitRepo;
    late TripRepository tripRepo;
    late ProviderContainer container;

    setUp(() {
      db = _makeDb();
      visitRepo = VisitRepository(db);
      tripRepo = TripRepository(db);

      container = ProviderContainer(overrides: [
        roavvyDatabaseProvider.overrideWithValue(db),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns all visits when yearFilter is null', () async {
      await visitRepo.saveAllInferred([
        _inferred('FR', 2015),
        _inferred('JP', 2020),
      ]);
      await tripRepo.upsertAll([
        _trip('FR_2015', 'FR', 2015),
        _trip('JP_2020', 'JP', 2020),
      ]);

      // Filter is null by default.
      final results =
          await container.read(filteredEffectiveVisitsProvider.future);
      final codes = results.map((v) => v.countryCode).toSet();
      expect(codes, containsAll(['FR', 'JP']));
      expect(codes.length, 2);
    });

    test('with year=2015: returns FR and DE but not JP', () async {
      await visitRepo.saveAllInferred([
        _inferred('FR', 2015),
        _inferred('JP', 2020),
        _inferred('DE', 2010),
      ]);
      await tripRepo.upsertAll([
        _trip('FR_2015', 'FR', 2015),
        _trip('JP_2020', 'JP', 2020),
        _trip('DE_2010', 'DE', 2010),
      ]);

      container.read(yearFilterProvider.notifier).state = 2015;

      final results =
          await container.read(filteredEffectiveVisitsProvider.future);
      final codes = results.map((v) => v.countryCode).toSet();
      expect(codes, containsAll(['FR', 'DE']));
      expect(codes.contains('JP'), isFalse);
    });

    test('null filter returns same results as effectiveVisitsProvider', () async {
      await visitRepo.saveAllInferred([
        _inferred('GB', 2012),
        _inferred('ES', 2018),
      ]);
      await tripRepo.upsertAll([
        _trip('GB_2012', 'GB', 2012),
        _trip('ES_2018', 'ES', 2018),
      ]);

      final allVisits = await container.read(effectiveVisitsProvider.future);
      final filtered =
          await container.read(filteredEffectiveVisitsProvider.future);

      final allCodes = allVisits.map((v) => v.countryCode).toSet();
      final filteredCodes = filtered.map((v) => v.countryCode).toSet();
      expect(filteredCodes, equals(allCodes));
    });

    test('manually-added country with no trips is excluded when filter active',
        () async {
      // User-added country has no trip records and no firstSeen.
      await visitRepo.saveAdded(
        UserAddedCountry(
          countryCode: 'NZ',
          addedAt: DateTime.utc(2022),
        ),
      );

      container.read(yearFilterProvider.notifier).state = 2022;

      final results =
          await container.read(filteredEffectiveVisitsProvider.future);
      final codes = results.map((v) => v.countryCode).toSet();
      // NZ has no trip records and no firstSeen → excluded (conservative behaviour).
      expect(codes.contains('NZ'), isFalse);
    });

    test('country with all trips after filter year shows as unvisited in visual states',
        () async {
      await visitRepo.saveAllInferred([
        _inferred('FR', 2015),
        _inferred('JP', 2022),
      ]);
      await tripRepo.upsertAll([
        _trip('FR_2015', 'FR', 2015),
        _trip('JP_2022', 'JP', 2022),
      ]);

      container.read(yearFilterProvider.notifier).state = 2018;

      final results =
          await container.read(filteredEffectiveVisitsProvider.future);
      final codes = results.map((v) => v.countryCode).toSet();
      expect(codes.contains('FR'), isTrue);
      expect(codes.contains('JP'), isFalse);
    });
  });
}
