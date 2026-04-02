import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Singleton cache for bundled product mockup images.
///
/// Loads [ui.Image] objects from the Flutter asset bundle and caches them in
/// memory. Evicts the oldest entry when the cache grows beyond [maxEntries].
///
/// Call [dispose] from the owning widget's [dispose] to release [ui.Image]
/// handles and free GPU memory.
class LocalMockupImageCache {
  LocalMockupImageCache._();

  static final LocalMockupImageCache instance = LocalMockupImageCache._();

  /// Maximum number of cached entries. Sufficient for browsing all colour
  /// variants without memory pressure (ADR-107).
  static const int maxEntries = 6;

  // Ordered map: insertion order tracks LRU age (oldest = first key).
  final Map<String, ui.Image> _cache = {};

  /// Returns a [ui.Image] decoded from the asset at [assetPath].
  ///
  /// Subsequent calls with the same path return the cached instance without
  /// re-decoding. Throws [FlutterError] if the asset cannot be loaded.
  Future<ui.Image> load(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) {
      // Refresh LRU position: move to end.
      _cache.remove(assetPath);
      _cache[assetPath] = cached;
      return cached;
    }

    final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (e) {
      throw FlutterError(
        'LocalMockupImageCache: failed to load asset "$assetPath". '
        'Ensure the path is registered in pubspec.yaml assets. '
        'Original error: $e',
      );
    }

    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Evict oldest entry if at capacity.
    if (_cache.length >= maxEntries) {
      final oldest = _cache.keys.first;
      _cache[oldest]?.dispose();
      _cache.remove(oldest);
    }

    _cache[assetPath] = image;
    return image;
  }

  /// Disposes all cached [ui.Image] handles and clears the cache.
  ///
  /// Call from the owning widget's [dispose] method.
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
  }
}
