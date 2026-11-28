# M212 — Pair Signature 4: Diagonal Split

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M209
**Status:** Todo
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
