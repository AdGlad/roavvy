# `design_studio/` — development-only design workspace

The bench where we **evaluate and improve** the procedural design engine.
Nothing here ships.

> ⚠️ **Not bundled.** This folder lives at the repo root, outside
> `apps/mobile_flutter/assets/`, so it is never packaged into the app. Reference
> artwork, generated batches and critiques are **development-only and must never
> be bundled into the production app unless explicitly approved** (and, for
> third-party reference images, only with rights cleared). Do not add any path
> here to `pubspec.yaml`.

## Layout

```
design_studio/
  reference_images/
    liked/        curated exemplars of designs we WANT to emulate
    disliked/     counter-examples of designs to avoid
  reference_analysis/   machine-readable analysis of each reference (→ recipe-space features)
  generated_batches/    seeded batches the engine produced, for review
  critiques/            structured critiques of batches (auto + human)
  regression_tests/     golden recipes + expected render hashes; catch regressions
  human_feedback/       raw human like/dislike/notes events (feed stage-5 learning)
  reports/              rolled-up quality/perf reports and config sweeps
```

## The loop this workspace supports

```
reference_images ──analyse──▶ reference_analysis ──┐
                                                   ▼
engine ──generate──▶ generated_batches ──critique──▶ critiques
   ▲                                                   │
   └──── config / grammar / preference tweaks ◀── reports ◀── human_feedback
                                                   ▲
                          regression_tests ────────┘  (gate: no golden may regress)
```

## Rules of the bench

- **Reproducible or it didn't happen.** Every generated item records its full
  `DesignRecipe` (schema in `design_engine/schemas`). A batch is a set of seeds +
  recipes, not a pile of PNGs.
- **Goldens are recipe+hash, not images.** Regression tests store the recipe and
  the expected render hash (`recipeId`/`imageHash`); regenerate images on demand.
- **Rights-aware.** Only store reference images we have the right to keep. Prefer
  our own renders; annotate provenance in `reference_analysis`.
- **Feedback is data.** Human critique flows into `human_feedback/` in the
  `feedback_record` shape and becomes `UserDesignPreferenceProfile` training
  signal — the same schema the app uses, so studio and runtime learning match.
