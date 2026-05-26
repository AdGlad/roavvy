# Backlog — Active Milestones

> Upcoming work only. Completed milestones live in `docs/dev/backlog.md`.
> Mobile milestones take priority over web (see memory: feedback_mobile_first).

---

## Next up (mobile-first order)

### M132 — Live Scan Replay
**Goal:** Globe replay widget opens immediately when scan starts; receives country/heritage/achievement events in real time as photos are detected; drains to `ScanSummaryScreen` when scan completes and queue is empty.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M131 ✅, M130 ✅
**Scope in:** `ReplayEvent` sealed hierarchy; `ReplayDataSource` interface; `HistoricalReplayDataSource`; `LiveScanReplayDataSource`; `LiveScanReplayController`; `GlobeReplayWidget` dual-mode (script vs dataSource); `scan_screen.dart` concurrent scan + replay wiring.
**Full plan:** `docs/dev/milestones/m132-live-scan-replay.md`
**Status:** ✅ Complete (2026-05-26)

---

### M131 — Cinematic Scan Replay (GlobeReplayWidget)
**Goal:** After scan completes with new countries, build a `TravelReplayScript` from inferred trips and push `GlobeReplayWidget` to replay the travel history cinematically before showing `ScanSummaryScreen`.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M130 ✅, M108 ✅
**Scope in:** `travel_replay_engine.dart` (`ReplayHeritageEvent`; `TravelReplayScript.visitedHeritageSiteCoords`); `replay_overlay_widgets.dart` (`ReplayHeritageOverlay`); `globe_replay_widget.dart` (`onScanComplete` param; heritage pulse); `scan_screen.dart` (`_buildScanReplayScript()`, push on new countries found).
**Full plan:** `docs/dev/milestones/m131-scan-cinematic-replay-sequence.md`
**Status:** ✅ Complete (2026-05-26)

---

### M130 — Scan: Cinematic Pacing & Orchestration Engine
**Goal:** Decouple scan detection speed from celebration delivery speed. Introduce a discovery event buffer → priority queue → cinematic presentation engine. P1–P4 priority tiers control timing (1.2–5s windows), a presentation lock prevents overlapping celebrations, four audio categories (passport stamp, heritage chime, achievement rise, orchestral swell) route by event type, and a queue depth indicator shows queued discoveries.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M122 ✅, M123 ✅, M125 ✅
**Scope in:** `_DiscoveryEvent` sealed class + `_PriorityQueue`; `_CinematicPresentationEngine` drain loop + presentation lock; `_AudioCategory` enum + 4-category audio routing; queue depth indicator; UNESCO heritage distinct presentation; P4 cooldown (max 1 per 6–8s); `_ScanPhase` progressive intensity; mute toggle.
**Full plan:** `docs/dev/milestones/m130-scan-cinematic-pacing-orchestration.md`
**Status:** ✅ Complete (2026-05-25)

---

### M129 — Heritage Pulse on Main Map
**Goal:** Show UNESCO World Heritage Site locations as ambient pulsing amber dots on the main map globe outside of scan; visited sites pulse brightly, unvisited sites appear as dim static dots; toggle chip persists in SharedPreferences.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M119 ✅, M126 ✅
**Scope in:** `GlobePainter` — `visitedHeritageSiteCoords` + `unvisitedHeritageSiteCoords` params; map screen heritage toggle chip + animation controller; `VisitRepository` visited WHS query; heritage count in map stats footer.
**Full plan:** `docs/dev/milestones/m129-heritage-pulse-main-map.md`
**Status:** ✅ Complete (2026-05-25)

---

### M128 — Heritage Scan Enhancements
**Goal:** Three focused heritage improvements during scan: persistent progress bar (N/1,157 sites), tappable globe dots with site name tooltip, and colour-coded dots (cultural = amber, natural = green).
**Phase:** 25 — Scan UX Transformation
**Depends on:** M123 ✅, M126 ✅
**Scope in:** `_liveHeritageSites: List<VisitedHeritageSite>` replaces coord-only list; `GlobePainter` split into `culturalSiteCoords` + `naturalSiteCoords` (amber/green); `_ScanStatsBar` animated `LinearProgressIndicator`; `_ScanGlobeWidget` tap-to-tooltip + `_HeritageTooltip` widget.
**Full plan:** `docs/dev/milestones/m128-heritage-scan-enhancements.md`
**Status:** ✅ Complete (2026-05-25)

---

### M127 — Scan Summary Screen
**Goal:** After scan completes, show a staged "Spotify Wrapped"-style reveal screen: new countries (flag chips), new continents, heritage sites found, achievements unlocked, trip count — with confetti and staggered animation.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M121 ✅, M122 ✅, M123 ✅, M125 ✅, M126 ✅
**Scope in:** `ScanSummaryScreen` (existed); added `newHeritageSiteNames` + `totalTripCount` params; `_HeritageSitesSection` widget; "across N trips" hero subtitle; threaded from `scan_screen.dart` completion handler.
**Full plan:** `docs/dev/milestones/m127-scan-summary-screen.md`
**Status:** ✅ Complete (2026-05-25)

---

