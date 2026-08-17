# Roavvy Design Knowledge Base

*The reusable design expertise that guides all procedural generation, evaluation
and optimisation of Roavvy merchandise. Research-phase output — **no rendering or
generation code is written or changed by this KB.** It is the taste the engine
implements.*

> **Status:** foundation complete, awaiting review. Per the goal, no
> implementation begins until this KB is reviewed. Everything here is
> development-only and **never bundled** (it lives under `design_studio/`).

---

## Read in this order

1. **[design_philosophy.md](design_philosophy.md)** — *What Makes a Roavvy T-Shirt.*
   The creative foundation: the thesis, seven commitments, the traveler-not-tourist
   line, and a 7-point test. Start here.
2. **[design_language.md](design_language.md)** — the visual identity: brand
   adjectives mapped to concrete genome traits, the vocabulary, the palette
   temperament, the anti-identity.
3. **[design_rules.md](design_rules.md)** — the testable rulebook (58 rules), each
   bound to genes + scorers, with why / confidence / applies / exceptions.
   Machine mirror: **[design_rules.json](design_rules.json)** (validated by
   **[design_rule.schema.json](design_rule.schema.json)**).
4. **[topics/](topics/)** — deep-dive per discipline (see below).
5. **[mood_boards/](mood_boards/)** — five **locked style presets** (the unit of
   generation): heritage-badge, vintage-poster, torn-flag-hero, modern-minimal-line,
   passport-stamp.
6. **[reference_collections.md](reference_collections.md)** — what references exist,
   what they teach, and the gaps (disliked bucket is the top priority).
7. **[research_summaries/](research_summaries/)** — the four research streams the
   rules are distilled from.
8. **[engine_recommendations.md](engine_recommendations.md)** — how this KB should
   change recipes, generation, evaluation, scoring, and the optimisation loop.

## Topics
[composition](topics/composition.md) ·
[visual-hierarchy](topics/visual-hierarchy.md) ·
[negative-space](topics/negative-space.md) ·
[colour](topics/colour.md) ·
[typography](topics/typography.md) ·
[texture](topics/texture.md) ·
[print-techniques](topics/print-techniques.md) ·
[apparel-layouts](topics/apparel-layouts.md) ·
[icon-usage](topics/icon-usage.md) ·
[flag-usage](topics/flag-usage.md) ·
[travel-storytelling](topics/travel-storytelling.md) ·
[design-trends](topics/design-trends.md) ·
[merchandising](topics/merchandising.md)

---

## Living catalogue & discovery (Creative Director)
- **[family_catalogue.md](family_catalogue.md)** — the canonical registry of every
  approved design family across all axes (composition · torn · print · primitives).
- **[concepts/](concepts/)** — accepted new-concept dossiers (e.g.
  `C-01-statement-count.md`): description, principles, recipe/procedural/rendering
  requirements, implementation recommendation.
- **[../reports/concept_discovery_roadmap.md](../reports/concept_discovery_roadmap.md)**
  — the ranked pipeline of future concepts to prototype & validate.

## The whole KB in one paragraph
A Roavvy tee turns *where you've been* into a graphic good enough to wear even if it
weren't personalised. It has **one hero**, **few muted derived colours**, **generous
space**, **real personal data honestly shown**, **one coherent style world**, and
**process-emulated texture** (halftones and earned wear, never software filters) —
and it is **printable by construction**. The engine is a designer that has
internalised this: it generates from locked style presets, scores against the 58
rules (with printability a hard gate above all taste), keeps aesthetic quality
weighted above relevance, presents three genuinely-different ideas, and learns a
user's taste only *within* the Design Language.

## How this KB binds to the engine
Every rule names the **genes** it biases (`design_recipe.schema.json`) and the
**scorers** that encode it (analytic: `coverageBalance`, `whitespace`,
`focalHierarchy`, `aspectFit`, `profileFit`; pixel: `contrastLegibility`,
`colorHarmony`, `edgeDensity`; plus `aiCritic`, `printabilityGate`, and a proposed
`referenceAffinity`). The four off-by-default feature flags — `typographyTreatment`,
`paletteEngine`, `motifEngine`, `preferenceReRank` — are the KB's biggest unlocks,
recommended in that order. Nothing here touches the untouchable purchase/print path.

## Provenance & rules of the bench
- Distilled from four parallel research streams (`research_summaries/`) + the
  studio's own reference analysis, deduplicated into 58 rules.
- Principles only — **no copyrighted artwork copied**; reference images are
  dev-only, rights not cleared, never bundled.
- Grounded in the existing spec: `design_engine/grammar/design_grammar.md`,
  `design_engine/config/engine_config.json`,
  `design_engine/docs/capability_matrix.md`,
  `docs/design/ai-tshirt-design-engine.md`.

## Maintenance
- A rule is only "confirmed" when liked references satisfy it at a higher rate than
  disliked ones, and/or chosen designs skew toward it (`design_rule.schema.json`
  `validation`). Until then its `confidence` is the honest prior.
- When `design_language.md` and a specific rule disagree, **the rule wins** (it is
  testable); update the language to match.
- When `design_rules.md` and `design_rules.json` disagree, fix the JSON to match
  the md (md is prose source of truth; JSON is binding source of truth).
- Append rules; don't renumber existing ids (they're referenced by recipes,
  critiques and mood boards).
