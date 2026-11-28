# M211 — Pair Signature 3: Twin Hearts

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M210
**Status:** Todo
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