### M126 — Scan: Globe Heritage Pulse
**Goal:** Render animated gold/amber pulse dots at UNESCO World Heritage Site GPS coordinates on the spinning globe when sites are discovered during a scan.
**Phase:** 25 — Scan UX Transformation
**Depends on:** M125
**Scope in:** `GlobePainter` — `heritageSiteCoords` + `heritagePulseValue` params; `_ScanGlobeWidget` — `heritageSiteCoords` prop + `_heritagePulseCtrl`; thread coords from `_ScanScreenState` through `_ScanningView`.
**Full plan:** `docs/dev/milestones/m126-scan-globe-heritage-pulse.md`
**Status:** ✅ Complete (2026-05-25)

---

### M125 — Scan: Live Achievement Toasts & Live Trip Count
**Goal:** Fire a deep-purple "Achievement Unlocked" toast when a country-count threshold is crossed during scan; add live inferred trip count to the stats bar.
**Phase:** 25 — Scan UX Transformation
**Scope in:** `_AchievementToastBanner`; `_toastedAchievements` set; `_liveTripCount` state field + `inferTrips()` per batch; `_ScanStatsBar` trip segment; `_ScanningView` props.
**Full plan:** `docs/dev/milestones/m125-scan-live-achievements-trip-count.md`
**Status:** ✅ Complete (2026-05-25)

---

### M123 — Scan: Live Heritage Discovery & Stats Totals
**Goal:** Close remaining gaps from M121/M122 design brief — stats bar with "14/244 countries · 3/7 continents · 7/1,223 heritage sites" totals; dedicated gold-themed heritage discovery toast ("🏛 Acropolis of Athens") fires 400ms after country toast when new UNESCO site found.
**Phase:** 25 — Scan UX Transformation
**Scope in:** `WorldHeritageLookupService.totalSiteCount` getter; `_liveHeritageCount` state field; `_ScanStatsBar` totals; `_HeritageToastBanner` widget; `_ScanningView` heritage toast wiring.
**Scope out:** Sound design, achievements during scan, gold pulse on map, heritage progress widget.
**Full plan:** `docs/dev/milestones/m123-scan-live-heritage-stats-totals.md`
**Status:** ✅ Complete (2026-05-25)

---

### M122 — Scan: Momentum & Discovery Density
**Goal:** Evolve the scan screen from celebration-first to continuous forward momentum. Convert horizontal discovery cards to compact vertical chips (newest-first, 40 px rows). Add three-tier confetti (micro/medium/full keyed to country/continent/major milestone). Add live stats bar (countries · continents · photos) visible during scanning. Compact scan mode selector. Toast rate-limiting for rapid discoveries.
**Phase:** 25 — Scan UX Transformation
**Scope in:** `scan_screen.dart` — `_DiscoveryChip` replaces `_DiscoveryCard`, `_CelebrationLevel` confetti tiers, `_ScanStatsBar`, compact `SegmentedButton` labels, toast rate-limit.
**Scope out:** Heritage during scan, sound design, achievements during scan, trip count live display.
**Full plan:** `docs/dev/milestones/m122-scan-momentum-discovery-density.md`
**Status:** ✅ Complete (2026-05-25)

---

### M121 — Scan: Emotional Discovery Experience
**Goal:** Transform the scan screen from a technical progress display into an emotional travel discovery experience. Replace split country-list/stamp panel with a live horizontal discovery feed; expand globe to ~55 % of screen; replace photo-count copy with phase-aware discovery language; add first-country cinematic overlay; enhance discovery toast with contextual first-visit year.
**Phase:** 25 — Scan UX Transformation
**Scope in:** `scan_screen.dart` only — layout, copy, new `_DiscoveryFeed`/`_DiscoveryCard` widgets, `_FirstCountryCinematic` overlay, `_DiscoveryEntry` data class, enhanced toast, emotional empty states.
**Scope out:** Rovy mascot, Travel Identity Score, background scan, audio, Memory Pulse during scan, ScanSummaryScreen.
**Full plan:** `docs/dev/milestones/m121-scan-emotional-discovery-experience.md`
**Status:** ✅ Complete (2026-05-25)

---

### M117 — Terms & Conditions Acceptance Gate
**Goal:** Display and require acceptance of Roavvy T&Cs before a user can access the app. Persisted via SharedPreferences. Re-prompts when `kCurrentTermsVersion` is bumped.
**Phase:** 24 — Legal & Compliance
**Scope in:** `legal/terms_service.dart`, `legal/terms_screen.dart`, `app.dart` (_OnboardingGate), `providers.dart` (termsAcceptedProvider), `privacy_account_screen.dart`, `account_deletion_service.dart`.
**Full plan:** `docs/dev/milestones/m117-terms-and-conditions-acceptance-gate.md`
**Status:** ✅ Complete (2026-05-23)

---

