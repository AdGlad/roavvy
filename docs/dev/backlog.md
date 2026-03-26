# Backlog — Future Milestones

---

## Phase Completion Status (as of 2026-03-22)

| Phase | Description | Status |
|---|---|---|
| Phase 1 — Core Scan & Map | PhotoKit bridge, country_lookup, Drift DB, map, scan, manual edits | ✅ **Complete** |
| Phase 2 — Sync & Achievements | Firebase Auth (anon + Apple), Firestore sync, achievement engine + UI, account deletion | ✅ **Complete** |
| Phase 3 — Sharing | Travel card image, web share page `/share/[token]`, share sheet, token revocation | ✅ **Complete** |
| Phase 4 — Web Map | Authenticated web map (`/sign-in`, `/map`, `/sign-up`) | ✅ **Complete (M13 + M14)** |
| Phase 5 — Trip Intelligence | Trip inference, trip storage, trip editing | ✅ **Complete (M15)** |
| Phase 6 — Geographic Depth | Region detection (ISO 3166-2) | 🔄 **Slice 1 complete (M16)** — city detection + continent overlay deferred |
| Phase 7 — Rich Mobile Experience | 4-tab shell, Journal, Stats + achievement gallery | ✅ **Complete (M17)** |
| Phase 8 — Celebrations & Delight | Onboarding, new-country celebration, achievement animation, scan summary | ✅ **Complete (M18)** |
| Phase 9 — App Store Readiness | Icon, screenshots, push notifications, iPad layout, referral CTA | 🔄 **M19 complete** — icon assets + App Store URL pending external deliverables |
| Phase 9.5 — Quality & Depth | Trip inference fix, region detection fix, confetti fix, interactive navigation, photo gallery | ✅ **Complete (M19A)** |
| Phase 10 — Commerce | Shopify setup, Firebase Functions, mobile commerce flow, post-purchase, order history | ✅ **Complete (M20A + M20 + M24)** |
| Phase 11 — Gamified Map | Visual states, XP, Discovery Overlay, Region chips, Rovy, Milestone cards, depth colouring, timeline scrubber, scan reveal | ✅ **Complete (M22–M26)** |

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

## Milestone 14 — Phase 4: Web Sign-Up ✅ COMPLETE (2026-03-22)

**Goal:** Users can create a Roavvy account on the web with email/password, completing the web auth flow.

**Delivered:**
- Task 100: `/sign-up` standalone route — `createUserWithEmailAndPassword`, client-side ≥8 char password validation, all three error states, link to `/sign-in`; `/sign-in` updated to remove mode toggle and link to `/sign-up`

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

## Milestone 20 — Phase 10: Shop & Merchandise ✅ COMPLETE (M20A + M20 + M24)

**Goal:** Users can buy personalised travel merchandise via a Shopify-hosted checkout.

**Delivered (M20A, Tasks 65–69):** Shopify store setup, API credentials, 40 product variants, Printful sync, API contracts doc.

**Delivered (M20, Tasks 70–75):** Firebase Functions scaffold + deploy; `createMerchCart` onCall function; `shopifyOrderCreated` webhook; mobile commerce flow (country selection → product browser → variant picker → SFSafariViewController checkout).

**Delivered (M24, Tasks 91–93):** Preview-first checkout (flag grid image generated before checkout launch); post-purchase celebration screen (`AppLifecycleState.resumed`); merch order history (`MerchOrdersScreen` via Firestore).

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

## Milestone 22 — Phase 11 Slice 1: Visual States + XP Foundation ✅ COMPLETE (2026-03-22)

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

## Milestone 23 — Phase 11 Slice 2: Region Progress + Rovy ✅ COMPLETE (2026-03-22)

**Goal:** The map shows region completion progress at a glance. Rovy provides contextual encouragement. The "one more country" nudge drives re-engagement.

**Region model decision (product):** 6 standard global continents derived from `kCountryContinent` in `packages/shared_models`. Custom sub-continental regions (Scandinavia, Benelux, etc.) are deferred to a later milestone as optional overlays.

