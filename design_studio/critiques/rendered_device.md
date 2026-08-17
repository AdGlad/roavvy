# On-device rendered critique (C-00 Lane A2) — 2026-08-17

Design Critic pass on **real on-device pixels** (iPhone 15 Pro sim, real fonts/SVGs;
12 designs in `generated_batches/rendered_device/`). This is the pixel-truth review
the analytic scorer + headless Lane A1 could not give. Findings are ranked; each
notes whether it is CONFIRMED (real, on-device) vs sim-limited.

## F1 — `statementCount` — ✅ FIXED, PIXEL-VERIFIED on-device (2026-08-17)
**Fix (2026-08-17):** added a `statementHero` gene (design_params → procedural_recipe.toDesignParams → thumbnailer → card_image_renderer → card_templates) that dispatches the `typography` painter to a new `_drawStatementHero()` — a large centered count + "COUNTRIES" + continents accent. Compiles, tests green (regression Δ0.000: pixel change invisible to the analytic scorer). Re-captured on-device: now renders a bold **"28 / COUNTRIES"** centered hero (7.3% opaque white coverage vs ~1% gold footer before). White-on-dark-garment, so composite on dark to view (`/tmp/statementCount_on_dark.png`). Production-ready.

**What:** `lifetime_statementCount_0` shows only "28 countries" in small gold text
as a **footer**, entire frame empty above. The count string generates (real font),
but it lands in the footer slot — NOT as the bold centered hero the family requires
(R-VH-01, R-STORY-03). Analytic score 0.79 was misleading; the design is nearly blank.
**Why it matters:** C-01 statementCount is **structurally valid but not
production-ready** — its whole premise ("the count IS the hero") is unrealised.
**Fix (procedural direction):** wire the stat string as the **hero title** (TitleGen
stat variant) and have the `typography` template render it hero-scale/centered, not
as a footer caption. This is the C-01 follow-up, now confirmed *necessary*, not optional.

## F2 — `negativeSpaceCutout` hero tiny/off-center — ❌ CONFIRMED STILL BROKEN (E-006 open)
**Investigation (2026-08-17):** the sub-agent made NO change — it found `_clipPathFor` already scales country outlines via `getBounds()` (verified 97.7% fill on a Kenya *countryOutline* probe). But that CONTRADICTS the on-device capture, which ran on this exact code and still showed tiny/off-center — **Re-capture (2026-08-17) confirms it IS plain `countryOutline` (Kenya) rendering tiny/lower-right** — directly disproving the agent's probe. So `_clipPathFor`'s getBounds() scaling is NOT reaching the live grid render path (or heroScale/grid-zone sizing overrides it). Real render-layer bug; investigate the grid-zone→clip sizing in `GridFlagsCard`/`card_image_renderer`, not just `_clipPathFor`. Original finding below.

**What:** `several-countries_negativeSpaceCutout_0` (and the lifetime/one-country
instances) render the clipped silhouette **tiny (~8% of frame), lower-right**, despite
recipe `heroScale 0.897`, `placement center`. Real assets loaded (flag colours/shield
correct), so this is NOT a Lane A1 artifact — the scale/placement simply isn't applied.
**Why it matters:** violates R-VH-01 (one bold hero) and R-NEG-01; a near-blank tee.
**Fix (render-layer):** the clip/mask path in `CardImageRenderer` must scale the
silhouette to `heroScale` and honour `placement`. Render-layer, higher-risk than a
generator param — scope carefully. → roadmap **E-006**.

## F3 — `dominantAccent` fragmented in circle (confirmed weak tendency)
**What:** `two-countries_dominantAccent_0` = blue quadrant + red sliver + red arc in a
circle, unbalanced, mostly empty (legal params: `heroScale 0.39` + `imageSize small`
+ montage + circle). Not a bug; a weak-composition combination.
**Fix (generator prior):** avoid small+montage+circle for dominantAccent; raise its
min hero scale for 2-country sets so the accent reads. Low-confidence, tunable. → E-007.

## F4 — `duoBlend` not blended, stacked flags (sim-limited, needs real device)
**What:** `two-countries_duoBlend_1` = FR flag over JP circle, **stacked, not blended**
(`layerMode: flat` fallback). The GPU blend/ripple shader likely does not run on the
**iOS simulator** (limited fragment-shader support), so this may be a sim artifact,
NOT a real-device defect. **Action:** re-capture on a physical device before judging;
do not "fix" the shader based on sim output.

## What the good ones look like (for calibration)
- `one-country-light_singleHero_0` — one bold JP flag, centred, generous space
  (E-005 fix holds on-device). ✅ On-brand.
- `one-country-light_negativeSpaceCutout_2` (q0.87) — worth checking whether it shares F2.

## Methodology win
Lane A2 confirmed F1/F2/F3 as REAL (not headless artifacts) and correctly isolated
F4 as sim-limited — exactly the pixel-truth the studio lacked. F1 especially: a
family the analytic pipeline scored 0.79 and "accepted" is actually near-blank until
its content is wired. The scorer measures parameters; only pixels show the design.
