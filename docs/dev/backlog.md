# Backlog — Future Milestones

---

## Phase Completion Status (as of 2026-03-19)

| Phase | Description | Status |
|---|---|---|
| Phase 1 — Core Scan & Map | PhotoKit bridge, country_lookup, Drift DB, map, scan, manual edits | ✅ **Complete** |
| Phase 2 — Sync & Achievements | Firebase Auth (anon + Apple), Firestore sync, achievement engine + UI, account deletion | ✅ **Complete** |
| Phase 3 — Sharing | Travel card image, web share page `/share/[token]`, share sheet, token revocation | ✅ **Complete** |
| Phase 4 — Web Map | Authenticated web map (`/sign-in`, `/map`) | ✅ **M13 complete** — sign-up (M14) deferred |
| Phase 5 — Trip Intelligence | Trip inference, trip storage, trip editing | ✅ **Complete (M15)** |
| Phase 6 — Geographic Depth | Region detection (ISO 3166-2) | 🔄 **Slice 1 complete (M16)** — city detection + continent overlay deferred |
| Phase 7 — Rich Mobile Experience | 4-tab shell, Journal, Stats + achievement gallery | ✅ **Complete (M17)** |
| Phase 8 — Celebrations & Delight | Onboarding, new-country celebration, achievement animation, scan summary | ✅ **Complete (M18)** |
| Phase 9 — App Store Readiness | Icon, screenshots, push notifications, iPad layout, referral CTA | 🔄 **M19 complete** — icon assets + App Store URL pending external deliverables |
| Phase 9.5 — Quality & Depth | Trip inference fix, region detection fix, confetti fix, interactive navigation, photo gallery | ✅ **M19A complete** |
| Phase 10 — Commerce | Shopify Storefront API, travel poster, shop landing page | 🔲 Not started |

See [docs/product/roadmap.md](../product/roadmap.md) for full phase definitions.
See [docs/ux/mobile_ux_spec.md](../ux/mobile_ux_spec.md) for the mobile UX specification.

### Phase 2 — remaining gap (absorbed into Phase 8)
- Achievement unlock animation — deferred; now planned as part of Phase 8 Celebrations.

### Phase 3 — no remaining gaps
All sharing features are complete as of M12.

---

## Milestone 12 — Phase 2/3 Closeout ✅ COMPLETE (2026-03-17)

**Goal:** Close the remaining Phase 2 and Phase 3 gaps before starting Phase 4.

**Delivered:**
- Task 31: Share token revocation — `PrivacyAccountScreen`, `ShareTokenService.revokeToken`, Firestore delete rule fix
- Task 32: Account deletion — `AccountDeletionService`, two-confirmation dialog flow, auth + Firestore + local data purge

---

## Milestone 13 — Phase 4: Authenticated Web Map ✅ COMPLETE (2026-03-19)

**Goal:** Signed-in users can open `roavvy.app/map` in a browser, sign in with the same Firebase account used on their phone, and see their live travel map.

**Why this comes first:** Phase 4's commercial goal (selling merchandise personalised with the user's travel data) requires a web-authenticated map as the foundation. The shop must read the user's country set from Firestore — which requires the user to be signed in on web.

**Scope — included:**
- Sign-in page (`/sign-in`): Firebase Auth JS SDK; Sign in with Google (primary) and Sign in with Apple (secondary); anonymous accounts cannot sign in here (no anonymous session on web)
- `/map` route: authenticated guard (redirect to `/sign-in` if not signed in); reads `users/{uid}/inferred_visits`, `user_added`, `user_removed` from Firestore; computes effective visited countries client-side; renders world map with Leaflet + existing `DynamicMap`/`Map` components
- Sign-out action on `/map` page
- Updated Firestore rules: allow read of `users/{uid}/...` subcollections only by matching `request.auth.uid == uid`
- Loading and error states on `/map`

**Scope — excluded:**
- Shopify integration (Milestone 14)
- Country editing on web (mobile-only for now)
- Multi-device conflict resolution (deferred indefinitely)

