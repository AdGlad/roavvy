import 'package:drift/drift.dart';
import 'package:shared_models/shared_models.dart';

import 'db/roavvy_database.dart';

/// Mediates all reads and writes to the Drift [Trips] table.
///
/// Trip identity (ADR-047):
/// - Inferred: id = "${countryCode}_${startedOn.toIso8601String()}"
/// - Manual:   id = "manual_${8-char random hex}"
///
/// [upsertAll] uses `insertOrReplace` semantics — re-inference updates
/// [TripRecord.endedOn] and [TripRecord.photoCount] in place without changing
/// the id (the natural key is anchored to [TripRecord.startedOn]).
class TripRepository {
  const TripRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Upserts [trips] using insert-or-replace.
  ///
  /// For inferred trips this updates [endedOn] and [photoCount] when a cluster
  /// grows after an incremental scan. Always sets [isDirty] = 1.
  Future<void> upsertAll(List<TripRecord> trips) async {
    if (trips.isEmpty) return;
    await _db.transaction(() async {
      for (final t in trips) {
        await _db.into(_db.trips).insertOnConflictUpdate(
          TripsCompanion(
            id: Value(t.id),
            countryCode: Value(t.countryCode),
            startedOn: Value(t.startedOn.toUtc()),
            endedOn: Value(t.endedOn.toUtc()),
            photoCount: Value(t.photoCount),
            isManual: Value(t.isManual ? 1 : 0),
            isDirty: const Value(1),
          ),
        );
      }
    });
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Returns all trips, unsorted.
  Future<List<TripRecord>> loadAll() async {
    final rows = await _db.select(_db.trips).get();
    return rows.map(_rowToRecord).toList();
  }

  /// Returns all trips for [countryCode], sorted by [startedOn] descending
  /// (most recent first).
  Future<List<TripRecord>> loadByCountry(String countryCode) async {
    final rows = await (_db.select(_db.trips)
          ..where((t) => t.countryCode.equals(countryCode))
          ..orderBy([(t) => OrderingTerm.desc(t.startedOn)]))
        .get();
    return rows.map(_rowToRecord).toList();
  }

  // ── Dirty reads (for Firestore sync) ─────────────────────────────────────

  /// Returns all rows with [isDirty] = 1.
  Future<List<TripRecord>> loadDirty() async {
    final rows = await (_db.select(_db.trips)
          ..where((t) => t.isDirty.equals(1)))
        .get();
    return rows.map(_rowToRecord).toList();
  }

  // ── Mark clean ───────────────────────────────────────────────────────────

  /// Sets [isDirty] = 0 and [syncedAt] for the trip with [id].
  Future<void> markClean(String id, DateTime syncedAt) =>
      (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
        TripsCompanion(
          isDirty: const Value(0),
          syncedAt: Value(syncedAt.toUtc().toIso8601String()),
        ),
      );

  // ── Deletes ──────────────────────────────────────────────────────────────

  /// Deletes the trip with [id]. Used when the user deletes a manual trip or
  /// when a manual trip's [startedOn] is edited (old id → delete, new id → upsert).
  Future<void> delete(String id) =>
      (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();

  /// Deletes all trips, including manual ones.
  ///
  /// Called as part of [VisitRepository.clearAll] ("delete travel history").
  /// Manual trips are cleared too — they are part of the travel record.
  Future<void> clearAll() => _db.delete(_db.trips).go();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static TripRecord _rowToRecord(TripRow r) => TripRecord(
        id: r.id,
        countryCode: r.countryCode,
        startedOn: r.startedOn.toUtc(),
        endedOn: r.endedOn.toUtc(),
        photoCount: r.photoCount,
        isManual: r.isManual == 1,
      );
}
