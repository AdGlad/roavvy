# M208 — Signature: Brush Flag (single country)

**Phase:** Two-country Signatures (M206–M214, ADR-185). This one is single-country and can run in parallel with M206/M207.
**Depends on:** M191
**Status:** Todo
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