### M110 — Dynamic Achievements & Replay Stats Overlay
**Goal:** Enhance cinematic travel replay with contextual achievement reveal moments and travel stats overlays. Achievements appear at the leg where their threshold is crossed; stats appear every 5 legs; a summary frame with Share and Create T-Shirt CTAs closes the experience.
**Phase:** 23 — Globe Experiences
**Depends on:** M109
**Scope in:** `ReplayOverlayEvent` sealed class (`ReplayAchievementEvent`, `ReplayStatEvent`); `TravelReplayScript.overlayEvents`/`summaryStats`; `ReplayTimelineBuilder` (pure precomputed achievement detection + stat placement); `ReplayPhase.overlay` + controller overlay sequencer; `ReplayAchievementOverlay` + `ReplayStatOverlay` widgets; `ReplaySummaryScreen` with count-up stats + Replay/Share/T-Shirt CTAs; wiring in `GlobeReplayWidget` + `replay_entry_sheet.dart`.
**Scope out:** New achievements; hero image display during overlay; audio; video export; continent entry UI.
**Full plan:** `docs/dev/milestones/m110-replay-stats-achievement-overlay.md`
**Status:** ✅ Complete

### M111 — Cinematic Audio & Replay Timing System
**Goal:** Transform replay into a cinematic travel memory experience through layered sound design, distance-aware pacing, refined easing curves, and emotional timing orchestration. Short arcs feel snappy; long intercontinental arcs feel sweeping and dramatic. Audio (whoosh, arrival chime, achievement swell, end cue) synchronises with replay events. Full mute and reduced-motion support.
**Phase:** 23 — Globe Experiences
**Depends on:** M110
**Scope in:** `ReplayPacingRules` (haversine arc distance → `LegPacing`); `LegPacing` data class; `TravelReplayScript.legPacing`; `TravelReplayController` pacing integration + easing upgrades + `reducedMotion` flag; `ReplayAudioController` (`audioplayers` wrapper; preload, play, mute); audio asset registration (5 OGG slots); audio synchronisation via existing `onLegStart`/`onLegComplete` hooks; globe fade on done; summary screen easing/timing improvements; mute toggle in top bar.
**Scope out:** Final production audio assets (placeholder OGGs used); hero image thumbnails during overlay; video export; Android/web; replay themes/music packs (architecture supports future extension).
**Full plan:** `docs/dev/milestones/m111-cinematic-audio-replay-timing.md`
**Status:** ✅ Complete (2026-05-11)

---

### M109 — Accurate Departure & Arrival Coordinates
**Goal:** Replace country-centroid start/end points in cinematic travel replay with actual GPS coordinates from trip photos — using the last valid GPS image of the departing segment and the first valid GPS image of the arriving segment. Fallback chain: nearest GPS image → city coordinate → country centroid.
**Phase:** 23 — Globe Experiences
**Depends on:** M108
**Scope in:** Extend `TravelLeg` with `fromLat/fromLng/toLat/toLng` + `resolvedFrom`/`resolvedTo` getters; update `TravelReplayScriptBuilder` GPS extraction helpers; update `GlobeReplayPainter` and `TravelReplayController` to use resolved coordinates; unit tests for GPS and fallback scenarios.
**Scope out:** City coordinate database (level-2 fallback deferred); per-photo replay mode; video/audio hooks; Android/web.
**Full plan:** `docs/dev/milestones/m109-accurate-departure-arrival-coordinates.md`
**Status:** ✅ Complete (2026-05-11)

---

### M108 — Cinematic Travel Replay System
**Goal:** Build a cinematic travel replay on the existing Flutter globe. Animates travel legs between countries with globe rotation, zoom, great-circle arc, moving marker, and arrival highlight. Supports trip / year / all-time / continent modes.
**Phase:** 23 — Globe Experiences
**Depends on:** M100
**Scope in:** `travel_replay_engine.dart` (TravelLeg, TravelReplayScript, TravelReplayScriptBuilder); `travel_replay_controller.dart` (ReplayPhase state machine, AnimationController per phase); `globe_replay_painter.dart` (arc, marker, pulse ring, back-face culling); `globe_replay_widget.dart` (composites existing globe + painter); `replay_entry_sheet.dart` (mode picker bottom sheet); `kCountryCentroids` map; map screen entry point.
**Scope out:** Video/GIF export; audio layer; continent entry UI; photo animation.
**Status:** ✅ Complete (2026-05-10).

---

### M106 — Flag Grid Quality, Layout Options, and Packed Row Default
**Goal:** Improve flag grid artwork so flags preserve their aspect ratios, avoid cropping, and fit cleanly in portrait/landscape outputs. Add three selectable layout algorithms; default all generation to Packed Row.
**Phase:** 22 — Merch Platform / Visual Quality
**Depends on:** M105
**Scope in:** `flag_grid_layout_engine.dart` (`FlagGridLayoutMode` enum, `FlagGridLayoutEngine`, `FlagGridTile`); `FlagTileRenderer.drawContained()` + `FilterQuality.high`; `GridFlagsCard.layoutMode` param; `CardImageRenderer.render(gridLayoutMode:)`; `_GridLayoutPicker` segmented control in `CardEditorScreen`; `_CardParams.gridLayoutMode`; ADR-156.
**Scope out:** New flag SVG sources (existing flag-icons 4×3 library is already vector quality); animated layout transitions; merch call sites (inherit packedRow default); web/Android.
**Full plan:** `docs/dev/milestones/m106-flag-grid-quality-and-layout.md`
**Status:** ✅ Complete (2026-05-10).

---