**Technical notes:**
- The web app already has Firebase SDK wired (`apps/web_nextjs/`), Leaflet, and the `DynamicMap`/`Map` components from Task 30. The map rendering can be reused directly.
- The effective visited countries computation (inferred − removed + added) must be reimplemented in TypeScript — this is the only non-trivial logic. Keep it simple: load all three subcollections, apply the merge rules.
- Google Sign-In is easier to implement on web than Apple (no nonce/callback complexity). Start with Google; add Apple if needed.
- Firestore rules for `users/{uid}` subcollections currently have no explicit read rule — the wildcard `allow read, write` is too broad; this milestone tightens them.

**Delivered:** `/sign-in` (Google + Apple), `/map` authenticated route, effective-visits merge in TypeScript, Firestore rules tightened, loading + error states.

---

## Milestone 14 — Phase 4: Web Sign-Up

**Goal:** Users can create a Roavvy account on the web with email/password, completing the web auth flow.

**Scope — included:**
- `/sign-up` page: email + password fields; Firebase `createUserWithEmailAndPassword`; validation (email format, password min 8 chars); on success → redirect to `/map`
- Error states: "email already in use", "weak password", "network error"
- Link from `/sign-in` → "Don't have an account? Sign up"
- Link from `/sign-up` → "Already have an account? Sign in"

**Scope — excluded:**
- Email verification (deferred)
- Password reset (deferred)
- Social sign-in on web

**Not started. No tasks written yet.**

---

## Milestone 15 — Phase 5: Trip Intelligence (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** Every country visit becomes a set of named trips with inferred dates. Users see trip counts on the map and a chronological trip list per country.

**Scope — included:**
- `TripRecord` domain model in `shared_models`: `id`, `countryCode`, `startedOn`, `endedOn`, `photoCount`
- Trip inference engine: clusters `InferredCountryVisit` photo records by country + 30-day gap; produces `TripRecord` list
- Drift `trips` table (schema v4): stores inferred trips; `isDirty`/`syncedAt` columns
- `TripRepository`: upsert, load by country, load all, clear
- Trip count shown on country detail sheet ("X trips")
- Trips list in country detail (date cards)
- Manual trip: add / edit dates / delete
- Firestore sync: push trip records to `users/{uid}/trips/{tripId}`

**Scope — excluded:**
- Photo gallery (Phase 7)
- Region/city detection (Milestone 16)
- Journal tab (Milestone 17)

**Delivered:** `TripRecord` + `TripInference` in `shared_models`; `trips` Drift table (schema v5); `TripRepository`; `TripEditSheet`; `BootstrapService` back-fills trips from existing scan data.

---

## Milestone 16 — Phase 6 Slice 1: Region Detection (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** After a photo scan, users see which regions (admin1) they visited within each country — resolved entirely offline.

**Scope — included:**
- `packages/region_lookup`: offline ISO 3166-2 admin1 polygon lookup
- Schema v7: `PhotoDateRecord.regionCode` column; scan pipeline resolves region codes in background isolate
- `RegionVisit` domain model + `region_visits` Drift table + `RegionRepository`
- Scan pipeline + bootstrap produce `RegionVisit` records
- Region count + region list in country detail sheet

**Scope — excluded (deferred to future milestones):**
- City detection (`packages/city_lookup`)
- Continent overlay on world map
- Region-level achievements
- Firestore sync for region_visits
- User-edit override for regions

**Offline constraint:** All geodata bundled. Zero network calls.

**Delivered:** `packages/region_lookup` (offline admin1 binary, 3.5 MB); `RegionVisit` + `region_visits` Drift table (schema v7); `RegionRepository`; scan pipeline resolves region codes; `BootstrapService` back-fills region visits; region count + expandable list in `CountryDetailSheet`. Tasks 42–46.

---

## Milestone 17 — Phase 7: Navigation Redesign & Rich Screens (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** 4-tab navigation. Journal tab lists all trips. Stats tab shows comprehensive stats + achievement gallery.

