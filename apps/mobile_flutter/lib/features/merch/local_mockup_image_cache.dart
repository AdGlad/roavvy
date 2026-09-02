import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../shared/garment_mockup/garment_mockup_spec.dart';
import '../shared/garment_mockup/garment_tint.dart';

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

  /// Loads a spec's garment image and its fabric shading source together
  /// (M174), returning `(garment, shading)`.
  ///
  /// When the spec registers a companion wrinkle map, that map is already a
  /// greyscale luminance and is loaded as-is. Otherwise the shading is derived
  /// from the garment photo with [GarmentTint.luminanceMap].
  ///
  /// It must NOT be the photo itself. The painter multiplies the shading over
  /// the print, so a colour photo multiplies its colour into the ink — the
  /// coloured garment shots (`Red-tshirt-front.jpeg` and friends) would drag
  /// every design towards the shirt's own dye. The derived map is cached under
  /// its own key, so a colour swap costs one pixel pass, once.
  Future<(ui.Image, ui.Image)> loadWithShading(GarmentMockupSpec spec) async {
    final garment = await load(spec.assetPath);
    if (spec.shadingAssetPath != spec.assetPath) {
      return (garment, await load(spec.shadingAssetPath));
    }
    return (garment, await _luminanceOf(spec.assetPath, garment));
  }

  /// The cached luminance map derived from an already-decoded garment photo.
  Future<ui.Image> _luminanceOf(String assetPath, ui.Image garment) async {
    final key = '$assetPath#luma';
    final cached = _cache[key];
    if (cached != null) {
      _cache.remove(key);
      _cache[key] = cached;
      return cached;
    }
    final map = await GarmentTint.luminanceMap(garment);
    // Never evict the garment we were just handed to derive this from.
    if (_cache.length >= maxEntries) {
      final oldest = _cache.keys.firstWhere(
        (k) => !identical(_cache[k], garment),
        orElse: () => _cache.keys.first,
      );
      _cache[oldest]?.dispose();
      _cache.remove(oldest);
    }
    _cache[key] = map;
    return map;
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