### M105 — Social Merch & Travel Identity System
**Goal:** Transform merchandise into a social, emotional, and viral engagement system. Users should feel "I unlocked something special" — with a travel identity, cinematic gallery reveal, featured lead card, and social share export.
**Phase:** 22 — Merch Platform
**Depends on:** M104
**Scope in:** `travel_identity.dart` (`TravelIdentity` enum + `TravelIdentityInfo`); `merch_drop.dart` (`MerchDrop` + `kCurrentMerchDrops`); `merch_share_exporter.dart` (social PNG export via share_plus); staggered reveal animations in `MerchOptionCard`; `MerchOptionFeaturedCard` for top-ranked option; achievement header celebration with identity label + scale animation; "Share" icon in `LocalMockupPreviewScreen` AppBar; identity-aware section labels; drop badge labels; ADR-155.
**Scope out:** New CardTemplateType values; new product types; checkout/Printful changes; animated video exports; social feed; web/Android.
**Full plan:** `docs/dev/milestones/m105-social-merch-identity-system.md`
**Status:** ✅ Complete (2026-05-10).

---

### M104 — Intelligent Merch Recommendation Engine
**Goal:** Replace fixed per-builder template lists with a ranked, density-aware `MerchTemplateRanker`; add `MerchStory` for emotionally engaging option titles; extend 5-tier auto-tune scaling; improve shirt colour intelligence with density awareness; add `contextLabel` to options.
**Phase:** 22 — Merch Platform
**Depends on:** M103
**Scope in:** New `merch_template_ranker.dart` (`MerchDensityClass`, `MerchTemplateRank`, `MerchTemplateRanker`); new `merch_story.dart` (`MerchStory.forOption()`); `merch_option_list_widgets.dart` (5-tier auto-tune, density-aware `merchSuggestShirtColor`, `contextLabel` in card); `pulse_merch_option.dart` (`contextLabel`); `merch_context.dart` (builders use ranker + story).
**Scope out:** New CardTemplateType values; new product types; AI runtime calls; checkout/Printful/web.
**Full plan:** `docs/dev/milestones/m104-intelligent-merch-recommendation-engine.md`
**Status:** ✅ Complete (2026-05-09).

---

### M103 — Expanded Merch Template Variety
**Goal:** Add two new renderable card templates (`CardTemplateType.typography`, `CardTemplateType.badge`), improve per-achievement option curation, and add shirt colour intelligence so each generated option pre-selects a suitable shirt colour.
**Phase:** 22 — Merch Platform
**Depends on:** M102
**Scope in:** `travel_card.dart` (2 new enum values); `card_templates.dart` (`TypographyCard`, `BadgeCard` widgets); `card_image_renderer.dart`; `merch_option_list_widgets.dart` (`merchSuggestShirtColor`); `pulse_merch_option.dart` (`suggestedShirtColor`); `local_mockup_preview_screen.dart` (`initialColour`); `merch_context.dart` (typography + badge in builders); exhaustive-switch updates in `card_editor_screen`, `artwork_confirmation_screen`, `card_type_picker_screen`.
**Scope out:** Route/vintage/scrapbook/minimalist templates; full card editor support for new templates; Printful/Shopify; web; Android.
**Full plan:** `docs/dev/milestones/m103-expanded-merch-template-variety.md`
**Status:** ✅ Complete (2026-05-09).

---

### M102 — Achievement-Aware Merchandise Context System
**Goal:** Extend `MerchContext` and `AchievementEngine` so achievements generate merchandise options scoped precisely to the relevant travel data: continent-explorer achievements filter to only countries in that continent; region achievements filter to sub-region; passport milestones prioritise stamp-led layouts.
**Phase:** 22 — Merch Platform
**Depends on:** M100
**Scope in:** `packages/shared_models` (Achievement: continentScope/regionScope fields; new continent/region/passport achievements in kAchievements; AchievementEngine: per-continent + per-region + passport stamp counts; new `continent_subregion_map.dart`); `apps/mobile_flutter` (MerchContext: scope-filtered _resolveCodes/_resolveTrips, new _buildContinentExplorerItems/_buildRegionItems/_buildPassportMilestoneItems; AchievementMerchOptionScreen subtitle for new types).
**Scope out:** `achievement_gallery.dart` / `next_achievements_carousel.dart` stat display accuracy; LocalMockupPreviewScreen, Printful, Shopify; web; Android.
**Status:** ✅ Complete (2026-05-09).

---

### M100 — Expanded Template Variety
**Goal:** Add Heart Flags as a fourth merch template group in both Memory Pulse and Achievement merch screens. Requires `onAssetsLoaded` hook on `HeartFlagsCard` so `CardImageRenderer` captures SVG flags correctly off-screen.
**Phase:** 22 — Merch Platform
**Depends on:** M99
**Scope in:** `card_templates.dart` (HeartFlagsCard onAssetsLoaded); `card_image_renderer.dart` (assetsCompleter for heart); `merch_context.dart` (heart group in all builders); `pulse_merch_option_screen.dart` (heart in groups).
**Scope out:** Route/typography/explorer/vintage templates; entry-only passport variant; shared_models; web.
**Status:** ✅ Complete (2026-05-08).

---

