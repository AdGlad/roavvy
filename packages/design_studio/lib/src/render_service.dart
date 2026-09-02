import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/foundation.dart';

/// Temporary startup diagnostics gate (mirrors the mobile host's flag). Enable
/// with `--dart-define=STUDIO_V2_TRACE=true`; zero-cost otherwise.
const bool _kTrace = bool.fromEnvironment('STUDIO_V2_TRACE');

/// Renders recipes to `ui.Image`s with a **bounded LRU** cache keyed by
/// `recipeId@longSide`, so the gallery can scroll and re-layout without
/// re-rendering designs it has already produced. Output aspect follows the
/// recipe's [Orientation] (square / portrait / landscape).
///
/// The cache is capped ([maxCacheEntries]) so a long editing session — most
/// acutely a live Fine-Tune slider drag, which mints a distinct recipe (and a
/// full-resolution render) on every tick — cannot grow memory without bound.
/// On eviction the least-recently-used entry's strong reference is simply
/// dropped; the [ui.Image] is **never** `dispose()`d here, because a mounted
/// widget may still be painting it (the caller owns the image's lifetime).
class RenderService {
  RenderService(AssetResolver assets)
      : _renderer = CanvasRenderer(assets: assets);

  final CanvasRenderer _renderer;

  /// Maximum number of rendered images held at once. Sized to comfortably cover
  /// the hero preview + every on-screen thumbnail tray with headroom, while
  /// capping worst-case memory (a full-res 1024px RGBA image is ~4 MB).
  static const int maxCacheEntries = 64;

  /// Insertion-ordered so the first key is the least-recently-used; a cache hit
  /// re-inserts to move the entry to the most-recently-used end.
  final Map<String, ui.Image> _cache = {};

  /// Live entry count — for diagnostics/tests asserting the bound holds.
  int get cacheSize => _cache.length;

  static const ui.Color _bg = ui.Color(0xFFF2F2F2);

  Renderer get renderer => _renderer;

  /// Width/height for a design's orientation, with [longSide] the larger edge.
  static (int, int) dimsFor(Orientation o, int longSide) {
    final short = (longSide * 0.8).round();
    switch (o) {
      case Orientation.portrait:
        return (short, longSide);
      case Orientation.landscape:
        return (longSide, short);
      case Orientation.square:
        return (longSide, longSide);
    }
  }

  RenderTarget targetFor(DesignRecipe r, int longSide,
      {RenderQuality quality = RenderQuality.preview,
      ui.Color? background,
      bool paintBackground = true}) {
    final (w, h) = dimsFor(r.composition.orientation, longSide);
    // The garment colour is a real design property: fill the background with the
    // recipe's garmentColour when set, so garment-aware re-inking has the right
    // tone to contrast against. Falls back to the neutral preview grey.
    final bg = background ?? _garmentColour(r) ?? _bg;
    return RenderTarget(
        width: w,
        height: h,
        quality: quality,
        background: bg,
        paintBackground: paintBackground);
  }

  /// The recipe's garment colour as a [ui.Color], or null when unset/unparseable
  /// (hex `#rrggbb` / `#aarrggbb`; named colours fall through to the grey default).
  static ui.Color? _garmentColour(DesignRecipe r) {
    var h = r.palette?.garmentColour?.replaceAll('#', '').trim();
    if (h == null) return null;
    if (h.length == 6) h = 'ff$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : ui.Color(v);
  }

  int _renderCalls = 0;

  /// A rendered image of [recipe] at [longSide], cached.
  ///
  /// [transparent] renders the artwork LAYER alone, with nothing behind it —
  /// what an on-garment preview needs, so the design sits on fabric instead of
  /// carrying a coloured card around it. The default bakes the recipe's garment
  /// colour behind the art (falling back to a neutral grey), which is what a
  /// standalone preview tile wants.
  Future<ui.Image> imageFor(
    DesignRecipe recipe,
    int longSide, {
    bool transparent = false,
  }) async {
    final key = '${recipe.recipeId}@$longSide${transparent ? '#alpha' : ''}';
    final cached = _cache[key];
    if (cached != null) {
      // Touch: move to the most-recently-used end so it survives eviction.
      _cache
        ..remove(key)
        ..[key] = cached;
      return cached;
    }
    if (_kTrace) {
      _renderCalls++;
      debugPrint('[v2trace] RenderService.render #$_renderCalls '
          'longSide=$longSide cache=${_cache.length} key=$key');
    }
    final sw = _kTrace ? (Stopwatch()..start()) : null;
    // `transparent` withholds the FILL, not the colour: the stages still ink
    // titles and contrast against the garment tone they will sit on.
    final result = await _renderer.render(recipe,
        targetFor(recipe, longSide, paintBackground: !transparent));
    if (sw != null) {
      debugPrint('[v2trace] RenderService.render #$_renderCalls DONE '
          'in ${sw.elapsedMilliseconds}ms');
    }
    // A concurrent call for the same key may have populated the cache while we
    // awaited; prefer the already-cached image so both callers share one.
    final raced = _cache[key];
    if (raced != null) return raced;
    _cache[key] = result.image;
    if (_cache.length > maxCacheEntries) {
      // Evict the least-recently-used (first) entry. Drop only the strong ref —
      // never dispose(): a mounted widget may still be painting that image.
      _cache.remove(_cache.keys.first);
    }
    return result.image;
  }

  Future<RenderResult> renderFull(DesignRecipe recipe, int longSide) =>
      _renderer.render(
        recipe,
        // No explicit background → targetFor uses the recipe's garment colour
        // (grey fallback), so print output matches the on-garment preview.
        targetFor(recipe, longSide, quality: RenderQuality.print),
      );

  /// Renders the artwork LAYER at print quality with a fully transparent
  /// background — the print-file form a print-on-demand pipeline expects (the
  /// artwork composites onto fabric, so no garment fill is baked in). Distinct
  /// from [renderFull], which bakes the garment colour behind the art for an
  /// on-garment preview.
  Future<RenderResult> renderArtwork(DesignRecipe recipe,
          {int longSide = 2048}) =>
      _renderer.render(
        recipe,
        // The garment fill is withheld, leaving only the artwork — but the
        // garment tone still reaches the stages so the ink stays legible.
        targetFor(recipe, longSide,
            quality: RenderQuality.print, paintBackground: false),
      );
}
