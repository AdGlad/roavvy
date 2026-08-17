# Topic: Travel Storytelling

**What it governs:** turning "places I've been" into an emotionally resonant graphic
— Roavvy's core differentiator. Maps to `composition.template` (passport/timeline/
journeys), `content.*`, `clip.code`, `motifs`.

## Principles
- **Ground every design in real, specific, verifiable data** (accurate outlines,
  correct dates, honest counts, real coordinates). Specificity = proof-of-
  experience = why it gets worn. Never fabricate precision. (R-STORY-01)
- **Sell the journey, not the inventory** — routes, "explorer since [year]," worn
  stamps. A list is a database; a journey is emotion. (R-STORY-02)
- **Every design is an identity claim, not decoration** — a flattering-yet-true
  statement worn as a low-risk social beacon. (R-STORY-03)
- **Understatement / insider cues over loud tourist branding** — traveler, not
  tourist. (R-STORY-04)
- **The country outline is a container/window into meaning,** not a bare shape —
  fill it with a flag, texture, visited-city dots or a journey line. (R-STORY-05)

## Storytelling devices (device → hook → when → risk)

| Device | Hook | Works when | Risk |
|---|---|---|---|
| Journey line (visit order) | Narrative + time | Few–medium points | Spaghetti; cliché if unstyled |
| Coordinates | Authenticity, archival romance | Few locations | Fabricated precision kills trust |
| Country/region outline | Recognition, pride | Single hero; as container | Bare outline = map-site cliché |
| Passport stamps | Nostalgia, collection | Medium counts; vintage | Abstract, don't replicate; clutter |
| Checklist "been there" | Achievement | Any count | Spreadsheet feel without strong type |
| Count as hero ("47 · 6") | Pride, status; thumbnail-strong | Dense data | Cold/braggy without warm framing |
| Est. "explorer since" | Longevity, belonging | Heritage badge (support) | Meaningless if fabricated |

## Rules in this topic
R-STORY-01 … R-STORY-05 (with R-ICON-04, R-FLAG-04, R-MERCH-02).

## Scorers
`profileFit` (relevance of the set/story to the persona and real data). Emotional
resonance is otherwise a job for the AI critic and telemetry (which stories get
chosen/purchased).

## Engine implication
This is where Roavvy's structural edge lives: the engine already has the real data
(`TravelProfileAnalyzer` → persona, candidateSets, signatureCountries, notableSites,
date span). The KB says: bias `template` toward narrative forms (`timeline`,
`journeys`, `passport`) for `trip`/`year` scopes, and **never fabricate** — if a
datum isn't real, don't show it. Weight `profileFit` at 0.3 (below aesthetic 0.7)
so a relevant-but-ugly design never wins.
