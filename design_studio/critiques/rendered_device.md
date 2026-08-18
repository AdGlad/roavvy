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

## F2 — `negativeSpaceCutout` — ❌ STILL BROKEN; E-006 MITIGATION REFUTED by pixels (2026-08-18)
**Investigation (2026-08-17):** the sub-agent made NO change — it found `_clipPathFor` already scales country outlines via `getBounds()` (verified 97.7% fill on a Kenya *countryOutline* probe). But that CONTRADICTS the on-device capture, which ran on this exact code and still showed tiny/off-center — **Fresh on-device re-capture (2026-08-18, AFTER the montage->fill-layout mitigation) STILL shows the outline tiny + lower-right** — so the E-006 mitigation was aimed at the wrong cause (montage/flag-fill). The OUTLINE ITSELF renders small (not a big outline with tiny flags), so this is a render-layer **clip-sizing** bug: the country/continent outline is not scaled to the frame despite recipe heroScale ~0.9. Earlier 2026-08-17 note: it IS plain `countryOutline` rendering tiny/lower-right — directly disproving the agent's probe. So `_clipPathFor`'s getBounds() scaling is NOT reaching the live grid render path (or heroScale/grid-zone sizing overrides it). Real render-layer bug; investigate the grid-zone→clip sizing in `GridFlagsCard`/`card_image_renderer`, not just `_clipPathFor`. Original finding below.

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


---

## Fresh on-device verdicts (2026-08-18, all latest fixes in)
Ran the pixel-QA (`render_qa.py`) + eyeball on a fresh capture:
- **E-006 negativeSpaceCutout — STILL BROKEN.** Outline renders tiny/lower-right;
  the montage mitigation did NOT fix it. Real render-layer clip-sizing bug. (See F2.)
- **E-008 typographicIntegration — CONFIRMED near-blank** (0.4% & 1.1% coverage,
  2 instances). Same class as pre-F1 statementCount: type-led family renders a
  small name-list, not a hero. Needs the statementHero-style treatment extended
  to this family (or a typography-template hero mode).
- **statementCount — OK** (renders the "28 / COUNTRIES" hero; pixel-QA flags it
  TINY only because white-ink-on-dark is thin coverage — a **metric caveat**, not a
  defect: `render_qa.py`'s coverage% under-reads white-text designs on dark garments).
- **dominantAccent — off-center** (centroid 0.17–0.28). Likely by-design (dominant
  hero + small accent is asymmetric); low priority, confirm intent before touching.
- **FLAG-CLASH fix** validated at recipe level (228->78); needs a multi-flag design
  in a future capture to eyeball the unification.


## E-006 — instrumented diagnosis (2026-08-18): it's FLAG COVERAGE, not the clip
A throwaway probe measured the real clip geometry (CountryPathService.pathFor +
`clipPathForTesting` with the real title/branding offsets 28/20):
- jp  pathBounds 594x533 -> clipBounds **241x216** (96% of the 224-tall grid zone)
- ke  -> 178x216, africa -> 192x216, europe -> 240x216 — all **FILL the zone**.

So `_clipPathFor` is CORRECT (the F2 agent's claim was right; my montage mitigation
was wrong-targeted). CardImageRenderer(grid) builds GridFlagsCard, which uses this
same fill-correct clip. Therefore the tiny render is NOT the clip — the **flag
layer does not cover the grid zone** (despite `coverGrid: true`), so only the small
flag-covered fragment is visible within the correctly-large outline clip → the tiny
lower-right sliver. **Real fix target:** `FlagGridLayoutEngine.compute(coverGrid:
true)` — make the flag tiles actually fill the grid zone for the clip case
(especially few-flag sets). Needs a layout-engine probe + on-device re-verify.


## E-006 — RESOLVED at generator level (2026-08-18)
The instrumented finding (clip + coverGrid correct; sparse renders come from too
few flags in a silhouette, thin outlines, and near-invisible white flags on light
garments) led to a design-suitability fix, not a render change:
`negativeSpaceCutout.minCountries 1 -> 3` — a "flags packed in a silhouette" needs
several flags; single/pair country is `singleHero`'s job (R-VH-01). Validated:
analyze clean, regression green (no diversity/quality regression), 960-sweep shows
0 single/two-country cutouts (min count now 4). **Residual (minor, separate):**
white/light flags in a cutout on a light garment still under-render — a flag-
CONTRAST concern for a future treatment fix, not a clip bug. On-device confirmation
of the multi-flag cutout look: run the widened 8-context capture.


## E-008 — fix applied (2026-08-18), pending on-device verify
`typographicIntegration` rendered near-blank (0.4% coverage) because `_drawMultiCountry`
drew country names at a fixed ~3.5% width font with half at 0.62 opacity — tiny + faint
= invisible on dark garments. Fix (`card_templates.dart`): scale names to fill the row
(`rowH*0.42`, clamped 4–7.5% width) so the type reads as a bold statement (KB "type-led
statement"), and lift the faint tier 0.62→0.82. analyze clean; the 2 card-test failures
are PRE-EXISTING (stale GridClipShape count 5-vs-8; a non-adjacency case) and unrelated.
**Cannot verify headless** (type designs fail to render without fonts) → confirm on the
next on-device 8-context capture.
