# Reference Collections

*What reference material the studio holds, what each item teaches, and the gaps to
fill. References are the **calibration signal** for a future `referenceAffinity`
scorer (the "quality bar" the capability matrix names as a headline gap). Each
should eventually carry a `ReferenceRecord` (`reference_analysis/reference_record.
schema.json`) mapping it to recipe-space features + a verdict + reasons.*

> All third-party reference images are **development-only, rights NOT cleared** —
> never bundle. Prefer replacing them with our own rights-clean renders over time.

## Current holdings (in `../reference_images/`)

### liked/torn/ — the best-calibrated set
`torn-through-usa.jpeg`, `torn-vertical-usa.jpg`, `usa-torn-color-bw.jpeg`.
- **Teaches:** single-flag hero, ragged/torn edges as the defining trait, heavy
  design-aware distress, bold centred scale, generous negative space, glance-
  legibility.
- **Analysed:** yes — `reference_analysis/torn-flag-tshirts.json`
  (focalConcentration 0.85, focalHierarchy strong, legibility high, colourfulness
  0.6, densityHint 0.35).
- **World:** [torn-flag-hero](mood_boards/torn-flag-hero.md). **Rules:** R-VH-01,
  R-FLAG-01(exception), R-TEX-01/02, R-NEG-01. **Recipes:** `torn_flag_usa`,
  `torn_flag_mono`, `ripped_flag`.

### liked/tshirts/ — badge / poster / collection exemplars
8 images. **Teaches:** centered-emblem and poster archetypes, limited palettes,
contained geometry, negative space. **Worlds:** heritage-badge, vintage-poster,
passport-stamp. **Analysed:** not yet — **TODO** author `ReferenceRecord`s.

### liked/streetwear/ — restraint & contrast exemplars
6 images. **Teaches:** high figure/ground contrast, bold-yet-restrained marks,
modern type. **World:** modern-minimal-line. **Analysed:** not yet — **TODO**.

### disliked/ — EMPTY (highest-priority gap)
No counter-examples yet. Without a negative anchor, `referenceAffinity` can reward
"looks like liked" but cannot penalise "looks like tat." **Add:**
- Souvenir-shop tat (loud "I ♥ PLACE", full-front tourist slogans).
- Full-saturation multi-flag clashes (R-FLAG-01 violations).
- Uniform-grunge fake vintage (R-TEX-01 violations).
- Bevel/gloss/chrome/drop-shadow type (R-TYPE-07, R-TREND-02 violations).
- Mad-Libs auto-filled layouts / edge-crowded clutter (R-COMP-04, R-NEG-01).
- Style mashups (R-TREND-01 violations).

## What each reference should capture (per `ReferenceRecord`)
`verdict` (liked/disliked) · `reasons` (the calibration signal) · `features`
(template, layoutMode, density, clipShape, printStyleFeel, dominantColors,
focalHierarchy, legibility, tags) · `analysis` (objective: aspectRatio,
focalConcentration, visualDensityHint, colourfulness) · `provenance` (source,
rightsCleared) · optional `nearestRecipeId` (link the bar to producible output).

## How references feed the engine
1. Author `ReferenceRecord`s for every image (liked **and** the new disliked set).
2. Build `referenceAffinity`: reward genome features resembling *liked* records,
   penalise resemblance to *disliked* ones (cheapest path to KB-aligned taste
   without a heavy learned model — `engine_recommendations.md` §3b).
3. Calibrate scorer weights so no *disliked* reference outranks any *liked* one;
   gate weight changes on the `regression_tests/` goldens.

## Collection roadmap (studio TODO, not implementation)
- Populate `disliked/` (above) — **first priority**.
- Author `ReferenceRecord`s for `tshirts/` and `streetwear/`.
- Add 3–5 references per aesthetic world so each mood board has a calibrated anchor.
- Add sensitive/disputed-flag references to calibrate R-FLAG-05 handling.
- Replace third-party images with rights-clean own-renders as the engine matures.
