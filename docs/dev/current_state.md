# Roavvy — Development State (as of 2026-03-25, through Task 150 / M43)

## What Works

The Flutter mobile app runs on a real iPhone with a complete navigation shell, offline world map, and interactive country detail sheets.

**Confirmed working end-to-end:**
- Photo library permission request (iOS Photos framework)
- PhotoKit asset fetch with `fetchLimit` and `sinceDate` incremental-scan predicate
- GPS coordinate extraction from EXIF metadata — streamed as per-photo records via `EventChannel('roavvy/photo_scan/events')`
- **CLGeocoder fully removed** — all country resolution is now offline, via `packages/country_lookup`
- Swift streams `{lat, lng, capturedAt}` per photo in batches of 50; Dart resolves coordinates to ISO codes on a background `Isolate`
- Scan stats display: assets inspected, with/without location, geocode successes/failures, unique countries
- Progress indicator during scanning (indeterminate `LinearProgressIndicator` + processed-photo counter)
- Per-country photo counts and `firstSeen`/`lastSeen` ranges populated from `capturedAt`
- Country visit persistence via Drift SQLite — three typed tables — survives app restart
- Review screen: remove a detected country, manually add a country, save the corrected list
- User edits (add / remove) written as typed records; removals create `UserRemovedCountry` tombstones
- **World map**: offline flutter_map canvas showing all country polygons; visited countries highlighted green; Antarctica suppressed
- **Country tap → detail sheet**: tapping any polygon opens a bottom sheet with visit details (name, dates, photo count, manually-added badge); tapping unvisited country shows "Add to my countries" action; open water taps do nothing
- **4-tab navigation shell**: Map · Journal · Stats · Scan (ADR-052); `IndexedStack` keeps all tabs alive; after scan completes, app auto-navigates to Map tab; tab indices locked (Map=0, Journal=1, Stats=2, Scan=3)
- **Riverpod provider graph**: `geodataBytesProvider`, `roavvyDatabaseProvider`, `visitRepositoryProvider`, `polygonsProvider`, `effectiveVisitsProvider`, `travelSummaryProvider`, `tripRepositoryProvider`, `regionRepositoryProvider`, `achievementRepositoryProvider`, `regionCountProvider` in `lib/core/providers.dart`
- **`RoavvySpike` fully retired** — renamed to `RoavvyApp`; app title is "Roavvy"
- **Stats strip**: `StatsStrip` ConsumerWidget overlaid at bottom of `MapScreen`; shows country count, earliest year, latest year; "—" when no date metadata; watches `travelSummaryProvider`
- **Delete travel history**: `PopupMenuButton` (⋮, top-right) on `MapScreen` with a single "Delete Travel History" item; shows `AlertDialog` confirmation; on confirm calls `VisitRepository.clearAll()` and invalidates `effectiveVisitsProvider` + `travelSummaryProvider`; clears `lastScanAt` so next scan is a full scan
- **Map empty state**: `_EmptyStateOverlay` widget shown in the `MapScreen` Stack when no countries are visited; copy invites user to scan; "Scan Photos" button navigates to the Scan tab via `onNavigateToScan` callback wired from `MainShell._goToScan()`
- **Firebase Auth**: `firebase_core` + `firebase_auth` initialised in `main()` (parallel with geodata + DB init); anonymous sign-in on first launch; `authStateProvider` (`StreamProvider<User?>`) in `lib/core/providers.dart`
- **Sign in with Apple**: `sign_in_with_apple` + `crypto` packages; SHA-256 nonce flow; anonymous credential upgrade via `linkWithCredential`; "Sign in with Apple" / "Signed in with Apple ✓" in `MapScreen` overflow menu; handles `credential-already-in-use` by signing in directly (ADR-028)
- **Firestore sync**: `cloud_firestore ^5.4.0`; `isDirty`/`syncedAt` columns on all three Drift tables (schema v3); `FirestoreSyncService.flushDirty(uid, repo)` pushes dirty rows to `users/{uid}/inferred_visits`, `users/{uid}/user_added`, `users/{uid}/user_removed`; called fire-and-forget after Apple sign-in (Task 19) and after each scan/review-save (Task 20); `NoOpSyncService` stub used in widget tests; `firestore.rules` scaffold at repo root (ADR-029, ADR-030)
- **Trip intelligence**: `TripRecord` domain model; `TripInference.inferTrips()` uses geographic sequence model (sort all records by date, run-length encode by country code — each contiguous run = one trip); `TripRepository` persists inferred trips; `TripEditSheet` for manual trip date edits; schema v5 `trips` table
- **Region detection**: `packages/region_lookup` — offline ISO 3166-2 admin1 polygon lookup; custom compact binary (`ne_admin1.bin`, 3.5 MB); `RegionVisit` domain model; `RegionRepository`; region count + expandable region list in `CountryDetailSheet`; schema v7 `region_visits` table
- **Bootstrap service**: `BootstrapService` re-derives trips and region visits from existing photo scan records on app launch (catches up users who scanned before these features existed)
- **Journal screen**: `JournalScreen` (tab 1); chronological trip list grouped by year; country flag emoji; taps open `CountryDetailSheet`; empty state with "Scan Photos" CTA
- **Stats screen**: `StatsScreen` (tab 2); stats panel (countries, regions, since year) with "—" fallback; achievement gallery grid (unlocked first, sorted by unlock date; then locked); amber trophy icon for unlocked, grey lock for locked; unlock date shown on unlocked cards
- **Web map** (`apps/web_nextjs`): Next.js 15 app; `/sign-in` (email/password, `?next` redirect-after-login with open-redirect sanitisation, ADR-078); `/sign-up`; `/map` authenticated route (header has "Shop" link); `/shop` public landing page (product showcase, sign-in CTA for unauthenticated, "coming soon" placeholder for authenticated); `/share/[token]` share page (+ "Turn your travels into a poster" CTA above App Store section); `/privacy`
- **Onboarding flow**: `_OnboardingGate` in `app.dart` routes new users to `OnboardingFlow` (3-screen PageView: Welcome · Privacy · Ready); returning users (existing visits) bypass onboarding; schema v8 `hasSeenOnboardingAt` column; `onboardingCompleteProvider` FutureProvider
- **Scan summary**: `ScanSummaryScreen` shown after review-save; State A (new discoveries) shows new country list + achievement chips with confetti animation; State B (nothing new) shows friendly compact summary with last-scan date; animations respect `reduceMotion`
- **Achievement unlock sheet**: `AchievementUnlockSheet` modal bottom sheet shown from scan summary chips and stats gallery; share action via `share_plus`
- **SnackBar removed from review-save path**: achievement display moved to `ScanSummaryScreen` (ADR-054)
- **iPhone-only targeting**: `TARGETED_DEVICE_FAMILY = "1"` in all 3 Xcode build configs (ADR-057); iPad `UISupportedInterfaceOrientations~ipad` block removed from `Info.plist`
- **Bundle identity**: `CFBundleDisplayName` and `CFBundleName` → `"Roavvy"` (ADR-057)
- **Privacy policy page** (`apps/web_nextjs/src/app/privacy/page.tsx`): static public Next.js route at `/privacy`; covers data collected, on-device processing, Apple sign-in, sharing, user rights, and contact
- **Privacy policy link in app**: `PrivacyAccountScreen` "Legal" section opens `https://roavvy.app/privacy` via `url_launcher` → `LaunchMode.externalApplication`
- **Local push notifications** (`lib/core/notification_service.dart`): singleton `NotificationService` (not Riverpod; ADR-056); `scheduleAchievementUnlock` (immediate, `tab:2` payload); `scheduleNudge` (30-day `zonedSchedule`, `tab:3` payload); `requestPermission` / `hasRequestedPermission`; all methods guard with `if (!_initialized) return` so they are safe to call before init
- **Notification tap routing**: `ValueNotifier<int?> pendingTabIndex`; `MainShell` subscribes in `initState()` + handles cold-start via `getLaunchTab()`; switches `IndexedStack` index and resets notifier to null
- **Notification permission prompt**: requested after first scan that finds new countries (`_NewDiscoveriesState._scheduleNotifications()`); not prompted on nothing-new path
- **"Get Roavvy" CTA on share page**: `/share/[token]` now shows descriptive copy + App Store badge below the map; `APP_STORE_URL` constant (placeholder `id0000000000`, TODO to replace); placeholder `app-store-badge.svg` (TODO to replace with official Apple badge)
- **App icon placeholder marker**: `REPLACE_WITH_FINAL_ICON.md` in `AppIcon.appiconset`; instructions for generating final sizes from 1024×1024 PNG
- **PHAsset IDs in local DB**: `asset_id` TEXT column on `photo_date_records` Drift table (schema v9); `VisitRepository.loadAssetIds(countryCode)` returns non-null asset IDs for a country
- **Photo gallery**: `PhotoGalleryScreen` — 3-column `GridView` of PHAsset thumbnails (150×150); empty state; loading indicator per cell; broken-image icon on fetch failure; tapping a cell pushes full-screen `InteractiveViewer`; `photo_manager ^3.0.0`; `ThumbnailFetcher` typedef injectable in tests (ADR-061); `CountryDetailSheet` restructured to 2-tab layout (Details / Photos)
- **Gamified map (M22 — Phase 11 Slice 1)**:
  - `CountryVisualState` enum (5 states: `unvisited`, `visited`, `reviewed`, `newlyDiscovered`, `target`); `countryVisualStateProvider` family + `countryVisualStatesProvider` map provider
  - `recentDiscoveriesProvider` — SharedPreferences-backed `StateNotifier<Set<String>>`; 24h expiry; async init via `Completer` ready gate (ADR-067)
  - `CountryPolygonLayer` — replaces imperative polygon building; splits into static + animated `PolygonLayer` groups; amber pulse animation (0.55–0.85 opacity, 1200ms); animation only starts when `newlyDiscovered` polygons exist and animations are enabled (ADR-066, ADR-055)
  - `XpEvent` domain model + `xp_events` Drift table (schema v10); `XpRepository`; `XpNotifier` (`StateNotifier<XpState>`) with 8 level thresholds and `Stream<int> xpEarned` for flash animation
  - `XpLevelBar` — 44pt amber top strip on `MapScreen`; circular level badge, level label, `LinearProgressIndicator`, "+N XP" flash via `AnimatedSwitcher` (1500ms)
  - XP awarded at 4 sites: scan completed (+25 XP), new country (+50 XP, wired in ScanScreen + ReviewScreen), share (+30 XP)
  - `DiscoveryOverlay` — full-screen amber gradient route; flag emoji (64pt), country name, "+50 XP", `HeavyImpact` haptic; pushed from `ScanSummaryScreen._handleDone()` for first new country; "Explore your map" CTA uses `popUntil('/')` (ADR-068)
  - `ScanSummaryScreen` converted to `ConsumerStatefulWidget`; `_handleDone()` registers all new codes with `recentDiscoveriesProvider` then pushes `DiscoveryOverlay`
  - `MapScreen` converted from `ConsumerStatefulWidget` to `ConsumerWidget`; reactive `effectiveVisitsProvider` in `build()`
