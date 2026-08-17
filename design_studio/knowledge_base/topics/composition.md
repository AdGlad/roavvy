# Topic: Composition

**What it governs:** how elements are arranged on the chest print — the macro
skeleton before colour or texture. In genome terms: `composition.template`,
`layoutMode`, `rowCount`, `density`, `orientation`, `imageSize`, and `clip.shape`.

## Principles
- **Contain the design in a deliberate geometry** (circle, shield, banner, stacked
  block, route grid) and put everything on shared axes. A container reads as craft
  and gives the generator a layout skeleton. (R-COMP-02)
- **Bind parts with Gestalt** — proximity, alignment, a shared shape, an enclosing
  frame — so scattered marks read as one object, not clip-art on a shirt.
  (R-COMP-01)
- **Compose personalised data; never insert it.** A 3-country and a 40-country
  design must each look deliberately laid out — the template reflows, it doesn't
  overflow. (R-COMP-04, and see `merchandising.md` density tiers R-MERCH-02)
- **Win at 200px and across a room** — one readable idea, strong silhouette. Fine
  detail dies at thumbnail and at distance. (R-COMP-03)

## Rules in this topic
R-COMP-01, R-COMP-02, R-COMP-03, R-COMP-04 (see also all of §A/§B in
`design_rules.md`).

## Scorers
`coverageBalance` (even fill, centre-of-mass), `aspectFit` (fits the print area),
`whitespace` (breathing room), `focalHierarchy` (a clear dominant element).

## Engine implication
Composition is the most mature part of the engine (`FlagGridLayoutEngine`,
templates, montage/treemap). The KB's addition is **semantic**: bias `template`/
`layoutMode` priors by scope + persona (grammar §"Scope → bias"), and make
`density`/`rowCount` a **function of `|countryCodes|`** so layouts stay composed
across the data range. See `engine_recommendations.md` §1–2.
