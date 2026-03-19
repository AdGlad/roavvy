import 'package:drift/drift.dart';

part 'roavvy_database.g.dart';

/// Singleton metadata table — always at most one row (id = 1).
///
/// Stores [lastScanAt] so the scan pipeline can pass an incremental
/// `sinceDate` predicate to the Swift bridge (ADR-012, ADR-022).
///
/// [bootstrapCompletedAt] is set the first time the existing-user bootstrap
/// runs (ADR-048). Null means bootstrap has not yet executed.
@DataClassName('ScanMetadataRow')
class ScanMetadata extends Table {
  IntColumn get id => integer()();
  TextColumn get lastScanAt => text().nullable()();
  TextColumn get bootstrapCompletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores one row per country from the scan pipeline.
///
/// Upserted after each scan run: [photoCount] accumulates, [firstSeen] keeps
/// the earliest value and [lastSeen] keeps the latest.
/// [isDirty] is 1 until the row has been successfully synced to Firestore.
@DataClassName('InferredVisitRow')
class InferredCountryVisits extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get inferredAt => dateTime()();
  IntColumn get photoCount => integer()();
  DateTimeColumn get firstSeen => dateTime().nullable()();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

/// Stores countries the user has explicitly added via the review screen.
///
/// Adding a country also deletes any matching row in [UserRemovedCountries]
/// ("un-delete" semantics per ADR-006).
/// [isDirty] is 1 until the row has been successfully synced to Firestore.
@DataClassName('AddedCountryRow')
class UserAddedCountries extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get addedAt => dateTime()();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

/// Permanent tombstones: "I did not visit here."
///
/// Suppresses any [InferredCountryVisits] or [UserAddedCountries] row for the
/// same code — including future scan results — until the user explicitly
/// re-adds it.
/// [isDirty] is 1 until the row has been successfully synced to Firestore.
@DataClassName('RemovedCountryRow')
class UserRemovedCountries extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get removedAt => dateTime()();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

/// Stores one row per unlocked achievement.
///
/// [achievementId] matches an [Achievement.id] from [kAchievements].
/// [unlockedAt] is the UTC timestamp when the achievement was first earned.
/// [isDirty] is 1 until the row has been successfully synced to Firestore.
/// Achievements are never cleared by [VisitRepository.clearAll] (ADR-036).
@DataClassName('UnlockedAchievementRow')
class UnlockedAchievements extends Table {
  TextColumn get achievementId => text()();
  DateTimeColumn get unlockedAt => dateTime()();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {achievementId};
}

/// Singleton table storing the user's stable share token (ADR-041).
///
/// Always at most one row (id = 1). Never deleted by
/// [VisitRepository.clearAll] so that previously shared URLs remain valid
/// after the user resets their travel history.
@DataClassName('ShareTokenRow')
class ShareTokens extends Table {
  IntColumn get id => integer()();
  TextColumn get token => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores one row per (trip × region) pair.
///
/// Populated by the scan pipeline after trip inference runs. One row per
/// ISO 3166-2 region code that appears in a trip's photo set.
///
/// Composite primary key `{tripId, regionCode}` allows a single trip to span
/// multiple regions (e.g. a US road trip through CA, NV, and AZ).
///
/// [isDirty] is 1 until the row has been successfully synced to Firestore
/// (sync not implemented until a future milestone — ADR-051).
@DataClassName('RegionVisitRow')
class RegionVisits extends Table {
  TextColumn get tripId => text()();
  TextColumn get regionCode => text()();
  TextColumn get countryCode => text()();
  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastSeen => dateTime()();
  IntColumn get photoCount => integer().withDefault(const Constant(0))();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {tripId, regionCode};
}

/// Per-photo country + timestamp records (ADR-048).
///
/// One row per geotagged photo; populated during scanning.
/// Composite primary key `{countryCode, capturedAt}` prevents duplicate rows
/// on incremental re-scans.
///
/// Stores [countryCode], [capturedAt], and optional [regionCode] —
/// no GPS coordinates (ADR-002).
/// Used by the trip inference engine to cluster photos into trips.
@DataClassName('PhotoDateRow')
class PhotoDateRecords extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get capturedAt => dateTime()();

  /// ISO 3166-2 region code resolved during scanning. Null when the coordinate
  /// falls in open water, a micro-state with no admin1 divisions, or for rows
  /// created before schema v7.
  TextColumn get regionCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {countryCode, capturedAt};
}

/// Stores one row per trip (inferred or manual).
///
/// **Identity (ADR-047):**
/// - Inferred: `id = "${countryCode}_${startedOn.toIso8601String()}"`
/// - Manual:   `id = "manual_${8-char random hex}"`
///
/// [isDirty] is 1 until the row has been successfully synced to Firestore.
@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get countryCode => text()();
  DateTimeColumn get startedOn => dateTime()();
  DateTimeColumn get endedOn => dateTime()();
  IntColumn get photoCount => integer()();

  /// 1 = manually created/edited; 0 = inferred from photos.
  IntColumn get isManual => integer().withDefault(const Constant(0))();
  IntColumn get isDirty => integer().withDefault(const Constant(1))();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  ScanMetadata,
  InferredCountryVisits,
  UserAddedCountries,
  UserRemovedCountries,
  UnlockedAchievements,
  ShareTokens,
  RegionVisits,
  PhotoDateRecords,
  Trips,
])
class RoavvyDatabase extends _$RoavvyDatabase {
  RoavvyDatabase(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(scanMetadata);
      }
      if (from < 3) {
        await m.addColumn(inferredCountryVisits, inferredCountryVisits.isDirty);
        await m.addColumn(inferredCountryVisits, inferredCountryVisits.syncedAt);
        await m.addColumn(userAddedCountries, userAddedCountries.isDirty);
        await m.addColumn(userAddedCountries, userAddedCountries.syncedAt);
        await m.addColumn(userRemovedCountries, userRemovedCountries.isDirty);
        await m.addColumn(userRemovedCountries, userRemovedCountries.syncedAt);
      }
      if (from < 4) {
        await m.createTable(unlockedAchievements);
      }
      if (from < 5) {
        await m.createTable(shareTokens);
      }
      if (from < 6) {
        await m.createTable(photoDateRecords);
        await m.createTable(trips);
        await m.addColumn(scanMetadata, scanMetadata.bootstrapCompletedAt);
      }
      if (from < 7) {
        await m.addColumn(photoDateRecords, photoDateRecords.regionCode);
        await m.createTable(regionVisits);
      }
    },
  );
}
