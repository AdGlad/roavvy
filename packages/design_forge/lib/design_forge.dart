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
