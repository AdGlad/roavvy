# M32 — Mobile Quality & Scan Reward Pass

**Milestone:** 32
**Phase:** 12 — Commerce & Mobile Completion
**Goal:** Address six user-reported UX and correctness issues across the map, journal, stats, and scan flows.

---

## Planner Output

**Goal:** Fix provider staleness after delete+rescan; filter trip photos by date range; make stats counts tappable; add a real-time discovery feed during scanning; show the discovery overlay for every new country; and refresh the map's visual design.

**Scope — included:**
- Map visual refresh: dark ocean background, richer country colour scheme, improved XpLevelBar and StatsStrip styling
- Stats screen: country count, regions count, and achievement count become tappable with drill-down destinations
- Journal stale state: after `clearAll()` and after scan completion, all journal-relevant providers are invalidated so the Journal tab reflects reality without requiring sign-out
- Trip photo filtering: `PhotoGalleryScreen` opened from a trip card shows only photos taken during that trip's date range
- Real-time scan discovery: the Scan tab shows a live "Countries found" list that grows as new countries are first detected during the scan
- Discovery overlay for all new countries: `DiscoveryOverlay` is shown sequentially for every newly discovered country, not just the first one

**Scope — excluded:**
- Map zoom-to-country or continent-level navigation
- Social ranking or soft percentile comparison
- Any web changes

**Risks:**
- Trip photo filtering requires a new `VisitRepository.loadAssetIdsByDateRange()` method and a schema-compatible date comparison; Drift's `isBetweenValues` on the `capturedAt` column is safe — no migration needed
- Sequential discovery overlays with many countries (e.g. first-time scan of 40 countries) must not feel punishing — cap at 5 overlays then jump to summary; include a "Skip all" CTA from the first overlay
- Provider invalidation after `clearAll()` must cover every provider that JournalScreen and StatsScreen watch — use `ref.invalidate` at each call site; a missed provider will still show stale data
- Real-time country detection in `ScanScreen` requires knowing the pre-scan effective visit set so new discoveries can be distinguished from already-visited countries; read `effectiveVisitsProvider` before the scan begins

---

## Task List

| Task | Description | Status |
|---|---|---|
| 105 | Map visual refresh — dark ocean, richer polygon colours, improved XpLevelBar + StatsStrip | 🔲 Not started |
| 106 | Stats screen tappable counts — country count → `CountryListScreen`; regions count → `RegionBreakdownSheet`; achievement count → achievement gallery | 🔲 Not started |
| 107 | Journal stale state fix — invalidate all dependent providers after `clearAll()` and after scan save | 🔲 Not started |
| 108 | Trip photo filtering — `loadAssetIdsByDateRange()` in `VisitRepository`; `PhotoGalleryScreen` accepts date range; trip card opens filtered gallery | 🔲 Not started |
| 109 | Real-time scan discovery feed — `ScanScreen` shows a live "Countries found" list growing as each new country is first detected | 🔲 Not started |
| 110 | Discovery overlay for all new countries — show `DiscoveryOverlay` sequentially for every new country (capped at 5); "Skip all" CTA | 🔲 Not started |

---

### Task 105 — Map visual refresh

**Deliverable:** `lib/features/map/map_screen.dart`, `lib/features/map/country_polygon_layer.dart`, `lib/features/map/map_visual_state.dart`, `lib/widgets/xp_level_bar.dart`, `lib/widgets/stats_strip.dart`

**Changes:**
- `FlutterMap` background colour → `Color(0xFF0D2137)` (dark navy ocean)
- Unvisited country fill → `Color(0xFF1E3A5F)` (dark blue-grey), border → `Color(0xFF2A4F7A)` stroke 0.4
- Visited depth colours shift to richer gold: 1 trip → `Color(0xFFD4A017)`, 2–3 → `Color(0xFFC8860A)`, 4–5 → `Color(0xFFB86A00)`, 6+ → `Color(0xFF8B4500)`; border → `Color(0xFFFFD700)` stroke 0.8
- `newlyDiscovered` pulse: `Color(0xFFFFD700)` (bright gold) with existing 1200ms fade; border stroke 1.5
- `target` state (1-away) border → `Color(0xFFFF8C00)` stroke 1.2; breathing fill `Color(0xFFFF8C00).withOpacity(0.15–0.30)`
- `XpLevelBar`: `Color(0xFF0D2137)` background with 0.85 opacity blur overlay (use `BackdropFilter`); level badge → gold fill; progress bar → `Color(0xFFFFD700)` on `Color(0xFF1E3A5F)` track
- `StatsStrip`: same dark glass treatment; country/trip/year text in white with amber accent on the values

