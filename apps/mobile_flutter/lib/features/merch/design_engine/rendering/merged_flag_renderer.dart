import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';

import '../procedural/procedural_recipe.dart';
import 'effect_renderer.dart';

/// Renders a two-flag "duo blend" recipe to PNG bytes for the feed: rasterises
/// the two flag SVGs, merges them on the GPU via [SkiaEffectRenderer], and
/// encodes the result. Deterministic in the recipe (blend mode / weight / ripple
/// / seed), so the preview reproduces exactly.
///
/// Returns null for any recipe that isn't a merge, or if a flag can't be loaded
/// (caller falls back to the normal thumbnailer).
class MergedFlagRenderer {
  MergedFlagRenderer(this._effects);

  final SkiaEffectRenderer _effects;

  static Future<MergedFlagRenderer> load() async =>
      MergedFlagRenderer(await SkiaEffectRenderer.load());

  Future<Uint8List?> renderPng(
    ProceduralDesignRecipe recipe, {
    int size = 512,
  }) async {
    if (!recipe.isMerged) return null;
    final a = await _rasterFlag(recipe.countryCodes[0], size);
    final b = await _rasterFlag(recipe.countryCodes[1], size);
    if (a == null || b == null) {
      a?.dispose();
      b?.dispose();
      return null;
    }
    final img = await _effects.blendFlags(
      flagA: a,
      flagB: b,
      size: size,
      weightA: recipe.weightA,
      mode: recipe.combination,
      rippleAmp: recipe.rippleAmp,
      rippleFreq: recipe.rippleFreq,
      seed: recipe.seed,
    );
    a.dispose();
    b.dispose();
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  }

  /// Rasterise a flag SVG to a `size`×`size` square (stretched to fill, so the
  /// whole graphic is flag — the shader samples in uv 0..1).
  Future<ui.Image?> _rasterFlag(String code, int size) async {
    try {
      final loader = SvgAssetLoader(
        'assets/flags/svg/${code.toLowerCase()}.svg',
      );
      final info = await vg.loadPicture(loader, null);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final s = info.size;
      if (s.width > 0 && s.height > 0) {
        canvas.scale(size / s.width, size / s.height);
      }
      canvas.drawPicture(info.picture);
      info.picture.dispose();
      final image = await recorder.endRecording().toImage(size, size);
      return image;
    } catch (_) {
      return null;
    }
  }
}
