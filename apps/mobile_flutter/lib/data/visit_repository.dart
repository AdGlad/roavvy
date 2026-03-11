import 'package:drift/drift.dart';
import 'package:shared_models/shared_models.dart';

import 'db/roavvy_database.dart';

/// Mediates all reads and writes to the three Drift tables that back the
/// visited-country state.
///
/// Design decisions (ADR-016):
/// - [saveInferred] upserts using read-modify-write inside a transaction so
///   that [photoCount] accumulates and [firstSeen]/[lastSeen] are merged
///   correctly across scan runs.
/// - [saveAdded] deletes any [UserRemovedCountries] row for the same code
///   ("un-delete" semantics, ADR-006).
/// - [saveRemoved] deletes any [UserAddedCountries] row for the same code.
class VisitRepository {
  const VisitRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Upsert-merge a single inferred visit.
  ///
  /// If a row for [visit.countryCode] already exists, the new [photoCount] is
  /// added to the stored value and [firstSeen]/[lastSeen] are merged
  /// (earliest/latest). Otherwise the row is inserted as-is.
  Future<void> saveInferred(InferredCountryVisit visit) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.inferredCountryVisits)
            ..where((t) => t.countryCode.equals(visit.countryCode)))
          .getSingleOrNull();

      final companion = InferredCountryVisitsCompanion(
        countryCode: Value(visit.countryCode),
        inferredAt: Value(visit.inferredAt),
        photoCount: Value(
          existing == null
              ? visit.photoCount
              : existing.photoCount + visit.photoCount,
        ),
        firstSeen: Value(_earlier(existing?.firstSeen, visit.firstSeen)),
        lastSeen: Value(_later(existing?.lastSeen, visit.lastSeen)),
      );

      await _db
          .into(_db.inferredCountryVisits)
          .insertOnConflictUpdate(companion);
    });
  }

  /// Upsert-merge a list of inferred visits in a single transaction.
  ///
  /// Reads all existing rows for the incoming codes upfront, then merges and
  /// upserts in one pass — no nested transactions.
  Future<void> saveAllInferred(List<InferredCountryVisit> visits) async {
    if (visits.isEmpty) return;
    await _db.transaction(() async {
      final codes = visits.map((v) => v.countryCode).toSet().toList();
      final existing = await (_db.select(_db.inferredCountryVisits)
            ..where((t) => t.countryCode.isIn(codes)))
          .get();
      final existingByCode = {for (final r in existing) r.countryCode: r};

      for (final v in visits) {
        final ex = existingByCode[v.countryCode];
        final companion = InferredCountryVisitsCompanion(
          countryCode: Value(v.countryCode),
          inferredAt: Value(v.inferredAt),
          photoCount: Value(
            ex == null ? v.photoCount : ex.photoCount + v.photoCount,
          ),
          firstSeen: Value(_earlier(ex?.firstSeen, v.firstSeen)),
          lastSeen: Value(_later(ex?.lastSeen, v.lastSeen)),
        );
        await _db
            .into(_db.inferredCountryVisits)
            .insertOnConflictUpdate(companion);
      }
    });
  }

  /// Record a user addition and cancel any removal for the same code.
  Future<void> saveAdded(UserAddedCountry added) async {
    await _db.transaction(() async {
      await (_db.delete(_db.userRemovedCountries)
            ..where((t) => t.countryCode.equals(added.countryCode)))
          .go();
      await _db.into(_db.userAddedCountries).insertOnConflictUpdate(
        UserAddedCountriesCompanion(
          countryCode: Value(added.countryCode),
          addedAt: Value(added.addedAt),
        ),
      );
    });
  }

  /// Record a user removal and cancel any addition for the same code.
  Future<void> saveRemoved(UserRemovedCountry removed) async {
    await _db.transaction(() async {
      await (_db.delete(_db.userAddedCountries)
            ..where((t) => t.countryCode.equals(removed.countryCode)))
          .go();
      await _db.into(_db.userRemovedCountries).insertOnConflictUpdate(
        UserRemovedCountriesCompanion(
          countryCode: Value(removed.countryCode),
          removedAt: Value(removed.removedAt),
        ),
      );
    });
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  Future<List<InferredCountryVisit>> loadInferred() async {
    final rows = await _db.select(_db.inferredCountryVisits).get();
    return rows
        .map(
          (r) => InferredCountryVisit(
            countryCode: r.countryCode,
            inferredAt: r.inferredAt.toUtc(),
            photoCount: r.photoCount,
            firstSeen: r.firstSeen?.toUtc(),
            lastSeen: r.lastSeen?.toUtc(),
          ),
        )
        .toList();
  }

  Future<List<UserAddedCountry>> loadAdded() async {
    final rows = await _db.select(_db.userAddedCountries).get();
    return rows
        .map((r) => UserAddedCountry(countryCode: r.countryCode, addedAt: r.addedAt.toUtc()))
        .toList();
  }

  Future<List<UserRemovedCountry>> loadRemoved() async {
    final rows = await _db.select(_db.userRemovedCountries).get();
    return rows
        .map((r) => UserRemovedCountry(countryCode: r.countryCode, removedAt: r.removedAt.toUtc()))
        .toList();
  }

  /// Loads and merges all three tables into the effective visited-country set.
  Future<List<EffectiveVisitedCountry>> loadEffective() async {
    final inferred = await loadInferred();
    final added = await loadAdded();
    final removed = await loadRemoved();
    return effectiveVisitedCountries(
      inferred: inferred,
      added: added,
      removed: removed,
    );
  }

  // ── Deletes ──────────────────────────────────────────────────────────────

  /// Clears the inferred table and writes [visits] in a single transaction.
  ///
  /// Preferred over separate [clearInferred] + [saveAllInferred] calls because
  /// it eliminates the data-loss window where a failure between the two
  /// operations leaves the user with no inferred visits.
  Future<void> clearAndSaveAllInferred(List<InferredCountryVisit> visits) async {
    await _db.transaction(() async {
      await _db.delete(_db.inferredCountryVisits).go();
      for (final v in visits) {
        await _db.into(_db.inferredCountryVisits).insertOnConflictUpdate(
          InferredCountryVisitsCompanion(
            countryCode: Value(v.countryCode),
            inferredAt: Value(v.inferredAt),
            photoCount: Value(v.photoCount),
            firstSeen: Value(v.firstSeen),
            lastSeen: Value(v.lastSeen),
          ),
        );
      }
    });
  }

  /// Clears only the inferred table. Used before a full rescan so stale
  /// inferred data does not accumulate with the new scan results.
  Future<void> clearInferred() =>
      _db.delete(_db.inferredCountryVisits).go();

  /// Wipes all three tables. Useful for user-initiated reset and tests.
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.inferredCountryVisits).go();
      await _db.delete(_db.userAddedCountries).go();
      await _db.delete(_db.userRemovedCountries).go();
    });
  }

  /// Closes the underlying database connection.
  ///
  /// Call from the owning widget dispose() to release SQLite resources cleanly.
  Future<void> close() => _db.close();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DateTime? _earlier(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