**Scope — included:**
- Navigation: 4-tab bottom bar (Map · Journal · Stats · Scan) replacing current 2-tab
- Map screen: visit-frequency colour gradient; stats strip updated (countries · continents · trips); continent labels at world zoom
- Country Detail: full-screen push (replaces bottom sheet); tabs: Overview · Trips · Regions · Photos
- Trip Detail: full-screen push; mini-map; regions; cities; photo grid
- Journal tab: chronological all-trips list; grouped by year; filter sheet
- Stats tab: stats panel (countries, continents, trips, years, longest trip); continent breakdown tiles; achievements gallery (locked + unlocked); per-year bar chart
- Photo grid (on-device via PhotoKit local identifiers stored during scan)
- Country share card (flag + trip count + top regions)
- Achievement share card (badge + title + unlock date)

**Delivered:** 4-tab `NavigationBar` + `IndexedStack` in `MainShell` (ADR-052); `JournalScreen` (trip list grouped by year, country flags, taps open CountryDetailSheet); `StatsScreen` (stats panel + achievement gallery grid, unlocked-first sort, amber trophy / grey lock icons); `AchievementRepository.loadAllRows()`; `regionCountProvider`. Tasks 47–49. 291 flutter tests passing.

---

## Milestone 18 — Phase 8: Celebrations & Delight (Mobile) ✅ COMPLETE (2026-03-19)

**Goal:** The app celebrates milestones. First use is magical.

**Delivered:**
- Task 50: `OnboardingFlow` (3-screen PageView: Welcome · Privacy · Ready); `_OnboardingGate` in `app.dart`; schema v8 `hasSeenOnboardingAt`; `onboardingCompleteProvider` with returning-user bypass (ADR-053)
- Task 51: `ScanSummaryScreen` (State A: new discoveries with country list + achievement chips; State B: nothing-new); `ReviewScreen` computes pre/post-save delta and pushes summary; double-pop `_handleSummaryDone` (ADR-054)
- Task 52: confetti animation via `confetti ^0.7.0`; row stagger animations (80ms, capped at row 7); all animations gated on `MediaQuery.disableAnimationsOf` (ADR-055)
- Task 53: `AchievementUnlockSheet` modal bottom sheet; share via `share_plus`; wired from scan summary chips and stats gallery; SnackBar removed from review-save path

327 flutter tests passing.

---

## Milestone 19 — Phase 9: App Store Readiness ✅ COMPLETE (2026-03-19)

**Goal:** App is ready for public App Store submission.

**Delivered:**
- Task 58: `TARGETED_DEVICE_FAMILY = "1"` in all 3 Xcode build configs; `CFBundleDisplayName`/`CFBundleName` → "Roavvy"; iPad orientation block removed (ADR-057)
- Task 55: Static `/privacy` page in Next.js app; "Legal" section in `PrivacyAccountScreen` links to it via `url_launcher`
- Task 57: `NotificationService` singleton (`lib/core/notification_service.dart`); `scheduleAchievementUnlock` + `scheduleNudge` (30-day `zonedSchedule`); `pendingTabIndex` `ValueNotifier`; permission prompt after first new-country scan; `MainShell` cold-start + in-session tap routing (ADR-056); `timezone` + `flutter_local_notifications` added to pubspec
- Task 56: "Get Roavvy" CTA on `/share/[token]` with App Store badge; `APP_STORE_URL` constant with TODO placeholder
- Task 54: `REPLACE_WITH_FINAL_ICON.md` placeholder in `AppIcon.appiconset` with icon generation instructions

**Pending external deliverables (not code):**
- 1024×1024 PNG icon from designer → replace placeholder PNGs
- App Store Connect listing → replace `id0000000000` in `APP_STORE_URL`
- Official Apple App Store badge SVG from developer.apple.com/app-store/marketing/guidelines/
- APNs key setup in Firebase Console (for production push delivery)
- App Store screenshots and metadata

333 flutter tests passing.

---

## Milestone 19A — Phase 9.5: Quality & Depth ✅ COMPLETE (2026-03-19)

**Goal:** Fix incorrect trip and region detection; restore confetti celebration; make every country, achievement, and trip tappable to a detail screen; add on-device photo gallery per country and trip.

**Delivered:**

