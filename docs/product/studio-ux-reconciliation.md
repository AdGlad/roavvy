# Studio UX — Storyboard ↔ Spec ↔ Repo Reconciliation

Reconciles three inputs into one buildable UX plan for the Roavvy T-Shirt Studio:

- **Storyboard** (`~/Downloads/Roavvy-Storyboard-ChatGPT.png`) = experience & visual-direction reference.
- **Control spec** (`docs/product/chatgpt-ux-brief.md` §13) = functionality contract.
- **Repo** (`apps/design_lab/lib/studio_canvas_screen.dart`) = implementation reality.

Rule: no existing functionality is removed just because the storyboard doesn't show it.

---

## 1. What the storyboard proposes

**Instant → Make It Yours → Fine Tune.**

- **Instant — Open Studio:** finished hero shirt from real travels; FRONT/BACK toggle;
  "28 countries detected" chips; big **MAKE IT YOURS**; app bottom-nav (Studio/Saved/Trips/Profile).
- **Make It Yours — a guided visual sequence of focused screens:**
  1. Choose Direction (big subject cards) · 2. Choose Detail (shape cards, flag subjects only) ·
  3. Pick a Vibe (13 rendered style thumbnails) · 4. Add Your Words (title + SUGGEST TITLES + AI ideas) ·
  5. Shirt & Colour (colour swatches, size, orientation) · 6. Front/Back (Sync style, Start-from-front-theme, Remix/Refine) ·
  7. Review & Save (front+back, spec summary, SAVE TO LIBRARY / ADD TO CART).
- **Fine Tune — Refine mode:** a category **menu** (Layout · Graphic · Text · Colour · Edges · Effects · Print Style)
  opening focused per-category panels (sliders + thumbnails). Remix + Locks throughout.

## 2. What the repo already has (reuse these)

Single live-canvas screen, top→bottom: AppBar (Adjust toggle, Save, Undo, "Surprise me") ·
breadcrumb · **Format bar** (Aspect / Size / Garment colour / Side) · **hero canvas** ·
**alternatives tray** (4 re-rolls + ✕ reject) · **Detail row** (flags only) ·
**one long Adjust panel** (Finish · Text · Grid · Passport · Silhouette · Shape · Colour · Edges · Effects · Print) ·
**axis-chip deck** (Direction/Vibe/Focus/Colour/Words + per-chip lock).

Already-solved primitives to reuse as-is: deterministic live re-render (`_HeroCanvas`),
per-axis `reroll`, alternatives + preference ordering, per-axis **lock**, **undo/branch** history,
`deriveBack` (front→back theme), garment-aware colour, Finish presets, the full control set.

## 3. Gap map (storyboard step → repo today → action)

| Storyboard | Repo today | Action |
|---|---|---|
| Instant hero + "Make it yours" | Hero canvas + chip deck | **Reuse** hero; reframe deck entry as "Make it yours" |
| Choose Direction (cards) | Direction axis chip → tray | **Refactor** to a card grid step |
| Choose Detail (cards) | `_detailRow()` chips | **Refactor** chips → cards (same 7 detail values) |
| Pick a Vibe (13 thumbnails) | Vibe axis → generic re-roll tray | **New**: labelled 13-style thumbnail picker (LabStyle) |
| Add Your Words (+ SUGGEST TITLES) | Text field in Adjust + Words axis | **Refactor** into a Words step w/ title + suggest-titles list |
| Shirt & Colour | Format bar (Aspect/Size/Colour/Side) | **Reuse** — already Tier-1 |
| Front/Back (Sync/Start-from-theme) | Side pills + `deriveBack` | **Enhance**: Sync-style toggle + explicit "start from front theme" |
| Review & Save | Save (heart) only | **New** Review summary (spec chips + Save to library) |
| Refine category menu | One long Adjust panel | **Refactor** into 7-category menu → focused panels |
| Remix button | "Surprise me" | **Rename** to Remix (same behaviour) |

## 4. Where the proposed UX INTENTIONALLY differs from the storyboard (and why)

