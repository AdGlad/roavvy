import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'asset_resolver.dart';
import 'effects/keyline.dart';
import 'render_target.dart';
import 'stages/render_stage.dart';
import 'stages/composition_stage.dart';
import 'stages/clip_stage.dart';
import 'stages/globe_stage.dart';
import 'stages/edge_treatment_stage.dart';
import 'stages/effects_stage.dart';
import 'stages/colour_stage.dart';
import 'stages/typography_stage.dart';
import 'stages/watercolour_stage.dart';

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
        GlobeStage(),
        ClipStage(),
        WatercolourStage(),
        EdgeTreatmentStage(),
        EffectsStage(),
        ColourStage(),
        TypographyStage(),
      ];

  @override
  Future<RenderResult> render(DesignRecipe recipe, RenderTarget target) async {
    final sw = Stopwatch()..start();
    // A quarter turn draws the design on the swapped canvas (its own shape),
    // then turns it onto [target], which it fills exactly.
    final quarter = recipe.composition.isQuarterTurn;
    final ctx = RenderContext(
      target: quarter
          ? RenderTarget(
              width: target.height,
              height: target.width,
              quality: target.quality,
              background: target.background,
              paintBackground: target.paintBackground)
          : target,
      assets: assets,
    );
    final out = RenderContext(target: target, assets: assets);

    for (final stage in stages) {
      await stage.apply(recipe, ctx);
    }

    // Keyline around the silhouette, before rotation (so it turns with it).
    final comp = recipe.composition;
    final drawn = ctx.artwork;
    ui.Color ringColour(String c) => c == Composition.autoOutline
        ? Keyline.autoFor(target.background)
        : (Keyline.parse(c) ?? Keyline.dark);
    if (drawn != null && comp.outlineRings.isNotEmpty) {
      final unit = math.min(ctx.width, ctx.height) / 100;
      ctx.artwork = await Keyline.applyRings(drawn, [
        for (final r in comp.outlineRings) (r.width * unit, ringColour(r.colour)),
      ]);
    } else if (drawn != null && comp.outlineWidth > 0) {
      final radius = comp.outlineWidth / 100 * math.min(ctx.width, ctx.height);
      final colour = comp.outlineColour == Composition.autoOutline
          ? Keyline.autoFor(target.background)
          : (Keyline.parse(comp.outlineColour) ?? Keyline.dark);
      ctx.artwork = await Keyline.apply(drawn, radius, colour);
    }

    // Flatten: background (garment) then the final artwork layer.
    final image = await out.rasterise((canvas) {
      if (target.background != null && target.paintBackground) {
        canvas.drawRect(out.fullRect, ui.Paint()..color = target.background!);
      }
      final art = ctx.artwork;
      if (art != null) {
        _drawArtwork(canvas, art, out.width.toDouble(), out.height.toDouble(),
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
/// Draws the finished [art] onto a [w]×[h] canvas, centred, shrunk by the
/// size class [scale] and turned [rotation] degrees ANTICLOCKWISE. For a
/// quarter turn [art] was drawn on the swapped (h×w) canvas, so once turned it
/// fills [w]×[h] exactly.
void _drawArtwork(ui.Canvas canvas, ui.Image art, double w, double h,
    double scale, int rotation) {
  final aw = art.width.toDouble(), ah = art.height.toDouble();
  final src = ui.Rect.fromLTWH(0, 0, aw, ah);
  if (rotation == 0 && scale >= 0.999) {
    canvas.drawImage(art, ui.Offset.zero, ui.Paint());
    return;
  }
  canvas
    ..save()
    ..translate(w / 2, h / 2)
    // Canvas y points down, so a negative angle turns anticlockwise on screen.
    ..rotate(-rotation * 3.141592653589793 / 180)
    ..drawImageRect(
        art,
        src,
        ui.Rect.fromCenter(center: ui.Offset.zero, width: aw * scale, height: ah * scale),
        ui.Paint()..filterQuality = ui.FilterQuality.high)
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