**Scope — included:**
- `Region` enum (6 values): `europe`, `asia`, `africa`, `northAmerica`, `southAmerica`, `oceania`
- `RegionProgressNotifier` — computes per-region completion ratio by reading `kCountryContinent` directly; provides `List<RegionProgressData>` (region, centroid LatLng, visited count, total count); no static `regionCountries` file needed
- Fixed centroid `LatLng` per region (hardcoded constants): Europe (54, 15), Asia (34, 100), Africa (2, 21), North America (40, −100), South America (−15, −60), Oceania (−25, 134)
- `RegionChipsMarkerLayer` — `MarkerLayer` on `FlutterMap` showing progress chips at region centroids; only visible at zoom ≥ 4; chips show "N/M [Region]" with arc progress ring; arc animates to full-ring checkmark on completion
- `TargetCountryLayer` — `PolygonLayer` for countries that are 1-away from completing a partially-done region; solid amber border (`borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`) + breathing fill opacity (0.10 → 0.25 → 0.10, 2400ms); uses same `AnimationController` pattern as M22 `CountryPolygonLayer` — no `CustomPainter` required
- `RegionDetailSheet` — bottom sheet showing region name, countries list (visited / unvisited), "You need X more" callout
- `RovyMessage` model: `{ text: String, trigger: RovyTrigger, emoji: String? }` where `RovyTrigger` is an enum: `newCountry | regionOneAway | milestone | postShare | caughtUp`
- `RovyBubble` widget — `ConsumerStatefulWidget`; positioned `bottom: 120, right: 16`; quokka avatar (48px, circular, amber border) + speech bubble extending left (max 180px width); `rovyMessageProvider` (StateProvider<RovyMessage?>); auto-dismiss after 4s via `Timer`; tap-to-dismiss; `AnimatedSwitcher` for scale-in entrance; one bubble visible at a time
- Rovy message triggers wired to events: new country (+encouragement), region 1-away (nudge), 10th country (milestone), post-share (thanks), zero-new-countries scan (caught up)

**Scope — excluded:**
- Custom sub-continental region overlays (Scandinavia, Benelux, etc.) — deferred, to be added as optional overlays on top of the continent base system
- Milestone cards (separate task in a later slice)
- Social ranking (Slice 3)
- Timeline scrubber (Later)
- Rovy SVG/PNG asset production (placeholder asset used during development; final asset is a design deliverable)

**Tasks:**

| Task | Description |
|---|---|
| 86 | `Region` enum + `RegionProgressNotifier` (reads `kCountryContinent`; hardcoded centroids) |
| 87 | `RegionChipsMarkerLayer` — progress chips on map at centroids, zoom-gated at zoom ≥ 4 |
| 88 | `TargetCountryLayer` + `RegionDetailSheet` — dashed 1-away border + region drill-down sheet |
| 89 | `RovyBubble` + `rovyMessageProvider` + trigger wiring at all event sites |

**Technical risks:**

1. **`TargetCountryLayer` visual treatment** — Dashed borders are not supported natively in `flutter_map` and require `CustomPainter` with manual screen-coordinate projection and repaint wiring — too risky for this slice. Use a solid amber border (`borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`) with a breathing fill opacity animation (0.10 → 0.25 → 0.10, 2400ms) using the same `AnimationController` pattern as `CountryPolygonLayer`. The solid amber border is visually distinct from teal (visited) and grey (unvisited) states without any `CustomPainter` complexity. **Do not implement dashed borders in M23.**
2. **Rovy asset dependency** — `RovyBubble` should work with a simple placeholder circle + "R" text label initially. Do not block Task 89 on the final SVG asset. The asset can be swapped in without code changes once available.

---

## Milestone 25 — Phase 11 Slice 3: Milestone Cards + Country Depth Colouring ✅ COMPLETE (2026-03-22)

**Goal:** Users are celebrated at country count milestones. The map shows visit depth per country via amber colour gradient.

