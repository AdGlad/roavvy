import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_params.dart';
import 'procedural/procedural.dart';

/// A generated design ranked for a specific user: intrinsic [quality] and
/// [preference] are reported separately (never conflated), plus the [combined]
/// score actually used for ordering.
class RankedDesign {
  const RankedDesign({
    required this.design,
    required this.quality,
    required this.preference,
    required this.combined,
  });
  final GeneratedDesign design;
  final double quality;
  final double preference;
  final double combined;

  ProceduralDesignRecipe get recipe => design.recipe;

  /// The renderable genome. Rendering is the caller's responsibility and should
  /// happen lazily (thumbnail first, print-resolution only on selection).
  DesignParams get params => design.recipe.toDesignParams();
}

/// The realtime, fully-local entry point the app uses to turn a travel filter
/// into designs:
///
/// ```
/// travel data/filter → DesignContext → candidate recipes → cheap validation →
/// quality scoring → preference re-rank → strongest N → (render lazily)
/// ```
///
/// Everything here is cheap and synchronous (no rasterisation) so it is safe to
/// call while scrolling. Rendering is deliberately NOT done here — the caller
/// renders thumbnails on demand (e.g. via `CardRenderThumbnailer` /
/// `CardImageRenderer`) and only asks for a print-resolution image when a design
/// is chosen. See design_engine/docs/architecture.md §"Rendering".
class ProceduralDesignService {
  const ProceduralDesignService({
    this.generator = const ProceduralDesignGenerator(),
    this.preferenceScorer = const PreferenceScorer(),
  });

  final ProceduralDesignGenerator generator;
  final PreferenceScorer preferenceScorer;

  /// Recommend the strongest [count] designs for [context], re-ranked by the
  /// user's [profile] (if any). Deterministic in `(context, seed)` for a given
  /// profile. [prefBlend] sets the exploration/exploitation balance between
  /// intrinsic quality and personal taste (0 = pure quality).
  List<RankedDesign> recommend(
    DesignContext context, {
    int seed = 0,
    int count = 8,
    int poolSize = 60,
    double exploration = 0.35,
    UserDesignPreferenceProfile profile =
        UserDesignPreferenceProfile.neutral,
    double prefBlend = 0.35,
  }) {
    // Generate a diverse candidate pool (larger than the final count so the
    // preference re-rank has room to work).
    final result = generator.generate(
      context,
      seed: seed,
      count: count * 2,
      poolSize: poolSize,
      exploration: exploration,
    );

    final ranked = [
      for (final d in result.designs)
        () {
          final pref = preferenceScorer.score(d.recipe, profile);
          return RankedDesign(
            design: d,
            quality: d.quality.total,
            preference: pref,
            combined: preferenceScorer.combined(
              d.quality.total,
              pref,
              prefBlend: prefBlend,
            ),
          );
        }(),
    ]..sort((a, b) => b.combined.compareTo(a.combined));

    return ranked.take(count).toList();
  }

  /// Diagnostics for the same request (rejection reasons, mean quality, …) —
  /// handy for on-device telemetry without re-running generation.
  GenerationStats statsFor(
    DesignContext context, {
    int seed = 0,
    int poolSize = 60,
  }) =>
      generator.generate(context, seed: seed, poolSize: poolSize).stats;
}

/// App-wide singleton. The service is const/stateless, so this is cheap and
/// safe to read anywhere in the widget tree.
final proceduralDesignServiceProvider =
    Provider<ProceduralDesignService>((ref) => const ProceduralDesignService());
