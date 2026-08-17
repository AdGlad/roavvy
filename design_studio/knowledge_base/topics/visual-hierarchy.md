# Topic: Visual Hierarchy

**What it governs:** the order in which the eye reads the design, and which single
element dominates. The most reliable premium-vs-amateur signal after colour.

## Principles
- **One dominant hero, always.** Each design is one idea seen from across a room;
  everything else supports it. Equal-weight elements read as "a pile of assets."
  (R-VH-01, R-ICON-02)
- **Three tiers: hero / support / detail,** each element in exactly one, with big
  scale jumps between them. Near-equal sizes read as undesigned. (R-VH-02)
- **Decisive scale contrast (~1.6–2×+),** not timid steps — small differences read
  as mistakes, large ones as confidence, and weak contrast collapses to mush at
  distance. (R-VH-03)

## Rules in this topic
R-VH-01, R-VH-02, R-VH-03 (supported by R-ICON-02, R-COMP-03).

## Scorers
`focalHierarchy` is the primary encoder (share of visual weight held by the
busiest region — the studio's `focalConcentration` metric, e.g. 0.85 on the liked
"torn-flag" reference). `edgeDensity` guards against busy, flat, no-focal mush.

## Engine implication
`focalHierarchy` already exists as an analytic scorer. The KB says: (1) weight it
highly — a flat, no-hero design should rank low even if relevant; (2) once
`typographyTreatment`/`motifEngine` flags are on, enforce the 3-tier split in
type sizing and cap motif count so a hero always emerges. A design where no single
element dominates is the clearest "reject/deprioritise" signal the scorer can send.
