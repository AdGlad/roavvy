/// Design Forge — standalone procedural design engine (pure Dart core).
///
/// No `dart:ui`: this library holds the deterministic [DesignRecipe] model, the
/// reproducibility backbone ([DeterministicRng]), and the [RecipeGenerator]
/// contract. Rendering (which needs `dart:ui`) lives in `design_forge_render`.
library design_forge;

export 'src/determinism/deterministic_rng.dart';
export 'src/generation/recipe_generator.dart';
export 'src/recipe/canonical_json.dart';
export 'src/recipe/design_recipe.dart';
export 'src/recipe/procedural_recipe_codec.dart';
export 'src/recipe/recipe_parts.dart';
export 'src/recipe/shape_catalog.dart';
export 'src/recipe/versions.dart';
export 'src/library/design_library.dart';

// Recommendation / preference system.
export 'src/recommendation/design_preferences.dart';
export 'src/recommendation/preference_learner.dart';
export 'src/recommendation/diversity_selector.dart';
export 'src/recommendation/preference_scorer.dart';
export 'src/recommendation/shape_preference.dart';
export 'src/recommendation/stratified_sampler.dart';
export 'src/recommendation/style_cluster.dart';
export 'src/recommendation/variation_generator.dart';
