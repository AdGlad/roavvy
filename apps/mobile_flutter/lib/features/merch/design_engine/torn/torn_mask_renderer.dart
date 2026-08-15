import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'torn_geometry_generator.dart';
import 'torn_recipe.dart';

/// The "Renderer" box of `TornRecipe → TornGeometryGenerator → Mask → Renderer`.
///
/// Turns a [TornRecipe] into a `ui.Image` **keep-mask** (white, alpha = kept
/// cloth) and applies it to intact flag artwork with [ui.BlendMode.dstIn] so the
/// torn perimeter is carved out of the (single or already-blended) flag. Flag-
/// agnostic: multi-flag designs blend first, then get one shared torn silhouette.
///
/// Masks are cached by [TornRecipe.tornId] + size, so the realtime feed can
/// re-render the same design cheaply; the cache owns and disposes its images.
class TornMaskRenderer {
  TornMaskRenderer._();
  static final TornMaskRenderer instance = TornMaskRenderer._();

  static const int _defaultCap = 1024;
  final _MaskCache _cache = _MaskCache(maxEntries: 12);
  final TornGeometryGenerator _geometry = const TornGeometryGenerator();

  /// A `ui.Image` keep-mask (alpha = kept cloth) for [recipe] at up to [cap] on
  /// the long side, matching the [width]/[height] aspect. Anti-aliased via
  /// [supersample]. Cached — **do not dispose the returned image**; the cache
  /// manages its lifecycle.
  Future<ui.Image> keepMask(
    TornRecipe recipe, {
    required int width,
    required int height,
    int cap = _defaultCap,
    int supersample = 2,
  }) async {
    final longSide = width > height ? width : height;
    final scale = longSide > cap ? cap / longSide : 1.0;
    final mw = (width * scale).round().clamp(2, cap);
    final mh = (height * scale).round().clamp(2, cap);

    final key = '${recipe.tornId}_${mw}x$mh';
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final mask = _geometry.generate(recipe,
        width: mw, height: mh, supersample: supersample);
    final img = await _toImage(mask);
    _cache.put(key, img);
    return img;
  }

  /// Applies [recipe]'s torn perimeter to intact [flag] artwork, returning a new
  /// image at the same dimensions. The caller owns [flag] and the result.
  Future<ui.Image> applyTo(ui.Image flag, TornRecipe recipe) async {
    final w = flag.width;
    final h = flag.height;
    final mask = await keepMask(recipe, width: w, height: h);
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(flag, rect, rect, ui.Paint());
    compositeInto(canvas, rect, mask);
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    return out;
  }

  /// Draws [mask] over the current canvas with `dstIn` so only the kept cloth of
  /// the already-drawn artwork survives. `filterQuality.low` lets the pre-AA'd
  /// fibre edges upscale softly rather than re-hardening to a jagged cut.
  void compositeInto(ui.Canvas canvas, ui.Rect dst, ui.Image mask) {
    canvas.drawImageRect(
      mask,
      ui.Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
      dst,
      ui.Paint()
        ..blendMode = ui.BlendMode.dstIn
        ..filterQuality = ui.FilterQuality.low,
    );
  }

  Future<ui.Image> _toImage(TornMask mask) {
    // RGBA where only alpha carries the mask (dstIn ignores src RGB); white RGB
    // keeps it debuggable.
    final rgba = Uint8List(mask.width * mask.height * 4);
    for (var i = 0; i < mask.alpha.length; i++) {
      final o = i * 4;
      rgba[o] = 255;
      rgba[o + 1] = 255;
      rgba[o + 2] = 255;
      rgba[o + 3] = mask.alpha[i];
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, mask.width, mask.height, ui.PixelFormat.rgba8888,
        completer.complete);
    return completer.future;
  }

  /// Test/maintenance hook: drop all cached masks.
  void clearCache() => _cache.clear();
}

/// Tiny LRU of keep-mask images; disposes images it evicts.
class _MaskCache {
  _MaskCache({required this.maxEntries});
  final int maxEntries;
  final Map<String, ui.Image> _entries = {}; // insertion-ordered == LRU

  ui.Image? get(String key) {
    final img = _entries.remove(key);
    if (img != null) _entries[key] = img; // re-insert as most-recent
    return img;
  }

  void put(String key, ui.Image img) {
    _entries.remove(key);
    _entries[key] = img;
    while (_entries.length > maxEntries) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest)?.dispose();
    }
  }

  void clear() {
    for (final img in _entries.values) {
      img.dispose();
    }
    _entries.clear();
  }
}
