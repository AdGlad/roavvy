import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';

/// Renders recipes to `ui.Image`s with an in-memory cache keyed by
/// `recipeId@longSide`, so the gallery can scroll and re-layout without
/// re-rendering designs it has already produced. Output aspect follows the
/// recipe's [Orientation] (square / portrait / landscape).
class RenderService {
  RenderService(AssetResolver assets)
      : _renderer = CanvasRenderer(assets: assets);

  final CanvasRenderer _renderer;
  final Map<String, ui.Image> _cache = {};

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
      {RenderQuality quality = RenderQuality.preview, ui.Color? background}) {
    final (w, h) = dimsFor(r.composition.orientation, longSide);
    return RenderTarget(
        width: w, height: h, quality: quality, background: background ?? _bg);
  }

  Future<ui.Image> imageFor(DesignRecipe recipe, int longSide) async {
    final key = '${recipe.recipeId}@$longSide';
    final cached = _cache[key];
    if (cached != null) return cached;
    final result = await _renderer.render(recipe, targetFor(recipe, longSide));
    _cache[key] = result.image;
    return result.image;
  }

  Future<RenderResult> renderFull(DesignRecipe recipe, int longSide) =>
      _renderer.render(
        recipe,
        targetFor(recipe, longSide,
            quality: RenderQuality.print, background: _bg),
      );
}
