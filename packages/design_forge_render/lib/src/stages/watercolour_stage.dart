import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/watercolour_raster.dart';
import 'render_stage.dart';

/// Paints the clipped artwork in watercolour when the recipe asks for it
/// ([DesignRecipe.watercolour]); a no-op otherwise, so existing recipes are
/// untouched. Runs right after the clip, so the brush wobble and soft ragged
/// rim apply to the shape's outline as well as to the colours inside it.
class WatercolourStage extends RenderStage {
  const WatercolourStage();

  @override
  String get id => 'watercolour';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final wc = recipe.watercolour;
    final art = ctx.artwork;
    if (wc == null || art == null) return;
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final w = art.width, h = art.height;
    final seed = DeterministicRng.hashString('watercolour:${recipe.seed}');
    final out = await Isolate.run(
        () => WatercolourRaster.paint(bytes, w, h, wc, seed));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        out, w, h, ui.PixelFormat.rgba8888, completer.complete);
    ctx.artwork = await completer.future;
  }
}
