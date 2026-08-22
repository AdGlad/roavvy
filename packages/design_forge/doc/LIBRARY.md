# Design library — save, reproduce, generate-similar

Every generated image is produced from a **`DesignRecipe`** — deterministic,
fully serialisable, with a content-hash `recipeId`. The recipe *is* the image's
reproduction spec: store the recipe JSON and you can re-render the exact image at
any resolution later. No raster needs to be kept.

## Portable core (`design_forge`, pure Dart)

`src/library/design_library.dart`:

- **`SavedDesign`** — a kept design: the full `recipe` + `liked` / `usedForTshirt`
  flags + timestamps. `id == recipe.recipeId`.
- **`DesignLibrary`** — an in-memory, JSON-(de)serialisable collection keyed by
  recipe id. `like` / `unlike` / `toggleLike` / `setUsedForTshirt`, and the
  `liked` / `usedForTshirt` / `entries` lists. **Policy:** a design is kept only
  while *selected* — un-liking a design that was never used for a t-shirt drops
  it, so the library never accumulates the whole generated batch.
- **`DesignStore`** — the storage seam (`read()` / `write()`), so the core has no
  `dart:io` / platform deps.
- **`PersistentDesignLibrary`** — `DesignLibrary` + a `DesignStore`: load once,
  persist after every mutation. Identical on macOS and iOS.

## Hosts

- **macOS Design Lab** — a file-backed `DesignStore` (`library.json`). The gallery
  has ♥ (like → saves the recipe) and 👕 (used for a t-shirt) toggles, and a
  **Batch / Liked / T-shirts** view that re-renders kept designs from their stored
  recipes. "Generate similar" = the editor's Variations (seeds around the parent).
- **iPhone app (pending integration)** — plug the same `PersistentDesignLibrary`
  into a documents-directory `DesignStore` (via `path_provider`). This is the only
  new code needed to "store locally on the iPhone"; the library logic is shared.

## Why this enables "generate similar"

A kept recipe carries its seed, flags and every parameter, so the
`RecipeGenerator` can spawn neighbours (vary seed / one axis) to produce more
designs in the same vein — the liked set becomes training signal for what the
user wants.
