# Next tasks (planner handoff — updated 2026-09-03)

# PLAN — T-Shirt Experience, M175–M183

Definition this plans against: `docs/product/tshirt-experience-definition.md`
(14 screens, 4 modes, 10 rules). Illustrated: https://claude.ai/code/artifact/07d17cb1-fa64-41e1-abfd-6c0b107ffbe8

**Framing.** All 14 screens already exist in some form — Studio V2 ships Instant, the seven
Make-It-Yours steps, Fine Tune and Review; the M174 mockup canvas and the V1 commerce tail
cover Placement, Size and Checkout. So this is NOT a build-out. Every milestone below closes
a specific gap between what ships and what the definition promises, and each is named for the
promise it makes true.

**Sequencing rule.** Wave 1 items are file-disjoint and can run in parallel (worktree
subagents, as Wave 1 of the previous initiative did). Wave 2 depends on Wave 1 landing.
Wave 3 is independent of both and can be pulled forward whenever there is capacity.

**Hard constraints (unchanged).** Never modify `features/merch` or `features/cards` except
where a milestone names the file explicitly. `features/studio_v2` must not import
`features/merch` (guarded by `v1_isolation_test.dart`) — shared code goes in
`features/shared/`. Never delete image assets.

---

## WAVE 1 — parallel-safe, start together

### M175 · Only offer shirts that can be made
**Rule 10.** The palette offers eight colours; the store carries five variants, and two of
those are mislabelled. Today Orange and Royal are blocked by name at add-to-cart, and Dark
Heather / Sport Grey both resolve to one store heather, so one of them ships a visibly
different shirt from the one chosen.

- Enable Orange and Royal in **Printful first** (it fulfils; Shopify-only variants would pass
  checkout and fail at fulfilment), let them sync, then wire the new GIDs.
- Split the two greys, or drop one from the palette until a variant exists.
- Replace the silent `tshirtGids[...] ?? tshirtGids.values.first` fallback with a loud failure.
- Colour swatches for unstocked colours should not render at all, rather than being blocked
  one screen later.

Files: `merch_variant_lookup.dart` · `printDimensions.ts` (PRINTFUL_VARIANT_IDS) ·
`studio_v2_cart_adapter.dart` · `studio_controller.dart` (garments).
**Blocked on:** a human enabling the colours in Printful. Everything else is ready.
Done when: every palette colour maps to a real variant, and a colour with no variant cannot
appear on the swatch row.

### M176 · Swipe through shirts, not names
**S1.** The Instant deck shows each pick's name and position. The promise is swiping through
ready-made shirts.

- Eight live garment thumbnails in the deck, rendered at thumbnail size through the existing
  `RenderService` cache.
- Render lazily around the current index; never block first paint (the startup-settle guard
  in `startup_idle_test.dart` is the tripwire).
- Keep the name as a caption.

Files: `instant_workspace.dart` · possibly `render_service.dart` (a thumbnail size tier).
Depends on: nothing. Done when: the deck shows shirts, and the settle guard still passes.

### M177 · The step contract, enforced
**Rule 4.** The definition's "appears when" column is a contract with no test behind it. A
control that leaks into the wrong context is the failure mode that makes depth feel like
clutter, and it will regress silently.

- Tests asserting: Travels only with trip history · Detail only for Flags · chest side only
  when Fit = Chest · ribbon coverage only when Art = Ribbon · Fine Tune categories present
  exactly per the table (Layout for Flags, Graphic for clipped-or-Passport, Text for Words).
- Table-driven, so adding a category means adding a row.

Files: new `test/features/studio_v2/step_contract_test.dart` · possibly small accessors on
`StudioController`. Depends on: nothing. Pure test milestone — cannot break the app.

---

## WAVE 2 — after Wave 1

### M178 · Buy from anywhere
**Rule 3.** Buying is reachable from Instant and Review only; the definition says a confident
person can leave at any point.

- A persistent buy affordance in the frame, on every step.
- One shared path — `buildGarmentCartRequest` already exists; no second copy.
- Never a dead end: unstocked colour states the reason in place.

Files: `studio_v2_screen.dart` (contested — coordinate with the phone-layout work) ·
`instant_workspace.dart` · `review_workspace.dart`.
Depends on: **M175** (buying must be truthful before it is everywhere).

### M179 · Placement inside the journey
**S12.** The M174 mockup canvas lives on the V1 merch screen the Studio hands off to. The
definition places it as a step in the flow.

- Bring the canvas into the V2 journey between Review and Size, or make the hand-off
  continuous enough that it reads as one flow.
- Carry the arranged transform through to the print file (`MerchImageProcessor` already
  accepts it).
- Resolve the uncommitted `printArea` wiring in `studio_v2_screen.dart` as part of this.

Files: `studio_v2_screen.dart` · `studio_v2_cart_adapter.dart` ·
`features/shared/garment_mockup/*`. Depends on: **M178** (shares the frame changes).

### M180 · What you see is what prints
**Rule 8.** Preview and print file are produced by different paths. Placement, colour and
scale agreeing is currently an assumption.

- Assert parity: the print file's placement, garment colour and artwork scale match the
  preview for the same recipe.
- Cover both faces and every print position.

Files: `merch_image_processor.dart` · `render_service.dart` · new parity tests.
Depends on: **M179** (parity is only meaningful once placement is final).

---