**Acceptance criteria:**
1. Ocean (non-country) areas are dark navy `#0D2137`.
2. Unvisited countries are visually distinct from the ocean but clearly unvisited (dark blue-grey, no gold).
3. Visited countries display 4-tier gold gradient; more trips = deeper gold.
4. Newly discovered countries pulse gold, not amber.
5. XpLevelBar and StatsStrip use dark glass treatment and remain legible in both bright and dark environments.
6. `flutter analyze` zero issues; all existing polygon layer tests pass.

---

### Task 106 — Stats screen tappable counts

**Deliverables:**
- `lib/features/stats/stats_screen.dart`
- `lib/features/stats/country_list_screen.dart` (new)
- `lib/features/stats/region_breakdown_sheet.dart` (new)

**Changes:**
- Countries count tile → `InkWell`; tap navigates to new `CountryListScreen`: flat list of all visited countries sorted alphabetically (flag emoji + name + trip count); each row taps to open `CountryDetailSheet`
- Regions count tile → `InkWell`; tap opens `RegionBreakdownSheet`: `DraggableScrollableSheet`; grouped list of countries → their detected regions (e.g. "France — Île-de-France, Provence, Normandy"); reads from `RegionRepository.loadAll()` grouped by `countryCode`
- Achievement count tile → `InkWell`; tap scrolls to the achievement gallery section already present in `StatsScreen` (use a `ScrollController` and `Scrollable.ensureVisible`)

**Acceptance criteria:**
1. Tapping the countries count navigates to `CountryListScreen` showing all visited countries with trip counts.
2. Each country row in `CountryListScreen` opens the existing `CountryDetailSheet`.
3. Tapping the regions count opens `RegionBreakdownSheet` grouped by country.
4. Tapping the achievement count scrolls to the achievement gallery.
5. All three tiles have a visible `InkWell` ripple and a trailing chevron `>` to signal tappability.
6. Empty states handled: "No countries yet — scan your photos!" / "No regions detected yet."
7. `flutter analyze` zero issues.

---

### Task 107 — Journal stale state fix

**Deliverable:** `lib/features/map/map_screen.dart`, `lib/features/scan/scan_screen.dart`

**Root cause:** After `clearAll()`, only `effectiveVisitsProvider` and `travelSummaryProvider` are invalidated. `JournalScreen` likely watches a derived trips provider that is not invalidated. After rescan, `ScanScreen` calls `ref.invalidate(effectiveVisitsProvider)` but not the trips or region providers that back the Journal tab.

**Changes:**
- Audit every `ref.watch` call in `JournalScreen` and `StatsScreen`; list all providers they depend on
- After `clearAll()` in `map_screen.dart`: add `ref.invalidate()` for every provider identified above (trips, region visits, XP events, recent discoveries, milestone repository, year filter)
- After scan save in `scan_screen.dart`: apply the same full invalidation list
- If `JournalScreen` reads from `TripRepository` directly via a `FutureProvider` that caches results, ensure that provider is in the invalidation list or switch it to `ref.watch` a version counter that increments on mutations

**Acceptance criteria:**
1. Delete all travel records → immediately re-scan → Journal tab shows new trips without signing out.
2. Journal shows "Scan your photos to start your travel journal" empty state immediately after delete (not stale trips from previous scan).
3. Stats screen counts update to reflect the new scan without sign-out.
4. No regression: Journal still populates correctly on a normal scan with no prior delete.
5. `flutter analyze` zero issues.

---

### Task 108 — Trip photo filtering

**Deliverable:** `lib/data/visit_repository.dart`, `lib/features/map/photo_gallery_screen.dart`, `lib/features/map/country_detail_sheet.dart`

