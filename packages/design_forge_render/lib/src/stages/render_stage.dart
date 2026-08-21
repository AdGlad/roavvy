import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../asset_resolver.dart';
import '../render_target.dart';

/// Shared, mutable pipeline state handed to each stage in order.
///
/// The pipeline is **image-in / image-out**: the composition stage builds
/// [artwork] (a transparent-background `ui.Image`), and every later stage
/// (clip, edge-treatment, effects, colour) transforms [artwork] into a new
/// `ui.Image`. The renderer flattens the final [artwork] over the target
/// background. This lets masks (`dstIn`/`dstOut`) and colour filters affect only
/// the artwork, never the garment background — exactly how the production
/// pipeline composes artwork then runs `PrintStylePipeline` on it.
class RenderContext {
  RenderContext({
    required this.target,
    required this.assets,
  });

  final RenderTarget target;
  final AssetResolver assets;

  /// The current artwork layer. Null until the composition stage sets it.
  ui.Image? artwork;

  int get width => target.width;
  int get height => target.height;

  /// Record [draw] into a target-sized picture and rasterise it.
  Future<ui.Image> rasterise(void Function(ui.Canvas canvas) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    draw(canvas);
    return recorder.endRecording().toImage(width, height);
  }

  /// Transform [artwork] by drawing it (via [draw]) into a fresh layer. The
  /// callback receives the canvas and the source image; it decides how to paint
  /// it (e.g. with a colour filter, or followed by a `dstIn` mask). No-op if
  /// there is no artwork yet.
  Future<void> transformArtwork(
    void Function(ui.Canvas canvas, ui.Image src) draw,
  ) async {
    final src = artwork;
    if (src == null) return;
    artwork = await rasterise((canvas) => draw(canvas, src));
  }

  ui.Rect get fullRect =>
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
}

/// One step of the render pipeline. Adding an effect means adding a stage, not
/// editing the renderer.
///
/// Pipeline order:
///   Assets → Composition → FlagCombination → Geometry/Mask → EdgeTreatment →
///   Effects → Colour → Typography/Graphics → Output.
abstract class RenderStage {
  const RenderStage();

  String get id;

  Future<void> apply(DesignRecipe recipe, RenderContext ctx);
}
