import 'dart:typed_data';

/// In-process LRU cache for thumbnail image bytes (M170).
///
/// Complements [ThumbnailChannel]'s NSCache (which manages device memory)
/// with a fast synchronous Dart lookup that avoids redundant async channel
/// calls within a session. Capped at [_kMaxEntries] to bound memory use.
class ThumbnailLruCache {
  ThumbnailLruCache._();

  static final ThumbnailLruCache instance = ThumbnailLruCache._();

  // Sized for the map grid's 300-photo cap: ~150px JPEG thumbnails are
  // roughly 15-30 KB each, so 200 entries stays under ~6 MB.
  static const int _kMaxEntries = 200;

  final _cache = <String, Uint8List>{};

  Uint8List? get(String assetId) {
    final bytes = _cache.remove(assetId);
    if (bytes == null) return null;
    // Re-insert at end (most-recently-used).
    _cache[assetId] = bytes;
    return bytes;
  }

  void put(String assetId, Uint8List bytes) {
    _cache.remove(assetId);
    if (_cache.length >= _kMaxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[assetId] = bytes;
  }
}