- **Gamified map (M23 — Phase 11 Slice 2: Region Progress + Rovy)**:
  - `Region` enum (6 values) + `RegionProgressData` model + `computeRegionProgress()` + `regionProgressProvider` — derived from `kCountryContinent`; hardcoded centroids per region (ADR-069)
  - `RegionChipsMarkerLayer` — `MarkerLayer` on `FlutterMap`; zoom-gated (zoom < 4 returns empty layer); chips show "N/M" with arc progress ring (`_ArcPainter` using `ui.Path`); complete regions show checkmark; tap opens `RegionDetailSheet` (ADR-069)
  - `TargetCountryLayer` — `ConsumerStatefulWidget`; solid amber border (`borderColor: Color(0xFFFFB300)`, `borderStrokeWidth: 2.5`) + breathing fill opacity (0.10 → 0.25, 2400ms); no `CustomPainter`; reduced-motion static 0.175 opacity; renders countries in regions exactly 1-away from completion (ADR-070)
  - `RegionDetailSheet` — `showRegionDetailSheet(context, data, visits)` top-level function; `DraggableScrollableSheet`; visited/unvisited country lists; "X more to complete" callout; no providers in sheet (ADR-072)
  - `RovyMessage` model + `RovyTrigger` enum (5 triggers: `newCountry`, `regionOneAway`, `milestone`, `postShare`, `caughtUp`) + `rovyMessageProvider` (`StateProvider<RovyMessage?>`) co-located in `rovy_bubble.dart` (ADR-071)
  - `RovyBubble` — `ConsumerStatefulWidget`; 48px amber circle "R" placeholder avatar; speech bubble (max 180px) extends left; `AnimatedSwitcher` scale-in; tap-to-dismiss; 4s auto-dismiss `Timer`; `AnimatedSwitcher` hides cleanly when null (ADR-071)
  - Rovy trigger wiring: region-1-away via `ref.listen(regionProgressProvider)` in `MapScreen.build()`; post-share in share action; new-country + milestone (10th country) in `ScanSummaryScreen._handleDone()`; caught-up in `ScanSummaryScreen._handleCaughtUp()`
  - `RegionChipsMarkerLayer`, `TargetCountryLayer`, `RovyBubble` wired into `MapScreen` Stack + FlutterMap children
