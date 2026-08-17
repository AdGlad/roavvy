# Concept Discovery Roadmap — expanding Roavvy's design language

*The Creative Director's living pipeline of NEW procedural design concepts (beyond
tuning existing families). Each candidate is scored for **catalogue value** and
**implementation cost**, aligned to the [Knowledge Base](../knowledge_base/), and
gated by Studio validation before promotion into the
[family catalogue](../knowledge_base/family_catalogue.md). Protect diversity: prefer
concepts that fill **gaps**, never ones that converge the catalogue on one look.*

Discovery cycle (per goal): Research → Identify opportunity → Hypothesis →
Prototype → Generate batch → Render → Critique → Compare → Refine → Validate → Add
→ Document → repeat.

Value = commercial appeal + originality + Roavvy identity + fills-a-gap.
Cost = new rendering? new scorer? content/TitleGen? (pure recombination = cheapest).

---

## Completed
- **C-01 · Statement Count** (achievement-forward typographic) — ✅ ACCEPTED
  2026-08-16. New composition family `statementCount`; validated (zero regressions,
  `massive-light` +0.011, diversity 3→4 / lifetime 4→5). Doc:
  `../knowledge_base/concepts/C-01-statement-count.md`. Follow-up: TitleGen stat
  variant + optional `focalContrast` branch for type-hero families.
- **C-02 · Passport-Stamp Collection** — ❌ REJECTED (deferred) 2026-08-16. Prototyped
  + refined + validated; scored 0.733 (above peer collection families) but improved
  **no** context and marginally degraded `year`/`region` — reverted (determinism
  restored, all Δ 0.000). **Deferred, not killed:** the analytic scorer can't render
  stamps, so it can't fairly judge the concept. Doc:
  `../knowledge_base/concepts/C-02-stamp-collection.md`. Unblock = the C-00 fix below.

## Cross-cutting prerequisite (surfaced by C-01 & C-02)
- **C-00 · Rendered-evidence evaluation** — 🟢 **Lane B DONE + Lane A BUILT** (2026-08-16).
  Finding: headless full-render is timing-flaky (renderer's own test is skipped →
  on-device only), so C-00 split in two. **Lane B (done):** closed the analytic
  blind spot — type-led focal credit in `quality_model.dart`; strict improvement,
  zero regressions, weakest contexts up most (lifetime +0.014, massive-light +0.013),
  baseline regenerated. **Lane A (built):** best-effort host capture harness `render_capture.dart`
  (`RENDER_CAPTURE=1 flutter test …`) rendered 5/12 real PNGs first run + surfaced 2
  analytic-blind findings (text→tofu; singleHero renders as a flag grid → opt roadmap
  E-005); on-device upgrade (A2) for full fidelity unblocks C-02/C-04/C-05. Doc: `../knowledge_base/concepts/C-00-rendered-evidence-evaluation.md`.

## Ranked backlog

### C-07 · Coordinate / Expedition-Log typographic — **HIGH value, LOW-MED cost**
- **Opportunity:** the nautical/archival "48.8566° N, 2.3522° E" look is a top-
  selling premium travel-apparel concept and only partially covered
  (typographicIntegration is generic). KB R-STORY-01/15 (real coordinates feel
  true), R-TYPE-05 (mono technical type).
- **Prototype:** could be a `typography`-template family (like C-01) OR a treatment
  layered on singleHero/negativeSpaceCutout. Content = real lat/long from the
  profile via TitleGen; **rendering needs a mono coordinate/stat line** (small).
- **Risk:** overlap with C-01/typographicIntegration — differentiate by the
  cartographic/instrument aesthetic + mono stat block; validate it reads distinct.

### C-03 · Cartographic Outline-as-Frame — **MED value, LOW cost**
- **Opportunity:** a clean country/continent outline as a **framing vessel** with
  generous negative space and one palette fill (R-STORY-05 window-into-meaning,
  R-NEG-01), distinct from `negativeSpaceCutout` (busy mask-hero packed with flags).
- **Prototype:** pure recombination (outline mask + sparse density + hero scale).
- **Risk:** overlap with `singleHero` (already uses outline clip) — must prove a
  distinct, cleaner framed look or fold into singleHero as a variant.

### C-04 · New print/texture treatments — **HIGH value (multiplies catalogue), MED cost**
- **Opportunity:** the print-style axis is orthogonal and multiplies every
  composition family; it is the strongest carrier of Roavvy identity (KB
  R-TREND-02 process-not-filter). Candidates: **duotone-halftone photo**, **screen-
  print misregistration**, **discharge/washed heavyweight**. All KB-backed.
- **Cost:** each needs `PrintStylePipeline` rendering work + a torn-style-like
  quality metric. Prototype one, validate against liked references.

### C-05 · New flag treatments — **MED-HIGH value, MED cost**
- **Opportunity:** duotone / single-ink / tonal flag rendering so multi-flag sets
  stop clashing (KB R-FLAG-01) — a treatment axis that improves EVERY multi-flag
  family. Prototype as a `palette.strategy` already in the recipe (duotone/
  monochrome) wired into flag rendering.

### C-06 · Journey Route Line refinement — **LOW-MED value, LOW cost**
- `chronoSequence` covers timeline/journeys; a true connecting **route arc** with
  stops (R-STORY-02) may be a refinement rather than a new family. Low priority.

---

## Standing discovery questions (revisit each cycle)
- What premium apparel styles are still missing from the catalogue? (see
  family_catalogue §5 thin spots)
- Which axis multiplies the catalogue most per unit cost? (usually **treatments**:
  print styles, flag treatments — they apply across all composition families)
- Is any trend emerging that we lack a grammar for? (gorpcore/topographic,
  blokecore/heritage — adopt as *grammars*, KB R-TREND-03)
- What is now procedurally possible that wasn't? (new templates/masks/shaders)

## Rules of discovery
- **Reject marginal concepts.** Promote only if Studio validation shows it
  *significantly* improves the catalogue without reducing diversity.
- **Prefer gap-fillers and treatment axes** over near-duplicates of existing
  families.
- **Cheapest viable prototype first** (pure recombination > new content > new
  scorer > new rendering).
- **Document every accepted concept** as a `knowledge_base/concepts/C-##-*.md` and
  promote it in the family catalogue; update KB rules/evaluation when it teaches
  something new.