**Delivered:**
- `depthFillColor(tripCount)` — 4-tier amber gradient for visited countries (1 trip → amber-200, 2–3 → amber-400, 4–5 → amber-600, 6+ → amber-800); `countryTripCountsProvider`
- `MilestoneRepository` — SharedPreferences-backed; `kMilestoneThresholds = [5, 10, 25, 50, 100]`
- `MilestoneCardSheet` — modal bottom sheet; badge emoji per threshold; headline + subtext + Share + Continue; `showMilestoneCardSheet(context, threshold)` helper
- `_checkAndShowMilestone` in `ScanSummaryScreen` — wired into both `_handleDone` and `_handleCaughtUp` paths

---

## Milestone 26 — Phase 11 Slice 4: Timeline Scrubber + Scan Reveal ✅ COMPLETE (2026-03-22)

**Goal:** The map becomes a time machine. New discoveries animate onto a mini-map during scan summary.

**Delivered:**
- `yearFilterProvider` + `filteredEffectiveVisitsProvider` + `earliestVisitYearProvider` + `countryVisualStatesProvider` updated to honour year filter (ADR-076)
- `TimelineScrubberBar` — amber Card with discrete Slider, label, Clear button; wired into MapScreen overflow menu
- `ScanRevealMiniMap` — Timer.periodic(400ms) pop-in of new country polygons; shown in ScanSummaryScreen State A when ≥2 new countries (ADR-077)

---

---

## Milestone 27 — Web Shop: Public `/shop` Landing Page + Entry Points ✅ COMPLETE (2026-03-22)

**Goal:** Web visitors can discover and browse the shop; sign-in entry points direct them into the personalisation flow.

**Scope — included:**
- `/shop` Next.js route (public, no auth required): two featured product cards (t-shirt + travel poster) with static sample mockup images; tagline copy; "Sign in to personalise your design" CTA → `/sign-in?next=/shop`
- Nav link "Shop" added to `/map` page header
- "Get a personalised poster of your map" CTA block added to `/share/[token]` page
- Redirect-after-login: if `/sign-in` receives `?next=/shop`, redirect to `/shop` on success

**Scope — excluded:**
- Country selection or checkout (M28)
- Live Printful/Printify mockup generation (static placeholder images)
- Mobile changes

**Delivered:** Task 101: `/shop` public page (product cards, amber hero, auth-aware CTA). Task 102: "Shop" nav link on `/map`; "Turn your travels into a poster" CTA on `/share/[token]`; `/sign-in` `?next` redirect-after-login with open-redirect sanitisation (ADR-078).

---

## Milestone 28 — Web Commerce: Authenticated Checkout

**Goal:** A signed-in web user can select their visited countries, call `createMerchCart`, and complete a Shopify checkout.

**Scope — included:**
- `/shop` updated: when signed in, shows country count + "Create my poster" CTA
- Country selection step: checkbox grid of visited countries (reads Firestore effective visits, all pre-selected)
- Cart creation: calls `createMerchCart` Firebase callable from web JS SDK; redirects to `checkoutUrl`
- Post-checkout: `/shop?ordered=true` confirmation state
- Error state: function failure → retry message

**Scope — excluded:**
- Variant picker (colour, size) on web — poster only
- Mockup image generation on web
- Order history on web

**Depends on:** M27

**Not started. No tasks written yet.**

---

## Milestone 43 — Scan Delight: Real-Time Discovery ✅ COMPLETE (2026-03-26)

**Goal:** Make every scan feel alive. Each newly discovered country triggers an in-scan toast, a confetti burst, and a world map that zooms to that country in real-time. After the scan, new countries are displayed as a dramatic flag timeline. When the user opens the app after 7+ days away, they are proactively prompted to scan for new countries.

**Phase:** Celebrations & Delight (Phase 8 follow-on)

**Why this milestone:** The scan is the highest-emotion moment in the app. The existing live feed (Task 109) shows a text list — this milestone turns it into a proper discovery experience: the user *watches* their map grow with each country found.

### Scope — included

