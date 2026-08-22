import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';
import '../recipe/recipe_parts.dart';
import '../recipe/shape_catalog.dart';

/// Variation axis — each represents one controlled dimension of change.
enum VariationAxis {
  effectIntensity('Effects'),
  colorTreatment('Color'),
  shapeSwap('Shape'),
  orientation('Orientation'),
  edgeTreatment('Edge'),
  garmentColor('Garment');

  const VariationAxis(this.label);
  final String label;
}

/// A recipe paired with the axis it was varied along.
class RecipeVariation {
  const RecipeVariation(this.recipe, this.axis);
  final DesignRecipe recipe;
  final VariationAxis axis;
}

/// Produces recipe neighbours of an anchor along controlled axes.
///
/// Each variation tweaks exactly one axis from the anchor recipe, keeping
/// everything else identical. This lets users explore "what if the shape
/// changed?" or "what if the effects were stronger?" independently.
class VariationGenerator {
  const VariationGenerator();

  /// Generate [count] variations of [anchor], distributed across axes.
  ///
  /// Returns at most [count] variations. Some axes may produce fewer
  /// variations than others depending on the anchor's properties.
  List<RecipeVariation> variate(
    DesignRecipe anchor, {
    int count = 12,
    int? seed,
  }) {
    final rng = DeterministicRng(seed ?? anchor.seed);
    final variations = <RecipeVariation>[];

    // Target ~2 per axis, round-robin.
    final perAxis = (count / VariationAxis.values.length).ceil();

    for (final axis in VariationAxis.values) {
      final axisRng = rng.stream('var_${axis.name}');
      final axisVariations = _variateAxis(anchor, axis, perAxis, axisRng);
      variations.addAll(axisVariations);
    }

    // Trim to count if we overshot.
    if (variations.length > count) variations.length = count;
    return variations;
  }

  List<RecipeVariation> _variateAxis(
    DesignRecipe anchor,
    VariationAxis axis,
    int count,
    DeterministicRng rng,
  ) {
    switch (axis) {
      case VariationAxis.effectIntensity:
        return _variateEffects(anchor, count, rng);
      case VariationAxis.colorTreatment:
        return _variateColor(anchor, count, rng);
      case VariationAxis.shapeSwap:
        return _variateShape(anchor, count, rng);
      case VariationAxis.orientation:
        return _variateOrientation(anchor, count, rng);
      case VariationAxis.edgeTreatment:
        return _variateEdge(anchor, count, rng);
      case VariationAxis.garmentColor:
        return _variateGarment(anchor, count, rng);
    }
  }

  List<RecipeVariation> _variateEffects(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    final base = anchor.effects ?? const Effects();
    final results = <RecipeVariation>[];
    final multipliers = [0.0, 0.5, 1.5, 2.0];
    for (var i = 0; i < count && i < multipliers.length; i++) {
      final m = multipliers[i];
      final varied = Effects(
        distress: (base.distress * m).clamp(0, 1),
        distressHardness: base.distressHardness,
        grain: (base.grain * m).clamp(0, 1),
        fade: (base.fade * m).clamp(0, 1),
        cracks: (base.cracks * m).clamp(0, 1),
        halftone: base.halftone,
        halftoneScale: base.halftoneScale,
        halftoneAngle: base.halftoneAngle,
        rippleAmp: base.rippleAmp,
        rippleFreq: base.rippleFreq,
        acidWash: (base.acidWash * m).clamp(0, 1),
        tieDye: base.tieDye,
        shatter: base.shatter,
        shatterSpikes: base.shatterSpikes,
      );
      results.add(RecipeVariation(
        anchor.copyWith(effects: varied, seed: anchor.seed + i + 100),
        VariationAxis.effectIntensity,
      ));
    }
    return results;
  }

  List<RecipeVariation> _variateColor(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    final base = anchor.palette ?? const Palette();
    final strategies = ColourStrategy.values
        .where((s) => s != base.strategy)
        .toList();
    final results = <RecipeVariation>[];
    for (var i = 0; i < count && i < strategies.length; i++) {
      results.add(RecipeVariation(
        anchor.copyWith(
          palette: Palette(
            garmentColour: base.garmentColour,
            strategy: strategies[i],
            accents: base.accents,
            vintageGrade: base.vintageGrade,
          ),
          seed: anchor.seed + i + 200,
        ),
        VariationAxis.colorTreatment,
      ));
    }
    // Also vary vintage grade.
    if (results.length < count) {
      final grades = [0.0, 0.3, 0.6, 0.9];
      for (final g in grades) {
        if (results.length >= count) break;
        if ((g - base.vintageGrade).abs() < 0.1) continue;
        results.add(RecipeVariation(
          anchor.copyWith(
            palette: Palette(
              garmentColour: base.garmentColour,
              strategy: base.strategy,
              accents: base.accents,
              vintageGrade: g,
            ),
            seed: anchor.seed + results.length + 200,
          ),
          VariationAxis.colorTreatment,
        ));
      }
    }
    return results.take(count).toList();
  }