### M98 — Achievement-Driven Merch Workflow
**Goal:** Fix the "Make a Tee" / "Create" buttons in the Stats & Achievement Dashboard to navigate into the same modern t-shirt purchase workflow used by Memory Pulse. Extract shared rendering widgets from `PulseMerchOptionScreen`; create `AchievementMerchOptionScreen` that generates `PulseMerchOption` items from achievement context. Both entry points share the same merch pipeline end-to-end.
**Phase:** 21 — Engagement & Gamification
**Depends on:** M96 (preset-driven merch), M97 (gamified stats dashboard)
**Scope in:** New `lib/features/merch/merch_option_list_widgets.dart`; new `lib/features/merch/achievement_merch_option_screen.dart`; `pulse_merch_option_screen.dart` (import shared widgets); `achievement_gallery.dart` (reroute `_MerchChip`); `merch_moments_section.dart` (reroute `_MerchMomentTile`).
**Scope out:** `LocalMockupPreviewScreen`, `MerchOrderConfirmationScreen`, Printful/Shopify, shared_models, web.
**Full plan:** `docs/dev/milestones/m98-achievement-merch-workflow.md`
**Status:** ✅ Complete (2026-05-08).

---

### M97 — Gamified Stats & Achievement Dashboard
**Goal:** Replace the plain 3-stat panel + flat achievement grid with a gamified travel dashboard: fl_chart PieChart donut progress ring, next-achievements carousel, tabbed achievement gallery with merch CTAs, and a Merch Moments section driven by unlocked achievements. Expands kAchievements from 8 to ~30 trackable achievements with progressTarget and MerchTriggerType fields.
**Phase:** 21 — Engagement & Gamification
**Scope in:** `pubspec.yaml` (fl_chart); `packages/shared_models` (Achievement model, kAchievements, AchievementEngine); `lib/core/providers.dart`; `lib/features/stats/stats_screen.dart`; new `lib/features/stats/widgets/` files.
**Scope out:** Passport stamp / streak achievements; poster/mug merch types; web; new Drift schema.
**Full plan:** `docs/dev/milestones/m97-gamified-stats-dashboard.md`
**Status:** ✅ Complete (2026-05-08).

---

### M89 — Hero Image Detection & Trip Labels
**Goal:** During photo scanning, select up to 5 metadata-scored candidates per trip; after scan completes, run on-device Vision framework labelling on candidates; persist a structured hero image record (labels + score + rank) in Drift. No photos leave the device. Scan performance unaffected.
**Phase:** 19 — Personalisation & Memory
**Scope in:** `packages/shared_models` (HeroImage model, HeroScoringEngine); Drift schema v11 (`hero_images` table); `HeroCandidateSelector`, `HeroImageRepository`, `HeroAnalysisService` (Dart); `HeroImageAnalyzer`, `LabelNormalizer` (Swift); MethodChannel bridge; Riverpod provider.
**Scope out:** Any UI displaying hero images; Firestore sync; landmark detection; web; Android.
**Depends on:** Existing scan pipeline (PhotoDateRecord + TripRecord + assetId in schema v9+)
**Full plan:** `docs/dev/milestones/m89-hero-image-detection.md`
**Status:** ✅ Complete (2026-04-29).

---

### M90 — Hero Image UI Surfaces
**Goal:** Surface M89 hero images in the three screens users already use: journal trip cards (full-bleed header), country detail sheet (cover image), and scan summary ("best shot" moment). Add hero override picker so users can swap their hero image from within each screen.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89
**Scope in:** `journal_screen.dart`, `country_detail_sheet.dart`, `scan_summary_screen.dart`; new `HeroImageView` widget; `ThumbnailPlugin.swift` (thumbnail MethodChannel).
**Full plan:** `docs/dev/milestones/m90-hero-image-ui.md`
**Status:** ✅ Complete (2026-04-30).

---

### M91 — Memory Pulse
**Goal:** On travel anniversaries, show an in-app memory card on the map screen and an optional local push notification with label-driven copy ("3 years ago today — Aegean sunrise in Greece 🌅"). Fully on-device; no server scheduling.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (labels), M90 (HeroImageView)
**Scope in:** New `memory_pulse_service.dart`, `memory_pulse_card.dart`; `notification_service.dart` extension; `map_screen.dart`; `providers.dart`.
**Full plan:** `docs/dev/milestones/m91-memory-pulse.md`
**Status:** ✅ Complete (2026-04-30).

---

### M92 — Label-Powered Auto Titles
**Goal:** Enrich the existing rule-based title generator with scene and mood labels from hero images. "Greece 2024" becomes "Aegean Sunset". Graceful fallback to geography titles when no labels available.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89
**Scope in:** `rule_based_title_generator.dart`, `title_generation_models.dart`, `card_editor_screen.dart`.
**Full plan:** `docs/dev/milestones/m92-label-powered-titles.md`
**Status:** ✅ Complete (2026-04-30).

---

### M93 — Hero Image Share Card Background
**Goal:** Optional hero photo background layer in passport and grid card editors. User toggles "Photo background" to place their travel photo behind stamps/flags. Background composited at print resolution for sharing and merch.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89, M90
**Scope in:** `card_editor_screen.dart`, `card_templates.dart` (PassportStampsCard + GridCard), `card_image_renderer.dart`; new `CardBackgroundPicker`; `ThumbnailPlugin.swift` (full-res fetch).
**Full plan:** `docs/dev/milestones/m93-hero-share-card-background.md`
**Status:** ✅ Complete (2026-05-01).

