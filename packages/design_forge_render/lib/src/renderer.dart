import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'asset_resolver.dart';
import 'render_target.dart';
import 'stages/render_stage.dart';
import 'stages/composition_stage.dart';
import 'stages/clip_stage.dart';
import 'stages/edge_treatment_stage.dart';
import 'stages/effects_stage.dart';
import 'stages/colour_stage.dart';
import 'stages/typography_stage.dart';

/// Turns a [DesignRecipe] into pixels. The default [CanvasRenderer] is a
/// **headless** pipeline: it draws directly to a `ui.Canvas` via a
/// `PictureRecorder` — no widget tree, no `OverlayEntry`, no `BuildContext` —
/// so it runs in an isolate, a flutter test, the macOS Lab, and (later) the
/// mobile app through the same code path.
abstract class Renderer {
  Future<RenderResult> render(DesignRecipe recipe, RenderTarget target);
}

/// The composable, stage-based renderer. Stages run in order against a shared
/// [RenderContext]; new effects are new stages, never a new renderer.
class CanvasRenderer implements Renderer {
  CanvasRenderer({
    required this.assets,
    List<RenderStage>? stages,
  }) : stages = stages ?? defaultStages();

  final AssetResolver assets;
  final List<RenderStage> stages;

  /// The default pipeline in canonical order:
  /// Composition → Clip(geometry/mask) → EdgeTreatment → Effects → Colour →
  /// Typography. Typography is a top overlay drawn AFTER the colour grade so the
  /// grade never washes out the title text.
  static List<RenderStage> defaultStages() => const [
        CompositionStage(),
        ClipStage(),
        EdgeTreatmentStage(),
        EffectsStage(),
        ColourStage(),
        TypographyStage(),
      ];

  @override
  Future<RenderResult> render(DesignRecipe recipe, RenderTarget target) async {
    final sw = Stopwatch()..start();
    final ctx = RenderContext(target: target, assets: assets);

    for (final stage in stages) {
      await stage.apply(recipe, ctx);
    }

    // Flatten: background (garment) then the final artwork layer.
    final image = await ctx.rasterise((canvas) {
      if (target.background != null && target.paintBackground) {
        canvas.drawRect(ctx.fullRect, ui.Paint()..color = target.background!);
      }
      final art = ctx.artwork;
      if (art != null) {
        _drawArtwork(canvas, art, ctx.width.toDouble(), ctx.height.toDouble(),
            recipe.composition.sizeClass.scale, recipe.composition.rotation);
      }
    });

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    sw.stop();

    return RenderResult(
      image: image,
      pngBytes: pngBytes,
      recipeId: recipe.recipeId,
      imageHash: _fnv1aBytes(pngBytes),
      elapsedMicros: sw.elapsedMicroseconds,
    );
  }
}

/// Stable 64-bit FNV-1a over bytes → 16-char hex. Used to assert render
/// determinism without relying on cross-GPU pixel equality.
/// Draws the finished [art] (canvas-sized, [w]×[h]) centred, shrunk by the
/// size class [scale] and turned [rotation] degrees ANTICLOCKWISE. A quarter
/// turn swaps the artwork's width and height, so it is fitted back inside the
/// same footprint (a portrait design on its side lands at ~80% width).
void _drawArtwork(ui.Canvas canvas, ui.Image art, double w, double h,
    double scale, int rotation) {
  final src = ui.Rect.fromLTWH(0, 0, w, h);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
  if (rotation == 0) {
    if (scale >= 0.999) {
      canvas.drawImage(art, ui.Offset.zero, ui.Paint());
    } else {
      canvas.drawImageRect(art, src,
          ui.Rect.fromLTWH(w * (1 - scale) / 2, h * (1 - scale) / 2, w * scale, h * scale),
          paint);
    }
    return;
  }
  final quarter = rotation == 90 || rotation == 270;
  // Turned footprint is (h × w); fit it inside (w × h) · scale.
  final k = quarter ? scale * (w / h < h / w ? w / h : h / w) : scale;
  canvas
    ..save()
    ..translate(w / 2, h / 2)
    // Canvas y points down, so a negative angle turns anticlockwise on screen.
    ..rotate(-rotation * 3.141592653589793 / 180)
    ..drawImageRect(art, src,
        ui.Rect.fromCenter(center: ui.Offset.zero, width: w * k, height: h * k), paint)
    ..restore();
}

String _fnv1aBytes(List<int> bytes) {
  const int mask = 0xFFFFFFFFFFFFFFFF;
  var h = 0xCBF29CE484222325;
  for (final b in bytes) {
    h = (h ^ (b & 0xFF)) & mask;
    h = (h * 0x100000001B3) & mask;
  }
  return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}