- **Gamified map (M25 — Phase 11 Slice 3: Milestone Cards + Country Depth Colouring)**:
  - `depthFillColor(tripCount)` — 4-tier amber gradient for `visited` countries (1 trip → amber-200 lightest, 2-3 → amber-400, 4-5 → amber-600, 6+ → amber-800 deepest); `countryTripCountsProvider` (`FutureProvider<Map<String, int>>`) derives counts from `TripRepository.loadAll()`; `target` and `reviewed` visual states unchanged
  - `MilestoneRepository` — SharedPreferences-backed (`shown_milestones_v1` JSON list); `getShownThresholds()` / `markShown(int)`; `kMilestoneThresholds = [5, 10, 25, 50, 100]`; `milestoneRepositoryProvider` in `providers.dart`
  - `MilestoneCardSheet` — modal bottom sheet; badge emoji per threshold (🌍 🗺️ ✈️ 🌐 🏆); headline + subtext + Share + Continue; `showMilestoneCardSheet(context, threshold)` top-level helper; `pendingMilestoneThreshold(count, shown)` pure function
  - `_checkAndShowMilestone` helper in `ScanSummaryScreen` — checks effective count vs. shown thresholds; marks shown before displaying; shows at end of both `_handleDone` (new countries) and `_handleCaughtUp` (nothing-new) paths
- **Gamified map (M26 — Phase 11 Slice 4: Timeline Scrubber + Scan Reveal)**:
  - `yearFilterProvider` — global `StateProvider<int?>` (null = show all); `earliestVisitYearProvider` — `FutureProvider<int?>` returning min trip `startedOn` year across all trips (ADR-076)
  - `filteredEffectiveVisitsProvider` — `FutureProvider<List<EffectiveVisitedCountry>>`; when filter null returns same as `effectiveVisitsProvider`; when set to year Y keeps countries with at least one trip `startedOn.year <= Y`; manually-added countries with no trips and no `firstSeen` are conservatively excluded
  - `countryVisualStatesProvider` updated to watch `yearFilterProvider`; derives states from `filteredEffectiveVisitsProvider` when filter active; `recentDiscoveriesProvider` (newlyDiscovered) always overlaid regardless of filter (ADR-076)
  - `TimelineScrubberBar` — `ConsumerWidget`; hidden when filter null; amber-tinted `Card`; `Slider` with discrete year steps; label "Showing countries visited by [year]"; Clear button sets filter to null; `SafeArea` bottom; wired into `MapScreen` Stack as `Column` above `StatsStrip`
  - `MapScreen` "Filter by year" `PopupMenuItem` — shown only when `earliestVisitYearProvider` returns a year < current year; tapping activates filter at current year; `filterByYear` added to `_MapMenuAction` enum
  - `ScanRevealMiniMap` — `ConsumerStatefulWidget` with `newCodes: List<String>`; fixed 180px `FlutterMap` (no interaction, `flags: 0`); two `PolygonLayer`s (grey unvisited, amber revealed); `Timer.periodic(400ms)` pops one code at a time into `_revealed` set; immediately reveals all when `MediaQuery.disableAnimationsOf` is true; timer cleaned up in `dispose` (ADR-077)
  - `ScanRevealMiniMap` shown in `ScanSummaryScreen` State A when `newCodes.length >= 2`; first item in ListView, padded 16px below
- **Mobile quality (M32 — Tasks 105–110)**:
  - **Map dark navy/gold visual refresh (Task 105, ADR-080)**: `MapScreen` + `MapOptions` background `Color(0xFF0D2137)`; `CountryPolygonLayer` unvisited fill `Color(0xFF1E3A5F)`; `depthFillColor` tiers updated to gold (1 trip `0xFFD4A017`, 2–3 `0xFFC8860A`, 4–5 `0xFFB86A00`, 6+ `0xFF8B4500`); newly-discovered fill `Color(0xFFFFD700)` + white border; `XpLevelBar` + `StatsStrip` background `Color(0xFF0D2137).withValues(alpha: 0.88)`; level badge `Color(0xFFFFD700)`; XP bar track `Color(0xFF1E3A5F)`
  - **Tappable regions stat (Task 106, ADR-081)**: `RegionBreakdownSheet` — `DraggableScrollableSheet` (NEW `lib/features/stats/region_breakdown_sheet.dart`); `FutureBuilder` over `RegionRepository.loadAll()`; grouped by country, alphabetical, `ExpansionTile` per country; `RegionRepository.loadAll()` added (returns all region visits); `StatsScreen` `_StatTile` gains `tappable` bool + chevron; `onRegionsTap` wired to `RegionBreakdownSheet.show(context)` when count > 0
  - **Journal stale state fix (Task 107, ADR-082)**: `tripListProvider = FutureProvider<List<TripRecord>>` added to `providers.dart`; `JournalScreen` converted from `ConsumerStatefulWidget` (with `late final Future`) to `ConsumerWidget` watching `tripListProvider`; after `clearAll()` and scan save, `tripListProvider`, `regionCountProvider`, `countryTripCountsProvider`, `earliestVisitYearProvider` are all invalidated
  - **Trip photo date filtering (Task 108, ADR-083)**: `VisitRepository.loadAssetIdsByDateRange(countryCode, start, end)` added using Drift `isBetweenValues` on existing `capturedAt` column (no schema change); `CountryDetailSheet` accepts optional `tripFilter: TripRecord?`; when set, Photos tab loads only assets captured within the trip date range; `JournalScreen` `_TripTile` passes `tripFilter: trip`
  - **Real-time scan discovery feed (Task 109)**: `ScanScreen` maintains `_liveNewCodes` list diffed per batch against pre-scan known codes; `_ScanningView` renders animated `_LiveCountryRow` widgets (newest first) with `FadeTransition` + `SlideTransition`; `_flagEmoji` helper added; `_liveNewCodes` reset on new scan
  - **Sequential DiscoveryOverlay for all new countries (Task 110, ADR-084)**: `DiscoveryOverlay` extended with `currentIndex`, `totalCount`, `onDone`, `onSkipAll` params; "Country N of M" indicator for multi sequences; primary CTA is "Next →" or "Done"/"Explore your map"; "Skip all" TextButton shown in multi-country sequences; `ScanSummaryScreen._pushDiscoveryOverlays()` iterates `newCodes.take(5)` with `await Navigator.push()` loop and `skipped` flag; `PopScope` approach rejected (fires on programmatic pops — ADR-084)
- **Mobile commerce entry points (M29 — Tasks 111–113, ADR-085)**:
  - **Scan summary "Get a poster" CTA (Task 111)**: `MerchCountrySelectionScreen` gains optional `preSelectedCodes: List<String>?`; lazy first-build init of `_deselected` from pre-selection param; `_NewDiscoveriesState` shows `TextButton` "Get a poster with your new discoveries →" above the primary CTA; opens `MerchCountrySelectionScreen(preSelectedCodes: widget.newCodes)` pre-filtered to new codes
  - **Map "Get a poster" menu item (Task 112)**: `_MapMenuAction.shop` added; `PopupMenuItem` "Get a poster" shown when `hasVisits`; positioned after "Share travel card"; pushes `MerchCountrySelectionScreen()` (all countries)
  - **30-day scan nudge banner (Task 113)**: `lastScanAtProvider = FutureProvider<DateTime?>` + `scanNudgeDismissedProvider = StateProvider<bool>` added to `providers.dart`; amber `_ScanNudgeBanner` shown in MapScreen Stack Column above `StatsStrip` when `hasVisits && lastScanAt > 30 days ago && !dismissed`; "Scan now" calls `onNavigateToScan`; X dismiss sets `scanNudgeDismissedProvider` true (per-session, not persisted)
  - Also fixed pre-existing parse error in `discovery_overlay.dart` (extra `)` left from PopScope removal in M32)