---

### M94 — Year in Review
**Goal:** Full-screen annual travel summary: timeline of hero images per trip, key stats, highlights ("most common scene: beach"), and a shareable 1080×1920 mosaic card. Triggered by New Year notification.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89, M90
**Scope in:** New `year_in_review_screen.dart`, `year_in_review_service.dart`; `map_screen.dart` (Dec/Jan entry chip); `card_image_renderer.dart` (YIR card render); `notification_service.dart` (New Year notification).
**Full plan:** `docs/dev/milestones/m94-year-in-review.md`
**Status:** ✅ Complete (2026-05-01).

---

### M95 — Memory Pulse 2.0: Question-Based Reveal + Share
**Goal:** Upgrade M91 Memory Pulse from a passive anniversary card into a curiosity-first engagement loop: question teaser card, animated reveal sheet, on-device share card, question-style notifications, smart morning/evening timing, and a post-scan pulse trigger.
**Phase:** 19 — Personalisation & Memory
**Depends on:** M91 (MemoryPulseService, MemoryPulseCard), M90 (HeroImageView)
**Scope in:** `memory_pulse_service.dart`, `memory_pulse_card.dart`; new `memory_reveal_sheet.dart`, `memory_share_service.dart`, `app_open_tracker.dart`; `main_shell.dart`; `scan_summary_screen.dart`.
**Full plan:** `docs/dev/milestones/m95-memory-pulse-reveal.md`
**Status:** ✅ Complete (2026-05-04).

---

### M86 — Map Screen Enhancements
**Goal:** Globe auto-rotation (east→west, pauses on interaction), lighter ocean background, horizontal visited-country flag strip (globe mode, tap → snap to country), tappable stats strip (Countries → CountriesListScreen, Achievements → StatsScreen), tappable XP level bar → progression sheet.
**Phase:** 16 — Map UX Polish
**Scope in:** `globe_map_widget.dart`, `globe_painter.dart`, `map_screen.dart`, `stats_strip.dart`, `xp_level_bar.dart`, `core/providers.dart`.
**Scope out:** Flat map mode enhancements; Journal country map; new achievement screen; web.
**Status:** ✅ Complete (2026-04-27).

---

### M77 — Incremental Scan Redesign ← CURRENT
**Goal:** Globe pre-populated with known countries, country list shows existing visits from scan start, assetId-based dedup for robustness, instant visual feedback on auto-scan.
**Phase:** 16 — Scan UX
**Scope in:** `scan_screen.dart`, `visit_repository.dart` only.
**Scope out:** Firestore, web, card editor, merch, packages, map screen.
**Status:** In progress (2026-04-24).

---

### M85 — Order Confirmation Screen (Pre-Checkout) ⚠️ HIGH PRIORITY

**Goal:** Insert a mandatory full-screen confirmation step between the Printful mockup and Shopify
checkout. The user must explicitly review their size, colour, print positions, and design, then tick
a checkbox before the "Proceed to Checkout" button enables. Prevents incorrect purchases, reduces
refunds, and sets clear no-refund expectations.

**Phase:** 16 — Commerce UX Polish

**Scope in:** New `merch_order_confirmation_screen.dart`; one-line change in
`local_mockup_preview_screen.dart` (replace direct `_completeCheckout()` call with
`Navigator.push` to the confirmation screen).

**Scope out:** Printful API; Firestore schema; Cloud Functions; card editor; scan; map; web.

---

#### UX Flow

```
[ready state — mockup visible]
        ↓  user taps "Review & Checkout →"
[MerchOrderConfirmationScreen — full screen, no AppBar back shortcut]
        ├─ Shows: front mockup (large), back mockup (if present), order summary card
        ├─ Warning box: custom-product / no-refund notice
        ├─ Checkbox: "I have reviewed all details and they are correct"
        ├─ [Go Back]              → Navigator.pop() → returns to ready state
        └─ [Proceed to Checkout]  → enabled only when checkbox ticked
                                  → calls _completeCheckout (launches checkoutUrl)
```

---

#### Flutter Screen Structure

**File:** `lib/features/merch/merch_order_confirmation_screen.dart`

```
MerchOrderConfirmationScreen (StatefulWidget)
  ├── Constructor params (all required, immutable — frozen snapshot at confirm time):
  │     frontMockupUrl: String?
  │     backMockupUrl:  String?
  │     artworkBytes:   Uint8List          ← final generated design image
  │     size:           String             ← e.g. 'L'
  │     colour:         String             ← e.g. 'Black'
  │     frontPosition:  String             ← 'center' | 'left_chest' | 'right_chest' | 'none'
  │     backPosition:   String             ← 'center' | 'none'
  │     templateType:   CardTemplateType   ← 'passport' | 'grid' | 'heart'
  │     checkoutUrl:    String
  │
  └── State:
        _confirmed: bool = false           ← drives checkbox + button enabled

Layout (SingleChildScrollView → Column):
  1. _MockupSection        — PageView of front/back mockup images (large, fills ~55% height)
  2. _OrderSummaryCard     — Colour chip + size badge + front/back position labels + template name
  3. _WarningBox           — amber-bordered container with warning copy
  4. _ConfirmationCheckbox — Row(Checkbox, Expanded(Text(...)))
  5. _ActionRow            — [Go Back (TextButton)] [Proceed to Checkout (FilledButton, disabled until _confirmed)]
```

