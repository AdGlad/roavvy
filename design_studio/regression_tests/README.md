# regression_tests

Guards that the engine's output doesn't silently drift. Because rendering is a
**pure function of a recipe**, a regression test is just:

```
regression_tests/
  goldens/
    <name>.golden.json   { recipe: DesignRecipe, expected: { recipeId, imageHash } }
  README.md
```

## What they catch

- **Reproducibility breaks** — a recipe that no longer renders to its
  `imageHash` (e.g. an unintended change in a card painter or print-style).
- **Legality regressions** — a recipe that used to be valid now fails the
  printability gate (or vice-versa).
- **Grammar meaning drift** — a fixed `(seed, context)` now yields a different
  recipe without a `grammarVersion` bump.

## How they run (recommended wiring)

A Flutter test iterates the goldens, calls the real `CardImageRenderer` +
`PrintStylePipeline`, and asserts the render hash equals `expected.imageHash`.
This reuses the existing deterministic render path — no new rendering code.
Intended home: `apps/mobile_flutter/test/features/merch/design_engine/golden_regression_test.dart`,
loading these JSON goldens. Updating a golden is a deliberate, reviewed act
(regenerate + bump the relevant version field).

Promote a design into a golden when a critique marks it `keep` and it's
representative of a scope/template we care about not breaking.