- **Firestore Trip Sync (M30 — Task 114)**: Trip sync infrastructure was pre-built during earlier milestones (`FirestoreSyncService.flushDirty()` trips path, `TripRepository.loadDirty/markClean`, wired at scan save / review save / app startup, 5 trip-flush tests, Firestore wildcard rules). M30 closed the only remaining gap: `apple_sign_in.dart` now accepts optional `tripRepo: TripRepository?` and forwards it to `flushDirty` so trips are flushed immediately post-Apple-sign-in. Web `/map` trip count deferred (mobile-first).
- **T-shirt mockup preview (M34 — Tasks 120–122, ADR-089)**:
  - `generatePrintfulMockup()` helper in `apps/functions/src/index.ts` — calls Printful v2 Mockup API (`POST /v2/mockup-tasks`), polls up to 20 s (10 × 2s), returns front-placement mockup URL or null on timeout/error; skips for poster variants (`printfulVariantId === 0`)
  - `createMerchCart` step 5: calls `generatePrintfulMockup` after Shopify cart is created; stores result in `MerchConfig.mockupUrl` (Firestore) and returns it in `CreateMerchCartResponse`; non-blocking — checkout always proceeds regardless of mockup outcome
  - `MerchConfig` TypeScript interface + `CreateMerchCartResponse` gain `mockupUrl: string | null`
  - `MerchVariantScreen`: `_mockupUrl` field stored from callable response; `_buildProductImageSlot` uses `_mockupUrl ?? _previewUrl` (mockup preferred; flag grid fallback); `BoxFit.contain` (was `cover`) for portrait shirt images; `_mockupUrl` cleared in `_resetPreview()`
- **Commerce sandbox validation (M33 — Tasks 115–119)**:
  - **Task 115 — Webhook `note_attributes` log**: `shopifyOrderCreated` webhook handler confirmed correct — parses `note_attributes` array and finds `{ name: "merchConfigId" }` attribute. Added `console.error` log of full `note_attributes` array at start of processing for Cloud Logging visibility during first test order.
  - **Task 116 — Firestore MerchConfig updates**: Verified correct — `status`, `shopifyOrderId`, `designStatus`, and `printfulOrderId` are all written at the correct points in `shopifyOrderCreated`. No code change needed.
  - **Task 117 — Printful draft order**: Confirmed no `"confirm": true` in Printful API v2 request body — orders are created as drafts by default (safe for sandbox testing). Added `console.error` log of Printful API response status and body for debugging.
  - **Task 118 — Post-purchase Firestore poll (ADR-087)**: `MerchVariantScreen` now stores `_merchConfigId` from `createMerchCart` response. `didChangeAppLifecycleState` no longer unconditionally pushes celebration; instead calls `_pollForOrderConfirmation()`, which polls `users/{uid}/merch_configs/{configId}` every 3s for up to 30s. Pushes `MerchPostPurchaseScreen` only when `status == 'ordered'`; shows neutral "We're processing your order..." dialog on timeout. `cloud_firestore` and `firebase_auth` imported in `merch_variant_screen.dart` (both packages already in `pubspec.yaml`).
  - **Task 119 — Variant mapping smoke test**: White/L → Printful ID 535 and Navy/M → Printful ID 527 confirmed correct in `printDimensions.ts`. No code change needed.
- **Trip Region Map (M35 — Tasks 123–126, ADR-090)**:
  - `regionPolygonsForCountry(String countryCode)` public function added to `packages/region_lookup` barrel; `RegionPolygon` exported from same barrel; `RegionLookupEngine.polygonsForCountry()` filters `_index.polygons` by `regionCode.startsWith('$countryCode-')` — synchronous, no I/O
  - `RegionRepository.loadRegionCodesForTrip(TripRecord trip)` — queries `photo_date_records` where `countryCode == trip.countryCode AND regionCode IS NOT NULL AND capturedAt BETWEEN startedOn AND endedOn`; returns distinct region codes via `.toSet().toList()` (Drift `isBetweenValues` pattern, mirrors `loadAssetIdsByDateRange`)
  - `TripMapScreen` (`lib/features/map/trip_map_screen.dart`) — full-screen `FlutterMap`; dark navy ocean background `Color(0xFF0D2137)`; two `PolygonLayer`s: amber visited (`Color(0xFFD4A017)`, 0.85α) + dark navy unvisited (`Color(0xFF1E3A5F)`, 0.9α); `FutureBuilder` for async region codes (shows `CircularProgressIndicator` while loading); `onMapReady: _fitBounds` calls `mapController.fitCamera(CameraFit.bounds(...))` from polygon vertex min/max; `AppBar` shows flag emoji + country name (title) + month range (subtitle)
  - `JournalScreen` trip card tap now pushes `TripMapScreen` via `Navigator.push(MaterialPageRoute)` (replaces `showModalBottomSheet` to `CountryDetailSheet`)
  - 28 region_repository tests; 48 region_lookup package tests; journal test updated to initialize region_lookup with minimal valid binary
- **Travel Card Generator (M37 — Tasks 130–133, ADR-092)**:
  - `TravelCard` domain model in `packages/shared_models/lib/src/travel_card.dart`; `CardTemplateType` enum (grid, heart, passport); `toFirestore()` serialisation; exported from `shared_models` barrel
  - `TravelCardService` (`lib/features/cards/travel_card_service.dart`) — writes `TravelCard` to `users/{uid}/travel_cards/{cardId}` subcollection; covered by existing wildcard Firestore rule; no new security rule needed
  - `GridFlagsCard`, `HeartFlagsCard`, `PassportStampsCard` (`lib/features/cards/card_templates.dart`) — all `AspectRatio(3/2)` `StatelessWidget`s accepting `List<String> countryCodes`; footer Row uses `Flexible` to prevent overflow at narrow widths; `HeartFlagsCard` uses gradient background + ❤️ watermark (ADR-092)
  - `CardGeneratorScreen` (`lib/features/cards/card_generator_screen.dart`) — `ConsumerWidget`; template picker row (3 amber-bordered tiles); `RepaintBoundary` in-screen preview; Share button captures PNG via `boundary.toImage(pixelRatio: 3.0)`, calls `TravelCardService.create()` fire-and-forget, opens `Share.shareXFiles`; "Print your card" button active (M38); empty state when 0 countries visited