## WAVE 3 — independent, pull forward freely

### M181 · Saved designs
**S14 / rule 9.** `PersistentDesignLibrary` saves garments; nothing browses them. A
reproducible design nobody can reopen is a promise with no payoff.

- Browse saved designs, reopen one into the Studio exactly as saved, re-order it.
Files: new `features/studio_v2/widgets/library_*.dart` · `prefs_persistence.dart`.

### M182 · After the purchase
**S14.** Order status through to delivery, and sharing the design — the shirt is a travel
brag, not just a transaction. V1 has share and confirmation screens to reuse.
Files: `merch_order_confirmation_screen.dart` · `merch_share_exporter.dart` (read-only reuse).

### M183 · Garment photography
The bundled shots are 513×640 — sized for the merch preview they were taken for, soft as a
full-height Studio hero. Asset work, not code: reshoot or source at 2–3×, same framing
(garment bounding boxes currently agree within 0.006 normalised, and the tint pipeline
depends on that). The grey shirt is the tint base and matters most.
Files: `assets/mockups/` · `garment_mockup_spec.dart` (paths only).

---

## Parallelisation map

```
Wave 1   M175 (commerce)   M176 (deck)   M177 (contract tests)     ← start together
             |                 |
             v                 |
Wave 2   M178 (buy anywhere) <-'
             |
             v
         M179 (placement) -> M180 (print parity)

Wave 3   M181 (library)    M182 (after purchase)   M183 (photography)   ← anytime
```

File-disjoint sets for parallel work:
- M175 → variant/commerce files + controller palette
- M176 → `instant_workspace.dart` (+ render service)
- M177 → tests only
Only M178/M179 touch `studio_v2_screen.dart`, which currently also carries someone else's
uncommitted phone-layout work — sequence those two rather than running them together.

## Known blockers at time of writing
- `apps/mobile_flutter/ios/Runner.xcodeproj/project.pbxproj` is in an unresolved conflict
  (`UU`) from a popped stash — **git refuses all commits until it is resolved**.
- `studio_v2_screen.dart` holds ~333 lines of in-flight phone-layout work plus two of my
  one-line wirings (`printArea`, the Instant stage case).

---

# PREVIOUS HANDOFF (2026-08-20) — retained below

# Next tasks (handoff — updated 2026-08-20)

Branch: `fix/e006-clip-fill-designs` (E-006 commit `b0d5e1d9` pushed). Everything below is
UNCOMMITTED working-tree work (on disk, survives compaction) unless noted.

---

# NEW INITIATIVE — T-Shirt Creation Experience (proposal, not yet implemented)

Full proposal (23-section discovery + design + milestone plan):
`docs/product/tshirt-creation-experience.md`.

Core promise: **"I designed this T-shirt. It is unique to me."** Recommended UX = a
**"Studio Canvas"** (instant hero design from your travels → evolve through a few
meaningful creative decisions, each re-rolling ONE recipe axis live → lock/branch/undo
via deterministic recipeIds → front/back as one garment → garment colour that re-inks
adaptive elements → your own words/AI titles). NOT a wizard, template picker, or repeated
Generate button.

