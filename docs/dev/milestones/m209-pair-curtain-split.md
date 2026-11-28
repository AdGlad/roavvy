# M209 — Pair Signature 1: Curtain Split

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M207
**Status:** Todo
**Pack:** `curtain_split.pack.json` (`countries: 2`)
**Size:** M

---

## 1. The design

References: `~/Downloads/split-flags-c.jpg` (US + Colombia) and `split-two-b.jpeg` (Hungary + US). Stock art, style only.
- One upright **grunge block** (about 4:5), flag A on the left and flag B on the right.
- They meet along a **curved S-shaped "curtain" seam**, so B looks like it is drawn across A. Both flags' stripes run straight; only the seam curves.
- **Heavy distress:** speckled grunge breaks across both flags, and the outer edges are rough and torn, not clean.
- Each half keeps its flag's **focus**: the US stars stay visible whether the US is on the left or the right (M206 flag focus).

## 2. Engine work

- New `splitPair` composition: two flags laid into one frame along a seam path (`straight` | `curtain` | `diagonal`; M212 reuses it). Parameters: `seamCurve`, `seamPosition` 0.42–0.58, and `seamGap` (0 here). Each half is cropped from its flag's focus.
- Distress: existing WearRaster grunge (`effects.distress`/cracks) over the whole block, plus a rough outer edge from the torn-flag edge code.

## 3. Risks

- Look-alike pairs (FR+NL, ID+MC) blur together at a zero-gap seam. Fall back to a thin garment-colour seam when the M207 legibility check warns, as a shared rule.

## 4. Definition of done

Zero hard fails on the M207 sample pairs plus 50 random pairs × 4 variations, then **owner approval in the Lab**.