- **Print from Card (M38 — Tasks 134–136, ADR-093)**:
  - `MerchConfig` TypeScript interface gains `cardId: string | null`; `CreateMerchCartRequest` gains `cardId?: string`; `createMerchCart` Function stores `cardId` (or null) on initial `MerchConfig` write — deployed to `roavvy-prod`
  - `MerchProductBrowserScreen` + `_ProductCard` + `MerchVariantScreen` each gain optional `cardId: String?` param; `MerchVariantScreen._generatePreview()` includes `'cardId': widget.cardId` in callable payload when non-null
  - `CardGeneratorScreen._onPrint()`: saves `TravelCard` fire-and-forget, navigates to `MerchProductBrowserScreen(selectedCodes: codes, cardId: cardId)` — skips `MerchCountrySelectionScreen`; "Print your card" button active (was disabled stub); guarded by `_sharing` flag
  - Existing `MerchCountrySelectionScreen` → `MerchProductBrowserScreen` path unchanged (no required params added); 478 tests passing
  - Stats screen "Create card" `OutlinedButton` — below stats panel, above achievements, visible when `visits.isNotEmpty`; pushes `CardGeneratorScreen`
  - Map "⋮" menu "Create card" item — `_MapMenuAction.createCard`; between "Share travel card" and "Get a poster"; visible when `hasVisits`; pushes `CardGeneratorScreen`
  - 9 widget tests in `test/features/cards/card_templates_test.dart`; 478 flutter tests passing (no regressions)
- **Achievement & Level-Up Commerce Triggers (M39 — Tasks 137–139, ADR-094)**:
  - `LevelUpRepository` (`lib/data/level_up_repository.dart`) — SharedPreferences-backed (`level_up_shown_v1` int key, default 1); `getLastShownLevel()` / `markShown(int)`; `levelUpRepositoryProvider` in `providers.dart`
  - `LevelUpSheet` (`lib/features/scan/level_up_sheet.dart`) — modal bottom sheet shown when user crosses an XP level; level emoji (8 mapped per label: 🌱🧭🗺️✈️🌍⚓🔭🏆); "You're now a [label]!" headline; "Create a travel card" `FilledButton` → pop + push `CardGeneratorScreen`; "Later" dismiss; `LevelUpSheet.show(context, levelLabel:)` convenience method (ADR-094)
  - `_checkAndShowLevelUp(VoidCallback next)` in `ScanSummaryScreen` — reads `xpNotifierProvider.state.level`; compares with `levelUpRepository.getLastShownLevel()`; marks shown + shows sheet when `currentLevel > lastShown`; chained in both `_handleDone` and `_handleCaughtUp` between milestone check and next step (ADR-094)
  - `MilestoneCardSheet` gains `onCreateCard: VoidCallback?` optional param; renders "Create a travel card" `FilledButton` above Share button when non-null; `showMilestoneCardSheet` gains matching `onCreateCard` param; wired from `ScanSummaryScreen._checkAndShowMilestone()` with navigation to `CardGeneratorScreen` (ADR-094)
  - `scan_summary_screen_test.dart`: `_StubXpNotifier` override added to `pumpSummary` to decouple from DB; `pumpAndSettle` added to "Back to map calls onDone" test; 5 unit tests for `LevelUpRepository`; 19 widget tests for `LevelUpSheet`; 506 flutter tests passing (no regressions)
- **Scan & Map Commerce Triggers (M40 — Tasks 140–141)**:
  - `ScanSummaryScreen` State A gains "Create a travel card →" `TextButton` above the existing "Get a poster" TextButton; navigates to `CardGeneratorScreen`; only shown when new countries found (M40 scan nudge)
  - `MapScreen` overflow menu "Get a poster" renamed → "Create a poster" (Phase 13b copy alignment; navigation to `MerchCountrySelectionScreen` unchanged); 2 new widget tests; 508 flutter tests passing (no regressions)
- **Scan Delight: Real-Time Discovery (M43 — Tasks 145–150, ADR-095)**:
  - **Confetti clipping fix (Task 145)**: `Stack` in `_NewDiscoveriesState.build()` gains `clipBehavior: Clip.none`; particles now fall across the full screen instead of being clipped at the top
  - **`_DiscoveryToastOverlay` (Task 146)**: `_ScanningView` converted from `StatelessWidget` to `ConsumerStatefulWidget`; `_DiscoveryToastBanner` slides in from top on each new country detected (`didUpdateWidget` length comparison); 2.5s hold then slides out; reduce-motion guard; toast controller disposed on `dispose()`
  - **`_ScanLiveMap` (Task 147)**: `ConsumerStatefulWidget` embedded in `_ScanningView`; fixed 220px `FlutterMap` (non-interactive); dark navy unvisited polygons + amber visited polygons; `MapController` auto-fits to each new country (debounced 800ms via cancel-and-restart `Timer`); returns `SizedBox.shrink()` when `polygonsProvider` is empty; `widget_test.dart` updated to override `polygonsProvider` with empty list
  - **Micro-confetti per discovery (Task 148)**: `ConfettiController` in `_ScanningViewState`; fires burst on each new country (cap 5, 500ms debounce); `ConfettiWidget` at top-center with `clipBehavior: Clip.none`; reduce-motion guard in `didUpdateWidget` and `build()`
  - **Post-scan flag timeline (Task 149)**: `_CountryList` replaced by `_FlagTimelineList`; each card shows 40px flag emoji, bold country name (`titleMedium`), continent label; rounded card background; staggered reveal reuses existing `_rowOpacities` animation; reduce-motion shows all cards at full opacity
  - **App-open scan prompt (Task 150)**: `DiscoverNewCountriesSheet` public `StatelessWidget` (camera icon, headline, "Scan now" `FilledButton`, "Later" `TextButton`); `_ScanPromptGate` `ConsumerStatefulWidget` (returns `SizedBox.shrink()`); added to `MapScreen` Stack; shown when `onboardingCompleteProvider == true && (lastScanAt == null || daysSince > 7)`; dismissed-today state persisted to SharedPreferences key `scan_prompt_dismissed_at`; 9 new widget tests (4 sheet tests + 5 gate integration tests); 511 flutter tests passing (no regressions)
