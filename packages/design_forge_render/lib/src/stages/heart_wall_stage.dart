import 'package:design_forge/design_forge.dart';

import 'heart_pair_stage.dart';
import 'render_stage.dart';

/// Paints every flag of the recipe as a small brushed heart in a grid when
/// the recipe asks for it ([DesignRecipe.heartWall], the Heart Wall
/// signature, M214); a no-op otherwise. Replaces whatever the composition
/// drew. Geometry comes from [HeartWallLayout]; the hearts are painted by
/// [HeartPairStage.paintHearts], each with its own strokes.
class HeartWallStage extends RenderStage {
  const HeartWallStage();

  @override
  String get id => 'heartWall';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final p = recipe.heartWall;
    if (p == null || recipe.content.flags.isEmpty) return;
    final layout = HeartWallLayout.compute(p,
        width: ctx.width.toDouble(),
        height: ctx.height.toDouble(),
        codes: [for (final f in recipe.content.flags) f.code],
        seed: recipe.seed);
    ctx.artwork = await HeartPairStage.paintHearts(
      ctx,
      layout.slots,
      seed: DeterministicRng.hashString('heartWall:${recipe.seed}'),
      hatchAngle: p.hatchAngle,
      hatchWidth: p.hatchWidth,
      spill: p.spill,
      tails: p.tails,
      streaks: p.streaks,
      frayed: p.frayed,
      scratches: p.scratches,
    );
  }
}