**Changes:**
- Add `Future<List<String>> loadAssetIdsByDateRange(String countryCode, DateTime start, DateTime end)` to `VisitRepository`: same query as `loadAssetIds` but with additional `WHERE capturedAt >= start AND capturedAt <= end` using Drift's `isBetweenValues`
- `PhotoGalleryScreen`: add optional `DateTime? startDate` and `DateTime? endDate` named parameters; when both are present, call `loadAssetIdsByDateRange` instead of `loadAssetIds`; update title to reflect e.g. "France — Mar 2022"
- `CountryDetailSheet` trip card "Photos" tab or trip row tap: pass the trip's `startedOn` and `endedOn` to `PhotoGalleryScreen`

**Acceptance criteria:**
1. Opening the photo tab from a trip card shows only photos with `capturedAt` between `trip.startedOn` and `trip.endedOn` (inclusive, using start-of-day / end-of-day boundaries).
2. The photo count displayed on the trip card matches the number of photos shown in the gallery.
3. Opening the country-level Photos tab (not from a specific trip) still shows all country photos.
4. Empty state: "No photos found for this trip" if no asset IDs in range.
5. `flutter analyze` zero issues; `loadAssetIdsByDateRange` has a unit test covering a date-range boundary case.

---

### Task 109 — Real-time scan discovery feed

**Deliverable:** `lib/features/scan/scan_screen.dart`

**Changes:**
- Before the scan loop starts, read the current effective visit codes into a `Set<String> _preExistingCodes`
- Add `List<String> _newlyFoundCodes = []` to `_ScanScreenState`
- In the scan batch loop: after updating `accum`, compute `Set<String> currentCodes = accum.keys.toSet()`; for each code in `currentCodes` not in `_preExistingCodes` and not already in `_newlyFoundCodes`, add it and call `setState`
- UI: below the progress counter, add a `ListView` (or `Column` if short) labelled "Countries found this scan"; each entry shows `[flag emoji] [country name]` appearing with a `SlideTransition` + `FadeTransition` from bottom; entries are prepended (newest first)
- If `_newlyFoundCodes` is empty at the time an entry would be added, the section appears for the first time with the first country

**Acceptance criteria:**
1. During a scan, as each new (previously-unvisited) country is first detected, it appears in a "Countries found" list on the scan screen within one batch cycle.
2. Countries already visited before the scan do not appear in the list.
3. Each new entry animates in (slide + fade, respects `reduceMotion`).
4. The list is visible while scanning is in progress; it does not disappear when the scan completes (it stays until the user navigates to the review screen).
5. If no new countries are found, the section does not appear.
6. `flutter analyze` zero issues.

---

### Task 110 — Discovery overlay for all new countries

**Deliverable:** `lib/features/scan/scan_summary_screen.dart`, `lib/features/map/discovery_overlay.dart`

**Changes:**
- `DiscoveryOverlay`: add optional `int totalCount` and `int currentIndex` parameters; when `totalCount > 1`, show "Country N of M" subtitle below the flag; "Explore your map" CTA becomes "Next →" for all but the last overlay, then "Done" on the last; also add a "Skip all →" `TextButton` on every overlay
- `ScanSummaryScreen._handleDone()`: instead of pushing one `DiscoveryOverlay`, iterate over `widget.newCodes` (capped at 5); push them sequentially, waiting for each to pop before pushing the next; after all overlays (or after Skip all), register all codes with `recentDiscoveriesProvider` and proceed normally
- "Skip all" pops back to `ScanSummaryScreen` immediately and registers all codes

**Acceptance criteria:**
1. If 1 new country: behaviour unchanged — one overlay, "Done" CTA.
2. If 2–5 new countries: overlays shown one-by-one with "Country N of M" label and "Next →" / "Done" CTA.
3. If 6+ new countries: first 5 shown with "Country 1 of 6+" label; after the 5th, proceed directly to summary (all codes still registered).
4. "Skip all" visible from overlay 1 onwards; tapping it exits all overlays and registers all codes.
5. Back button on any overlay skips remaining overlays (same as "Skip all").
6. All new countries are registered with `recentDiscoveriesProvider` regardless of whether the user tapped through or skipped.
7. `flutter analyze` zero issues.
