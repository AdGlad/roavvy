# M212 — Pair Signature 4: Diagonal Split

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M209
**Status:** Draft built — awaiting owner Lab approval
**Pack:** `diagonal_split.pack.json` (`countries: 2`)
**Size:** S–M

---

## 1. The design

Reference: `~/Downloads/split-two.jpeg` (Algeria + Paraguay, plus thumbnails of India, Finland, Mexico/US and England/Portugal). Stock art, style only.
- A tall **portrait block**, cut corner-to-corner by a **diagonal channel** in the garment colour (the shirt shows through).
- Flag A is upper-left/left and flag B lower-right/right. Each flag runs **vertically** (rotated 90°) so its stripes run the length of the block.
- **Brushed, dripping outer edges** (dry brush, M208 mask), and the inside stays clean.

## 2. Engine work

- `splitPair` with `seam: diagonal` and `seamGap` > 0 as a knockout. Each flag is rotated 90° and cropped from its focus.
- **Emblem-aware angle:** if the diagonal would cut an emblem (Algeria's crescent, Paraguay's seal, Portugal's arms), nudge `seamPosition` or the angle within its envelope. This is a shared rule driven by the M207 emblem check.

## 3. Definition of done

As M209. The **owner approves**.

## As built (2026-11-28)

**Pack:** `diagonal_split.pack.json` (v1 draft, `countries: 2`, portrait canvas, tall block 0.66:1).
- Base: `seam: diagonal`, `seamSlant` 0.78, `seamFlip` (top-left → bottom-right, as the reference), `seamGap` 0.035 channel in the garment colour, `rotateFlags`, `edge: brush` with its own `brush` (`BrushStroke`: 18 spikes, dryness 0.6, leadClean 0.2, spill 0.4, taper 0.2), distress 0.03, edgeWear 0.3, no scratches, no shadow.
- Envelope: seed, `seamPosition` 0.47–0.53, `seamSlant` 0.70–0.82, `brush.liftFray` 0.3–0.6, `brush.dryness` 0.45–0.7.
- Locks: us+co, fr+it, mx+pt, jp+kr, np+ch, id+mc.

**Engine (shared, in `split_pair.dart` / `SplitPairComposer`):**
- `SplitPair.brush` (optional `BrushStroke`, written only when set, so Curtain Split's recipe ids are unchanged).
- `edge: brush` is now real: `BrushEdge.outline` on the block (stroke running down), colour extended into the spikes, inside left exactly as composed, channel sides roughened with the same brush (no lift-off spikes).
- Turned flags: a flag with a hoist emblem (canton, hoist triangle) turns so its hoist lands where its half is widest — anticlockwise when that is the bottom (`SplitFlagPlacement.ccw`). US as A puts its stars bottom-left, as B top-right.
- Diagonal shrink fallback searches the height along the block (bisection per height) and keeps the largest flag (Nepal sits in the wide end, about 45% of the block wide instead of ~20%). Curtain's shrink path is unchanged.
- `FlagFocus` hoist triangles (cu, pr, bs, cz, jo, ps, sd, ss, km, ph, er, mz, tl, st, zw, as) protect the middle 60% of the hoist instead of its full height. This also applies to Curtain Split (its jm+cu and ve+pr sample renders change slightly).

**QA** (hero + 4 variations):
- 32 sample pairs: 0 hard fails (heroes 5 pass / 27 warn; variations 12 pass / 116 warn).
- 50 random pairs (seed 212): 0 hard fails (heroes 11 pass / 39 warn; variations 42 pass / 158 warn).
- Warnings are flag-colour contrast on some shirt colours (as every flag pack) plus `pair_balance` where a flag had to shrink (Nepal, Bhutan's partner, the UAE, Ecuador).

**Open:**
- A flag that must shrink (Nepal; the UAE/Ecuador in narrow halves) leaves bare garment in part of its half, as in Curtain Split.
- The Lab has no `splitPair` / `brush` controls yet; tuning means editing the pack file.
