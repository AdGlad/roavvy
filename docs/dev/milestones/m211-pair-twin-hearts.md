# M211 — Pair Signature 3: Twin Hearts

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M210
**Status:** Draft built — awaiting owner Lab approval
**Pack:** `twin_hearts.pack.json` (`countries: 2`)
**Size:** S

---

## 1. The design

Reference: `~/Downloads/two-hearts-1.jpeg` (US + Colombia). Stock art, style only.
- **Two hearts side by side**, close together and the same size, each filled with one whole flag: A on the left, B on the right.
- Each heart has the same **dry-brush edge** (M208/M210), and the stripes read as brush strokes. Each heart tilts slightly toward the other.
- The overall shape is a wide landscape, which suits a chest print or a smaller back print. The pack `layout` default is decided with the owner (e.g. full front at 0.8 scale).

## 2. Engine work

- A new `pairRow` composition with two clips, a gap, mirrored tilt and an optional overlap. Each heart uses the existing heart clip with `flagFit` and the M210 brush edge.

## 3. Definition of done

As M209. The **owner approves**.

## As built (2026-11-28)

**Status:** Draft built. Zero hard QA failures; **the owner's approval in the Lab is still to come.**

- **Engine:**
  - It uses the same `heartPair` section as M210, with `layout: twin`, instead of a separate `pairRow` composition.
  - `HeartPairLayout` places two equal hearts `gap` apart. They lean apart by `tilt`° (A turns anticlockwise, B clockwise), with the tips toward each other as in the reference, and the gap grows so the tips never touch.
  - Each heart holds one whole flag, fitted around its focus with the same emblem rule as M210.
- **Brush:** `paintHatch(frayed: true)` gives square-cut, near-horizontal strokes whose ends break into fans of bristles, with long dry streaks running in from the ends. This is the streaky look of the reference.
- **Pair QA:** the seam is reported at the gap (`gap` > 0), so the seam check is skipped. The crops are the heart polygon in flag space.
- **Pack `twin_hearts`** (draft v1, landscape):
  - heartScale 0.8, gap 0.012, tilt 7°, strokes 0.07 wide at −4°, frayed, streaks 0.55.
  - The variation envelope covers seed, tilt (3–11), hatch angle (±8), streaks and spill.
  - The default print layout is full front at 0.8 scale (owner to confirm).
  - Locks are set on the six default lock pairs.
- **QA** (heroes + 4 variations): 32 sample pairs → 0 fail, and 50 random pairs → 0 fail. Early drafts at heartScale 0.86 clipped the print edge, which is why it is now 0.8. The soft warnings are garment contrast only.
- **Open item:** on the landscape canvas the hearts leave empty space above and below. A wider canvas option would let them print bigger.