Key architecture decision: **`DesignRecipe` (design_forge) is the single reproducible
source of truth**; reuse the proven `CardImageRenderer`/`PrintStylePipeline`/`createMerchCart`
print path via a `DesignRecipe → DesignParams` adapter (don't rewrite it); mature
`design_forge_render` toward print parity over time. The forge↔merch seam already exists
but is mostly written-yet-unwired (`recommendSmart`, `PreferenceBridge`,
`variation_grid_screen`, `preference_survey_screen`).

Flow was folded to a 6-phase Studio Canvas (doc §9 + §9a reconcile the ChatGPT
storyboard): A Start(instant hero) · B Shape it(Direction/Vibe/Focus/Colour/Words, live,
lock/branch/undo) · C Back(auto-derived, shares theme) · D Review(garment colour once) ·
E Refine(optional/Advanced) · F Save/Cart/Share. De-duped: colour 3→1, AI text 2→1,
editing surfaces 3→1; added explicit Direction; "put it on a t-shirt"→Add to cart.

### BUILD STATE (branch `feat/tshirt-creation-experience`, off main `9e47821a`)
HARD CONSTRAINT: never modify `apps/mobile_flutter/lib/features/merch|cards` (production,
read-only) or delete image assets. Wave-1 work is entirely in the isolated Studio packages.

Wave 1 — DONE & merged into `feat/tshirt-creation-experience` (built via 3 parallel
worktree subagents, file-disjoint, clean merges). Combined: forge 83, render 22(+1 skip),
lab 47 tests green; analyze clean (lab + render); `flutter build macos` ✓.
- M2 = commit `94ac5727` (merged) — `DesignAxis` enum + `DesignRecipe.axisSeeds` +
  `LabShowcaseGenerator.reroll(recipe, axis, {newSeed, locked})` / `rerollUnlocked`.
  Determinism preserved (empty axisSeeds → old recipeIds byte-identical, golden-tested).
  NOTE: `colour`/`words` axes are enum-first-class but currently no-op to re-roll (palette
  rides the vibe/finish stream; text rides direction) — splitting those out is a wave-2 step.
- M5 = commit `9af3e22e` (merged) — `ColourStrategy.garmentAware` in colour_stage;
  Palette gains `contrastInk`(bool)/`adaptiveInk`(hex?); render_service passes garmentColour
  into RenderTarget.background. Flags stay semantic; text/stamp ink flips dark↔light.
- M6 = commit `08fe8221` (merged) — `TypographyStage` (new) in defaultStages (after colour);
  title from `content.meta['title']`, textCase+placement honored. FONT NOT bundled (none
  licensed in repo) → uses platform default, `titleStyle`→family unwired. TODO in code+pubspec.

Wave 2 — DONE & merged + pushed (3 parallel worktree agents; pushed to origin `3cf3d0f7`).
Combined green: forge 95, render 22(+1 skip), lab 58; analyze clean; macOS build ✓.
- Generator wiring `8159072d` — palette moved onto its own `colour` axis stream (garment
  colour from a 6-hex spread; garmentAware for adaptive-ink designs); titles on the `words`
  axis (12-phrase bank, title rules enforced, varies on reroll). reroll(colour)/reroll(words)
  are now real. Determinism goldens re-captured. Data recipes' palette also moved to colour.
- M3 Studio Canvas prototype `40a8d69e` — `apps/design_lab/lib/studio_canvas_screen.dart`
  (+ minimal main.dart entry "Studio Canvas"): instant hero + 5-chip deck→reroll +
  alternatives tray + per-axis lock + Surprise-me(rerollUnlocked) + breadcrumb undo.
- M7 `GarmentDesign` `aee03cc3` — `packages/design_forge/.../garment_design.dart` (front+back,
  themeSeed, deriveBack, withGarmentColour, reproducible garmentId).
- Integration fix `3cf3d0f7` — M7 was built on a pre-M5 base; patched `_recipeWithGarmentColour`
  to preserve M5's `contrastInk`/`adaptiveInk` (Palette has no copyWith).
NOTE: worktree provisioning branched agents from a STALE base (main/9e47821a, not the
feature tip) — agents self-merged/fast-forwarded to fix it. For future waves, tell agents to
base on `feat/tshirt-creation-experience` explicitly. Follow-ups: solid-ink passport stamps
not yet generated (garmentAware stamp path wired but idle); per-style colour character lost
when palette moved off the vibe stream (would need a StyleSpec colour hook); bundle OFL font.

Wave 3 — DONE & merged + pushed (origin `7dd7be1e`; 2 parallel worktree agents, both
correctly synced to feature tip). Combined green: forge 101, render 22(+1 skip), lab 62;
macOS build ✓.
- M4 `4446f59f` — Studio Canvas decisions → preference learning: `viewed` (hero shown),
  `styleChosen` (commit via chip/alt/Surprise), ♥ Save `saved`+library.like, tray ✕ dismiss
  `rejected`+library.reject; one `_observe` choke-point persists prefs. Optional bias: when
  sampleCount>0, opening hero = best-of-6 by PreferenceScorer + alternatives ordered by score
  (neutral prefs → byte-identical to before, existing tests green).
- deriveBack enrichment `ff655000` — complementary-family mapping (compact/text front→rich
  grid/passportStamp back; busy front→compact badge/frontRibbon/typographic), deterministic
  by themeSeed; `complementFamilyFor`/`complementCandidates` public.

Wave 3 follow-ups: reject ✕ has no reason chip (batch Lab does); library writes are
fire-and-forget async (mobile port should await); back-grid layout fields left to renderer
defaults; per-style colour character still generic since palette left the vibe stream; bundle
OFL font still pending (needs a licensed asset — cannot fetch).

STATUS: 6 milestones + gen-wiring + M4 landed (M2,M5,M6,M3,M7,M4). Prototype runnable:
`cd apps/design_lab && flutter run -d macos` → "Studio Canvas" button.

### FUNNEL HIERARCHY + CONTROL TAXONOMY (see doc §9b for full detail + gaps)
Hierarchy: Direction → (Detail if Flags) → Form controls → Style → Effects → Colour → Words.
Flags/Maps/Animals/Landmarks are ALL Flags (differ by the clip shape = "Detail"). Non-flag
subjects: Passport(real stamps), Route(timeline+journeys), World(wordCloud), Words(typographic),
Milestones(badge/frontRibbon/achievements/stats).
Control tiers: (1) FIXED/GLOBAL always-available, never touched by style change — aspect
(orientation), size S/M/L, garment colour, front/back, surprise/seed, save/cart; (2)
CROSS-CUTTING creative deck — direction/style/effects/words/colour-treatment; (3) CONTEXTUAL
per-subject — clip transforms, grid fill/rows/density/copies/scatter, flag combine, passport
ink/size/scatter/stampMode/dates, data entries/weights/range/journeyStyle/big-count.
Style OWNS: edge + effect-mix defaults + colour treatment + clip archetypes + orientation bias;
GENERIC (never style-owned): garment colour, aspect, size, front/back, subject, title, seed.
PRINCIPLE: style seeds defaults for UNLOCKED axes only; Tier-1 fixed controls survive style
changes; locks make any axis sticky.
GAPS (doc §9b): funnel doesn't expose Tier-3 form controls; Direction doesn't switch family +
no Detail sub-level; no first-class fields for copies-per-country / passport stampMode /
statementHero / Size S/M/L; effects not ported (riso/newsprint/sunFaded/photocopy); typography
footer/subtitle + bundled font; RenderQuality supersample; print export (M1); front/back UI;
per-style colour character; journeyStyle variants.
NEXT BUILD OPTIONS: (A) restructure deck to Direction→Detail→Adjust(form)→Style→Effects→
Colour→Words + wire Direction→family + persistent Tier-1 bar; (B) add recipe fields (copies,
stampMode, statementHero, sizeClass) + port 4 missing print effects.
WORKING STYLE (user directive after 2 token-limit blowups): NO parallel subagents — do the
work INLINE in small sequential commits. See [[feedback_no_parallel_subagents_token_budget]].

PATH B — DONE inline + pushed (origin `76e276a6`), 6 small commits, all green
(forge 105, render 27+1 skip):
- B1 `5d1a9e04` recipe fields: Composition.copiesPerCountry/statementHero/sizeClass (+SizeClass
  enum), Clip.stampMode, Effects riso/newsprint/sunFaded/photocopy — append-only, omit-at-default.
- B2 `7ca4805d` render the 4 effects in effects_stage.dart.
- B3 `fab350b0` copiesPerCountry tiles a country into the grid (composition_stage).
- B4 `1dd460ec` passport stampMode filters entry/exit stamps (clip_stage).
- B5a `7b1bebee` sizeClass shrinks artwork onto the garment (renderer flatten).
- B5b `76e276a6` statementHero big-count hero (typography_stage).

PATH A — DONE inline + pushed (origin `4bdb723d`), all green (forge 105, lab 66, macOS build ✓):
- A1 `fd2cdb43` Direction chip switches SUBJECT/genre (withGenre; cycles Flags/Passport/Route/
  World/Words/Milestones, per-subject alternatives tray).
- A2 `03e5d081` Flags Detail sub-step (Grid/Map/Animals/Landmarks/Heart/Circle → live clip).
- copyWith prereq `76d45872` on Composition/Clip/Effects/Palette (for live edits).
- A3 `29a8f3aa` contextual Adjust panel ('tune' toggle): grid fill/copies/scatter, passport
  scatter/ink/stampMode, Effects sliders incl. ported riso/newsprint/sunFaded/photocopy.
- A4 `4bdb723d` persistent Tier-1 Format&Colour bar (aspect/size/garment-colour/front-back via
  GarmentDesign.deriveBack); FIXED _spliceAxes to carry copiesPerCountry/statementHero/sizeClass
  from base so re-rolls never reset Tier-1/contextual edits.
So Path B's new fields ARE now user-testable in the Studio Canvas (Adjust panel + Tier-1 bar).

BATCH EMISSION — DONE (origin `f08b258b`): `_one` now varies sizeClass/copiesPerCountry/
statementHero from independent sub-streams; determinism goldens re-baselined (reroll_test now
uses a single map compare for easy future re-baselining); splice keeps these sticky across
re-rolls. lab 66 green.
ALL B FIELDS NOW BATCH-EMITTED: sizeClass/copies/statementHero (`f08b258b`) + passport stampMode
(`04609c95`).
FOLLOW-UPS DONE (pushed, origin `1effd09e`): editable Back side (`5d28ed46` — `_current` is a
view over front/back, Back materialised via deriveBack then independently editable); per-style
colour character (`1effd09e` — grunge→mono, vintage/retro→heavy grade, minimalist/premium→clean).
lab 67 green, macOS build ✓.
M6 UNBLOCKED (`54eac508`): TypographyStage honours Typography.titleStyle as a font-family NAME;
generator sets it on the words stream from `_titleFonts` (Futura/Impact/Georgia/Copperplate/
Avenir Next Condensed — macOS system faces, graceful fallback under Ahem/other platforms). So
titles now render in a distinctive display face in the Lab; re-rolling Words also changes the
lettering. Determinism goldens re-baselined. To ship a specific licensed face cross-platform:
drop an OFL .ttf in apps/design_lab/assets/ + pubspec fonts: and add its family to `_titleFonts`
— NO code change needed in the stage.
ADJUST-PANEL PARITY (control audit vs old recipe_editor.dart) — DONE + pushed (origin `8a5c5e6d`):
- C1 `0f0e6170` Effects section completed (distress/cracks/acid/tie-dye/shatter+spikes/ripple+freq/
  halftone+scale) + Print sub-group (riso/newsprint/sunFaded/photocopy). _adjSlider gained a min.
- C2 `c18d0336` Shape section (clip size/rotation/corner/feather for map/silhouette/heart/circle).
- C3 `58f40699` Colour section (strategy: flagDerived/monochrome/duotone/garmentAware + vintage grade).
- C4 `8a5c5e6d` Edges (torn) section + EdgeTreatment.copyWith (style + damage/corners/fray).
lab 67 green, forge 105, macOS build ✓.
MERGED TO MAIN — latest `dcfbb252`. Passport Multi/Mono `387a0449`: Multi=flag colours;
Mono=auto black/white by t-shirt colour (clip_stage._resolveInk from palette.garmentColour).
Silhouette picker `37b667a4`: Plants detail + dropdown of ALL animal/plant/landmark silhouettes
for the selected countries. lab 70, render 28 green.

MORE PARITY DONE + pushed (origin `87e8874f`): Finish presets `a9e1135a` (one-tap Clean/Vintage/
Retro/Halftone/Distress/Tie-dye/Shatter/Riso/Mono at top of Adjust); custom TEXT input `87e8874f`
(Words subject → sets flag-filled text clip live). lab 69 green, macOS build ✓.
STILL MISSING from Canvas vs old editor (low priority): Pattern Single/Blend/Multi + flagCombination
mode/weightA/seam (needs multi-flag country-selection first — poor fit for fixed context);
country/region CODE picker for Map (→ Detail); placement anchor nudge (→ Tier-1/Refine); explicit
seed field/reproduce (→ breadcrumb). These are structural/low-value; core control parity achieved.
FOLLOW-UPS NOT DONE: riso/newsprint visual polish (approximations, needs on-screen review).
STILL DEFERRED (needs go-ahead): M1 mobile adapter + live recommendSmart (EDITS production), M8, M0.
DEFER (production/approval): M1 mobile adapter + live recommendSmart, M8 hardening, M0 survey.
NEXT: M1 is the one that puts this in the real iPhone app but EDITS production merch — needs
explicit user go-ahead. Offer to write the adapter design + migration-safe plan for review first.

(historical wave-1 scoping below)
- [x] **M2** axis re-roll + lock — OWNS `packages/design_forge` determinism/generation +
  `apps/design_lab/lib/lab_generator.dart` (+ append-only `design_recipe.dart`). Deliver a
  `DesignAxis` enum + per-axis sub-seed re-roll so ONE axis changes while others stay
  byte-identical; `reroll(recipe, axis, {locked})`. Tests prove isolation.
- [~] **M5** garment-aware colour — OWNS `packages/design_forge_render/.../stages/colour_stage.dart`
  + `render_service.dart` (garment bg) + Palette fields in `recipe_parts.dart`. Implement
  `ColourStrategy.garmentAware`; flags keep semantic colour, adaptive elements re-ink.
- [~] **M6** typography stage — OWNS NEW `.../stages/typography_stage.dart` + `renderer.dart`
  defaultStages + `apps/design_lab/pubspec.yaml` font. Consume the currently-inert
  `Typography` recipe group. (Real glyphs need a bundled OFL font; TODO if none in repo.)

Integration after wave 1: merge each agent's worktree branch into
`feat/tshirt-creation-experience`, run forge+render+lab tests + analyze + `flutter build
macos`, then commit. THEN wave 2 (depends on M2): M3 Studio Canvas prototype in design_lab,
M4 lock/branch/learning, M7 GarmentDesign model. DEFER (production/approval): M1 mobile
adapter + live recommendSmart, M8 hardening, M0 survey wiring.

Milestones (see doc §21 for files/tests/acceptance):
- [ ] **M0 (opt)** Taste-swipe cold start — wire existing `preference_survey_screen`.
- [ ] **M1** (deferred — touches production) genome unify: `DesignRecipe→DesignParams` adapter + live `recommendSmart`.
- [~] **M2** single-axis re-roll + lock (+ `recipeId@size` cache already in RenderService).
- [ ] **M3** Studio Canvas MVP (prototype first in design_lab).
- [ ] **M4** Lock / branch / alternatives + wire authoring stream into `PreferenceLearner`.
- [~] **M5** Garment colour as design — `ColourStrategy.garmentAware` + adaptive tagging.
- [~] **M6** Text as material — Typography stage + bundle font.
- [ ] **M7** Front & back as one `GarmentDesign` (engine model first).
- [ ] **M8** Production hardening — RenderQuality supersample, reorder/reprint, print-parity suite.

Top risks (doc §23): two renderers drifting (add parity test); axis-isolation vs draw
order (may need per-axis seeds); on-device shared asset package; font licensing/isolate
registration; garmentAware element tagging.

---

## DONE & shipped (committed + pushed)
- **E-006 clip-fill fixes** — commit `b0d5e1d9`. continent-mask share gate, clip tiling
  rowCount, no-sparse-under-clip, tiling-layout-under-clip. On-device verified. PR:
  https://github.com/AdGlad/roavvy/pull/new/fix/e006-clip-fill-designs

## NEW this session — macOS render harness (fast preview engine) — UNCOMMITTED
- `apps/mobile_flutter/tool/render_harness.dart` — renders procedural designs through the
  REAL CardImageRenderer on a native **macOS** window (full Skia/fonts/SVG, 0 render errors,
  no iOS build). Run: `flutter run -d macos -t tool/render_harness.dart`. Writes labelled
  PNGs + manifest.json + index.html to `design_studio/generated_batches/macos_preview/`.
  Cached runs are ~seconds (first run compiles Firebase pods, ~10 min one-time).
- `macos/Runner/DebugProfile.entitlements` — set `app-sandbox` to **false** (DEBUG only;
  Release stays sandboxed) so the harness can write PNGs to the repo. Required.
- `macos/Podfile`, `Runner.xcodeproj/project.pbxproj`, `Runner.xcworkspace/…` — auto-changed
  by `flutter run -d macos` (pod install / project config).
- **Review grid artifact** (36 designs, browsable, quality-scored):
  https://claude.ai/code/artifact/e168bdf7-0e06-49a1-a831-d1e5d24ab1e5
  (redeploy by re-publishing scratchpad `review_grid.html`; a py generator inlines PNGs as data URIs)
- ACTION: harness tooling is worth committing (separate from E-006 fix) — user hasn't said yet.

## WORKFLOW pivot (agreed with user)
Kill the automated quality-score optimization (it rated broken designs highly + dropped title
text — proxy-optimization failure). New loop = **human-in-the-loop, sample-driven**:
1. Generate grid via macOS harness → user picks designs needing work (by tile label / screenshot).
2. User gives a sample image OR words OR "surprise me" + **scope** (this instance vs whole family).
3. Decode sample → tune a GENERALIZABLE knob (palette/layout/clip/print-style/typography),
   re-render (seconds), review, iterate. Keep regression suite as safety gate only.
Global suggestions become generator rules (highest leverage).

## IN PROGRESS — heart clip fit (global rule)
User rule: **a clip shape must ALWAYS scale to fit the available space — never cut off at any edge.**
- Bug: `repetitionField · heart` had its bottom tip chopped flat. Root cause in
  `heart_layout_engine.dart` `heartPath()`: parametric y runs ≈ −12..+17 but code divided by 13,
  pushing the tip ~15% below the box.
- FIX APPLIED (uncommitted): `heartPath()` now measures true bounds and fit-scales
  (aspect-preserved, centred) so the whole heart fits. Audited other masks — heart was the
  only overflowing one (country/continent/silhouette use getBounds; circle radius 0.46<0.5).
- PENDING: verify render (harness task `bbxswmi5r` was re-rendering at compaction) — view
  `design_studio/generated_batches/macos_preview/img/*repetitionField*.png` (several-countries_s2
  and lifetime_s2) and confirm the tip is whole; then run regression_test.dart.

## OPEN — real app crashed on device (2026-08-19)
Skia text-layout crash (`SkLRUCache<…ParagraphCacheKey…>::remove`) + `assetsd` drop (photo lib)
+ `DiagnosticsProperty<void>` framework exception. NOT the recipe logic (no text-layout code
changed). NEED: which screen (scan/map/merch?), on launch or after a tap, every time or one-off.
Isolate scan-path (likely photo-perm / stale-framework → flutter clean) vs merch-path (compare
main vs branch). See [[project-device-build-issues]].

## Deferred (lower severity)
- Single-country `typographicIntegration` near-blank ("My First Country" thin text) — too sparse.
- Harness renders dark-garment designs on a WHITE bg → white-ink families (`statementCount`)
  look faint/blank. Add a garment-coloured backdrop option to judge them.

---

# NEW INITIATIVE — Design Forge (standalone engine + macOS Design Lab)

Goal: a NEW cross-platform procedural design engine + macOS dev tool, perfected
independently and later replacing `CardImageRenderer`. **Production path untouched.**
Full architecture + phased plan: `packages/design_forge/doc/ARCHITECTURE.md`.

Key thesis: replace `CardImageRenderer`'s widget-tree capture (`OverlayEntry` +
`RepaintBoundary.toImage`, needs BuildContext) with a **pure `ui.Canvas` stage
pipeline** — makes the engine headless, isolate-friendly, VM-testable, portable
to macOS + mobile. Reuse as-is: `DeterministicRng`, torn engine v2 (`torn/`),
print-style textures/treatments, `flag_blend.frag` + `EffectRenderer` seam,
271 flag SVGs + 162 silhouettes.

