/// Version constants that participate in the reproducibility contract.
///
/// A rendered design is reproducible iff you persist, alongside the recipe:
/// [kSchemaVersion], [kEngineVersion], [kGrammarVersion], [kAssetsVersion],
/// the `seed`, and the resolved inputs. Bump rules:
///  * [kSchemaVersion]  — the JSON shape of [DesignRecipe] changed.
///  * [kGrammarVersion] — a generation rule changed (what a seed *means*).
///  * [kEngineVersion]  — the renderer changed what pixels a recipe produces.
///  * [kAssetsVersion]  — bundled flag/silhouette/path assets changed.
library;

/// The `DesignRecipe` JSON schema version. Append-only optional fields do NOT
/// require a bump; a structural/breaking change does.
const int kSchemaVersion = 1;

/// Semantic version of the generation grammar (rules that turn a seed into a
/// recipe). Changing it can change what an old seed produces.
const String kGrammarVersion = '0.0.1';

/// Semantic version of the render engine (recipe → pixels).
const String kEngineVersion = '0.0.1';

/// Version tag for the bundled asset set (flags, silhouettes, outlines).
const String kAssetsVersion = '0.0.1';
