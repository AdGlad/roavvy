# M198 — In-app Signature Feed: six heroes, then endless variations

**Phase:** v2 Signature T-shirts (M190–M199)
**Depends on:** M190; M192 approved (can start with 1 approved pack, finishes with 6)
**Status:** Todo
**Primary target:** `packages/design_studio` · `apps/mobile_flutter/lib/features/studio_v2/`
**Size:** L

---

## 1. Why this exists

This is where the six approved recipes reach the user. Opening the T-shirt flow for a country shows the six signature designs at their best (the heroes), then, as the user scrolls, more generated variations that stay inside each recipe's approved ranges, so every one still looks like a deliberate graphic design and none looks random.

## 2. Architecture

```
packages/design_studio/lib/src/
  signature_feed.dart      SignatureFeed(catalog, country, trips, prefs) -> page(i, n) of FeedItem
  feed_item.dart           FeedItem{packId, index, recipe, isHero}
apps/mobile_flutter/lib/features/studio_v2/
  widgets/signature_feed_workspace.dart   the new front door (replaces Instant as entry)
  widgets/feed_tile.dart                  garment mockup tile, lazy render, like + buy
  host/signature_thumbnail_cache.dart     LRU of rendered PNGs keyed by recipeId
```

- **Order.** Page 0 = the 6 heroes in a fixed recipe order (owner can reorder in a constant). After that: round-robin across packs, variation index increasing, so recipes stay mixed. Duplicates are dropped by a quantised-parameter signature. From page 2 on, the existing `PreferenceScorer` re-ranks within each page of 12 (liked designs pull similar variations forward; `DiversitySelector` keeps all six recipes visible). Browsing alone doesn't teach the model (the current Instant rule): only like, customise and buy do.
- **Personalisation.** Country from the selected trip; trip year/date fill the date slots (stamp, crest "EST.", typographic year, poster). Single-country designs only in v2; multi-country is a later milestone.
- **Rendering.** Tiles render at 600×750 on a 2-isolate pool via `RenderService` + `BundleAssetResolver`; prefetch the next 6 off-screen; cancel when scrolled past. Cache in memory (LRU 60) and on disk by `recipeId`. Print files are only rendered at checkout through `production_render.dart`.
- **Flow.** Tap tile → full garment preview with colour picker → Buy (existing `GarmentCartRequest` path) or Customise (existing Studio V2 steps, carrying the exact recipe) or ♥ Save (`PersistentDesignLibrary`). Customise is limited to the recipe's envelope plus text, so a customised design is still a signature design.
- **Gating.** Everything stays behind ADR-180's `commerceEnabled` / `CommerceGate` seam. No new entry points outside `features/commerce_entry/`.

## 3. Tasks

- **T1 SignatureFeed** (pure ordering logic, design_studio) + unit tests: hero page, round-robin, dedupe, determinism, preference re-rank keeps diversity.
- **T2 Thumbnail pipeline**: isolate pool, prefetch, cancellation, LRU + disk cache; benchmark on a physical iPhone (target: first 6 heroes visible < 1.5 s on iPhone 12, scroll at 60 fps with no jank from rendering).
- **T3 Feed workspace UI**: country/trip picker at top, hero row, infinite grid, garment colour toggle, like/save.
- **T4 Detail + buy/customise** wiring to existing review/cart and Studio steps; customise constrained to the envelope.
- **T5 Entry**: Studio V2 opens on the feed (Instant stays reachable only as a dev flag until removed in M199).
- **T6 Tests**: widget tests for hero row, scroll pagination, tap→detail→cart request contents (recipeId, placement `backFull`); parity test: feed recipe renders == Lab goldens.

## 4. Acceptance

- [ ] With all approved packs bundled, a country shows 6 heroes then ≥ 200 distinct variations with no duplicates.
- [ ] Same country + same trip → identical feed order on two devices.
- [ ] Performance targets met on a physical device.
- [ ] Draft packs never appear in a release build.
- [ ] Full suite green in both commerce modes.
