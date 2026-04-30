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

  /// Returns all rank-1 heroes across every trip.
  ///
  /// Used by [MemoryPulseService] to find the next future anniversary for
  /// notification scheduling (M91, ADR-136).
  Future<List<HeroImage>> getHeroesForRank1() async {
    final rows = await (_db.select(_db.heroImages)
          ..where((t) => t.rank.equals(1)))
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

  // ── M91 Memory Pulse queries ──────────────────────────────────────────────

  /// Returns rank-1 hero images whose [capturedAt] matches today's month+day
  /// and is at least 1 year before [today] (UTC). Used by [MemoryPulseService].
  ///
  /// Uses a raw `strftime` query because Drift's typed API does not support
  /// calendar-date extraction (ADR-136). `captured_at` is stored as Unix
  /// milliseconds, so we divide by 1000 before passing to strftime.
  Future<List<HeroImage>> getHeroesWithAnniversaryToday(DateTime today) async {
    final utc = today.toUtc();
    final mmdd =
        '${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
    // 365-day threshold so leap-year edge cases don't block 1-year-ago results.
    final oneYearAgoMs =
        utc.subtract(const Duration(days: 365)).millisecondsSinceEpoch;

    final rows = await _db
        .customSelect(
          'SELECT * FROM hero_images '
          "WHERE strftime('%m-%d', captured_at / 1000, 'unixepoch') = ? "
          'AND captured_at < ? '
          'AND rank = 1',
          variables: [
            Variable.withString(mmdd),
            Variable.withInt(oneYearAgoMs),
          ],
          readsFrom: {_db.heroImages},
        )
        .get();

    return rows.map(_fromQueryRow).toList();
  }

  HeroImage _fromQueryRow(QueryRow row) {
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
      id: row.read<String>('id'),
      assetId: row.read<String>('asset_id'),
      tripId: row.read<String>('trip_id'),
      countryCode: row.read<String>('country_code'),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('captured_at'),
        isUtc: true,
      ),
      heroScore: row.read<double>('hero_score'),
      rank: row.read<int>('rank'),
      isUserSelected: row.read<int>('is_user_selected') == 1,
      primaryScene: row.readNullable<String>('primary_scene'),
      secondaryScene: row.readNullable<String>('secondary_scene'),
      activity: parseList(row.readNullable<String>('activity')),
      mood: parseList(row.readNullable<String>('mood')),
      subjects: parseList(row.readNullable<String>('subjects')),
      landmark: row.readNullable<String>('landmark'),
      labelConfidence: row.read<double>('label_confidence'),
      qualityScore: row.read<double>('quality_score'),
      thumbnailLocalPath: row.readNullable<String>('thumbnail_local_path'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
        isUtc: true,
      ),
    );
  }

  // ── M90 UI queries ────────────────────────────────────────────────────────

  /// Streams the single highest-scoring rank-1 hero for [countryCode].
  ///
  /// Used by [bestHeroForCountryProvider] to power the country detail sheet.
  /// Emits null when no hero exists for the country.
  Stream<HeroImage?> watchBestHeroForCountry(String countryCode) {
    return (_db.select(_db.heroImages)
          ..where((t) =>
              t.countryCode.equals(countryCode) &
              t.rank.isBiggerOrEqualValue(1))
          ..orderBy([(t) => OrderingTerm.desc(t.heroScore)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  /// Returns the single highest-scoring rank-1 hero across [tripIds].
  ///
  /// Used by scan summary "best shot" section. Returns null when no heroes
  /// have been analysed for the given trips yet.
  Future<HeroImage?> getBestHeroFromTrips(List<String> tripIds) async {
    if (tripIds.isEmpty) return null;
    final rows = await (_db.select(_db.heroImages)
          ..where((t) =>
              t.tripId.isIn(tripIds) & t.rank.isBiggerOrEqualValue(1))
          ..orderBy([(t) => OrderingTerm.desc(t.heroScore)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Sets [assetId] as the user-selected hero for [tripId].
  ///
  /// Clears [isUserSelected] on all other rows for the trip, then sets it
  /// on the chosen row. Promotes the chosen row to rank 1 if needed.
  /// The isUserSelected guard (ADR-134) then protects it from re-scan.
  Future<void> setUserSelected(String assetId, String tripId) async {
    await _db.transaction(() async {
      await (_db.update(_db.heroImages)
            ..where((t) => t.tripId.equals(tripId)))
          .write(const HeroImagesCompanion(isUserSelected: Value(0)));

      await (_db.update(_db.heroImages)
            ..where((t) =>
                t.assetId.equals(assetId) & t.tripId.equals(tripId)))
          .write(const HeroImagesCompanion(
            isUserSelected: Value(1),
            rank: Value(1),
          ));
    });
  }

  /// Sets [assetId] as the user-selected hero for [tripId], inserting a new
  /// row if the photo was not previously stored as a hero candidate.
  ///
  /// Use this when the user picks any trip photo (not just an existing
  /// hero candidate). Supplying [countryCode] and [capturedAt] is required
  /// so the new row has complete metadata if it does not already exist.
  ///
  /// Clears [isUserSelected] on all other rows for the trip, then upserts
  /// the chosen photo as rank-1 with isUserSelected=1.
  Future<void> upsertUserSelected({
    required String assetId,
    required String tripId,
    required String countryCode,
    required DateTime capturedAt,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      // Clear selection on existing rows.
      await (_db.update(_db.heroImages)
            ..where((t) => t.tripId.equals(tripId)))
          .write(const HeroImagesCompanion(isUserSelected: Value(0)));

      // Upsert the selected photo as the rank-1 hero.
      // If a row already exists for this assetId+tripId it is updated;
      // if not, a minimal row is inserted (scores default to 0).
      await _db.into(_db.heroImages).insertOnConflictUpdate(
        HeroImagesCompanion(
          id: Value('hero_$tripId'),
          assetId: Value(assetId),
          tripId: Value(tripId),
          countryCode: Value(countryCode),
          capturedAt: Value(capturedAt.millisecondsSinceEpoch),
          heroScore: const Value(0.0),
          rank: const Value(1),
          isUserSelected: const Value(1),
          labelConfidence: const Value(0.0),
          qualityScore: const Value(0.0),
          createdAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
    });
  }

  /// Clears [isUserSelected] on all rows for [tripId].
  ///
  /// The next scan/analysis pass will overwrite these rows with auto-ranked
  /// results (the isUserSelected guard no longer blocks them).
  Future<void> clearUserSelected(String tripId) async {
    await (_db.update(_db.heroImages)
          ..where((t) => t.tripId.equals(tripId)))
        .write(const HeroImagesCompanion(isUserSelected: Value(0)));
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
