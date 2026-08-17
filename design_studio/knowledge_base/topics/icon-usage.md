# Topic: Icon & Motif Usage

**What it governs:** silhouettes, landmarks and symbols layered into a design.
Maps to `motifs[]` (`kind`: animal/plant/landmark/symbol, `slug`, `countryCode`)
and `clip.shape` silhouettes. The `motifEngine` flag is **off** — highest clutter
risk, so save it for last.

## Principles
- **One consistent icon style/stroke** — same line-vs-solid, stroke weight, corner
  radius, detail level. A mismatched icon destroys the single-author gestalt.
  (R-ICON-01)
- **A single strong icon beats an illustration crowd** — simple silhouettes survive
  distance, wrinkle and small print; detailed scenes lose their detail exactly
  where apparel is viewed. (R-ICON-02)
- **Flat, simplified shapes; no photorealism/bevel/gloss** — simplification is the
  editorial labour that reads as authored. (R-ICON-03)
- **Country/landmark silhouettes must be recognizable and geographically accurate**
  — recognition ("that's MY country") is the emotional payload; test at thumbnail.
  (R-ICON-04)

## Rules in this topic
R-ICON-01 … R-ICON-04 (supports R-VH-01, R-STORY-01/05).

## Scorers
`edgeDensity` (style consistency / busyness), `focalHierarchy` (one hero motif),
`profileFit` (motif relevance to the wearer's places). Silhouette recognizability
is a candidate for the AI critic / `referenceAffinity`.

## Engine implication
When `motifEngine` turns on, enforce the strongest guards first: **one hero motif
max**, **consistent stroke family**, and **motif must not fight the focal element**
(R-VH-01). Resolve motifs only against bundled, rights-cleared silhouette/landmark
assets; require geographic accuracy for outlines (`clip.code` must resolve). This
is the highest-clutter gene, so it ships last and needs the tightest priors — see
`engine_recommendations.md` §6.
