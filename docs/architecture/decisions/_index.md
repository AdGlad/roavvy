<!-- Load this first. Read full ADR text only when a specific decision is relevant. -->

# ADR Index

| # | Title | Status | Key decision |
|---|---|---|---|
| 001 | iOS-first mobile app in Flutter with a Swift platform bridge | Accepted | Flutter app; PhotoKit via Swift MethodChannel |
| 002 | Photos never leave the device; only derived metadata synced | Accepted | Only `{countryCode, firstSeen, lastSeen}` crosses persistence boundary |
| 003 | Local SQLite (Drift) as mobile source of truth; Firestore as sync target | Accepted | All mutations write to Drift first; Firestore updated async |
| 004 | `packages/country_lookup` bundles geodata; zero network dependency | Accepted | Natural Earth polygons as Flutter asset; single pure function API |
| 005 | Coordinate bucketing at 0.5° before geocoding | Accepted | ~55 km grid deduplication; reduces geocoder calls by 90%+ |
| 006 | Merge precedence: `manual` beats `auto`; later `updatedAt` wins same-source | Accepted | Manual edits are permanent; tombstone suppresses future inference |
| 007 | `packages/shared_models` is a zero-dependency dual-language package | Accepted | Dart + TypeScript mirrors updated in the same PR |
| 008 | Three typed input kinds + one read model for the domain visit model | Accepted | `InferredCountryVisit`, `UserAddedCountry`, `UserRemovedCountry`, `EffectiveVisitedCountry` |
| 009 | CLGeocoder used in spike; to be replaced by `country_lookup` | Accepted (spike) | Spike-only; CLGeocoder requires network; superseded by ADR-004 |
| 010 | Scan result is a single aggregate IPC call in the spike | Accepted (spike) | Single `invokeMethod` returning aggregate map; to be replaced by streaming |
| 011 | `shared_preferences` used for spike persistence; Drift SQLite is the target | Accepted (spike) | Spike-only JSON blob; replaced by Drift |
| 012 | Per-scan `fetchLimit` and `sinceDate` predicate in PhotoKit | Accepted | `limit` + `creationDate > sinceDate` predicate in Swift bridge |
| 013 | `ScanSummary` placed in `shared_models`; `ScanStats` is spike-only | Accepted | `ScanSummary` owns pipeline metrics + `List<InferredCountryVisit>` |
| 014 | Map rendering library: flutter_map | Accepted | BSD-3 licence; `PolygonLayer` with Natural Earth source; no tiles |
| 015 | Country polygon data source: single Natural Earth 1:50m asset | Accepted | Custom compact binary; single asset serves both lookup and rendering |
| 016 | Drift schema: one row per country code for `inferred_country_visits` | Accepted | Upsert on re-scan; no per-run history |
| 017 | `country_lookup` exposes polygon geometry via `loadPolygons()` | Accepted | Public `loadPolygons()` added to package API surface |
| 018 | Riverpod as app-layer state management; core provider graph | Accepted | Core providers: geodataBytes, DB, visitRepository, polygons, effectiveVisits, travelSummary |
| 019 | Country display names from a static lookup map in the app layer | Accepted | `const Map<String, String> kCountryNames` in app layer; English-only |
| 020 | Country tap detection via MapOptions.onTap + resolveCountry() | Accepted | Offline point-in-polygon lookup on tap; no flutter_map hitValue |
| 021 | Open iOS Settings via MethodChannel; no `permission_handler` package | Accepted | `openSettings` on existing `roavvy/photo_scan` channel |
| 022 | `lastScanAt` stored in Drift `ScanMetadata` table | Accepted | Schema v2; singleton pattern; `VisitRepository` owns read/write |
| 023 | Scan limit increased from 500 to 2,000 photos | Accepted | `fetchLimit = 2000`; button copy updated |
| 024 | Task 13 post-scan result summary: inline in `ScanScreen` | Accepted | `_ScanResult` sealed class; `_NothingNew` vs `_NewCountriesFound` |
| 025 | Delete history entry point: `PopupMenuButton` overlay on `MapScreen` | Accepted | `Positioned` ⋮ button top-right; `AlertDialog` confirmation |
| 026 | Firebase SDK initialization: `Firebase.initializeApp()` in `main()` | Proposed | Awaited in `main()` alongside geodata + DB init; no `FutureProvider` |
| 027 | Anonymous Firebase Auth as the identity baseline | Proposed | `signInAnonymously()` on first launch; `authStateProvider` StreamProvider |
| 028 | Sign in with Apple as sole persistent identity provider; credential upgrade | Proposed | `sign_in_with_apple`; anonymous → Apple via `linkWithCredential` |
| 029 | Firestore schema: three subcollections under `users/{uid}` | Proposed | `inferred_visits`, `user_added`, `user_removed`; ISO 8601 strings |
| 030 | Sync architecture: `FirestoreSyncService.flushDirty`; fire-and-forget | Proposed | Called at write sites; `isDirty` flag; no background sync in Phase 1 |
| 031 | Startup dirty-row flush in `main()` closes the offline gap | Accepted | Fire-and-forget flush before `runApp()` if UID available |
| 032 | Firestore offline persistence must be explicitly configured | Accepted | `persistenceEnabled: true, cacheSizeBytes: UNLIMITED` set in `main()` |
| 033 | Delete travel history does not propagate to Firestore in Phase 1 | Accepted | Known gap; multi-device pull deferred; stale Firestore docs are inert |
| 034 | Achievement domain model and rules engine in `packages/shared_models` | Accepted | `AchievementEngine.evaluate()` pure function; 8 initial achievements |
| 035 | Continent mapping: static `const Map<String, String>` in `shared_models` | Accepted | `kCountryContinent`; 6 inhabited continents; territories mapped to admin country |
| 036 | Achievement Drift table: `unlocked_achievements` in schema v4 | Accepted | `AchievementRepository`; `isDirty`/`syncedAt` pattern |
| 037 | `flushDirty` signature: `AchievementRepository` as optional named parameter | Accepted | `{AchievementRepository? achievementRepo}` to avoid breaking callers |
| 038 | `TravelSummary.achievementCount` populated in app-layer provider | Accepted | `fromVisits()` returns 0; `travelSummaryProvider` overrides from repo |
| 039 | Auth session persistence: remove forced sign-out; shared Apple sign-in helper | Accepted | `apple_sign_in.dart` shared helper; sign-out in overflow menu |
| 040 | Travel card widget and share: `RepaintBoundary` capture + share_plus | Accepted | `Offstage` widget; `TravelCardWidget` pure `StatelessWidget`; `share_plus` |
| 041 | Share token: dedicated Drift table, UUID v4 via dart:math, denormalised Firestore | Accepted | `share_tokens` table (schema v5); `sharedTravelCards/{token}` Firestore doc |
| 042 | Privacy settings screen as entry point for sharing management and account deletion | Proposed | `PrivacyAccountScreen` push screen; "Privacy & account" overflow item |
| 043 | Account deletion: deletion sequence, auth.delete() ordering, sharedTravelCards rule fix | Proposed | `auth.delete()` first; `resource.data.uid` fix for delete rule |
| 044 | Web identity provider: email/password | Accepted | `signInWithEmailAndPassword`; no OAuth in M13 |
| 045 | `AuthContext` and `ProtectedRoute` retained; redirect target corrected | Proposed | Retain both; fix `setPersistence` timing race; `"/"` → `"/sign-in"` |
| 046 | Web Firestore access: one-shot `getDocs` from three subcollections | Proposed | `getDocs` not `onSnapshot`; `effectiveVisits()` TypeScript pure function |
| 047 | Trip record identity: natural key for inferred trips; prefixed random hex for manual | Accepted | `"${countryCode}_${startedOn.toIso8601String()}"` for inferred |
| 048 | `photo_date_records` table design; Drift schema v6; bootstrap strategy | Accepted | Composite PK `{countryCode, capturedAt}`; `bootstrapCompletedAt` on ScanMetadata |
| 049 | `packages/region_lookup`: standalone offline admin1 polygon lookup package | Accepted | New package; `initRegionLookup` + `resolveRegion`; independent of `country_lookup` |
| 050 | `regionCode` is derived metadata; extends ADR-002 persistence scope | Accepted | `regionCode` allowed in `photo_date_records`; never in Firestore yet |
| 051 | Region resolution uses 0.5° bucketed coordinates; schema v7 is single atomic migration | Accepted | Same bucketed point for country + region; consistency guaranteed |
| 052 | 4-tab navigation shell: tab index contract and data access | Accepted | Map=0, Journal=1, Stats=2, Scan=3; `effectiveVisitsProvider` in Journal |
| 053 | Onboarding persistence: `hasSeenOnboarding` on `ScanMetadata`; schema v8 | Accepted | Nullable TextColumn; `onboardingCompleteProvider` FutureProvider |
| 054 | Scan summary: delta computation pattern and navigation contract | Accepted | Pre-save snapshot via `ref.read`; post-save via `ref.refresh`; `VoidCallback onDone` |
| 055 | Celebration animation: `confetti` package with size gate | Accepted | `confetti` pkg with 200KB binary gate; stagger via `AnimationController` |
| 056 | Local push notifications: `flutter_local_notifications`; prompt timing; tap-routing | Accepted | On-device scheduling; prompt after first successful scan; `ValueNotifier` routing |
| 057 | iPhone-only targeting for M19 App Store submission; bundle identity fix | Accepted | `TARGETED_DEVICE_FAMILY = "1"`; `CFBundleDisplayName = "Roavvy"` |
| 058 | Trip inference: geographic sequence model replaces 30-day gap clustering | Accepted | Chronological run-length encoding; one trip per contiguous same-country run |
| 059 | Confetti: ScanSummaryScreen push moved from ReviewScreen to ScanScreen | Accepted | ScanScreen owns scan lifecycle; ReviewScreen is pure editor |
| 060 | PHAsset local identifiers stored in local SQLite; never in Firestore | Accepted | Nullable `assetId TEXT` on `photo_date_records` (schema v9) |
| 061 | Photo gallery: `photo_manager` package for on-device thumbnail fetch | Accepted | `AssetEntity.thumbnailDataWithSize()`; fully offline |
| 062 | Commerce architecture: backend-mediated Shopify integration | Accepted | Firebase Functions orchestration layer; `MerchConfig` in Firestore |
| 063 | Print-on-demand partner: Printful | Accepted | Direct API for generated orders from M21 (not Shopify app) |
| 064 | Firebase Functions v2: project structure, function types, Storefront token strategy | Accepted | `onCall` for createMerchCart; `onRequest` for webhook; permanent Storefront token |
| 065 | Per-order custom flag image generation pipeline | Accepted | Two-stage model: generate at createMerchCart time; webhook validates and submits |
| 066 | `CountryPolygonLayer` replaces imperative polygon building in `MapScreen` (M22) | Accepted | Static + animated PolygonLayer split; `ConsumerStatefulWidget` |
| 067 | `recentDiscoveriesProvider` uses SharedPreferences with lazy async init (M22) | Accepted | `StateNotifierProvider`; async prefs load; 24h TTL |
| 068 | `DiscoveryOverlay` pushed from `ScanSummaryScreen` on dismissal (M22) | Accepted | Option 3: overlay after summary; `popUntil('/')` from overlay CTA |
| 069 | `RegionChipsMarkerLayer` uses `MarkerLayer` with zoom gating via `MapCamera` (M23) | Accepted | `MarkerLayer`; zoom < 4.0 → empty; `GestureDetector` chip |
| 070 | `TargetCountryLayer` uses native `PolygonLayer` with solid amber border and breathing opacity | Accepted | Amber border + `AnimationController` breathing; no `CustomPainter` |
| 071 | `rovyMessageProvider` is a `StateProvider<RovyMessage?>` (M23) | Accepted | Single-message store; null = dismissed; replace-not-queue |
| 072 | `RegionDetailSheet` is a top-level function calling `showModalBottomSheet` (M23) | Accepted | Pure function `showRegionDetailSheet`; no provider dependency in sheet |
| 073 | Two-stage checkout: `createMerchCart` called at preview time; `checkoutUrl` cached | Accepted | Cart created on "Preview my design" tap; cached URLs used for checkout |
| 074 | Post-purchase screen triggered by `AppLifecycleState.resumed` (M24) | Accepted | `WidgetsBindingObserver`; optimistic celebration screen |
| 075 | `MerchOrdersScreen` reads Firestore directly via `FutureProvider`; no repository layer | Accepted | Co-located `FutureProvider`; no `MerchRepository` |
| 076 | `yearFilterProvider` is a global `StateProvider<int?>` in `providers.dart` (M26) | Accepted | Null = all time; int = show countries ≤ that year |
| 077 | `ScanRevealMiniMap` uses `Timer.periodic` + `Set<String>` to sequence polygon pop-in | Accepted | 400ms timer; two PolygonLayers; instant per-country appearance |
| 078 | `/sign-in` redirect-after-login uses `?next` query param; sanitised | Accepted | `next` must start with `/`, not `//`, not contain `://` |
| 079 | Web `/shop/design` calls `createMerchCart` via Firebase Functions JS SDK | Accepted | `getFunctions` from `init.ts`; `window.location.href` for checkout redirect |
| 080 | Map dark-ocean colour scheme (M32) | Accepted | Dark navy ocean; gold depth tiers; unified dark theme |
| 081 | `tripListProvider` FutureProvider replaces `late final` future in JournalScreen (M32) | Accepted | `ref.watch(tripListProvider)`; invalidated after scan save and clearAll |
| 082 | Trip photo date filtering via optional `tripFilter` on `CountryDetailSheet` (M32) | Accepted | `loadAssetIdsByDateRange`; optional `TripRecord? tripFilter` parameter |
| 083 | Real-time scan discovery feed: `_newlyFoundCodes` list in `ScanScreen` (M32) | Accepted | Per-batch diff against preScanCodes; `AnimatedList` country reveal |
| 084 | Sequential `DiscoveryOverlay` for multiple new countries; cap at 5 (M32) | Accepted | Async `for`-loop; `await push`; "Skip all" via `onSkipAll` callback |
| 085 | M29 commerce entry point decisions | Accepted | `preSelectedCodes` init pattern; `scanNudgeDismissedProvider`; banner placement |
| 086 | Shopify credential model: OAuth Client Credentials for admin token | Accepted | Short-lived admin token for provisioning; permanent Storefront token in `.env` |
| 087 | Post-purchase payment confirmation via Firestore poll (M33) | Accepted | 3s/30s poll loop on `MerchConfig.status == 'ordered'`; not optimistic |
| 088 | Payment provider strategy: manual method for sandbox; Shopify Payments for production | Accepted | Manual "Test Payment" for dev; Shopify Payments + KYC before public launch |
| 089 | Printful Mockup API: v2 async generation within `createMerchCart` (M34) | Accepted | `POST /v2/mockup-tasks`; poll 10×2s; non-blocking fallback to null |
| 090 | Trip Region Map: synchronous polygon access + FutureBuilder for visited codes (M35) | Accepted | `RegionLookupEngine.polygonsForCountry()` sync; `FutureBuilder` for visited codes |
| 091 | Country Region Map: hit-notifier tap detection + tap-point label anchor (M36) | Accepted | `LayerHitNotifier<String>`; tap coordinate as label anchor |
| 092 | Travel Card Generator: Firestore-only storage, timestamp ID, in-screen capture | Accepted | `users/{uid}/travel_cards`; timestamp ID; `RepaintBoundary` capture |
| 093 | Print from Card: optional `cardId` on `createMerchCart` + `MerchConfig` | Accepted | Optional `cardId` threaded to callable payload; backwards-compatible |
| 094 | Achievement & Level-Up Commerce Triggers: level detection and sheet navigation | Accepted | `LevelUpRepository` SharedPreferences; `VoidCallback next` chain |
| 095 | M43 Scan Delight: widget conversions, in-scan toast/map/confetti, app-open prompt | Accepted | `_ScanningView` → `ConsumerStatefulWidget`; `_ScanPromptGate` for app-open modal |
| 096 | Passport Stamp Card: CustomPainter rendering, deterministic layout, richer card input | Accepted | `CustomPainter` stamps; `PassportLayoutEngine`; `StampData` from `TripRecord` |
| 097 | Passport Stamp Realism Upgrade: Ink Simulation, Pressure Distortion, Authentic Layout | Accepted | 12 stamp styles; noise opacity mask; `BlendMode.multiply` paper composite |
| 098 | Flag Heart Card: True Heart-Mask Layout Engine with Dynamic Grid Density | Accepted | Parametric heart equation; `flutter_svg`; SVG flag assets bundled |
| 099 | Commerce Template & Placement: `CardImageRenderer`, in-screen template picker | Accepted | `CardImageRenderer.render()`; template picker in `MerchVariantScreen` |
| 100 | ArtworkConfirmation: user-scoped Firestore subcollection, SHA-256 image hash | Accepted | `users/{uid}/artwork_confirmations`; `CardRenderResult({bytes, imageHash})` |
| 101 | Branding Layer: `CardBrandingFooter` Widget, dateLabel pass-through | Accepted | `CardBrandingFooter` widget; Heart canvas label replaced with Widget overlay |
| 102 | M50 Layout Quality: Grid Adaptive Tile Size and Passport Print-Safe Mode | Accepted | `gridTileSize()` clamp formula; `PassportLayoutResult` with `wasForced` |
| 103 | M51 Artwork Confirmation Flow: Screen, Navigation, Re-Confirmation | Accepted | Pre-render in `CardGeneratorScreen`; `ArtworkConfirmResult` pop return |
| 104 | M52 Timeline Card Template: Layout Engine, Widget, and Enum Extension | Accepted | `CardTemplateType.timeline`; `TimelineLayoutEngine` in app layer |
| 105 | M53 Mockup Approval: Screen Placement, `artworkImageBytes` Threading | Accepted | Approval before cart creation; `MockupApprovalScreen` push route |
| 106 | M54 Gap Closure: Artwork Bytes Reuse, Confirmation Archival, UID-Null UX | Accepted | Reuse confirmed bytes for Timeline; archive superseded confirmations |
| 107 | M55 Local Product Mockup: Single unified screen, on-device compositing | Accepted | `LocalMockupPreviewScreen` replaces three screens; `LocalMockupPainter` |
| 108 | M56 Celebration Queue: Sequential Navigation via Async Loop | Proposed | Remove 5-overlay cap; `kCelebrationGapMs = 300` constant |
| 109 | M56 Celebration Audio: `audioplayers` Package, App-Layer Only | Proposed | `audioplayers` pkg; ambient mode; one player per `DiscoveryOverlay` |
| 110 | M56 Incremental Scan State: `lastScanAt` is the Boundary Marker | Proposed | `null` = no full scan; non-null = next sinceDate; pre-scan timestamp |
| 111 | M56 Pastel Region Colour Palette: Static Ordered List, Index-Mod Assignment | Proposed | 12 pastel colours; alphabetical regionCode sort; index-mod assignment |
| 112 | M56 Card Design Image Consistency: Single Pre-Render and Deterministic Param Threading | Accepted | Pre-render before `ArtworkConfirmationScreen`; `_CardParams` includes `heartOrder` |
| 113 | M57 Passport Stamp Density and Preview Consistency | Accepted | Two stamps per trip; cap 200; dynamic radius; `forPrint=true` in preview |
| 114 | M58 2.5D T-Shirt Mockup: Asset Format, Flip Animation, Screen Layout | Accepted | 1200×1600 RGBA PNG; `_ShirtFlipView`; `DraggableScrollableSheet` options |
| 115 | M59 Photoreal Shirt Mockup: Split-Image Source Cropping and 3-Layer Compositing | Accepted | `srcRectNorm` for front/back crop; 3-layer multiply blend |
| 116 | M60 Globe Map Orthographic Projection and Gesture Navigation | Accepted | Pure-Dart projection; `-delta.dy` lat, `+delta.dx` lng; antimeridian split |
| 117 | M61 Passport Card Refinement: Safe Zones, Color Customization, Rendering Consistency | Accepted | Title + branding safe zones; user stamp colour; `TextPainter` direct draw |
| 118 | M61 Grid Card Upgrade: Shared Title State and SVG Layout Engine | Accepted | `TravelCard.titleOverride`; geometric grid solver; `FlagImageCache` |
| 119 | M62 Front Chest Ribbon Design: Dual-Sided Merch Architecture | Accepted | `FrontRibbonCard`; front ribbon + back card dual artwork |
| 119b | M62 Create Card UX Redesign: Two-Stage Flow, Carousel Picker | Accepted | `CardTypePickerScreen` + `CardEditorScreen`; `HeartLayoutEngine.sortCodes` public |
| 120 | M63 Dual-Placement T-Shirt: Multi-File Print and Mockup Architecture | Accepted | `frontCardBase64` + `backCardBase64`; `generateDualPlacementMockups`; dual print files |
| 121 | M64 Stamp Color Selection Moved to T-Shirt Design Stage | Accepted | Remove color picker from editor; `PassportColorMode` in merch layer; auto-suggest rules |
| 122 | M65 Printful Dual-Mockup Client: Store and Display Both Placement URLs | Accepted | `_frontMockupUrl` + `_backMockupUrl`; explicit status enum; no silent mixing |
| 123 | M69 Celebration Globe: Animated Globe Inside DiscoveryOverlay | Accepted | `CelebrationGlobeWidget` with `GlobeProjection`; no third-party 3D lib |
| 124 | M67 Grid and Heart SVG Flag Loading: ChangeNotifier-Based Async Repaint | Accepted | `StatefulWidget` + `ChangeNotifier repaint:`; async `loadSvgToCache()`; emoji fallback on first frame |
| 125 | M70 Passport Stamp UX: Portrait Lock, Shuffle Seed, Year-Free Titles | Accepted | Portrait-only passport; nullable shuffle seed; year removed from title generation |
| 126 | M72 Country Celebration Carousel: Single-Route Multi-Country Flow | Accepted | `CountryCelebrationCarousel` replaces N-deep nav stack; dot progress indicator |
| 134 | M89 On-Device Hero Image Detection Pipeline | Accepted | Vision `VNClassifyImageRequest`; async post-scan; labels normalised to Roavvy vocabulary; `assetId` local-only (extends ADR-002); Drift schema v11 |
| 135 | M90 Hero Image UI: MethodChannel Thumbnail Fetch + Reactive HeroImageView | Accepted | `roavvy/thumbnail` channel; NSCache; `HeroImageView`; override picker preserves isUserSelected guard |