---

#### State Management

- Entirely local `StatefulWidget` state — no Riverpod needed.
- `_confirmed` bool toggles on checkbox tap → `setState`.
- Checkout URL passed in at construction; never re-fetched or mutated.
- No back-navigation lock needed (user may freely go back; nothing destructive happens).

---

#### Validation Logic

```dart
// Checkbox
Checkbox(
  value: _confirmed,
  onChanged: (v) => setState(() => _confirmed = v ?? false),
)

// Proceed button
FilledButton(
  onPressed: _confirmed ? _launchCheckout : null,
  child: const Text('Proceed to Checkout'),
)

// Launch
Future<void> _launchCheckout() async {
  final uri = Uri.parse(widget.checkoutUrl);
  if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
    // show snackbar
  }
}
```

---

#### Production Copy

**Screen title:** `Review Your Order`

**Section header (mockup):** `Your Design`

**Section header (details):** `Order Details`

**Detail labels:**
- Colour: `{colour}` (with matching filled circle swatch)
- Size: `{size}`
- Front print: `{frontPositionLabel}` — where center→`Centre`, left_chest→`Left Chest`,
  right_chest→`Right Chest`, none→`No Front Print`
- Back print: `{backPositionLabel}` — center→`Centre`, none→`No Back Print`
- Design: `{templateLabel}` — passport→`Passport Stamps`, grid→`Flag Grid`, heart→`Heart Flags`

**Warning box:**
```
⚠  Custom-Made Product

Please review every detail above carefully before continuing.

This item is made to order — once payment is completed,
we cannot offer refunds or exchanges for change of mind.

You can still cancel during checkout.
```

**Checkbox label:**
```
I confirm the size, colour, design, and print positions shown above are correct.
```

**Go Back button:** `← Go Back`
**Proceed button:** `Proceed to Checkout →`

---

#### Trigger Change in LocalMockupPreviewScreen

In `_buildBottomBar()`, replace:
```dart
// BEFORE
onPressed: _completeCheckout,
child: const Text('Complete order →'),

// AFTER
onPressed: () => Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => MerchOrderConfirmationScreen(
    frontMockupUrl: _mockupUrl,
    backMockupUrl:  _backMockupUrl,
    artworkBytes:   _artworkBytes!,
    size:           _tshirtSize,
    colour:         _colour,
    frontPosition:  _frontPosition,
    backPosition:   _backPosition,
    templateType:   _template,
    checkoutUrl:    _checkoutUrl!,
  ),
)),
child: const Text('Review & Checkout →'),
```

---

#### Edge Cases

| Case | Handling |
|---|---|
| `frontMockupUrl` is null (still generating) | Show `artworkBytes` rendered locally with a "Preview" label; do not block confirmation |
| Both mockup URLs null | Show local artwork preview for both sides |
| `checkoutUrl` is somehow null | Button disabled with label "Checkout unavailable — go back" |
| User taps back during checkout browser | Returns to ready state; confirmation screen is gone (popped on checkout launch) |
| Design changed after confirmation (impossible) | State is frozen at push time — no references to parent mutable state |

---

#### ADR

ADR-131: Mandatory pre-checkout confirmation screen (`MerchOrderConfirmationScreen`) inserted
between `_MockupState.ready` and Shopify checkout launch. All order data passed as immutable
constructor params at push time. No Firestore or API calls in the confirmation screen.
Checkbox gates the proceed button. "Go Back" returns to `ready` state with mockup intact.

---

**Dependencies:** None — sits on top of existing `ready` state output.
**Status:** ✅ Complete (2026-04-27).

---

### M96 — Preset-Driven Merch & Advanced Customisation
**Goal:** Replace the blank-state card-first merch flow with a preset-driven experience: instant t-shirt mockup from a smart preset, two-layer customisation (quick inline controls + explicit advanced sheet), locked image source of truth across the full purchase pipeline, Printful placement/none/back mockup fixes, and loading UX with retry logic.
**Phase:** 20 — Commerce Experience
**Depends on:** M75, M85, M93
**Scope in:** New `merch_preset.dart`, `merch_customisation_sheet.dart`, `printful_placement_mapper.dart`; refactor `local_mockup_preview_screen.dart`.
**Scope out:** Post-purchase "My Merch" screen; gift messages (M81); shipping speed selection (M83); web checkout.
**Full plan:** `docs/dev/milestones/m96-preset-merch-customisation.md`
**Status:** ✅ Complete (2026-05-04).

---

### M75 — Inline T-Shirt Config UX (Remove "More" Tab)
**Goal:** Remove the "More" bottom sheet; bring all product configuration inline on the main
Design Your T-Shirt screen. No hidden navigation, no duplicate controls, premium Apple-quality UX.
**Phase:** 16 — Commerce UX Polish
**Scope in:** `local_mockup_preview_screen.dart` only — layout refactor + widget removal/addition.
**Scope out:** Printful API; card templates; card editor; web; scan; map.
**Status:** ✅ Complete (2026-04-22).

