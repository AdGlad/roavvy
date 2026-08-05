/// Procedural graphic-design engine (first working version).
///
/// Turns a [DesignContext] + seed into strong, diverse, printable
/// [ProceduralDesignRecipe]s by sampling a composition grammar under the Roavvy
/// Design DNA, validating cheaply, and scoring intrinsic quality — all locally,
/// deterministically, and without any remote model.
///
/// See design_engine/docs/architecture.md for the 5-stage separation.
library;

export 'composition_family.dart';
export 'design_context.dart';
export 'design_dna.dart';
export 'deterministic_rng.dart';
export 'hard_constraints.dart';
export 'preference_profile.dart';
export 'procedural_generator.dart';
export 'procedural_recipe.dart';
export 'quality_model.dart';
