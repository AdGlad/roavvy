import 'package:photo_manager/photo_manager.dart' hide LatLng;

import '../../data/db/roavvy_database.dart';
import '../../data/photo_gps_repository.dart';

/// Background service that fetches GPS coordinates from PhotoKit and caches
/// them in [PhotoGpsCache] (M155, ADR-160).
///
/// Must be called on the main isolate — [AssetEntity] uses platform channels
/// and cannot cross isolate boundaries.
///
/// Processes uncached assetIds in batches of [_kBatchSize] with a small
/// [_kBatchDelay] between batches so the UI remains responsive.
class PhotoGpsFetchService {
  const PhotoGpsFetchService({
    required RoavvyDatabase db,
    required PhotoGpsRepository repo,
  })  : _db = db,
        _repo = repo;

  static const int _kBatchSize = 50;
  static const Duration _kBatchDelay = Duration(milliseconds: 20);

  final RoavvyDatabase _db;
  final PhotoGpsRepository _repo;

  /// Fetches and caches GPS for all assetIds in [PhotoDateRecords] that are
  /// not yet in [PhotoGpsCache].
  ///
  /// Skips assets whose [AssetEntity] is null (deleted from library) or
  /// whose lat/lng is null (no EXIF location data).
  ///
  /// Safe to call multiple times — already-cached assets are skipped.
  Future<void> fetchAndCache() async {
    final allAssetIds = await _loadAllAssetIds();
    if (allAssetIds.isEmpty) return;

    final cached = await _repo.cachedAssetIds();
    final uncached =
        allAssetIds.where((id) => !cached.contains(id)).toList();
    if (uncached.isEmpty) return;

    for (var i = 0; i < uncached.length; i += _kBatchSize) {
      final batch = uncached.skip(i).take(_kBatchSize).toList();
      final locations = await _fetchBatch(batch);
      if (locations.isNotEmpty) {
        await _repo.storeBatch(locations);
      }
      if (i + _kBatchSize < uncached.length) {
        await Future<void>.delayed(_kBatchDelay);
      }
    }
  }

  Future<List<String>> _loadAllAssetIds() async {
    final rows = await (_db.select(_db.photoDateRecords)
          ..where((t) => t.assetId.isNotNull()))
        .get();
    return rows.map((r) => r.assetId!).toList();
  }

  Future<List<PhotoLocation>> _fetchBatch(List<String> assetIds) async {
    final results = <PhotoLocation>[];
    for (final id in assetIds) {
      try {
        final entity = await AssetEntity.fromId(id);
        if (entity == null) continue;
        final lat = entity.latitude;
        final lng = entity.longitude;
        if (lat == null || lng == null || lat == 0.0 && lng == 0.0) continue;
        results.add(PhotoLocation(id, lat, lng));
      } catch (_) {
        // Silently skip inaccessible or deleted assets.
      }
    }
    return results;
  }
}
