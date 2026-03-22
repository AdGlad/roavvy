import 'package:drift/drift.dart';
import 'package:shared_models/shared_models.dart';

import 'db/roavvy_database.dart';

/// Mediates all reads and writes to the [RegionVisits] Drift table.
///
/// Each row represents a user's visit to one ISO 3166-2 region within a
/// single trip. Populated by the scan pipeline after trip inference runs
/// (Task 45). Not yet synced to Firestore (ADR-051).
class RegionRepository {
  const RegionRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Upserts [visits] using insert-or-replace.
  ///
  /// Re-inference after an incremental scan replaces existing rows with
  /// updated [lastSeen] and [photoCount] values.
  Future<void> upsertAll(List<RegionVisit> visits) async {
    if (visits.isEmpty) return;
    await _db.transaction(() async {
      for (final v in visits) {
        await _db.into(_db.regionVisits).insertOnConflictUpdate(
          RegionVisitsCompanion(
            tripId: Value(v.tripId),
            regionCode: Value(v.regionCode),
            countryCode: Value(v.countryCode),
            firstSeen: Value(v.firstSeen.toUtc()),
            lastSeen: Value(v.lastSeen.toUtc()),
            photoCount: Value(v.photoCount),
            isDirty: const Value(1),
          ),
        );
      }
    });
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Returns the number of distinct region codes across all region visits.
  ///
  /// Used by the Stats screen to display the "Regions" stat tile (ADR-052).
  Future<int> countUnique() async {
    final result = await _db.customSelect(
      'SELECT COUNT(DISTINCT region_code) AS cnt FROM region_visits',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Returns all region visits for [countryCode], across all trips.
  Future<List<RegionVisit>> loadByCountry(String countryCode) async {
    final rows = await (_db.select(_db.regionVisits)
          ..where((t) => t.countryCode.equals(countryCode)))
        .get();
    return rows.map(_rowToRecord).toList();
  }

  /// Returns all region visits across every country and trip.
  ///
  /// Used by [RegionBreakdownSheet] to display the full region breakdown.
  Future<List<RegionVisit>> loadAll() async {
    final rows = await _db.select(_db.regionVisits).get();
    return rows.map(_rowToRecord).toList();
  }

  /// Returns all region visits belonging to [tripId].
  Future<List<RegionVisit>> loadByTrip(String tripId) async {
    final rows = await (_db.select(_db.regionVisits)
          ..where((t) => t.tripId.equals(tripId)))
        .get();
    return rows.map(_rowToRecord).toList();
  }

  // ── Deletes ──────────────────────────────────────────────────────────────

  /// Deletes all region visits for [tripId].
  ///
  /// Called when the user deletes a trip (Correction 3 — ADR-051).
  Future<void> deleteByTrip(String tripId) =>
      (_db.delete(_db.regionVisits)..where((t) => t.tripId.equals(tripId)))
          .go();

  /// Deletes all rows.
  ///
  /// Called as part of "delete travel history" (Task 45).
  Future<void> clearAll() => _db.delete(_db.regionVisits).go();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static RegionVisit _rowToRecord(RegionVisitRow r) => RegionVisit(
        tripId: r.tripId,
        countryCode: r.countryCode,
        regionCode: r.regionCode,
        firstSeen: r.firstSeen.toUtc(),
        lastSeen: r.lastSeen.toUtc(),
        photoCount: r.photoCount,
      );
}