Packages: `packages/design_forge` (pure Dart) · `packages/design_forge_render`
(flutter/dart:ui) · `apps/design_lab` (macOS dev app).

## Phase 0 — Scaffold & spike — DONE & VERIFIED (uncommitted)
- [x] `packages/design_forge` (pure Dart) + `packages/design_forge_render` (flutter);
      dep graph pure ← render wired. (macOS `apps/design_lab` app deferred to Phase 6;
      headless render already proven via flutter_test, so the Lab isn't on the
      critical path for the proof.)
- [x] Ported `DeterministicRng` (SplitMix64 + named sub-streams) into pure core + tests.
- [x] `DesignRecipe` (identity + content + composition), canonical-JSON `recipeId`
      content hash, JSON round-trip, `RecipeGenerator` + `DeterministicRuleGenerator`.
- [x] Headless pipeline: `CanvasRenderer` (RenderStage → RenderContext → CompositionStage)
      single flag SVG → pure `ui.Canvas` → PNG, NO OverlayEntry/BuildContext.
      `SvgFlagResolver` rasterises via flutter_svg `vg.loadPicture` (headless), cached.
- [x] Verified: `dart test` (14 pass) + `flutter test` (4 pass), both `analyze` clean;
      exported + eyeballed single_jp + grid4 PNGs — real flag pixels, deterministic hash.
