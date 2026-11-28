# M214 — Heart Wall: many countries (backlog)

**Phase:** Two-country Signatures (M206–M214, ADR-185). This is the stretch milestone, so it is in the backlog.
**Depends on:** M206 (generalise to N), M211 (brushed heart)
**Status:** Backlog
**Pack:** `heart_wall.pack.json` (`countries: n`)
**Size:** M

---

## 1. The design

Reference: `~/Downloads/multi-hearts.jpeg`. Stock art, style only.
- A tidy grid of **small hearts, one flag each**, in rows of about 6, shaped by how many countries there are. It is the "every country I've been to" shirt.
- Each heart has a light brushed edge and is the same size. Order: by first visit (default), or alphabetical.

## 2. Notes

- It extends the M206 arity from 2 to n (`{{countries}}` list token). It can probably reuse the existing `grid` family layout.
- QA at 3, 6, 12, 24 and 48 countries, with an empty-cell rule for awkward counts (e.g. centre the last row).
- It is planned last because it is not a pair design. The owner can promote it.