- Task 59: Trip inference — geographic sequence model (replaced 30-day gap; sort all records by date, run-length encode by country code)
- Task 60: Region detection — coverage gaps diagnosed and fixed
- Task 61: Confetti — post-scan celebration flow restored
- Task 62: Interactive navigation — Stats screen tap-through to country list + achievement detail
- Task 63: Privacy model — `asset_id` TEXT column on `photo_date_records` (schema v9); `VisitRepository.loadAssetIds()`
- Task 64: Photo gallery — `PhotoGalleryScreen` (3-column grid, `photo_manager ^3.0.0`, `ThumbnailFetcher` typedef ADR-061); `CountryDetailSheet` 2-tab layout (Details / Photos)

---

## Milestone 20 — Phase 10: Shop & Merchandise

**Goal:** Users can buy personalised travel merchandise (a travel poster with their visited countries highlighted) via a Shopify-hosted checkout.

**Why:** This is the primary revenue stream. The product is differentiated: a physical travel poster that reflects the user's actual travel history, not a generic map.

**Scope — included:**
- Shop landing page (`/shop`): accessible without sign-in; shows featured products
- Product personalisation flow: user signs in (or is already signed in from `/map`), their visited country codes are loaded, the map is rendered as an SVG/PNG preview
- Shopify Storefront API integration: product catalogue, add to cart, redirect to Shopify checkout
- Travel poster asset generation: render the Leaflet map to an image (canvas export); attach to the Shopify line item as a custom property (`visitedCodes` array) for fulfilment
- In-app [Buy a travel poster] CTA on Stats screen and travel card share flow

**Scope — excluded:**
- Shopify admin / product management (done manually by the business)
- Custom fulfilment automation (deferred — initially handled manually)
- Physical print quality rendering (the web map is the preview; actual print files are separate)

**Technical risks:**
1. **Shopify Storefront API**: requires a Shopify store and a private app token. Setup is a prerequisite.
2. **Map-to-image export**: Leaflet renders to a `<canvas>` — `canvas.toDataURL()` gives a PNG. Custom layers (polygons) must be on canvas, not SVG. May need to switch from the current SVG-based GeoJSON layer to a canvas layer. Needs a spike.
3. **Passing the country set to Shopify**: Storefront API allows line item custom attributes. The `visitedCodes` array goes in there. Fulfilment system reads it to generate the custom print file.

**Not started. No tasks written yet.**

---

## Milestone 14 — Phase 4: Shop & Merchandise [SUPERSEDED — see Milestone 20]

**Goal:** Users can buy personalised travel merchandise (a travel poster with their visited countries highlighted) via a Shopify-hosted checkout.

**Why:** This is the primary revenue stream. The product is differentiated: a physical travel poster that reflects the user's actual travel history, not a generic map.

**Scope — included:**
- Shop landing page (`/shop`): accessible without sign-in; shows featured products
- Product personalisation flow: user signs in (or is already signed in from `/map`), their visited country codes are loaded, the map is rendered as an SVG/PNG preview
- Shopify Storefront API integration: product catalogue, add to cart, redirect to Shopify checkout
- Travel poster asset generation: render the Leaflet map to an image (canvas export); attach to the Shopify line item as a custom property (`visitedCodes` array) for fulfilment

**Scope — excluded:**
- Shopify admin / product management (done manually by the business)
- Custom fulfilment automation (deferred — initially handled manually)
- Physical print quality rendering (the web map is the preview; actual print files are separate)

**Technical risks:**
1. **Shopify Storefront API**: requires a Shopify store and a private app token. Setup is a prerequisite.
2. **Map-to-image export**: Leaflet renders to a `<canvas>` — `canvas.toDataURL()` gives a PNG. Custom layers (polygons) must be on canvas, not SVG. May need to switch from the current SVG-based GeoJSON layer to a canvas layer. Needs a spike.
3. **Passing the country set to Shopify**: Storefront API allows line item custom attributes. The `visitedCodes` array goes in there. Fulfilment system reads it to generate the custom print file.

**Not started. No tasks written yet.**

---

## Milestone 15 — Phase 5: Trip Intelligence [see new M15 above]

> This entry superseded. Phase 5 is now Trip Intelligence (mobile). See Milestone 15 above.
> Old Phase 5 (Polish & App Store Readiness) is now Milestones 18 and 19.

---

---