- Phase-2 note surfaced: flags currently stretch-to-fill (JP disc slightly elliptical);
  add aspect-fit/letterbox in the composition stage.

Verify render pkg: `cd packages/design_forge_render && flutter test`
Verify core:       `cd packages/design_forge && dart test`
Export samples:    `OUT=<dir> EXPORT_SAMPLES=1 flutter test test/export_sample_test.dart`

## Phase 1 — Recipe + generator + serialisation — IN PROGRESS (uncommitted)
- [x] Full versioned `DesignRecipe` covering ALL goal dimensions: family, weighted
      flags, composition (template/layoutMode/rowCount/density/jitter/placement),
      flagCombination, clip/shape, edgeTreatment (torn families), palette/colour,
      effects (distress/grain/fade/halftone/ripple/acidWash), typography, motifs.
      Append-only optional groups; forward-compatible enum decoding; canonical-JSON
      `recipeId`; lossless round-trip. `recipe_parts.dart` + tests (21 core tests ✓).
- [x] `ProceduralRecipeCodec.fromFlatJson()` — maps the studio flat
      `ProceduralDesignRecipe.toJson()` shape → `DesignRecipe` (pure, no app dep).
      Verified against real anchors (`design_studio/recipes/*.recipe.json`);
      preserves original id in provenance, recomputes new-schema recipeId.
      Lossy-by-design: keeps continuous treatment genes; synthesises EdgeTreatment
      only for edgeTear/rippedFlag print styles. 24 core tests ✓.
