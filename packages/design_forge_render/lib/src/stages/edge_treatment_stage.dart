import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import '../geometry/torn_mask.dart';
import 'render_stage.dart';

/// Applies a torn/ripped OUTER-edge treatment to the artwork by masking it with
/// a deterministic torn alpha mask (`dstIn`). Interior stays intact.
class EdgeTreatmentStage extends RenderStage {
  const EdgeTreatmentStage({this.generator = const TornMaskGenerator()});

  final TornMaskGenerator generator;

  @override
  String get id => 'edgeTreatment';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final edge = recipe.edgeTreatment;
    if (edge == null || ctx.artwork == null) return;

    // Seed the mask from the recipe seed + a named sub-stream so it varies
    // independently of composition choices but stays reproducible.
    final maskSeed =
        DeterministicRng(recipe.seed).stream('edge:torn').nextInt(1 << 30);

    final clipped =
        recipe.clip != null && recipe.clip!.shape != ClipShape.none;
    if (clipped) {
      // The artwork is a non-rectangular shape (silhouette / heart / circle):
      // tear its OWN outline so the rip follows the shape, not the frame.
      ctx.artwork = await generator.erodeOutline(ctx.artwork!, edge, maskSeed);
      return;
    }

    // Full-bleed rectangular artwork: tear the frame perimeter (flag look).
    final mask = await generator.generate(ctx.width, ctx.height, edge, maskSeed);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(src, ui.Offset.zero, ui.Paint());
      canvas.drawImage(
        mask,
        ui.Offset.zero,
        ui.Paint()..blendMode = ui.BlendMode.dstIn,
      );
    });
  }
}