  List<RecipeVariation> _variateShape(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    final currentId = anchor.clip?.shapeId;
    final candidates = kClipShapeCatalog
        .where((m) => m.id != currentId)
        .toList();
    final shuffled = rng.shuffled(candidates);
    final results = <RecipeVariation>[];
    for (var i = 0; i < count && i < shuffled.length; i++) {
      final meta = shuffled[i];
      final clip = anchor.clip != null
          ? Clip(
              shapeId: meta.id,
              code: anchor.clip!.code,
              text: anchor.clip!.text,
              scale: anchor.clip!.scale,
              rotationDeg: anchor.clip!.rotationDeg,
              aspectRatio: meta.aspectRatio,
              cornerRadius: anchor.clip!.cornerRadius,
              feather: anchor.clip!.feather,
              position: anchor.clip!.position,
            )
          : Clip(shapeId: meta.id, scale: 0.85, aspectRatio: meta.aspectRatio);
      results.add(RecipeVariation(
        anchor.copyWith(clip: clip, seed: anchor.seed + i + 300),
        VariationAxis.shapeSwap,
      ));
    }
    return results;
  }

  List<RecipeVariation> _variateOrientation(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    final current = anchor.composition.orientation;
    final others =
        Orientation.values.where((o) => o != current).toList();
    return others.take(count).map((o) {
      return RecipeVariation(
        anchor.copyWith(
          composition: Composition(
            family: anchor.composition.family,
            orientation: o,
            layoutMode: anchor.composition.layoutMode,
            fillAlgorithm: anchor.composition.fillAlgorithm,
            rowCount: anchor.composition.rowCount,
            density: anchor.composition.density,
            jitter: anchor.composition.jitter,
            placement: anchor.composition.placement,
          ),
          seed: anchor.seed + others.indexOf(o) + 400,
        ),
        VariationAxis.orientation,
      );
    }).toList();
  }

  List<RecipeVariation> _variateEdge(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    final current = anchor.edgeTreatment?.style;
    final styles = TearStyle.values.where((s) => s != current).toList();
    final shuffled = rng.shuffled(styles);
    final results = <RecipeVariation>[];
    // Include "no edge treatment" if anchor has one — build a fresh recipe
    // without edge treatment since copyWith can't null it out.
    if (anchor.edgeTreatment != null && results.length < count) {
      results.add(RecipeVariation(
        DesignRecipe(
          seed: anchor.seed + 500,
          content: anchor.content,
          composition: anchor.composition,
          flagCombination: anchor.flagCombination,
          clip: anchor.clip,
          palette: anchor.palette,
          effects: anchor.effects,
          typography: anchor.typography,
          motifs: anchor.motifs,
          provenance: anchor.provenance,
        ),
        VariationAxis.edgeTreatment,
      ));
    }
    for (var i = 0; i < shuffled.length && results.length < count; i++) {
      final style = shuffled[i];
      results.add(RecipeVariation(
        anchor.copyWith(
          edgeTreatment: EdgeTreatment(
            style: style,
            edgeDamage: rng.nextRange(0.2, 0.6),
            maxDepth: rng.nextRange(0.05, 0.15),
            frayAmount: rng.nextRange(0.0, 0.4),
            cornerDamage: rng.nextRange(0.1, 0.5),
            asymmetry: rng.nextRange(0.1, 0.6),
          ),
          seed: anchor.seed + i + 501,
        ),
        VariationAxis.edgeTreatment,
      ));
    }
    return results;
  }

  List<RecipeVariation> _variateGarment(
    DesignRecipe anchor,
    int count,
    DeterministicRng rng,
  ) {
    const garments = [
      '#FFFFFF', '#F5F5F0', '#1A1A1A', '#2C2C2C',
      '#1B3A4B', '#2D4A3E', '#4A2D2D', '#3D3D5C',
    ];
    final current = anchor.palette?.garmentColour;
    final others = garments.where((g) => g != current).toList();
    final results = <RecipeVariation>[];
    for (var i = 0; i < count && i < others.length; i++) {
      final base = anchor.palette ?? const Palette();
      results.add(RecipeVariation(
        anchor.copyWith(
          palette: Palette(
            garmentColour: others[i],
            strategy: base.strategy,
            accents: base.accents,
            vintageGrade: base.vintageGrade,
          ),
          seed: anchor.seed + i + 600,
        ),
        VariationAxis.garmentColor,
      ));
    }
    return results;
  }
}