## Phase 2 — Composition + flag combination — DONE (uncommitted)
- [x] Image-in/image-out layer pipeline (masks/effects hit artwork, not background).
- [x] Aspect-fit (contain) single hero; cover-bleed for edge-treated designs.
- [x] 2-flag combination via Canvas clip regions: diagonalSplit / vertical / horizontal.
      (wave/torn shader combos still pending — need flag_blend.frag exec on device.)

## Phase 3 — Geometry & edges — DONE (uncommitted)
- [x] ClipStage: heart + circle parametric masks (feather supported). Country/
      silhouette outline clips pending (need SVG path assets wired).
- [x] EdgeTreatmentStage + self-contained TornMaskGenerator: edge-concentrated fBm
      depth + high-freq strands → separated tapering FINGERS, interior intact,
      per-edge asymmetry (canton preserved), corner damage. Verified visually + tests
      (interior-kept / edge-eroded / determinism).

## Phase 4 — Effects + colour — DONE (uncommitted)
- [x] EffectsStage: distress (dstOut speckle), grain (softLight noise), fade,
      halftone (luminance→dot screen). ColourStage: vintage grade, monochrome,
      duotone via ColorFilter.matrix. All seeded/deterministic; compose freely.
- [ ] Ripple/displacement — the one remaining initial capability; needs the
      flag_blend.frag shader path (ShaderStage), best verified on device/macOS.

