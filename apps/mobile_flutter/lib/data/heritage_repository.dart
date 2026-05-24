import 'dart:math';

import 'package:drift/drift.dart';
import 'package:shared_models/shared_models.dart';

import 'db/roavvy_database.dart';

/// Mediates all reads and writes to the [VisitedHeritageSites] Drift table.
///
/// Upsert logic merges incoming records with existing rows so that:
/// - [firstSeen] always keeps the earliest observed date.
/// - [lastSeen] always keeps the latest observed date.
/// - [photoCount] is summed across scans.
/// - [confidence] is upgraded from `"nearby"` → `"strong"` but never downgraded.
/// - [nearestDistanceKm] keeps the minimum observed distance.
///
/// Keyed on [VisitedHeritageSite.siteId]; one row per site regardless of how
/// many member countries a transboundary site spans. (ADR-163, ADR-165)
class HeritageRepository {
  const HeritageRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Upserts [sites] into the database, merging with existing rows.
  ///
  /// For existing rows the merge rules above apply. For new siteIds a fresh
  /// row is inserted. Idempotent for unchanged data.
  Future<void> upsertAll(List<VisitedHeritageSite> sites) async {
    if (sites.isEmpty) return;

    // Load existing rows in one query to apply merge logic in Dart.
    final existing = await _db.select(_db.visitedHeritageSites).get();
    final existingById = {for (final r in existing) r.siteId: r};

    await _db.transaction(() async {
      for (final site in sites) {
        final prev = existingById[site.siteId];
        final merged = prev == null
            ? VisitedHeritageSitesCompanion.insert(
                siteId: site.siteId,
                name: site.name,
                countryCode: site.countryCode,
                category: site.category,
                latitude: site.latitude,
                longitude: site.longitude,
                inscriptionYear: Value(site.inscriptionYear),
                firstSeen: site.firstSeen.toUtc(),
                lastSeen: site.lastSeen.toUtc(),
                photoCount: Value(site.photoCount),
                confidence: site.confidence,
                nearestDistanceKm: site.nearestDistanceKm,
              )
            : VisitedHeritageSitesCompanion.insert(
                siteId: site.siteId,
                name: site.name,
                countryCode: site.countryCode,
                category: site.category,
                latitude: site.latitude,
                longitude: site.longitude,
                inscriptionYear: Value(site.inscriptionYear),
                firstSeen: prev.firstSeen.isBefore(site.firstSeen)
                    ? prev.firstSeen
                    : site.firstSeen.toUtc(),
                lastSeen: prev.lastSeen.isAfter(site.lastSeen)
                    ? prev.lastSeen
                    : site.lastSeen.toUtc(),
                photoCount: Value(prev.photoCount + site.photoCount),
                confidence:
                    _strongerConfidence(prev.confidence, site.confidence),
                nearestDistanceKm:
                    min(prev.nearestDistanceKm, site.nearestDistanceKm),
              );
        await _db.into(_db.visitedHeritageSites).insertOnConflictUpdate(merged);
      }
    });
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  Future<List<VisitedHeritageSite>> loadAll() async {
    final rows = await _db.select(_db.visitedHeritageSites).get();
    return rows.map(_fromRow).toList();
  }

  Future<List<VisitedHeritageSite>> loadByCountry(String countryCode) async {
    final rows = await (_db.select(_db.visitedHeritageSites)
          ..where((t) => t.countryCode.equals(countryCode)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<int> loadVisitedCount() async {
    final rows = await _db.select(_db.visitedHeritageSites).get();
    return rows.length;
  }

  /// Returns a map of `category → count` for achievement evaluation.
  Future<Map<String, int>> loadVisitedCountByCategory() async {
    final rows = await _db.select(_db.visitedHeritageSites).get();
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.category] = (counts[row.category] ?? 0) + 1;
    }
    return counts;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static VisitedHeritageSite _fromRow(VisitedHeritageSiteRow row) {
    return VisitedHeritageSite(
      siteId: row.siteId,
      name: row.name,
      countryCode: row.countryCode,
      category: row.category,
      latitude: row.latitude,
      longitude: row.longitude,
      inscriptionYear: row.inscriptionYear,
      firstSeen: row.firstSeen,
      lastSeen: row.lastSeen,
      photoCount: row.photoCount,
      confidence: row.confidence,
      nearestDistanceKm: row.nearestDistanceKm,
    );
  }

  /// Returns the stronger of two confidence strings.
  /// `"strong"` > `"nearby"`. (ADR-165)
  static String _strongerConfidence(String a, String b) =>
      (a == 'strong' || b == 'strong') ? 'strong' : 'nearby';
}