## Milestone 22 — Phase 11 Slice 1: Visual States + XP Foundation

**Goal:** The map visually encodes progress. Every visited country looks different from unvisited. XP is tracked. New country discovery has a proper emotional moment.

**Why this slice first:** Maximum emotional impact with minimum new infrastructure. The visual state system and XP engine are the foundation everything else in Phase 11 builds on.

**Scope — included:**
- `CountryVisualState` enum + `countryVisualStateProvider` (derives state from effective visits + recency)
- `CountryPolygonLayer` widget — replaces current `PolygonLayer` call; applies fill/border/opacity per state
- `recentDiscoveriesProvider` — tracks ISO codes discovered in last 24h (persisted to SharedPreferences)
- `XpEvent` domain model + Drift `xp_events` table + `XpRepository`
- `XpNotifier` (StateNotifier) — computes total XP, current level (8 thresholds), progress to next level
- `XpLevelBar` widget — map top strip: level badge, label, progress bar; "+N XP" animation on earn
- `DiscoveryOverlay` — full-screen route shown when a new country is added post-scan; country name, flag, XP earned, "Explore your map" CTA; haptic feedback (HeavyImpact)
- XP award rules wired into existing write sites: new country (+50 XP), region completed (+150 XP), scan completed (+25 XP), share (+30 XP)
- 5 country visual states rendered correctly on real device with ≥ 50 country dataset
- `flutter analyze` zero issues
- Unit tests: `XpNotifier` level computation; `countryVisualStateProvider` state derivation; `XpRepository` insert + query

**Scope — excluded:**
- Region progress chips (Slice 2)
- Rovy mascot (Slice 2)
- Social ranking (Slice 3)
- Discovery overlay animation refinement (basic first, polish later)

**Tasks:**

| Task | Description |
|---|---|
| 81 | `CountryVisualState` enum + `countryVisualStateProvider` + `recentDiscoveriesProvider` |
| 82 | `CountryPolygonLayer` — replaces polygon rendering; 5 visual states with correct fill/border/animation |
| 83 | `XpEvent` + `xp_events` Drift table + `XpRepository` + `XpNotifier` (levels + progress) |
| 84 | `XpLevelBar` widget (top strip on MapScreen) + XP award wired into write sites |
| 85 | `DiscoveryOverlay` full-screen route — new country moment with haptic + XP display |

**Technical risks:**

1. **Polygon re-rendering performance with 5 visual states** — profile on a 50+ country dataset. Split into separate `PolygonLayer` instances per state group (static vs. animated) to avoid forcing a full rebuild on each animation tick. Newly-discovered polygons (animated) are in their own `PolygonLayer`; unvisited/visited/reviewed (static) are in another. Profile on device before shipping Task 82.
2. **`recentDiscoveriesProvider` persistence** — use SharedPreferences (not Drift) for this lightweight 24h window metadata. Key: `recent_discoveries_v1`, value: JSON list of `{ isoCode, discoveredAt }`. Filter expired entries on load. Decision must be made before Task 81.
3. **XP write sites** — existing scan/review/share paths need to call `XpRepository.award()` without blocking or breaking existing logic. Use `unawaited()` pattern (same as Firestore sync). If `XpRepository.award()` throws, log and swallow — XP loss is recoverable; scan failure is not.

---

## Milestone 23 — Phase 11 Slice 2: Region Progress + Rovy

**Goal:** The map shows region completion progress at a glance. Rovy provides contextual encouragement. The "one more country" nudge drives re-engagement.

