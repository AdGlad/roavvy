# Topic: Typography

**What it governs:** type treatment — the #1 amateur-vs-pro tell. In genome terms:
`typography.titleStyle`, `typography.case`, `typography.placement`
(`typographyTreatment` flag is **off** — biggest single quality unlock). Note: the
printed *string* is generated downstream by TitleGen and is **not** part of the
reproducible genome; only the *treatment* (style/case/placement) is.

## Principles
- **Max two typefaces** (a third only for a distinct technical/mono role). Each
  face is a voice; too many read as noise. (R-TYPE-01)
- **Type as a designed, era-coded system:** condensed grotesque = expedition/
  utilitarian; slab = rugged heritage; ornate serif = grand-tour; mono = technical/
  coordinate. Pair by contrast of role, harmony of feel. (R-TYPE-05)
- **Track all-caps and small type; kern hero display by eye** — tight caps jam,
  open tracking reads engraved/premium, big words show ugly default gaps. Never
  track scripts. (R-TYPE-02)
- **Match case to intent** — caps for badges/official, mixed/script for warmth/
  narrative. (R-TYPE-03)
- **Clean arcs** — consistent radius, symmetric top/bottom, even spacing; this is
  where amateurs fail on seals. (R-TYPE-04)
- **Never default system fonts or garbled pseudo-text.** **Solve contrast with
  colour/value, not outline+shadow+bevel.** (R-TYPE-06, R-TYPE-07)

## Rules in this topic
R-TYPE-01 … R-TYPE-07.

## Scorers
`contrastLegibility` (text vs background at print size) and the `printabilityGate`
(min text px). Type *style* coherence is best judged by the AI critic against the
locked style preset (R-TREND-01).

## Engine implication
**Turn `typographyTreatment` into a gene first** — lowest risk, biggest amateur-
vs-pro delta. Seed priors: ≤2 roles, tracked caps, case tied to template (arc only
on `badge`). Add cheap analytic gates: "≤2 type families", min text size (already
gated). Because the string isn't in the genome, the treatment gene stays
deterministic while copy varies. See `engine_recommendations.md` §2–3.
