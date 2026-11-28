# M214 — Heart Wall: many countries (backlog)

**Phase:** Two-country Signatures (M206–M214, ADR-185). This is the stretch milestone, so it is in the backlog.
**Depends on:** M206 (generalise to N), M211 (brushed heart)
**Status:** Draft built — awaiting owner Lab approval
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

## As built (2026-11-29)

**Status:** Draft built. Zero hard QA failures; **the owner's approval in the Lab is still to come.**

- **Arity n:** pack `"countries": "n"` (`SignatureRecipe.anyCount`, `isList`) with the structural `{{countries}}` token (one flag ref per country, in order) and `{{countryCount}}`.
  - `SignatureList` keys (`"us,fr,jp"`).
  - `SignatureResolver.heroList` / `variationList`, with the RNG key over the joined list.
  - The codec reads and writes `"n"`.
- **Design:**
  - `DesignRecipe.heartWall` (`HeartWall`) plus pure-Dart `HeartWallLayout`. Hearts are equal in size, in input order. The column count (at most 6) is the one that makes the hearts biggest, and the last row is centred. Each heart gets a seeded tilt of ±3°.
  - `HeartWallStage` paints through the shared `HeartPairStage.paintHearts` (brushed hatch, frayed light ends, light grain). Heart Pair renders are unchanged; their packs regenerate byte-identical.
  - Every bundled flag keeps at least 75% of its emblem (test).
- **Pack `heart_wall`** (draft v1, portrait):
  - The variation envelope covers seed, tilt jitter (0–5), hatch angle (±6) and streaks.
  - Locks are set on the five sample lists.
- **Lab:**
  - List packs sheet `SignatureList.samples` (3, 6, 12, 24, 48 countries) and show "n countries" labels.
  - The Approve dialog takes `;`-separated lock lists.
  - The headless sheet has `LISTS=a,b;c,d`.
- **QA** (heroes + 4 variations at 3, 6, 12, 24, 48 countries): 0 fail. The soft warnings are white/red-shirt contrast on white-heavy flags.
- **App:**
  - `teesFor` now skips every pack that isn't single-country, so the Heart Wall doesn't appear as a single-country tee.
  - **Follow-up:** add an app entry ("My countries" heart wall from the traveller's visited countries in first-visit order, with a count cap) through the signature tee page, like pair tees. It is out of scope here.
- **Open items:**
  - For 3 countries the grid picks 2 + 1, because that makes the hearts biggest on portrait. A single row of 3 would need a rule.
  - With 49 or more countries the hearts get small. The cap is 60 per design.
