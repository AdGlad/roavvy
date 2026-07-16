import 'package:drift/drift.dart';

import 'db/roavvy_database.dart';

/// Stores and retrieves GPS coordinates for geotagged photos.
///
/// Coordinates are fetched once by [PhotoGpsFetchService] and cached here
/// permanently. Only photos whose PhotoKit asset exposes non-null lat/lng
/// are stored (ADR-160).
class PhotoGpsRepository {
  const PhotoGpsRepository(this._db);

  final RoavvyDatabase _db;

  /// Upserts a single GPS location for [assetId].
  Future<void> store(String assetId, double lat, double lng) =>
      _db.into(_db.photoGpsCache).insertOnConflictUpdate(
        PhotoGpsCacheCompanion.insert(
          assetId: assetId,
          lat: lat,
          lng: lng,
        ),
      );

  /// Bulk upserts a list of locations. More efficient than calling [store]
  /// in a loop for large batches.
  Future<void> storeBatch(List<PhotoLocation> locations) async {
    await _db.batch((batch) {
      for (final loc in locations) {
        batch.insert(
          _db.photoGpsCache,
          PhotoGpsCacheCompanion.insert(
            assetId: loc.assetId,
            lat: loc.lat,
            lng: loc.lng,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Returns all cached GPS locations.
  Future<List<PhotoLocation>> loadAll() async {
    final rows = await _db.select(_db.photoGpsCache).get();
    return rows.map((r) => PhotoLocation(r.assetId, r.lat, r.lng)).toList();
  }

  /// Returns the set of assetIds that already have a cached GPS entry.
  /// Used by [PhotoGpsFetchService] to skip already-processed assets.
  Future<Set<String>> cachedAssetIds() async {
    final rows = await (_db.select(_db.photoGpsCache)
          ..orderBy([]))
        .map((r) => r.assetId)
        .get();
    return rows.toSet();
  }
}

/// Lightweight record tying an on-device photo asset to its GPS position.
class PhotoLocation {
  const PhotoLocation(this.assetId, this.lat, this.lng);

  final String assetId;
  final double lat;
  final double lng;
}
