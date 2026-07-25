# M186 — Living Scan: Hero Reuse & Narrative Beats

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** M181 (photo threading), M183 (year/phase pacing hooks)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

Two kinds of polish that turn the scan from a slideshow into a *story*:

1. **Reuse the heroes we already have.** On a re-scan (the common incremental
   case), curated hero images already exist in Drift for prior trips. Using them
   immediately gives returning users the polished imagery instantly instead of a
   raw first-glimpse — and once background hero analysis finishes, the
   first-glimpse photo can upgrade to the best shot in place.
2. **Narrative beats.** The scan already emits `YearStartedEvent` and detects
   heritage sites live. Surfacing these as tasteful title cards ("2018 ✈️") and
   landmark name-drops ("You've been to the Colosseum") makes the scan feel like
   a recap of the user's life, not a file crawl.

---

## Scope

### Delivered
- **Hero reuse on re-scan:** representative imagery (postcards/montage) prefers
  an existing rank-1 `HeroImage` for the country/trip when one exists, before
  falling back to a live first-glimpse photo.
- **Hero upgrade swap:** when post-scan hero analysis completes, the displayed
  country image transitions from first-glimpse to the scored hero (subtle
  crossfade) if the summary/scan surface is still visible.
- **Year chapter cards:** brief title card when the scan crosses into a new
  travel year, driven by existing `YearStartedEvent`.
- **Landmark name-drops:** a tasteful ribbon over a heritage site's photo when a
  UNESCO site is first detected (from the live heritage accumulator).

### Out of scope
- Changing the hero scoring algorithm (M89 pipeline unchanged).
- New share/export surfaces.

---

## UX Design

- **Hero source order:** existing rank-1 hero → live first-glimpse → flag/colour.
- **Upgrade swap:** ~400ms crossfade; only if the same country card is on
  screen; never yanks focus.
- **Year card:** low-key centered "2018" with a small plane glyph, ~1.2s, fades;
  suppressed under reduce-motion (instant text).
- **Landmark ribbon:** reuse the `_HeritageTooltip` visual language; auto-dismiss;
  photo backdrop when the site's photo is available.

## Architecture

- Query heroes via existing `HeroImageRepository` / `heroForTripProvider` /
  `bestHeroForCountryProvider` — no new persistence. On re-scan the pre-scan
  hero rows are already loaded; expose a `heroAssetIdFor(countryCode)` lookup to
  the scan surfaces.
- Upgrade swap: the summary already uses `bestHeroFromScanProvider`; extend the
  live surfaces to watch `heroForTripProvider` for the discovered trips and swap
  the image when a non-null hero arrives.
- Year cards + landmark ribbons: consume the events already emitted into
  `LiveScanReplayDataSource` (`YearStartedEvent`, `HeritageSiteDiscoveredEvent`)
  on the M134 overlay; add equivalents to the in-screen `_ScanningView`.

## Tasks
- T1 — `heroAssetIdFor(countryCode)` lookup; prefer existing hero over
  first-glimpse in postcards/montage on re-scan.
- T2 — Post-scan hero-upgrade crossfade on visible country cards.
- T3 — Year chapter card driven by `YearStartedEvent` (overlay + in-screen).
- T4 — Landmark name-drop ribbon from `HeritageSiteDiscoveredEvent`, with photo
  backdrop when available.
- T5 — Reduce-motion variants for all beats.
- T6 — Tests: hero preferred on re-scan; upgrade swap fires on hero arrival;
  year card + ribbon render and dismiss.
- T7 — `flutter analyze` clean; device QA on a re-scan with existing heroes.

## Definition of Done
- [ ] Re-scan shows existing curated heroes immediately.
- [ ] First-glimpse images upgrade to scored heroes when analysis completes.
- [ ] Year chapter cards appear on year transitions.
- [ ] Landmark name-drops appear for newly detected heritage sites.
- [ ] All beats have reduce-motion variants.
- [ ] `flutter analyze` no new issues; tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Upgrade swap flickers or fights postcard load | Medium | Medium | Only swap on stable non-null hero; single crossfade |
| Too many beats feel busy | Medium | Medium | Rate-limit; design QA; cap year cards/ribbons per scan |
| Heritage photo unavailable | Medium | Low | Ribbon renders on plain scrim without a photo |
