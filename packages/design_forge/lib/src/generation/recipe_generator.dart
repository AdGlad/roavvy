import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';

/// The travel/filter input to generation — "what is this design about?".
///
/// Phase-0 minimal: a resolved set of flag codes plus an opaque [scopeKey] used
/// to derive a stable seed and to re-resolve the context later. On mobile this
/// is produced from `TravelProfile`/`MerchContext`; the engine never needs to
/// know how it was derived.
class DesignContext {
  const DesignContext({
    required this.flagCodes,
    this.scopeKey,
  });

  final List<String> flagCodes;
  final String? scopeKey;
}

/// Produces [DesignRecipe]s. The engine renders whatever a generator emits, so
/// generators can be deterministic rules today and preference-learned or
/// on-device-model driven later — **AI proposes recipes, the deterministic
/// engine renders them**. Rendering never depends on a generator.
abstract class RecipeGenerator {
  List<DesignRecipe> generate(
    DesignContext context, {
    required int seed,
    int count = 1,
  });
}

/// A tiny deterministic rule generator that proves the interface end-to-end:
/// picks a family from a seeded sub-stream and maps the resolved flags 1:1.
/// Real grammar/priors arrive in Phase 1.
class DeterministicRuleGenerator implements RecipeGenerator {
  const DeterministicRuleGenerator();

  @override
  List<DesignRecipe> generate(
    DesignContext context, {
    required int seed,
    int count = 1,
  }) {
    final flags = [
      for (final code in context.flagCodes) FlagRef(code.toLowerCase()),
    ];
    return [
      for (var i = 0; i < count; i++)
        _one(context, seed: seed + i, flags: flags),
    ];
  }

  DesignRecipe _one(
    DesignContext context, {
    required int seed,
    required List<FlagRef> flags,
  }) {
    final rng = DeterministicRng(seed);
    final family = flags.length <= 1
        ? DesignFamily.singleHero
        : rng.stream('family').pick(const [
            DesignFamily.grid,
            DesignFamily.duoBlend,
          ]);
    return DesignRecipe(
      seed: seed,
      content: RecipeContent(flags: flags, source: context.scopeKey),
      composition: Composition(family: family),
      provenance: const RecipeProvenance(generator: 'deterministicRule'),
    );
  }
}