1. **Steps overlay the live shirt; they are not separate full screens.**
   Storyboard draws each step as its own route with a small preview. Our principle is *the
   shirt is always the hero and every change is immediately visible on it*. So "Make It Yours"
   is a **paged panel / bottom sheet over the persistent live hero**, not 8 routes that hide the
   garment. This keeps the storyboard's progressive disclosure while preserving the repo's live-preview strength.

2. **No functionality is dropped for storyboard omissions.** The storyboard's Refine shows
   Layout/Graphic/Text/Edges/Effects/Print but not everything. We KEEP and re-home:
   **Colour** (flagDerived/monochrome/duotone/garmentAware + Vintage grade) as its own Refine
   category (the menu even lists "Colour — Palette & treatment"); **Passport** Multi/Mono +
   stampMode + scatter (under Graphic/Detail context); **Halftone scale, Ripple + freq,
   Shatter spikes** (Effects); **Silhouette picker** (Graphic). Spec §13 is the contract.

3. **Artwork Size (S/M/L) ≠ garment fit size (XS–XXL).** The storyboard's "Shirt & Colour"
   shows S/M/L/XL/XXL, conflating two things. Engine `SizeClass` (S/M/L) controls *how big the
   print sits on the shirt*. Physical garment fit (S–XXL) is a **Printful product attribute chosen
   at cart**, not an artwork control. We keep artwork Size = S/M/L in the Studio and defer fit-size
   to checkout. (Avoids a misleading control that appears to resize the print but doesn't.)

4. **Bottom app-nav (Saved/Trips/Profile) and Add-to-Cart/checkout are out of scope for the Lab.**
   These are app-shell + commerce concerns that live in the mobile app (milestone M1). The Lab
   prototype's Review ends at **Save to Library** with an explicit *(Add to cart — mobile/M1)*
   placeholder, so the flow reads end-to-end without faking a store.

5. **"Remix" replaces "Surprise me".** Adopt the storyboard's clearer, on-brand verb; behaviour
   (re-roll all UNLOCKED axes) is unchanged.

## 5. Build plan — STATUS (isolated Studio packages only; production merch/cards never touched; inline chunked commits)

All phases landed on `feat/studio-ux-storyboard`; lab 76 tests green, analyze clean, macOS build ✓.

- **P1 — Make-It-Yours framing.** ✅ The deck is labelled "MAKE IT YOURS" with a
  "Fine tune" entry to Refine, so the flow reads Instant → Make It Yours → Fine Tune.
  (Kept as panels over the persistent live hero — intentional difference #1 — rather than 8 routes.)
- **P2 — Vibe style grid.** ✅ Tapping Vibe surfaces 13 labelled LabStyle thumbnails, each a
  live restyle of the current design (new `LabShowcaseGenerator.withStyle` + a spliced vibe re-roll;
  vibe re-rolls now stamp provenance, recipeId unaffected). Highlights the active style.
- **P3 — Refine category menu.** ✅ The one long Adjust panel is now Finish · Layout · Graphic ·
  Text · Colour · Edges · Effects · Print → one focused body at a time, contextual to the design.
  Every control retained.
- **P4 — Words editor.** ✅ Tapping Words opens an editable printed-title field +
  "Suggest titles" (distinct Words-axis re-rolls) instead of a blind re-roll.
- **P5 — Front/Back sync.** ✅ While on the Back, "Sync to front" re-derives it from the front's
  current theme (storyboard "Start from Front theme").
- **P6 — Review & Save.** ✅ A Review action opens a sheet with front/back previews, spec chips,
  printed title, Save to Library, and a disabled "Add to cart (mobile)" placeholder (commerce = M1).
- **P7 — Remix rename.** ✅ "Surprise me" → "Remix"; tune button → "Fine tune (Refine)".

**Not built (deferred, per intentional differences §4):** bottom app-nav (Saved/Trips/Profile),
real cart/checkout, and garment fit-size (XS–XXL) — all mobile/commerce (milestone M1). Lower-priority
polish still open from spec §13: Pattern Single/Blend/Multi + flagCombination, Map country/region
picker, placement anchor, explicit seed field.