| # | Feature | Notes |
|---|---|---|
| In | Discovery toast during scan | Animated "🎉 New Country! 🇯🇵 Japan" banner slides in from top, stays 2.5s, slides away; non-blocking |
| In | Inline world map during scan | `FlutterMap` embedded in `_ScanningView`; discovered countries highlight amber; camera auto-fits to each new country's polygon bounds on discovery |
| In | Micro-confetti per discovery | Short burst via existing `ConfettiWidget` when each new country is added; capped at first 5 per scan, min 500ms gap between bursts; respects `MediaQuery.disableAnimationsOf` |
| In | Post-scan flag timeline | Visual upgrade to `ScanSummaryScreen` State A — larger flag emojis, staggered card reveal, discovery-order preserved |
| In | App-open scan prompt | When `lastScanAt` is null or > 7 days ago, show a `DiscoverNewCountriesSheet` modal on app open; "Scan now" → Scan tab; "Later" dismisses |

### Scope — excluded

- Sound effects (separate milestone; App Store audio review complexity)
- Map screen dashboard circles / continent rings (significant layout redesign, separate milestone)
- Trip timeline sidebar on map screen (separate milestone)
- Confetti for the 6th+ country in a single scan (performance cap; addressable in a polish pass)

### Tasks

| Task | Description |
|---|---|
| 140 | `_DiscoveryToastOverlay` — animated banner widget shown in `_ScanningView` when a new country is added to `_liveNewCodes`; flag emoji + country name; slide-in/out; non-blocking |
| 141 | Inline scan world map — `_ScanLiveMap` widget added to `_ScanningView`; `FlutterMap` with `polygonsProvider`; discovered countries rendered amber; `MapController.fitCamera(CameraFit.bounds(...))` per new country |
| 142 | Micro-confetti per discovery — `ConfettiController` in `_ScanningView`; fires short burst on each new country (cap 5, min 500ms debounce); anchored near the toast overlay; `MediaQuery.disableAnimationsOf` guard |
| 143 | Post-scan flag timeline — `ScanSummaryScreen` State A redesign: larger flag cards with staggered reveal; replaces current compact country-name list |
| 144 | App-open scan prompt — `DiscoverNewCountriesSheet`; shown from `MapScreen` `initState`/`didChangeDependencies` when `lastScanAt == null \|\| daysSince > 7`; persists dismissed-today state to SharedPreferences; "Scan now" calls `onNavigateToScan` |

### Dependencies

- `confetti` package: already in `pubspec.yaml` (Task 52)
- `polygonsProvider`: already in `providers.dart`
- `lastScanAtProvider`: already in `providers.dart` (Task 113)
- All tasks depend on no new packages

### Risks

| Risk | Mitigation |
|---|---|
| `fitCamera` on `MapController` during scan causes jank if many countries found rapidly | Debounce camera moves to max one per 800ms; queue latest code, skip intermediate ones |
| Inline map in scan screen makes the screen too tall / cluttered | Fixed height 200px; sits above the live feed list; collapses gracefully if `polygonsProvider` is empty |
| `ConfettiController` `play()` called on a disposed widget (scan cancelled mid-burst) | Guard with `mounted` check; cancel burst timer in `dispose()` |
| App-open prompt shown immediately on first launch (before onboarding) | Only show when `onboardingCompleteProvider` is true AND `lastScanAt` condition met |

---

## Milestone 35 — Trip Region Map ✅ COMPLETE (2026-03-24)

**Goal:** Tapping a trip in the Journal opens a full-screen country map styled like the main map, with the regions visited on that trip highlighted in amber.

**Tasks:** 123–126

---

## Milestone 36 — Country Region Map (Stats → Regions) ✅ COMPLETE (2026-03-26)

**Goal:** From the Stats screen Regions breakdown, tapping a country opens a full-screen map of that country with all visited regions highlighted; tapping a region shows a floating name label.

**Tasks:** 127–129 (see `next_tasks.md`)

---

## Milestone 34 — Mobile Commerce: Full T-shirt Mockup Preview ✅ COMPLETE (2026-03-24)

**Goal:** Before completing checkout, the user sees a photorealistic mockup of the full t-shirt with their flag grid design applied — not just the print file image.

**Tasks:** 120–122 (see `next_tasks.md`)

---