- **Country Region Map (M36 — Tasks 127–129, ADR-091)**:
  - `CountryRegionMapScreen` (`lib/features/map/country_region_map_screen.dart`) — full-screen `FlutterMap`; dark navy ocean + two `PolygonLayer`s (amber visited at 0.85α, dark navy unvisited at 0.9α); visited region codes fetched async via `RegionRepository.loadByCountry(countryCode)`; camera auto-fits via `onMapReady: _fitBounds`; `AppBar` shows flag + country name + "N regions visited" subtitle (updated reactively via `.then()` on the same future)
  - Region tap interaction: `LayerHitNotifier<String>` on the visited `PolygonLayer<String>` (each polygon has `hitValue: regionCode`); `GestureDetector` wrapping the visited layer reads `_hitNotifier.value` on tap — non-null hit → show `MarkerLayer` label at tap coordinate; null hit → dismiss label; `_hitNotifier` disposed in `dispose()` (ADR-091)
  - `RegionBreakdownSheet` updated: each country `ExpansionTile` gains `trailing: IconButton(Icons.map_outlined)` that pops the sheet and pushes `CountryRegionMapScreen` via `Navigator.of(context)..pop()..push(...)`; expand-by-header-tap preserved
  - 7 new widget tests in `country_region_map_screen_test.dart`; 469 flutter tests passing (no regressions)

**`packages/country_lookup` — implemented and wired into the app:**
- Offline GPS → ISO 3166-1 alpha-2 resolution via point-in-polygon lookup
- Custom compact binary format (`ne_countries.bin`) with 1° grid spatial index — 1.2 MB, 233 countries, 1580 polygons
- `initCountryLookup(Uint8List)` + `resolveCountry(double, double)` + `loadPolygons()` public API
- Zero external dependencies; pure Dart
- 27 tests passing

## Domain Model

`packages/shared_models` defines the canonical domain types:

| Type | Role |
|---|---|
| `InferredCountryVisit` | Country detected from photo GPS by the scan pipeline |
| `UserAddedCountry` | Country explicitly added by the user |
| `UserRemovedCountry` | Permanent tombstone — suppresses inference forever |
| `EffectiveVisitedCountry` | Computed read model; one per code; never stored |
| `TravelSummary` | Aggregate stats: countryCount, earliestVisit, latestVisit |
| `TripRecord` | Inferred or manually-edited trip: id, countryCode, startedOn, endedOn, photoCount |
| `RegionVisit` | Sub-national region visit: tripId, countryCode, regionCode, firstSeen, lastSeen, photoCount |
| `PhotoDateRecord` | Per-photo record from scan pipeline: lat, lng, capturedAt, regionCode, assetId |
| `Achievement` | Achievement definition: id, title, description |
| `AchievementEngine` | Pure static `evaluate()` → Set of unlocked achievement IDs |

`CountryVisit`, `VisitSource`, and `effectiveVisits()` have been fully retired (Task 5).

## Key Files

```
apps/mobile_flutter/
  lib/main.dart                           ProviderScope with geodataBytes + DB overrides → RoavvyApp
  lib/app.dart                            RoavvyApp → _OnboardingGate → OnboardingFlow or MainShell
  lib/core/providers.dart                 Riverpod providers incl. onboardingCompleteProvider (ADR-018)
  lib/core/country_names.dart             kCountryNames static map (ADR-019)
  lib/features/shell/main_shell.dart      NavigationBar + IndexedStack (Map/Journal/Stats/Scan tabs, ADR-052)
  lib/features/map/map_screen.dart        ConsumerStatefulWidget; reads polygonsProvider + effectiveVisitsProvider; Stack with StatsStrip
  lib/features/map/stats_strip.dart       StatsStrip ConsumerWidget; watches travelSummaryProvider
  lib/features/map/country_detail_sheet.dart  Bottom sheet: visit details + manual add action
  lib/features/scan/scan_screen.dart      ConsumerStatefulWidget; scan + review flow
  lib/features/journal/journal_screen.dart  Trip list grouped by year; country flag; opens CountryDetailSheet
  lib/features/stats/stats_screen.dart    Stats panel + achievement gallery (ADR-052 Decision 3)
  lib/features/onboarding/onboarding_flow.dart  3-screen onboarding PageView; calls markOnboardingComplete()
  lib/features/scan/scan_summary_screen.dart    Post-scan summary (new discoveries + nothing-new states; confetti)
  lib/features/scan/achievement_unlock_sheet.dart  Achievement detail sheet; share via share_plus
  lib/features/visits/review_screen.dart  Review / edit / add / remove countries; pushes ScanSummaryScreen on save
  lib/core/notification_service.dart      NotificationService singleton; scheduleNudge / scheduleAchievementUnlock / requestPermission; pendingTabIndex ValueNotifier
  lib/photo_scan_channel.dart             startPhotoScan() / ScanBatchEvent / ScanDoneEvent / PhotoRecord
  lib/data/db/roavvy_database.dart        Drift table definitions (schema v8: visits + trips + regions + achievements + scan_meta)
  lib/features/map/photo_gallery_screen.dart  3-column thumbnail grid; full-screen viewer; ThumbnailFetcher typedef (ADR-061)
  lib/features/map/region_chips_marker_layer.dart  RegionChipsMarkerLayer + _RegionChip + _ArcPainter (ADR-069)
  lib/features/map/region_progress_notifier.dart   RegionProgressData, computeRegionProgress, regionProgressProvider, kRegionCentroids
  lib/features/map/region_detail_sheet.dart        showRegionDetailSheet — DraggableScrollableSheet with visited/unvisited lists (ADR-072)
  lib/features/map/target_country_layer.dart       TargetCountryLayer — breathing amber PolygonLayer for 1-away countries (ADR-070)
  lib/features/map/rovy_bubble.dart                RovyMessage, RovyTrigger, rovyMessageProvider, RovyBubble (ADR-071)
  lib/data/visit_repository.dart          VisitRepository — typed upsert/load/clear + dirty-load + mark-clean + loadAssetIds + loadAssetIdsByDateRange
  lib/data/trip_repository.dart           TripRepository — upsert, loadAll, loadByCountry, clear
  lib/data/region_repository.dart         RegionRepository — upsert, loadByCountry, loadByTrip, countUnique, clearAll, loadAll
  lib/data/achievement_repository.dart    AchievementRepository — upsertAll, loadAll, loadAllRows, loadDirty, markClean
  lib/data/bootstrap_service.dart         BootstrapService — re-derives trips + region visits from existing scan data
  lib/data/firestore_sync_service.dart    SyncService interface + FirestoreSyncService + NoOpSyncService
  lib/core/region_names.dart              kRegionNames — ISO 3166-2 → English name (~400 entries)
  ios/Runner/AppDelegate.swift            Swift PhotoKit bridge — EventChannel streaming, no CLGeocoder
  assets/geodata/ne_countries.bin         Offline country lookup binary (1.2 MB)

  lib/features/stats/region_breakdown_sheet.dart  RegionBreakdownSheet — DraggableScrollableSheet; grouped region visits by country; ExpansionTile per country (ADR-081)
  lib/features/map/discovery_overlay.dart  DiscoveryOverlay — full-screen amber gradient; currentIndex/totalCount/onDone/onSkipAll; sequential multi-country support (ADR-084)

  test/widget_test.dart                   ScanScreen widget + channel unit tests (ProviderScope)
  test/data/visit_repository_test.dart    VisitRepository unit tests (in-memory Drift DB)
  test/data/firestore_sync_service_test.dart  FirestoreSyncService unit tests (FakeFirebaseFirestore)
  test/features/map/map_screen_test.dart  MapScreen widget tests (ProviderScope)
  test/features/map/stats_strip_test.dart StatsStrip widget tests (4 tests)
  test/features/map/country_detail_sheet_test.dart  CountryDetailSheet widget tests
  test/features/map/photo_gallery_screen_test.dart  PhotoGalleryScreen + CountryDetailSheet Photos-tab tests (4 tests)
  test/features/map/region_chips_marker_layer_test.dart  RegionChipsMarkerLayer widget tests (4 tests)
  test/features/map/target_country_layer_test.dart        TargetCountryLayer widget tests (3 tests)
  test/features/map/rovy_bubble_test.dart                 RovyBubble widget tests (5 tests)
  test/features/shell/main_shell_test.dart  Navigation tab switching tests (6 tests)
  test/features/journal/journal_screen_test.dart  JournalScreen widget tests (11 tests)
  test/features/stats/stats_screen_test.dart      StatsScreen widget tests (8 tests)
  test/features/onboarding/onboarding_flow_test.dart  OnboardingFlow tests (8 tests)
  test/features/scan/scan_summary_screen_test.dart    ScanSummaryScreen tests (16 tests)
  test/features/scan/achievement_unlock_sheet_test.dart  AchievementUnlockSheet tests (8 tests)
  test/features/visits/                   ReviewScreen + TripEditSheet widget tests
  test/data/trip_repository_test.dart     TripRepository unit tests
  test/data/region_repository_test.dart   RegionRepository unit tests
  test/data/achievement_repository_test.dart  AchievementRepository unit tests
  test/data/bootstrap_service_test.dart   BootstrapService unit tests

packages/region_lookup/
  lib/region_lookup.dart                  initRegionLookup() / resolveRegion(lat, lng) / loadRegionPolygons()
  assets/geodata/ne_admin1.bin            Offline admin1 binary (3.5 MB, ISO 3166-2)
  test/region_lookup_test.dart            Region lookup unit tests

apps/web_nextjs/
  src/app/sign-in/page.tsx               Firebase Auth sign-in (email/password; ?next redirect-after-login; Suspense wrapper for useSearchParams)
  src/app/sign-up/page.tsx               Firebase Auth sign-up (createUserWithEmailAndPassword; client-side ≥8 char validation)
  src/app/shop/page.tsx                  Public /shop landing page (product cards; auth-aware CTA)
  src/app/map/page.tsx                   Authenticated world map (Leaflet + Firestore)
  src/app/share/[token]/page.tsx         Public share page (+ "Get Roavvy" CTA)
  src/app/privacy/page.tsx               Static privacy policy page
  src/lib/firebase/effectiveVisits.ts    Client-side effective-visits merge logic
```