## Fit / orientation / multi-flag fixes (2026-08-20, uncommitted)
- [x] Clip truncation FIXED — clipped (and torn) designs now cover-fill the frame,
      so heart/circle/silhouette masks land on flag pixels everywhere (no straight
      left/right cuts). Grid cells cover when clipped.
- [x] Flag aspect FIXED — `resolveFlag` rasterises at NATIVE aspect (no more
      stretched discs); composition fit/cover uses true proportions.
- [x] Multi-flag (3+) FIXED — showcase generator now uses ALL selected flags
      (1→hero, 2→blend, 3+→grid); every selected country appears.
- [x] Orientation — added `Orientation.square` (append-only); RenderService renders
      square/portrait(4:5)/landscape(5:4); editor has a square/portrait/landscape
      SegmentedButton; generator weights square 0.7. (`Orientation` clashes with
      Flutter MediaQuery's — recipe_editor hides Flutter's.)

## Torn edges on clipped shapes (silhouette/heart/circle) — FIXED (uncommitted)
- [x] Torn on a silhouette did nothing (torn tore the FRAME perimeter, which a
      centred silhouette never reaches). Added `TornMaskGenerator.erodeOutline` —
      a chamfer distance-transform boundary erosion that tears the artwork's OWN
      alpha outline. `EdgeTreatmentStage` uses it whenever a clip is present, and
      keeps frame-perimeter tearing for full-bleed flags. Band is shape-relative
      (3–11% of min dim) + mostly high-freq notches so thin silhouette parts
      survive. Verified: coco-de-mer + heart torn outlines, interiors intact.

## Multi-flag instances + 8 fitting algorithms (2026-08-20, uncommitted)
- [x] `FillAlgorithm` gene (grid, treemap, diagonalStripe, voronoi, tornRegion,
      noiseBlend, radial, mosaic) on `Composition`. `MultiFlagLayout` implements
      all 8: rect partitions (grid/treemap/mosaic) draw whole flags cover-filled;
      organic ones (diagonal/radial/voronoi/torn/noise) build a per-pixel region
      label map + reveal each flag through its region. Deterministic, fills frame.
- [x] Lab editor: Pattern = Single / Blend / Multi. Multi shows a Tiles slider
      (1–64 instances, repeats the base flags) + an Algorithm dropdown (8). Blend
      is now a plain mode+weight block (removed the vestigial on/off toggle).
- [x] Batch generator picks a random fill algorithm for 3+ flag designs.
- [x] Verified: all 8 algorithms render (distinct flags + 12 same-flag instances);
      forge 23, render 9, lab 10 tests; analyze clean; macOS build ✓.
- Note: organic algos (voronoi/torn/noise) cover-fill each flag to its region
  bbox → busier look; aesthetic tuning is follow-up.

## Phase 5 — Preview vs print — PARTIAL
- [x] RenderTarget preview/print tiers; resolution-independence test (same recipeId,
      both non-blank). [ ] isolate render pool + supersampled torn mask for print.

## Phase 6 — macOS Design Lab — DONE (uncommitted)
- [x] `apps/design_lab` Flutter macOS app — BUILDS (`flutter build macos` ✓).
      Flag multi-select (271, searchable) · batch generate + next-batch · fast
      cached gallery of live renders · **live parameter editor** (select a tile →
      sliders/dropdowns/toggles for family/combo/clip/torn/effects/ripple/colour +
      seed, preview re-renders in realtime; recipe_editor.dart, stale-render guard) ·
      reproduce-from-seed · favourite (persisted) · export PNG · contact-sheet export.
      Sandbox DISABLED in macos entitlements so it can read repo flag SVGs (dev tool).
      Run: `flutter run -d macos` from apps/design_lab. Headless loop verified via
      test/showcase_contact_sheet_test.dart; edit logic via test/recipe_editor_test.dart.

