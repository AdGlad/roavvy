import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_models/shared_models.dart';

import '../../data/db/roavvy_database.dart';

/// Mediates reads and writes to the Drift [HeroImages] table (M89, ADR-134).
///
/// Enforces the [isUserSelected] guard: rows where `isUserSelected = true`
/// are never overwritten by automatic analysis or re-scanning.
///
/// [assetId] and [thumbnailLocalPath] are device-local values that must
/// never appear in Firestore (extends ADR-002, ADR-060).
class HeroImageRepository {
  const HeroImageRepository(this._db);

  final RoavvyDatabase _db;

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Upserts the hero and candidate rows for a trip.
  ///
  /// Skips any row where the existing DB row has `isUserSelected = 1` —
  /// user choices are permanent until the user explicitly resets them.
  Future<void> upsertHeroesForTrip(
    String tripId,
    List<HeroImage> heroes,
  ) async {
    if (heroes.isEmpty) return;

    // Load existing user-selected IDs for this trip.
    final existing = await (_db.select(_db.heroImages)
          ..where((t) =>
              t.tripId.equals(tripId) & t.isUserSelected.equals(1)))
        .get();
    final userSelectedIds = existing.map((r) => r.id).toSet();

    await _db.transaction(() async {
      for (final hero in heroes) {
        if (userSelectedIds.contains(hero.id)) continue; // never overwrite

        await _db.into(_db.heroImages).insertOnConflictUpdate(
          _toCompanion(hero),
        );
      }
    });
  }

  /// Returns the rank-1 hero image for [tripId], or null if none exists.
  Future<HeroImage?> getHeroForTrip(String tripId) async {
    final row = await (_db.select(_db.heroImages)
          ..where((t) => t.tripId.equals(tripId) & t.rank.equals(1)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Returns all hero candidates (rank 1–3) for [tripId], ordered by rank.
  Future<List<HeroImage>> getCandidatesForTrip(String tripId) async {
    final rows = await (_db.select(_db.heroImages)
          ..where((t) => t.tripId.equals(tripId) & t.rank.isBiggerOrEqualValue(1))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Returns all rank-1 heroes for the given [countryCode].
  Future<List<HeroImage>> getHeroesForCountry(String countryCode) async {
    final rows = await (_db.select(_db.heroImages)
          ..where((t) =>
              t.countryCode.equals(countryCode) & t.rank.equals(1)))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Tombstones a hero row (sets rank = -1) without deleting it.
  ///
  /// Used when a PHAsset is no longer available on the device.
  Future<void> tombstone(String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.heroImages)..where((t) => t.id.equals(id))).write(
      HeroImagesCompanion(
        rank: const Value(-1),
        thumbnailLocalPath: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Deletes all hero rows for [tripId] (used when a trip is deleted).
  Future<void> deleteHeroesForTrip(String tripId) async {
    await (_db.delete(_db.heroImages)
          ..where((t) => t.tripId.equals(tripId)))
        .go();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Watches the rank-1 hero image for [tripId], emitting whenever the row
  /// changes (e.g. after background analysis completes).
  Stream<HeroImage?> watchHeroForTrip(String tripId) {
    return (_db.select(_db.heroImages)
          ..where((t) => t.tripId.equals(tripId) & t.rank.equals(1)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  // ── Queries for cache validation ──────────────────────────────────────────

  /// Returns all assetIds where rank >= 0 (non-tombstoned) for batch
  /// existence checking by [HeroCacheValidator].
  Future<List<String>> getAllActiveAssetIds() async {
    final rows = await (_db.select(_db.heroImages)
          ..where((t) => t.rank.isBiggerOrEqualValue(0)))
        .get();
    return rows.map((r) => r.assetId).toList();
  }

  /// Returns all hero rows for a given [assetId] (used by cache validator).
  Future<List<HeroImage>> getCandidatesForAssetId(String assetId) async {
    final rows = await (_db.select(_db.heroImages)
          ..where((t) => t.assetId.equals(assetId)))
        .get();
    return rows.map(_fromRow).toList();
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  HeroImagesCompanion _toCompanion(HeroImage hero) {
    final now = hero.updatedAt.millisecondsSinceEpoch;
    return HeroImagesCompanion(
      id: Value(hero.id),
      assetId: Value(hero.assetId),
      tripId: Value(hero.tripId),
      countryCode: Value(hero.countryCode),
      capturedAt: Value(hero.capturedAt.millisecondsSinceEpoch),
      primaryScene: Value(hero.primaryScene),
      secondaryScene: Value(hero.secondaryScene),
      activity: Value(
        hero.activity.isEmpty ? null : jsonEncode(hero.activity),
      ),
      mood: Value(
        hero.mood.isEmpty ? null : jsonEncode(hero.mood),
      ),
      subjects: Value(
        hero.subjects.isEmpty ? null : jsonEncode(hero.subjects),
      ),
      landmark: Value(hero.landmark),
      labelConfidence: Value(hero.labelConfidence),
      qualityScore: Value(hero.qualityScore),
      heroScore: Value(hero.heroScore),
      rank: Value(hero.rank),
      isUserSelected: Value(hero.isUserSelected ? 1 : 0),
      thumbnailLocalPath: Value(hero.thumbnailLocalPath),
      createdAt: Value(hero.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(now),
    );
  }

  HeroImage _fromRow(HeroImageRow row) {
    List<String> parseList(String? json) {
      if (json == null || json.isEmpty) return const [];
      try {
        final decoded = jsonDecode(json) as List<dynamic>;
        return decoded.whereType<String>().toList();
      } catch (_) {
        return const [];
      }
    }

    return HeroImage(
      id: row.id,
      assetId: row.assetId,
      tripId: row.tripId,
      countryCode: row.countryCode,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        row.capturedAt,
        isUtc: true,
      ),
      heroScore: row.heroScore,
      rank: row.rank,
      isUserSelected: row.isUserSelected == 1,
      primaryScene: row.primaryScene,
      secondaryScene: row.secondaryScene,
      activity: parseList(row.activity),
      mood: parseList(row.mood),
      subjects: parseList(row.subjects),
      landmark: row.landmark,
      labelConfidence: row.labelConfidence,
      qualityScore: row.qualityScore,
      thumbnailLocalPath: row.thumbnailLocalPath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
    );
  }
}
