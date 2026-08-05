# generated_batches

Batches of designs the engine produced, captured for review and regression.

A **batch** is reproducible metadata, not a pile of images:

```
generated_batches/
  <batchId>/
    batch.json        manifest: engineVersion, grammarVersion, configVersion,
                      the DesignContext(s), the seed range, and the list of
                      DesignRecipe objects produced (+ their scores)
    *.png             optional rendered previews (git-ignored; regenerate)
```

`batch.json` must let anyone **regenerate the exact images** from recipes alone.
Keep the manifest in git; let the PNGs be disposable (see `.gitignore`).

Batches are the unit that gets critiqued (`../critiques`), promoted into
`../regression_tests` when good, and rolled up in `../reports`.