## Architecture Decisions

| ADR | Decision | Status |
|---|---|---|
| 001 | iOS-first Flutter app with Swift MethodChannel bridge | Accepted |
| 002 | Photos never leave device; only derived metadata synced | Accepted |
| 003 | Drift SQLite as mobile source of truth; Firestore as sync target | Accepted — Drift built; Firestore sync deferred |
| 004 | `country_lookup` bundles geodata; zero network dependency | Accepted |
| 005 | Coordinate bucketing at 0.5° before geocoding | Accepted |
| 006 | Merge precedence: `manual` > `auto`; later `updatedAt` wins same-source | Accepted |
| 007 | `shared_models` zero-dependency, dual-language (Dart + TS) | Accepted — TS side not yet built |
| 008 | Three typed input kinds + one read model | Accepted |
| 009 | CLGeocoder → `country_lookup` | ✓ Done |
| 010 | Single IPC call → EventChannel streaming | ✓ Done |
| 011 | `shared_preferences` → Drift | ✓ Done |
| 012 | `fetchLimit` + `sinceDate` predicate in PhotoKit bridge | Accepted |
| 013 | `ScanSummary` in `shared_models`; `ScanStats` spike-only | Accepted |
| 014 | flutter_map as polygon rendering library | Accepted |
| 015 | Natural Earth 1:50m in custom compact binary | Accepted |
| 016 | Drift `inferred_country_visits`: one row per country code | Accepted |
| 017 | `country_lookup` exposes polygon geometry via `loadPolygons()` | Accepted |
| 018 | Riverpod as app-layer state management; core provider graph | Accepted — implemented |
| 019 | Country display names from static `kCountryNames` map | Accepted — implemented |
| 020 | Country tap via `MapOptions.onTap` + `resolveCountry()` | Accepted — implemented |
| 021 | Bottom nav shell; ConsumerWidget migration for MapScreen + ScanScreen | Accepted — implemented |
| 025 | Delete history entry point: `PopupMenuButton` overlay on `MapScreen` | Accepted — implemented |
| 026 | Firebase init in `main()`, parallel with geodata + DB | Accepted — implemented |
| 027 | Anonymous auth + `authStateProvider` StreamProvider | Accepted — implemented |
| 028 | Sign in with Apple credential upgrade; `credential-already-in-use` handled | Accepted — implemented |
| 029 | Firestore schema: `users/{uid}/{inferred_visits,user_added,user_removed}/{countryCode}` | Accepted — implemented |
| 030 | Sync architecture: fire-and-forget, silent failure, `NoOpSyncService` in tests | Accepted — implemented |
| 031 | Startup dirty-row flush on launch | Accepted — implemented |
| 032 | Explicit Firestore offline persistence settings | Accepted — implemented |
| 034 | Achievement domain model in `shared_models`; 8 achievements; `kAchievements` catalogue | Accepted — implemented |
| 035 | `kCountryContinent` map; 6 inhabited continents; territories mapped to administering country | Accepted — implemented |
| 036 | `unlocked_achievements` Drift table; `isDirty`/`syncedAt` columns | Accepted — implemented |
| 037 | Achievement evaluation at scan + review-save + startup flush write sites | Accepted — implemented |
| 038 | Achievement Firestore sync; SnackBar unlock notification | Accepted — implemented |
| 039 | Auth persistence: remove forced sign-out; add sign-out action to MapScreen overflow menu | Accepted — implemented |
| 040 | Travel card: `TravelCardWidget` + screenshot-to-share via iOS share sheet | Accepted — implemented |
| 041 | Share token: Firestore `share_tokens` collection; `/share/[token]` web route | Accepted — implemented |
| 042 | Privacy settings screen; share token revocation | Accepted — implemented |
| 043 | Account deletion: two-confirm dialog; purge auth + Firestore + local data | Accepted — implemented |
| 049 | `packages/region_lookup`: custom compact binary format for admin1 polygons | Accepted — implemented |
| 051 | `RegionVisit` + `region_visits` Drift table; schema v7; region resolution in scan pipeline | Accepted — implemented |
| 052 | 4-tab shell index contract (Map=0, Journal=1, Stats=2, Scan=3); no numeric literals outside `MainShell` | Accepted — implemented |
| 053 | Onboarding persistence: `hasSeenOnboardingAt` nullable TEXT in `ScanMetadata`; returning-user bypass via non-empty visits | Accepted — implemented |
| 054 | Scan summary navigation: ReviewScreen pushes ScanSummaryScreen; double-pop on done; no SnackBar in review-save path | Accepted — implemented |
| 055 | Celebration animations respect `MediaQuery.disableAnimationsOf`; confetti gated; row stagger capped at row 7 | Accepted — implemented |
| 056 | Local push notifications: `NotificationService` singleton; `scheduleAchievementUnlock` (immediate) + `scheduleNudge` (30-day `zonedSchedule`); `pendingTabIndex` ValueNotifier for tap routing; permission prompt after first new-country scan | Accepted — implemented |
| 057 | iPhone-only: `TARGETED_DEVICE_FAMILY = "1"`; `CFBundleDisplayName`/`CFBundleName` → "Roavvy" | Accepted — implemented |
| 061 | `ThumbnailFetcher` typedef injected in `PhotoGalleryScreen`; tests stub it to avoid `photo_manager` platform channel | Accepted — implemented |