## Remaining (Phases 5b, 7, 8)
- [ ] Ripple shader stage (flag_blend.frag) + wave/torn shader flag-combos.
- [x] Silhouette clip (animal/plant/landmark) — 162 potrace SVGs wired as alpha
      masks via `AssetResolver.resolveClipMask` + `SvgFlagResolver` silhouette
      lookup (sanitises potrace's misplaced `/` + strips DOCTYPE/metadata). Lab
      editor has a shape=silhouette option + slug picker (prioritises silhouettes
      matching the design's flags). Verified: us→bald eagle, jp→Mt Fuji, etc.
- [x] "Copies per country" slider (replaces hidden "Tiles") — always visible
      (except Blend); total = copies × distinct countries; dragging >1 auto-switches
      to Multi grid. Verified: 4× Australia grid; 2× each of US/GB/FR = 6.
- [x] Clip UX: friendly shape labels (Country boundary / Region (continent) /
      Animal|Plant|Landmark silhouette / Heart / Circle). Country picker hidden for
      single-country (implied). Batch generator now emits countryOutline clips for
      single-country designs so country-boundary clipping shows in the gallery.
      Regions available = the 6 continents (Europe/Asia/Africa/N&S America/Oceania);
      sub-continental region boundary polygons are NOT in the asset set (would need
      world-coordinate country data to union; country JSONs are individually normalised).
- [x] Country/continent OUTLINE clip — `resolveClipMask` now rasterises
      `assets/country_paths/{cc}.json` (238) + `continent_paths/{name}.json`
      (`{w,h,polys}` → filled ui.Path → alpha mask). Verified: FR flag→France shape,
      4-flag grid→Europe shape.
- [x] Silhouette kinds split — Lab editor now offers Animal / Plant / Landmark
      silhouette shapes + Country outline + Continent outline in the Clip dropdown.
- [x] Plant/landmark SVGs are NOT missing — they exist in the silhouette_factory:
      `tools/silhouette_factory/assets/svg/` (animals, 492), `svg_plants/` (114),
      `svg_landmarks/` (207), all potrace SVGs in per-country subfolders (+ matching
      PNGs). The APP only bundles a curated one-per-country animal subset (161), which
      is why the Lab first showed only animals. FlagSource now indexes the factory
      per-kind dirs (recursive, kind = source dir — accurate, no slug guessing);
      resolver reads by slug via the index, falling back to the bundled dir.
      Verified: fleur-de-lis (plant) + Eiffel Tower (landmark) render.
      **PROD TODO (separate):** flatten the chosen plant/landmark SVGs into
      `apps/mobile_flutter/assets/silhouettes/` + pubspec so the shipping app can use
      them; today only the Lab (which reads the factory dirs off disk) sees them.
- [ ] Isolate render pool + print-res supersampling; stage-level caching.
- [ ] Preference-learned + on-device-model RecipeGenerators (interface ready).
- [ ] Integration A/B harness vs CardImageRenderer (no cutover). Production untouched.

---

# NEW INITIATIVE — Clip Shape Registry (extensible shapes)

Goal: clip shapes as a flexible, data-driven part of DesignRecipe (not a hard-coded
enum). Full design: `packages/design_forge/doc/SHAPES.md`.

## M1 + M2 — DONE & verified (uncommitted)
- [x] `ClipShapeMeta` + `kClipShapeCatalog` registry (pure design_forge): id, label,
      family (geometric/travel/outdoor/geographic/symbolic/typographic/custom),
      source (procedural/text/resolver/svgAsset), aspectRatio, cornerRadius.
- [x] `Clip` recipe extended: shapeId, code, text, scale, rotationDeg, aspectRatio,
      cornerRadius, feather, position. Backward-compatible (shape→shapeId;
      `Clip.shape(ClipShape,…)` kept). 23 forge tests ✓.
- [x] Shape-agnostic `ClipStage`: catalog lookup → target rect (scale/aspect/
      position) → procedural `ui.Path` (ShapeGeometry) / text mask (TextMask) /
      resolver mask; rotation about centre; feather. No per-shape code in stage.
- [x] `ShapeGeometry` registry (~19 procedural shapes) + `TextMask` (typography).
      All 22 render (shapes_export_test) ✓. Effects/edge independent (verified).
- [x] Lab editor: Family → Shape browser + live Scale / Rotation / Corner / Text.
      Generator showcases curated strong shapes. render 9 / lab 15 tests ✓,
      analyze clean, macOS build ✓.

## M3 — remaining
- [ ] Studio batch-across-shapes + evaluation to CULL weak/gimmicky shapes
      (lightning/wave/compass candidates); prioritise strong silhouette + apparel fit.
- [ ] Custom-SVG upload (customSvg source) + world-map shape asset.
- [ ] Apply scale/rotation transform to ASSET masks (procedural + text already do).
- [ ] Bundle a display font for text masks (headless test uses Ahem = solid boxes;
      real letters render on macOS/device).
