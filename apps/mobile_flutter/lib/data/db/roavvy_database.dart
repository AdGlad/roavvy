import 'package:drift/drift.dart';

part 'roavvy_database.g.dart';

/// Stores one row per country from the scan pipeline.
///
/// Upserted after each scan run: [photoCount] accumulates, [firstSeen] keeps
/// the earliest value and [lastSeen] keeps the latest.
@DataClassName('InferredVisitRow')
class InferredCountryVisits extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get inferredAt => dateTime()();
  IntColumn get photoCount => integer()();
  DateTimeColumn get firstSeen => dateTime().nullable()();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

/// Stores countries the user has explicitly added via the review screen.
///
/// Adding a country also deletes any matching row in [UserRemovedCountries]
/// ("un-delete" semantics per ADR-006).
@DataClassName('AddedCountryRow')
class UserAddedCountries extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

/// Permanent tombstones: "I did not visit here."
///
/// Suppresses any [InferredCountryVisits] or [UserAddedCountries] row for the
/// same code — including future scan results — until the user explicitly
/// re-adds it.
@DataClassName('RemovedCountryRow')
class UserRemovedCountries extends Table {
  TextColumn get countryCode => text()();
  DateTimeColumn get removedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {countryCode};
}

@DriftDatabase(
  tables: [InferredCountryVisits, UserAddedCountries, UserRemovedCountries],
)
class RoavvyDatabase extends _$RoavvyDatabase {
  RoavvyDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
