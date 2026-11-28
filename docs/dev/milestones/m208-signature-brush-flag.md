# M208 — Signature: Brush Flag (single country)

**Phase:** Two-country Signatures (M206–M214, ADR-185). This one is single-country and can run in parallel with M206/M207.
**Depends on:** M191
**Status:** Draft built — awaiting owner Lab approval
**Pack:** `brush_flag.pack.json`
**Size:** M

---

## 1. The design

References: `~/Downloads/greece.jpeg` and `costa-rica.webp`. They show the same design for two countries (stock art, style only).
- The flag is painted as **one wide dry-brush stroke**: a landscape block with bristle streaks feathering out along the top and bottom edges, and a ragged, fraying trailing edge on the right where the brush lifted. The left edge is mostly clean.
- The flag reads **in full**: stripes, cross and emblem stay intact (Costa Rica's crest is crisp).
- The **country name** in a casual handwritten marker hand sits **above** the flag, centred, in the garment's legible ink (white on dark, ink on light: ADR-183).

## 2. Engine work

- New `brushStroke` stage (design_forge): a mask of a broad dry stroke. It has bristle streaks along the stroke direction, a frayed lift-off end, slight pressure taper, and gaps where the bristles skip. Parameters: `bristles`, `dryness`, `liftFray`, `taper`, `skew`, `seed`. The flag is drawn through the mask, with no recolouring.
- **Emblem guard:** use the M206 flag focus/emblem box to keep dryness gaps off the emblem.
- Captions: a new handwritten font (OFL, e.g. *Caveat Brush* or *Kalam*; the owner picks from three), `top: {{countryName}}`, sized to the flag width, and long names shrink (e.g. "Bosnia and Herzegovina", "Saint Vincent and the Grenadines").
- **Reuse:** the M208 brush mask is the edge treatment for M210, M211 and M212.

## 3. Envelope candidates

`seed`, `dryness`, `liftFray`, `skew` ±3°, caption size. The flag variant is fixed.

## 4. Definition of done

Same as M192 §4: zero hard QA fails for every country, soft fails reviewed, and **the owner approves in the Lab**. Locks and goldens are committed.

## As built (2026-11-28) — draft, awaiting owner approval in the Lab

- **Recipe part** `DesignRecipe.brushStroke` (`BrushStroke`, design_forge): `bristles`, `dryness`, `liftFray`, `leadClean`, `taper`, `spill`, `skew`, `scale`, `centerY`, `minAspect`, `maxAspect`. Absent = no change to any existing recipe id.
- **Reusable edge** `BrushEdge` (design_forge_render `geometry/brush_edge.dart`): roughens the edge of any shape given as alpha — `brushArtwork(art, brush, seed)`, `maskForPath(path, w, h, brush, seed)`, `maskForRect(rect, …, vertical:)`, pure-Dart `paint(rgba, w, h, brush, seed)`. Thin bristle streaks along the edges running with the stroke, frayed lift-off at the trailing end, near-clean leading edge, a few overshooting hairs; bites are limited to an edge band, so the middle (emblems) is never touched. Documented in `packages/design_forge/doc/SIGNATURE.md`. For M210–M212.
- **Stage** `BrushFlagStage` (after Clip): the flag in its own aspect clamped to 1.3–2.0 (CH, QA stay strokes), 84% of a landscape canvas, centred at 60% height; non-rectangular flags (Nepal) keep their own outline, which is brushed.
- **Font** `captions.font: "handwritten"` = embedded Kalam Bold (SIL OFL 1.1, Latin subset, 75 KB; `fonts/Kalam-Bold.ttf`, `fonts/OFL-Kalam.txt`). Chosen as the closest of three tried (Caveat Brush, Kalam Bold, Gochi Hand) to the reference lettering; the owner can swap it.
- **Captions**: accented capitals (Å, Ô, Ü) now get headroom so they never touch the print edge (was the only hard QA failure: AX, CI, TR).
- **QA sweep**: captions are inked per shirt in the Lab sweep too (`dependsOnGarment` includes captions), matching the app's `inkFollowsShirt`.
- **Pack** `brush_flag.pack.json` (draft v1): envelope seed, `brushStroke.dryness` 0.4–0.7, `brushStroke.liftFray` 0.35–0.7, `brushStroke.skew` ±3°, `captions.topSize` 0.15–0.18. Locks for us/jp/br/fr/za/sc.
- **QA** (271 countries, hero + 8 variations): see the final numbers in the PR. Remaining soft warnings are flag-colour vs shirt-colour contrast (e.g. a red flag edge on a red shirt), as for every flag pack — for the owner to review.
- Costa Rica's bundled flag SVG has no coat of arms (asset, not this pack).
