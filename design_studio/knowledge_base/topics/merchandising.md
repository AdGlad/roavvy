# Topic: Merchandising Observations

**What it governs:** how the *system* (not a single design) reads as a curated
premium collection — the anti-"auto-generated smell" discipline.

## Principles
- **Controlled variation along curated axes, never raw randomness.** Each axis
  (palette set, layout template, hero element, texture level) constrained to values
  that always look good together. Random knobs make ugly outliers; "same 3
  templates" feels cheap. (R-MERCH-01)
- **At least three density tiers per template, chosen by data volume.** 1–3
  countries → hero outline; 4–15 → badge/stamp cluster; 16+ → normalised grid /
  count-forward. One layout can't look premium from 2 to 90 countries. (R-MERCH-02)
- **Design for the marketplace thumbnail** — purchase starts at ~200px. (R-MERCH-03,
  = R-COMP-03)
- **Keep one consistent system across a series** for collectibility and repeat
  purchase. (R-MERCH-04)

## Rules in this topic
R-MERCH-01 … R-MERCH-04 (with R-COMP-04, R-TREND-01/03).

## Scorers
`coverageBalance` + `profileFit` (density fits the data), `contrastLegibility` +
`focalHierarchy` (thumbnail strength), plus the **genome-distance diversity filter**
and a proposed **semantic diversity** check (don't present three designs that
satisfy the top rules the same way).

## Engine implication
Two system-level asks: (1) make `density`/`layoutMode`/`rowCount` a **function of
`|countryCodes|`** with explicit tiers (R-MERCH-02) so every user gets a composed
result; (2) enforce **semantic diversity** in the presented three — distinct
archetypes and distinct ideas, not near-duplicates. Telemetry on which designs get
chosen/purchased tunes the curated ranges over time (Stage 5 learning, clamped so
personalisation never leaves the Design Language). See `engine_recommendations.md`
§2, §5.
