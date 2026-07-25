# M181 — Living Scan: Real Photos in the Discovery Feed

**Status:** `done`
**Created:** 2026-07-25
**Updated:** 2026-07-25
**Depends on:** none (foundation for M184, M186)
**Program:** Living Scan (M181–M186)

---

## Product Rationale

The scan today tells you *that* you visited a country (a gold shape, a flag
emoji, a photo count) but never *shows* you the place. The single biggest
emotional gap in the whole flow is the absence of the user's own photos.

This milestone puts a real, representative photo of each newly discovered
country into the experience — the discovery feed chip becomes a **postcard**,
and the first-country cinematic uses the actual photo as its backdrop. This is
the foundation the rest of the Living Scan program builds on.

Privacy is unaffected: photo bytes never leave the device. Thumbnails are
decoded on demand from the local `PHAsset` via the existing `ThumbnailChannel`
/ `HeroImageView` path (ADR-135).

---

## Scope

### Delivered
- Each `_DiscoveryEntry` carries a representative `assetId` chosen live during
  the scan (first geotagged photo for that country in the current run).
- Discovery feed chip (`_DiscoveryChip`) shows a small rounded thumbnail in
  place of / beside the flag emoji once loaded; flag emoji is the fallback.
- First-country cinematic (`_FirstCountryCinematic`) uses the country's photo
  as a full-bleed backdrop behind the "Welcome to your world" copy.
- Graceful fallback everywhere: iCloud-only / deleted / permission-failed
  photos fall back to the existing flag + gold tile (already handled by
  `HeroImageView`).
- Thumbnail load is throttled/capped so it never slows the scan itself.

### Out of scope
- Hero-quality selection during scan (heroes are scored post-scan — M186 swaps
  the first-glimpse photo for the polished hero once available).
- Ambient montage layer (M184).
- Heat map (M182).

---

## UX Design

- **Postcard chip:** the 40px feed row gains a leading ~28×28 rounded thumbnail
  (BoxFit.cover) with a subtle border. Flag emoji shown while loading and on
  failure. The newest row keeps its primary accent bar.
- **First-country cinematic:** photo backdrop at ~0.85 opacity with a dark
  scrim so the white headline stays legible; flag + country name overlaid.
- **Reduce-motion:** no animation change needed; images render statically.
- **Sparse library:** below a threshold (e.g. <3 countries) behaviour is
  identical to today — a single postcard still looks intentional.

## Architecture

- Extend `_DiscoveryEntry` with `String? representativeAssetId`.
- In `_scan()` batch loop (`scan_screen.dart`), when a new country is first
  added to `_liveNewEntries`, capture the `assetId` of the first
  `PhotoDateRecord` for that code in the batch (records already carry
  `assetId`). Do not overwrite once set.
- Reuse `HeroImageView` (or a lighter `_Thumbnail` wrapper) with a small
  `ThumbnailSize.square(96)` for feed chips to keep decode cost low.
- **Concurrency cap:** load at most N (e.g. 3) thumbnails concurrently via a
  simple queue so PhotoKit I/O does not contend with the scan isolate. One
  thumbnail per country, not per photo.
- The **overlay scan surface** (`globeOverlayProvider.showScan`, M134) is the
  primary path from the Map action bar — thread the representative `assetId`
  into `CountryDiscoveredEvent` (or a sibling field on `LiveScanReplayDataSource`)
  so the overlay feed can render postcards too, not just the in-screen
  `_ScanningView`.

---

## Tasks

- T1 — Add `representativeAssetId` to `_DiscoveryEntry`; populate live in the
  batch loop from the first `PhotoDateRecord.assetId` per new code.
- T2 — Build a lightweight throttled thumbnail widget/queue (cap concurrency,
  96px, flag/colour fallback).
- T3 — Render thumbnail in `_DiscoveryChip`; flag emoji as loading/fallback.
- T4 — Photo backdrop + scrim in `_FirstCountryCinematic`.
- T5 — Thread `assetId` into `CountryDiscoveredEvent` / live source so the
  M134 overlay feed renders postcards.
- T6 — Widget tests: chip shows fallback when assetId null; cinematic renders
  with and without a photo; concurrency cap respected.
- T7 — `flutter analyze` clean; manual QA on a real device with an iCloud-only
  photo to confirm fallback.

## Definition of Done
- [ ] Discovery feed shows real photo thumbnails for discovered countries.
- [ ] First-country cinematic uses the photo backdrop with legible copy.
- [ ] iCloud-only / failed loads fall back to flag + gold tile, no jank.
- [ ] No measurable increase in scan wall-clock time (thumbnail load capped).
- [ ] Works on both the M134 overlay surface and the in-screen `_ScanningView`.
- [ ] `flutter analyze` no new issues; widget tests pass.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Thumbnail decode slows scan | Medium | High | Concurrency cap, small size, one/country |
| iCloud photos fail to load | High | Low | Flag/colour fallback already exists |
| Memory pressure from many decoded thumbnails | Low | Medium | Small size + `gaplessPlayback`; evict off-screen |