## Milestone 32 — Mobile Quality & Scan Reward Pass ✅ COMPLETE (2026-03-26)

**Goal:** Fix six user-reported UX and correctness issues across map, journal, stats, and scan flows.

**Delivered (Tasks 105–110):** Map dark navy/gold visual refresh (ADR-080); tappable regions stat → `RegionBreakdownSheet` (ADR-081); journal stale state fix via `tripListProvider` (ADR-082); trip photo date filtering via `loadAssetIdsByDateRange` (ADR-083); real-time scan discovery feed; sequential `DiscoveryOverlay` for all new countries capped at 5 with "Skip all" CTA (ADR-084).

---

## Milestone 29 — Mobile Commerce: Remaining Entry Points + Scan Nudge ✅ COMPLETE (2026-03-26)

**Goal:** Users encounter the shop at peak motivation moments; the app proactively nudges users who haven't scanned in 30+ days.

**Delivered (Tasks 111–113, ADR-085):** Scan summary "Get a poster" CTA pre-filtered to new codes; Map "⋮" menu "Get a poster" item; 30-day scan nudge banner in `MapScreen` (dismissed per-session via `scanNudgeDismissedProvider`).

---

## Milestone 30 — Firestore Trip Sync ✅ COMPLETE (2026-03-23)

**Goal:** Trip records are synced to Firestore for multi-device access.

**Delivered (Task 114):** Trip sync infrastructure was substantially pre-built in earlier milestones (`FirestoreSyncService.flushDirty()` trips path, `TripRepository.loadDirty/markClean`, wired at scan save / review save / app startup, 5 trip-flush tests, Firestore wildcard rules). M30 closed the only remaining gap: `apple_sign_in.dart` now accepts optional `tripRepo: TripRepository?` and forwards it to `flushDirty` so trips are flushed immediately post-Apple-sign-in.

**Deferred:** Web `/map` trip count (mobile-first priority).

---

## Milestone 31 — Web Auth: Password Reset

**Goal:** Users who forget their password can recover their account from the web.

**Scope — included:**
- `/forgot-password` Next.js route: email field; `sendPasswordResetEmail`; generic success message; error state
- "Forgot your password?" link on `/sign-in`
- "Back to sign in" link on `/forgot-password`

**Scope — excluded:**
- Custom email template (Firebase default)
- Password reset on mobile

**Not started. No tasks written yet.**

---

## Milestone 45 — Passport Stamp Realism Upgrade ✅ COMPLETE (2026-03-26)

**Goal:** Make passport stamps look physically authentic — ink simulation, pressure distortion, 12 stamp style templates, realistic typography with arc text and sublabels, aging effects, and rare artefacts (double-stamp ghosting, partial stamps, ink blobs).

**Phase:** Phase 15 — Visual Design Upgrade

**Architecture:** ADR-097

**Scope — included:**
- `StampStyle` enum (12 styles: airportEntry, airportExit, landBorder, visaApproval, transit, vintage, modernSans, triangle, hexBadge, dottedCircle, multiRing, blockText) replacing `StampShape`
- `StampNoiseGenerator` — procedural opacity mask via seeded noise (edge falloff, micro-gaps, ink bleed via `MaskFilter.blur`)
- `StampShapeDistorter` — vertex jitter for geometric imperfection
- `StampTypographyPainter` — condensed typography, monospaced dates, ARRIVAL/DEPARTURE sublabels, arc text on circular stamps, baseline jitter
- `StampInkPalette` — 6 de-saturated ink families
- `StampAgeEffect` — 4 aging levels (fresh/aged/worn/faded) affecting opacity and colour
- `RareArtefactEngine` — double-stamp ghost (5%), partial stamp (3%), ink blob (2%), smudge (2%), correction stamp (1%)
- Multi-step rendering pipeline with `PictureRecorder` offscreen compositing and `BlendMode.multiply` over paper
- Layout: temporal ordering (earliest stamps lower), partial page-edge clipping (8% of stamps), 3×4 soft-grid clustering

**Scope — excluded:**
- Flag Heart card (M46)
- Sound effects

