# Topic: Negative Space

**What it governs:** the empty area around and within the design, and the physical
print size on the garment. Empty space is a design element, not wasted room.

## Principles
- **Protect generous negative space; don't fill the shirt.** Empty space signals
  confidence and isolates the hero. Edge-to-edge crowding is the fear-of-empty-
  space amateur tell and implies "quantity to justify the price." (R-NEG-01)
- **Contain the print size** — ~25–30 cm wide, high-to-mid centre; left-chest marks
  ~7–10 cm. Oversized prints crowd the neckline/armholes, distort on the body
  curve, and read fast-fashion. (R-NEG-02)
- Negative space is *also* a printability win: fewer large flats to band/halo on
  DTG (see `print-techniques.md`, R-PRINT-05).

## Rules in this topic
R-NEG-01, R-NEG-02 (tightly coupled to density R-MERCH-02 and composition R-COMP).

## Scorers
`whitespace` (penalise *both* cramped and too-sparse — there is a premium middle),
`aspectFit` (contained, non-letterboxed placement).

## Engine implication
`whitespace` already scores breathing room. The KB tightens the target band and
ties it to `density`: penalise `dense` when `|countryCodes|` is small, and reserve
`dense` for genuinely large sets rendered as a *uniform* grid (R-FLAG-03). The
printability gate's `titleReserveFrac`/`brandingReserveFrac` already carve
protected empty zones — the scorer should reward designs that respect them
gracefully rather than fighting them.
