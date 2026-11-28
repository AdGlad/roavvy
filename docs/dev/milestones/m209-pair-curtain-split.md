# M209 — Pair Signature 1: Curtain Split

**Phase:** Two-country Signatures (M206–M214, ADR-185)
**Depends on:** M207
**Status:** Draft built — awaiting owner Lab approval
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

## As built (2026-11-28)

**Status:** draft pack built; zero hard QA fails; awaiting the owner's approval in the Lab.

- **Engine:** `DesignFamily.splitPair` + `DesignRecipe.splitPair` (`SplitPair`, `SplitSeam`, `SplitEdge`) and the pure `SplitPairLayout` in `design_forge/lib/src/recipe/split_pair.dart`; `PairGeometry.of` reports true crops (flag-space polygons) and the seam in render space. Renderer `SplitPairComposer` (`design_forge_render/lib/src/stages/split_pair_composer.dart`) and `WearRaster.grunge` (streaky torn edge, clustered flecks, scratches, fade).
- **Shared rules:** canton/high-focus flag gets the top of the seam (US stars visible on either side); two cantons → straight seam + ≥1.1 block; wide cantons widen the block; placement searches for ≥78% emblem visibility, then edge-extension, then shrink-to-fit (Swiss cross, Nepal, Bhutan); vertical tricolours narrowed to show all stripes; `autoGap` channel when the seam colour distance is < 1.3× the QA limit; pair QA now treats a drawn channel as a seam.
- **FlagFocus retuned** against renders: ch, np, pa, ki, pg, tt, cg, tz, bt (boxes that covered the whole flag), au and hm (now ensigns).
- **Pack:** `curtain_split.pack.json` v1 draft, portrait, 32 `samplePairs`; envelope seed, seamPosition 0.47–0.53, seamSlant 0.18–0.30, seamCurve 0.3–0.9, distress 0.45–0.75; locks us+co, fr+it, mx+pt, jp+kr, np+ch, id+mc.
- **QA** (hero + 4 variations): 32 sample pairs — 0 fail (heroes 3 pass / 29 warn); 50 random pairs (seed 209) — 0 fail (heroes 11 pass / 39 warn). Warnings are almost all `contrast:*` (flag colours vs some shirt colours, as every flag pack); `pair_balance` only where Nepal/Bhutan are shrunk; one `pair_seam`.
- **Known limits / for the owner:** Nepal pairs leave Nepal small (its pennant must stay whole); emblem flags whose emblem is wider than half the block (Bhutan, Switzerland, Guyana) are shown smaller with extended edge colour; `edge: brush` falls back to torn until M208's `BrushEdge` is wired in (hook `SplitPairComposer._brushEdge`).