## Test Coverage

| Layer | Count | Framework |
|---|---|---|
| `packages/shared_models` — merge, TravelSummary, AchievementEngine, TripInference | 56 | `dart test` |
| `packages/country_lookup` — lookup + loadPolygons | 27 | `dart test` |
| `packages/region_lookup` — region lookup | ~10 | `dart test` |
| `apps/mobile_flutter` — all flutter tests | 404 | `flutter test` |
| **Total** | **~487** | |

`flutter test` covers: channel unit tests, VisitRepository, ReviewScreen, ScanScreen, FirestoreSyncService, MapScreen, StatsStrip, CountryDetailSheet, MainShell (6), JournalScreen (11), StatsScreen (8), TripRepository, RegionRepository, AchievementRepository, BootstrapService, TripEditSheet, SignInScreen, AccountDeletionService, ShareTokenService, TravelCardWidget, providers, and achievement evaluation.

```bash
cd packages/shared_models && dart test
cd packages/country_lookup && dart test
cd packages/region_lookup && dart test
cd apps/mobile_flutter && flutter test
```

## Phase / Milestone Completion

| Dev Milestone | Product Phase | Status |
|---|---|---|
| M1–7 (Tasks 1–15) | Phase 1 — Core Scan & Map | ✅ Complete |
| M8 (Tasks 16–21) | Phase 2 — Firebase Auth + Firestore sync | ✅ Complete |
| M9 (Tasks 22–26) | Phase 2 — Achievements | ✅ Complete |
| M10 (Tasks 27–28) | Phase 3 — Travel card image + share sheet | ✅ Complete |
| M11 (Tasks 29–30) | Phase 3 — Web share page (`/share/[token]`) | ✅ Complete |
| M12 (Tasks 31–32) | Phase 2/3 Closeout — token revocation + account deletion | ✅ Complete |
| M13 (Tasks 33–37) | Phase 4 — Authenticated web map (`/sign-in`, `/map`) | ✅ Complete |
| M15 (Tasks 38–41) | Phase 5 — Trip intelligence (TripRecord, TripInference, TripRepository, TripEditSheet) | ✅ Complete |
| M16 (Tasks 42–46) | Phase 6 — Region detection (`region_lookup`, RegionVisit, RegionRepository, CountryDetailSheet) | ✅ Complete |
| M17 (Tasks 47–49) | Phase 7 — 4-tab shell, JournalScreen, StatsScreen + achievement gallery | ✅ Complete |
| M18 (Tasks 50–53) | Phase 8 — Celebrations & Delight (onboarding, scan summary, confetti, achievement sheet) | ✅ Complete |
| M19 (Tasks 54–58) | Phase 9 — App Store Readiness (iPhone-only, bundle identity, notifications, privacy policy, share CTA) | ✅ Complete (icon + App Store URL pending external deliverables) |
| M19A (Tasks 59–64) | Phase 9.5 — Quality & Depth (trip inference fix, region fix, confetti fix, interactive nav, PHAsset IDs, photo gallery) | ✅ Complete |
| M20A (Tasks 65–69) | Phase 10 — Commerce setup (Shopify store, API credentials, 40 product variants, Printful sync, API contracts doc) | ✅ Complete |
| M20 (Tasks 70–75) | Phase 10 — Commerce PoC (Firebase Functions scaffold + deploy, `createMerchCart` onCall, `shopifyOrderCreated` webhook, mobile commerce flow: country selection → product browser → variant picker → Shopify checkout) | ✅ Complete |

| M22 (Tasks 81–85) | Phase 11 Slice 1 — Visual States + XP (CountryVisualState, CountryPolygonLayer, XpRepository, XpNotifier, XpLevelBar, DiscoveryOverlay) | ✅ Complete |
| M23 (Tasks 86–89) | Phase 11 Slice 2 — Region Progress + Rovy (RegionChipsMarkerLayer, TargetCountryLayer, RegionDetailSheet, RovyBubble + triggers) | ✅ Complete |
| M24 (Tasks 91–93) | Phase 10 Commerce Polish — preview-first checkout, post-purchase celebration screen, merch order history | ✅ Complete |
| M25 (Tasks 94–96) | Phase 11 Slice 3 — Milestone Cards + Country Depth Colouring (depthFillColor, countryTripCountsProvider, MilestoneRepository, MilestoneCardSheet) | ✅ Complete |
| M26 (Tasks 97–99) | Phase 11 Slice 4 — Timeline Scrubber + Scan Reveal (yearFilterProvider, filteredEffectiveVisitsProvider, TimelineScrubberBar, ScanRevealMiniMap) | ✅ Complete |
| M14 (Task 100) | Phase 4 — Web Sign-Up (`/sign-up` page, email/password account creation, cross-links with `/sign-in`) | ✅ Complete |
| M27 (Tasks 101–102) | Phase 12 — Web Shop landing page (`/shop` public page, product cards, auth-aware CTA, `/map` Shop nav link, `/share/[token]` poster CTA, `/sign-in` redirect-after-login with open-redirect sanitisation) | ✅ Complete |

**All phases 1–11 are complete (M14 + M22–M26).** Remaining M19 blockers are external: 1024×1024 icon PNG from designer, App Store Connect listing for final URL. Deferred: Phase 6 continent overlay and city detection; Phase 11 soft social ranking; Phase 12 not yet defined.

**Commerce is live with end-to-end polish.** `createMerchCart` and `shopifyOrderCreated` deployed to `roavvy-prod`. Mobile flow: country selection → product browser → variant picker → "Preview my design" (generates flag grid image) → "Complete checkout →" (SFSafariViewController) → post-purchase celebration screen. Order history accessible via Privacy & account → My orders.