**Scope — included:**
- `RegionProgressNotifier` — computes per-region completion ratio from `RegionRepository` + a static region→countries map; provides `List<RegionProgressData>` (region name, centroid lat/lng, visited count, total count)
- Static `regionCountries` map in `lib/features/map/region_countries.dart` — maps region code to `List<String>` of ISO-2 country codes for all supported regions (Europe, SE Asia, Scandinavia, Benelux, Caribbean, Southern Africa, etc.)
- Static `regionCentroids` map in `lib/features/map/region_centroids.dart` — maps region code to `LatLng` centroid position for chip placement
- `RegionChipsMarkerLayer` — `MarkerLayer` on `FlutterMap` showing progress chips at region centroids; only visible at zoom ≥ 4; chips show "N/M [Region]" with arc progress ring; arc animates to full-ring checkmark on completion
- `TargetCountryLayer` — `PolygonLayer` for countries that are 1-away from completing a partially-done region; dashed amber border via `CustomPainter`; breathing opacity animation (0.40 → 0.65 → 0.40, 2400ms)
- `RegionDetailSheet` — bottom sheet showing region name, countries list (visited / unvisited), "You need X more" callout; tapping an unvisited country → `UnvisitedCountrySheet`
- `RovyMessage` model: `{ text: String, trigger: RovyTrigger, emoji: String? }` where `RovyTrigger` is an enum: `newCountry | regionOneAway | milestone | postShare | caughtUp`
- `RovyBubble` widget — `ConsumerStatefulWidget`; positioned `bottom: 120, right: 16`; quokka avatar (48px, circular, amber border) + speech bubble extending left (max 180px width); `rovyMessageProvider` (StateProvider<RovyMessage?>); auto-dismiss after 4s via `Timer`; tap-to-dismiss; `AnimatedSwitcher` for scale-in entrance; one bubble visible at a time
- Rovy message triggers wired to events: new country (+encouragement), region 1-away (nudge), 10th country (milestone), post-share (thanks), zero-new-countries scan (caught up)
- All new features behind a `featureFlags.regionChips` and `featureFlags.rovyBubble` compile-time flag until Slice 1 visual states are stable in production

**Scope — excluded:**
- Milestone cards (separate task in a later slice)
- Social ranking (Slice 3)
- Timeline scrubber (Later)
- Rovy SVG/PNG asset production (placeholder asset used during development; final asset is a design deliverable)

**Tasks:**

| Task | Description |
|---|---|
| 86 | `RegionProgressNotifier` + `regionCountries` static map + `regionCentroids` static map |
| 87 | `RegionChipsMarkerLayer` — progress chips on map at centroids, zoom-gated at zoom ≥ 4 |
| 88 | `TargetCountryLayer` + `RegionDetailSheet` — dashed 1-away border + region drill-down sheet |
| 89 | `RovyBubble` + `rovyMessageProvider` + trigger wiring at all event sites |

**Technical risks:**

1. **Region→country completeness** — the static `regionCountries` map must be comprehensive enough to be meaningful without being so granular it never triggers. Define regions at the sub-continental level (e.g. Scandinavia = DK, FI, IS, NO, SE; not "Northern Europe" which spans 15 countries and feels unachievable). Review region definitions with product before Task 86.
2. **Dashed border via `CustomPainter`** — `flutter_map` `PolygonLayer` does not natively support dashed borders. `TargetCountryLayer` must convert `LatLng` polygon points to screen coordinates using `MapCamera.latLngToScreenPoint` and draw dashes via `Canvas.drawLine`. This must handle map pan/zoom correctly — the painter must be invalidated when the map moves. Use `MapController.mapEventStream` to trigger repaint. Test on a country with many polygon points (Russia, Canada) to verify performance.
3. **Rovy asset dependency** — `RovyBubble` should work with a simple placeholder circle + "R" text label initially. Do not block Task 89 on the final SVG asset. The asset can be swapped in without code changes once available.

---

## Deferred items (no milestone assigned)

- Firestore pull / multi-device conflict resolution
- Map zoom-to-country on tap (replaced by Country Detail full-screen in M17)
- Vertex simplification for map rendering performance
- `packages/shared_models` TypeScript counterpart (effective-visits merge logic for web)
- CI deployment of `firestore.rules`
- Firestore rules comprehensive security review
- Android support (revisit after iOS App Store launch)
- Email verification for web accounts
- Password reset flow for web accounts
- Social sign-in on web (Google / Apple) — deferred; email/password is sufficient for M13/14
- "Scan for new photos" button when > 30 days since last scan (currently the user must go to Scan tab manually)
- Social feed or user discovery — soft social ranking (aggregate percentile comparison, "you've explored more than 72% of Roavvy travellers") is partially addressed in M23 (Slice 3 of Phase 11); a full social feed with user-to-user interaction remains deferred indefinitely
