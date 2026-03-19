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
/// - All write methods set [isDirty] = 1 so the sync service can identify
///   unsynced rows (ADR-030).
class VisitRepository {
  const VisitRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Upsert-merge a single inferred visit.
  ///
  /// If a row for [visit.countryCode] already exists, the new [photoCount] is
  /// added to the stored value and [firstSeen]/[lastSeen] are merged
  /// (earliest/latest). Otherwise the row is inserted as-is.
  /// Always sets [isDirty] = 1.
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
        isDirty: const Value(1),
      );

      await _db
          .into(_db.inferredCountryVisits)
          .insertOnConflictUpdate(companion);
    });
  }

  /// Upsert-merge a list of inferred visits in a single transaction.
  ///
  /// Reads all existing rows for the incoming codes upfront, then merges and
  /// upserts in one pass — no nested transactions. Always sets [isDirty] = 1.
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
          isDirty: const Value(1),
        );
        await _db
            .into(_db.inferredCountryVisits)
            .insertOnConflictUpdate(companion);
      }
    });
  }

  /// Record a user addition and cancel any removal for the same code.
  /// Always sets [isDirty] = 1.
  Future<void> saveAdded(UserAddedCountry added) async {
    await _db.transaction(() async {
      await (_db.delete(_db.userRemovedCountries)
            ..where((t) => t.countryCode.equals(added.countryCode)))
          .go();
      await _db.into(_db.userAddedCountries).insertOnConflictUpdate(
        UserAddedCountriesCompanion(
          countryCode: Value(added.countryCode),
          addedAt: Value(added.addedAt),
          isDirty: const Value(1),
        ),
      );
    });
  }

  /// Record a user removal and cancel any addition for the same code.
  /// Always sets [isDirty] = 1.
  Future<void> saveRemoved(UserRemovedCountry removed) async {
    await _db.transaction(() async {
      await (_db.delete(_db.userAddedCountries)
            ..where((t) => t.countryCode.equals(removed.countryCode)))
          .go();
      await _db.into(_db.userRemovedCountries).insertOnConflictUpdate(
        UserRemovedCountriesCompanion(
          countryCode: Value(removed.countryCode),
          removedAt: Value(removed.removedAt),
          isDirty: const Value(1),
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

  // ── Dirty reads (for Firestore sync) ─────────────────────────────────────

  /// Returns all inferred visit rows with [isDirty] = 1.
  Future<List<InferredCountryVisit>> loadDirtyInferred() async {
    final rows = await (_db.select(_db.inferredCountryVisits)
          ..where((t) => t.isDirty.equals(1)))
        .get();
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

  /// Returns all user-added rows with [isDirty] = 1.
  Future<List<UserAddedCountry>> loadDirtyAdded() async {
    final rows = await (_db.select(_db.userAddedCountries)
          ..where((t) => t.isDirty.equals(1)))
        .get();
    return rows
        .map((r) => UserAddedCountry(countryCode: r.countryCode, addedAt: r.addedAt.toUtc()))
        .toList();
  }

  /// Returns all user-removed rows with [isDirty] = 1.
  Future<List<UserRemovedCountry>> loadDirtyRemoved() async {
    final rows = await (_db.select(_db.userRemovedCountries)
          ..where((t) => t.isDirty.equals(1)))
        .get();
    return rows
        .map((r) => UserRemovedCountry(countryCode: r.countryCode, removedAt: r.removedAt.toUtc()))
        .toList();
  }

  // ── Mark clean (called by FirestoreSyncService after a successful write) ──

  /// Sets [isDirty] = 0 and [syncedAt] for an inferred visit row.
  Future<void> markInferredClean(String countryCode, DateTime syncedAt) =>
      (_db.update(_db.inferredCountryVisits)
            ..where((t) => t.countryCode.equals(countryCode)))
          .write(InferredCountryVisitsCompanion(
        isDirty: const Value(0),
        syncedAt: Value(syncedAt.toUtc().toIso8601String()),
      ));

  /// Sets [isDirty] = 0 and [syncedAt] for a user-added row.
  Future<void> markAddedClean(String countryCode, DateTime syncedAt) =>
      (_db.update(_db.userAddedCountries)
            ..where((t) => t.countryCode.equals(countryCode)))
          .write(UserAddedCountriesCompanion(
        isDirty: const Value(0),
        syncedAt: Value(syncedAt.toUtc().toIso8601String()),
      ));

  /// Sets [isDirty] = 0 and [syncedAt] for a user-removed row.
  Future<void> markRemovedClean(String countryCode, DateTime syncedAt) =>
      (_db.update(_db.userRemovedCountries)
            ..where((t) => t.countryCode.equals(countryCode)))
          .write(UserRemovedCountriesCompanion(
        isDirty: const Value(0),
        syncedAt: Value(syncedAt.toUtc().toIso8601String()),
      ));

  // ── Deletes ──────────────────────────────────────────────────────────────

  /// Clears the inferred table and writes [visits] in a single transaction.
  ///
  /// Preferred over separate [clearInferred] + [saveAllInferred] calls because
  /// it eliminates the data-loss window where a failure between the two
  /// operations leaves the user with no inferred visits.
  /// Always sets [isDirty] = 1 on newly written rows.
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
            isDirty: const Value(1),
          ),
        );
      }
    });
  }

  /// Clears only the inferred table. Used before a full rescan so stale
  /// inferred data does not accumulate with the new scan results.
  Future<void> clearInferred() =>
      _db.delete(_db.inferredCountryVisits).go();

  /// Wipes all visit tables, photo date records, trips, and scan metadata.
  /// Used for user-initiated reset and tests. Clears [lastScanAt] so the next
  /// scan is a full scan (ADR-022).
  ///
  /// Does NOT delete [shareTokens] so that previously shared URLs remain
  /// valid after history reset (ADR-041).
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.inferredCountryVisits).go();
      await _db.delete(_db.userAddedCountries).go();
      await _db.delete(_db.userRemovedCountries).go();
      await _db.delete(_db.scanMetadata).go();
      await _db.delete(_db.photoDateRecords).go();
      await _db.delete(_db.trips).go();
      await _db.delete(_db.regionVisits).go();
    });
  }

  // ── Scan metadata ────────────────────────────────────────────────────────

  /// Returns the UTC timestamp of the last successful scan, or null if no
  /// scan has completed (triggers a full scan on next call to startPhotoScan).
  Future<DateTime?> loadLastScanAt() async {
    final row = await (_db.select(_db.scanMetadata)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final raw = row?.lastScanAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Persists [value] as the last successful scan timestamp.
  ///
  /// Call only after a scan completes without error (ADR-022).
  Future<void> saveLastScanAt(DateTime value) => _db
      .into(_db.scanMetadata)
      .insertOnConflictUpdate(ScanMetadataCompanion(
        id: const Value(1),
        lastScanAt: Value(value.toUtc().toIso8601String()),
      ));

  /// Clears [lastScanAt] so the next scan performs a full scan.
  Future<void> clearLastScanAt() =>
      _db.delete(_db.scanMetadata).go();

  // ── Photo date records (ADR-048) ─────────────────────────────────────────

  /// Saves [records] to `photo_date_records` using insert-or-ignore semantics.
  ///
  /// The composite PK `{countryCode, capturedAt}` prevents duplicates on
  /// incremental re-scans. Rows already present are silently skipped.
  ///
  /// Only call with records whose [PhotoDateRecord.capturedAt] is non-null
  /// (photos without a creation date cannot contribute to trip inference).
  Future<void> savePhotoDates(List<PhotoDateRecord> records) async {
    if (records.isEmpty) return;
    await _db.transaction(() async {
      for (final r in records) {
        await _db
            .into(_db.photoDateRecords)
            .insertOnConflictUpdate(PhotoDateRecordsCompanion(
          countryCode: Value(r.countryCode),
          capturedAt: Value(r.capturedAt.toUtc()),
          regionCode: Value(r.regionCode),
        ));
      }
    });
  }

  /// Returns all rows in `photo_date_records`.
  Future<List<PhotoDateRecord>> loadPhotoDates() async {
    final rows = await _db.select(_db.photoDateRecords).get();
    return rows
        .map((r) => PhotoDateRecord(
              countryCode: r.countryCode,
              capturedAt: r.capturedAt.toUtc(),
              regionCode: r.regionCode,
            ))
        .toList();
  }

  /// Deletes all rows in `photo_date_records`.
  Future<void> clearPhotoDates() => _db.delete(_db.photoDateRecords).go();

  // ── Bootstrap flag (ADR-048) ──────────────────────────────────────────────

  /// Persists [value] as the bootstrap completion timestamp on `ScanMetadata`
  /// row id=1.
  ///
  /// Call once after the existing-user bootstrap produces trips from
  /// `firstSeen`/`lastSeen` data so the bootstrap does not re-run on the next
  /// launch.
  Future<void> saveBootstrapCompletedAt(DateTime value) => _db
      .into(_db.scanMetadata)
      .insertOnConflictUpdate(ScanMetadataCompanion(
        id: const Value(1),
        bootstrapCompletedAt: Value(value.toUtc().toIso8601String()),
      ));

  /// Returns the UTC timestamp when the existing-user bootstrap completed, or
  /// null if bootstrap has not yet run (or was cleared by [clearAll]).
  Future<DateTime?> loadBootstrapCompletedAt() async {
    final row = await (_db.select(_db.scanMetadata)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final raw = row?.bootstrapCompletedAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  // ── Share token (ADR-041) ─────────────────────────────────────────────────

  /// Returns the stored share token, or null if none has been saved yet.
  Future<String?> getShareToken() async {
    final row = await (_db.select(_db.shareTokens)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return row?.token;
  }

  /// Persists [token] as the singleton share token (id = 1).
  Future<void> saveShareToken(String token) => _db
      .into(_db.shareTokens)
      .insertOnConflictUpdate(ShareTokensCompanion(
        id: const Value(1),
        token: Value(token),
      ));

  /// Deletes the share token row (id = 1).
  ///
  /// Called after a successful revocation so the map link is no longer shown.
  Future<void> clearShareToken() =>
      (_db.delete(_db.shareTokens)..where((t) => t.id.equals(1))).go();

  // ── Misc ──────────────────────────────────────────────────────────────────

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
