import 'dart:math' as math;

import 'package:shared_models/shared_models.dart';

import '../../cards/flag_grid_layout_engine.dart';
import '../merch_preset.dart';
import '../merch_variant_lookup.dart';
import '../product_mockup_specs.dart';
import 'design_engine_contracts.dart';
import 'design_params.dart';
import 'travel_profile.dart';

/// The [Mutator] used by the evolutionary loop (M199 / architecture §7).
///
/// [mutate] perturbs 1–2 high-impact genes; [crossover] mixes two genomes
/// gene-wise. Both always call [DesignParams.normalize] so the output is
/// renderable, and both are pure functions of the injected [math.Random] (so
/// the loop stays deterministic).
class GenomeMutator implements Mutator {
  const GenomeMutator();

  /// Templates the genome may explore (badge excluded per architecture §4).
  static const List<CardTemplateType> _templatePool = [
    CardTemplateType.grid,
    CardTemplateType.passport,
    CardTemplateType.timeline,
    CardTemplateType.wordCloud,
    CardTemplateType.landmark,
    CardTemplateType.typography,
    CardTemplateType.heart,
    CardTemplateType.frontRibbon,
  ];

  static const List<_Gene> _genes = _Gene.values;

  @override
  DesignParams mutate(
    DesignParams params,
    TravelProfile profile,
    math.Random rng,
  ) {
    final geneCount = 1 + rng.nextInt(2); // perturb 1 or 2 genes
    final order = List<_Gene>.of(_genes)..shuffle(rng);
    var next = params;
    for (final gene in order.take(geneCount)) {
      next = _applyGene(gene, next, rng);
    }
    return next.normalize();
  }

  @override
  DesignParams crossover(DesignParams a, DesignParams b, math.Random rng) {
    // The (source, countryCodes, clipShape, clipCode) block must stay internally
    // consistent (a silhouette clip references its single country), so it is
    // inherited wholesale from one parent. The remaining genes mix freely.
    final base = rng.nextBool() ? a : b;
    T pick<T>(T x, T y) => rng.nextBool() ? x : y;
    return DesignParams(
      template: pick(a.template, b.template),
      source: base.source,
      countryCodes: base.countryCodes,
      gridLayoutMode: pick(a.gridLayoutMode, b.gridLayoutMode),
      clipShape: base.clipShape,
      clipCode: base.clipCode,
      rowCount: pick(a.rowCount, b.rowCount),
      density: pick(a.density, b.density),
      jitter: pick(a.jitter, b.jitter),
      stampMode: pick(a.stampMode, b.stampMode),
      isPortrait: pick(a.isPortrait, b.isPortrait),
      imageSize: pick(a.imageSize, b.imageSize),
      shirtColour: pick(a.shirtColour, b.shirtColour),
      seed: pick(a.seed, b.seed),
    ).normalize();
  }

  // ── Gene mutations ─────────────────────────────────────────────────────────

  DesignParams _applyGene(_Gene gene, DesignParams p, math.Random rng) {
    switch (gene) {
      case _Gene.template:
        return p.copyWith(template: _pick(_templatePool, rng));
      case _Gene.gridLayoutMode:
        return p.copyWith(
          gridLayoutMode: _pick(FlagGridLayoutMode.values, rng),
        );
      case _Gene.clip:
        return _mutateClip(p, rng);
      case _Gene.rowCount:
        final step = (1 + rng.nextInt(2)) * (rng.nextBool() ? 1 : -1);
        return p.copyWith(rowCount: (p.rowCount + step).clamp(1, 10));
      case _Gene.density:
        return p.copyWith(density: _pick(MerchDensity.values, rng));
      case _Gene.jitter:
        final delta = (rng.nextDouble() - 0.5); // ±0.5
        return p.copyWith(jitter: (p.jitter + delta).clamp(0.0, 1.0));
      case _Gene.shirtColour:
        return p.copyWith(
          shirtColour: tshirtColors[rng.nextInt(tshirtColors.length)],
        );
      case _Gene.imageSize:
        return p.copyWith(imageSize: _pick(ImageSize.values, rng));
      case _Gene.orientation:
        return p.copyWith(isPortrait: !p.isPortrait);
      case _Gene.seed:
        return p.copyWith(seed: rng.nextInt(1 << 20));
    }
  }

  /// Chooses a clip shape consistent with the genome's country set. Clips only
  /// apply to the grid template, so a clip mutation also switches [template] to
  /// grid. Silhouette / outline clips are single-country only and carry the
  /// country code; [normalize] is the final safety net.
  DesignParams _mutateClip(DesignParams p, math.Random rng) {
    final options = <(GridClipShape, String?)>[
      (GridClipShape.none, null),
      (GridClipShape.heart, null),
      (GridClipShape.circle, null),
    ];
    if (p.countryCodes.length == 1) {
      final code = p.countryCodes.first;
      options.addAll([
        (GridClipShape.countryOutline, code),
        (GridClipShape.animalSilhouette, code),
        (GridClipShape.plantSilhouette, code),
        (GridClipShape.landmarkSilhouette, code),
      ]);
    }
    final choice = options[rng.nextInt(options.length)];
    return p.copyWith(
      template: CardTemplateType.grid,
      clipShape: choice.$1,
      clipCode: choice.$2,
    );
  }

  T _pick<T>(List<T> values, math.Random rng) =>
      values[rng.nextInt(values.length)];
}

/// High-impact genes mutation may perturb.
enum _Gene {
  template,
  gridLayoutMode,
  clip,
  rowCount,
  density,
  jitter,
  shirtColour,
  imageSize,
  orientation,
  seed,
}