---

### M61 — Grid Card Upgrade
**Goal:** Replace emoji flags with real SVG flag images; adaptive tile sizing; portrait/landscape re-layout; shared editable title state across Grid/Passport/Heart.
**Phase:** 15 — Visual Design Upgrade
**Scope out:** Web card generator changes
**Status:** ✅ Superseded by M106 (SVG flags, FlagGridLayoutEngine, FilterQuality.high, Packed Row layout)

---

### M66 — Heart Card Redesign (Flag-Based Layout)
**Goal:** Transparent heart filled with real flag SVGs; gapless edge-to-edge binary-search packing; 80% edge-flag visibility rule; no emoji fallback; print-ready transparent background.
**Phase:** 15 — Visual Design Upgrade
**Scope out:** Web card generator changes
**Status:** ✅ Complete (2026-05-26)

---

---

### M79 — Personalised Packing Slip
**Goal:** Add Roavvy branding to every Printful packing slip: logo sticker, custom message, support email, store name override, and a Roavvy-friendly order reference instead of Printful's numeric ID.
**Phase:** 17 — Commerce Polish
**API:** `packing_slip` object on `POST /orders` (Printful v1). Fields: `logo_url`, `message`, `email`, `store_name`, `custom_order_id`.
**Scope in:** `shopifyOrderCreated` in `apps/functions/src/index.ts` only.
**Scope out:** Shopify checkout flow; mobile UI; web.
**Status:** ✅ Complete (2026-05-26)

---

### M80 — Shipment Tracking In-App
**Goal:** When Printful ships an order, write the tracking URL + carrier to the user's `MerchConfig` in Firestore and send a push notification with a deep-link to the carrier tracking page.
**Phase:** 17 — Commerce Polish
**API:** `package_shipped` Printful webhook event (carrier, service, tracking_number, tracking_url).
**Scope in:** New `printfulWebhook` Cloud Function; Firestore `MerchConfig` (add `trackingUrl`, `trackingCarrier`); push notification trigger; mobile order status UI.
**Scope out:** Custom tracking UI; web order history.
**Status:** Not started. No tasks written.

---

### M81 — Gift Message at Checkout
**Goal:** Add a "This is a gift" toggle + message field to the merch checkout flow. Message is forwarded to Printful's `gift` object (subject + message, max 200 chars each) and printed on the packing slip.
**Phase:** 17 — Commerce Polish
**API:** `gift.subject` + `gift.message` on `POST /orders` (Printful v1).
**Scope in:** `local_mockup_preview_screen.dart` (gift toggle + field); `createMerchCart` request type; `shopifyOrderCreated` (pass gift to Printful).
**Scope out:** Shopify-level gift wrapping; web checkout.
**Status:** ✅ Complete (2026-05-26)

---

### M82 — Order Failed Recovery
**Goal:** Handle the `order_failed` Printful webhook: update `designStatus=order_failed` in Firestore and send the user a push notification prompting them to contact support.
**Phase:** 17 — Commerce Polish
**API:** `order_failed` Printful webhook event.
**Scope in:** `printfulWebhook` Cloud Function (shared with M80); Firestore status update; push notification.
**Scope out:** Self-serve file resubmission; web.
**Status:** Not started. Depends on M80 (shared webhook handler).

---

### M83 — Shipping Speed Selection
**Goal:** Show 2–3 shipping options (Standard / Express / Priority) with live rates and estimated delivery dates at checkout. User pays the difference; selected method is forwarded to the Printful order.
**Phase:** 18 — Commerce Conversion
**API:** `POST /shipping/rates` (country_code + items); `shipping` field on `POST /orders`.
**Scope in:** `createMerchCart` (rate lookup, pass selected method); checkout UI shipping picker; `CreateMerchCartRequest` type.
**Scope out:** Shopify shipping settings; web checkout.
**Status:** Not started. No tasks written.

---

### M84 — Order Cost Preview
**Goal:** Show a live cost breakdown (item + print + shipping + tax) in the merch screen before the user taps "Checkout", using Printful's estimate endpoint.
**Phase:** 18 — Commerce Conversion
**API:** `POST /orders/estimate-costs` (Printful v1).
**Scope in:** New `estimateMerchCost` callable Cloud Function; cost breakdown widget in `local_mockup_preview_screen.dart`.
**Scope out:** Shopify price; web checkout.
**Status:** Not started. No tasks written.

---

### M28 — Web Commerce: Authenticated Checkout *(web — lower priority)*
**Goal:** Signed-in web user selects visited countries → `createMerchCart` → Shopify checkout.
**Depends on:** M27 ✅
**Scope in:** `/shop` country select grid; cart creation; redirect to `checkoutUrl`; post-checkout confirmation; error state
**Scope out:** Variant picker on web; mockup generation on web; order history on web
**Status:** Not started. No tasks written.

---

### M31 — Web Auth: Password Reset *(web — lower priority)*
**Goal:** `/forgot-password` route with `sendPasswordResetEmail`; "Forgot password?" link on `/sign-in`.
**Scope out:** Custom email template; mobile password reset
**Status:** Not started. No tasks written.