**Not started. No tasks written yet.**

---

## Milestone 46 — Flag Heart: True Heart-Mask Layout Engine ✅ COMPLETE (2026-03-27)

**Goal:** Replace the current `HeartFlagsCard` (gradient background + emoji flags) with a geometric heart composed entirely of real SVG flag tiles — the heart shape itself is formed by the flags, clipped at the heart boundary with at least 66% of each tile visible.

**Phase:** Phase 15 — Visual Design Upgrade

**Architecture:** ADR-098

**Scope — included:**
- `HeartLayoutEngine` — parametric heart mask `(x²+y²−1)³−x²y³≤0`, density bands (5 tiers), 5/9-point coverage test, flag assignment with re-run on density mismatch
- `MaskCalculator` — heart parametric evaluation, tile coverage fraction, `Path` generation for `Canvas.clipPath()`
- `FlagTileRenderer` — SVG flag rendering via `flutter_svg`, PNG fallback, offscreen `PictureRecorder` at export DPI
- `FlagImageCache` — LRU cache (max 300 entries) keyed by country code + tile size
- `HeartImageExporter` — multi-resolution export (1024, 3000, 5000px) via `compute()`
- `HeartRenderConfig` — gap width, corner radius, edge feather, shadow opacity
- `HeartFlagOrder` enum — randomized (default), chronological, alphabetical, geographic
- Flag SVG asset bundle: `assets/flags/svg/{code}.svg`, ~260 files
- `flutter_svg` added to `pubspec.yaml`
- `CardGeneratorScreen`: flag-order segmented control (heart template only)
- Transparent PNG export (alpha channel, no background artefacts)

**Scope — excluded:**
- Passport stamp realism (M45)
- Web card generator
- Android

**Delivered (Tasks 163–168):** `HeartLayoutEngine` (parametric mask + density bands + coverage filter + 4 ordering strategies); `MaskCalculator` (isInsideHeart + coverageFraction + heartPath); `FlagTileRenderer` + `FlagImageCache` (LRU, 300 entries); 271 SVG flag assets (flag-icons 4x3, MIT); `flutter_svg ^2.0.10+1`; `HeartFlagsCard` rewritten to `CustomPaint` with `_HeartPainter`; `HeartRenderConfig`; `CardGeneratorScreen` flag-order segmented control; 632 flutter tests passing.

**Deferred:** `HeartImageExporter` multi-resolution export at 3000/5000px (deferred — `RepaintBoundary.toImage(pixelRatio: 3.0)` remains export path).

---

## Milestone 47 — Commerce Template & Placement

**Goal:** The merch purchase workflow correctly reflects the card template the user designed (Grid, Heart, or Passport), the selected colour variant drives the Printful mockup so the user sees the right coloured t-shirt, and the user can choose front or back placement for their design.

**Phase:** Phase 10 — Commerce (Bug Fix + Enhancement)

**Architecture:** ADR-099

**Scope — included:**
- `CardImageRenderer` utility — offscreen `PictureRecorder` PNG renderer for all 3 card templates
- Template picker (Grid / Heart / Passport) inside `MerchVariantScreen` with live mockup regeneration
- Front/back placement picker in `MerchVariantScreen` (t-shirt only)
- Firebase Function: `placement` field support in `CreateMerchCartRequest` → Printful mockup API
- `clientCardBase64` size guard (>4 MB rejected)
- BUG-001 diagnostic logging closure for `catalog_variant_id` type coercion

**Scope — excluded:**
- Flag Heart SVG renderer (M46)
- Web commerce flow
- Poster placement
- Android

**In Progress. Tasks 163–168.**

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
- `createMerchCart` Cloud Function deployed with 256 MB memory but source specifies `memory: '2GiB'` — function needs redeployment with correct config; large flag grids may OOM under the current deployed spec (discovered 2026-03-24)
- Social feed or user discovery — soft social ranking (aggregate percentile comparison, "you've explored more than 72% of Roavvy travellers") is partially addressed in M23 (Slice 3 of Phase 11); a full social feed with user-to-user interaction remains deferred indefinitely
