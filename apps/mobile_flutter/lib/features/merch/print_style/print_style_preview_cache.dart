import 'dart:typed_data';

/// Small LRU cache of **styled artwork PNG bytes**, so browsing print styles is
/// instant after the first generation of each style and never re-runs the
/// pipeline for a style the user already previewed.
///
/// Keyed by `(artworkHash, styleId, seed)` — a new base artwork (different
/// hash), a different style, or a different seed all miss and regenerate.
/// Bounded to [maxEntries] (LRU eviction), mirroring [LocalMockupImageCache]'s
/// memory discipline.
class PrintStylePreviewCache {
  PrintStylePreviewCache({this.maxEntries = 8});

  final int maxEntries;

  // Insertion-ordered: first key is the oldest (LRU).
  final Map<String, Uint8List> _cache = {};

  static String keyFor({
    required String artworkHash,
    required String styleId,
    required int seed,
  }) => '${artworkHash}_${styleId}_$seed';

  /// Returns cached styled bytes for [key], refreshing its LRU position, or null.
  Uint8List? get(String key) {
    final v = _cache.remove(key);
    if (v != null) _cache[key] = v; // move to most-recent
    return v;
  }

  /// Stores [bytes] under [key], evicting the oldest entry when at capacity.
  void put(String key, Uint8List bytes) {
    _cache.remove(key);
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  void clear() => _cache.clear();

  int get length => _cache.length;
}
