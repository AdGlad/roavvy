# Roavvy — Current State (updated M103, 2026-05-09)

## What is built

| Feature area | Status | Notes |
|---|---|---|
| Photo scan | ✅ | PhotoKit bridge; GPS → country (offline, `country_lookup`); unified scan UX (M78): always-visible globe + country list + passport stamps pre-populated at rest, live-animated during scan; all scan outcomes navigate through ScanSummaryScreen; assetId-based dedup (M77) |
| World map | ✅ | `flutter_map`; globe (auto-rotating east→west, snap-to-country via flag strip, M86); dark navy/gold; depth colouring; timeline scrubber; gamified visual states (5 states); tappable stats strip → Countries/Achievements screens (M86); tappable XP level → progression sheet (M86) |
| Country/region detection | ✅ | ISO 3166-2 admin1 via `region_lookup`; region progress chips + detail sheet |
| Trips / Journal | ✅ | `TripInference`; trip region map; journal screen; photo gallery per country/trip |
| Achievements + XP | ✅ | 8 XP levels; milestone cards at [5,10,25,50,100]; `LevelUpSheet`; gamified achievement dashboard with fl_chart PieChart donut, next-achievements carousel, tabbed gallery, merch CTAs (M97); 29 achievements across country/continent/trip/thisYear categories; `continentCountProvider`, `tripCountProvider`, `thisYearCountryCountProvider` (M97) |
| Celebrations | ✅ | `DiscoveryOverlay` with animated globe, per-country confetti; celebration carousel (M72) |
| Travel cards | ✅ | Grid (SVG flags, M67), Heart (SVG flags + title rendering, M67), Passport templates; `CardEditorScreen`; AI + fallback titles (year-free, M70); label-powered titles from hero images (M92); optional photo background (passport + grid) composited at print resolution (M93); Passport Book PDF export + in-app preview (M87) |
| Sharing | ✅ | Share sheet; `/share/[token]` web page; token revocation |
| Commerce (mobile) | ✅ | T-shirt + poster; Printful mockup (front+back, strict-only, no local fallback post-approval, M73); front placement options (left/center/right/none); back placement (center/none); left_chest uses named Printful placement + small chest PNG (M76); strict checkout gate; mandatory pre-checkout confirmation screen with checkbox gate + no-refund warning (M85); Shopify checkout; post-purchase poll; preset-driven merch entry (kMerchPresets: recent_trip/this_year/all_time/single_country), MerchCustomisationSheet Layer 2, PrintfulPlacementMapper, _artworkLocked image lock, mockup polling fallback warning (M96); achievement-driven merch entry: `AchievementMerchOptionScreen` generates `PulseMerchOption` items scoped to achievement context; shared rendering layer (`merch_option_list_widgets.dart`) used by both Memory Pulse and Achievement entry points (M98); `MerchContext` shared merch context layer: achievement-type-specific option generation (first-country, country milestones, continent, trip, year), template ordering by achievement type, World Collection only when scope is a strict subset of all countries (M99); 4 template groups (Passport, Flags, Heart Flags, Tour Dates) in both Memory Pulse and Achievement merch screens; `HeartFlagsCard.onAssetsLoaded` hook enables correct SVG-flag off-screen rendering in `CardImageRenderer` (M100, ADR-151); achievement-aware merch context: `Achievement.continentScope`/`regionScope` fields scope merchandise to a continent or sub-region; `kCountrySubRegion` (Mediterranean, SoutheastAsia); continent-explorer, region, and passport stamp milestone achievements in `kAchievements`; `AchievementEngine` evaluates per-continent/region/passport counts; `MerchContext` dispatches to `_buildContinentExplorerItems`, `_buildRegionItems`, `_buildPassportMilestoneItems` (M102, ADR-152); 2 new card templates: `CardTemplateType.typography` (stacked country-name text) + `CardTemplateType.badge` (circular explorer badge); `PulseMerchOption.suggestedShirtColor`; `LocalMockupPreviewScreen.initialColour`; `merchSuggestShirtColor()` helper; `MerchContext` builders include typography + badge per achievement type (M103, ADR-153) |
| Commerce (web) | ✅ | `/shop` public landing; auth-aware CTA; web checkout in M28 (not started) |
| Firebase | ✅ | Anonymous auth; Apple Sign-In; Firestore sync (visits, trips, achievements, merch configs) |
| Web app | ✅ | `/sign-in`, `/sign-up`, `/map`, `/shop`, `/share/[token]`, `/privacy` |
| Onboarding | ✅ | 3-screen `OnboardingFlow`; bypassed for returning users |
| Notifications | ✅ | Achievement unlock + 30-day nudge; tap routing to correct tab |
| Hero image pipeline | ✅ | On-device Vision labelling post-scan; `hero_images` table in Drift v11; `HeroCandidateSelector`, `HeroImageAnalyzer`, `HeroScoringEngine`, `HeroImageRepository`, `HeroAnalysisService`; `heroForTripProvider` (M89) |
| Hero image UI | ✅ | `HeroImageView` widget (shimmer + fallback colour); `ThumbnailPlugin.swift` (`roavvy/thumbnail` channel, NSCache); full-bleed trip card headers in Journal; cover image in country detail sheet; best-shot section in scan summary; `HeroOverridePicker` (isUserSelected guard); `bestHeroForCountryProvider`, `bestHeroFromScanProvider` (M90) |
| Memory Pulse | ✅ | Travel anniversary detection via strftime SQL; `MemoryPulseService` (checkToday, buildCopy, scheduleNextAnniversaryNotification); `MemoryPulseCard` widget (single + paged); `_MemoryPulseSection` on map screen (slide-in animation); `todaysMemoriesProvider`; `memoriesDismissedProvider`; `scheduleMemoryPulse` notification (ID 2); `pendingMemoryTripId` cold-start routing (M91) |
| Rovy mascot | ✅ | `RovyBubble`; 5 trigger types; 4s auto-dismiss |

## What is NOT built

- M28: Web commerce checkout (country select → Shopify cart on web)
- M31: Web password reset flow
- M61: Grid Card real-flag SVG upgrade (currently emoji-based)
- M66: Heart Card gapless SVG repack
- M87: ✅ Complete (2026-05-01) — Passport Book PDF (cover + stamp pages + summary, in-app preview, share)
- M88: ✅ Complete (2026-05-02) — Native Flutter Globe Spin Physics (Inertia & Decay)
- M89: Journal Redesign: 3D Trip Carousel & Immersive Details
- M91: Memory Pulse ✅ Complete (2026-04-30)
- M92: ✅ Complete (2026-04-30) — label-powered auto titles
- M93: ✅ Complete (2026-05-01) — photo background compositing for passport + grid cards
- M94: ✅ Complete (2026-05-01) — Year in Review screen, mosaic card, Dec/Jan banner, New Year notification
- Social / friends features
- iPad layout (iPhone-only target)
- Sound effects (separate milestone)

## Key files — mobile

| Domain | File |
|---|---|
| Card editor | `lib/features/cards/card_editor_screen.dart` |
| Card templates | `lib/features/cards/card_templates.dart` |
| Passport layout | `lib/features/cards/passport_layout_engine.dart` |
| Heart layout | `lib/features/cards/heart_layout_engine.dart` |
| AI title (Swift) | `ios/Runner/AiTitlePlugin.swift` |
| Fallback title | `lib/features/cards/title_generation/rule_based_title_generator.dart` |
| Globe / celebration | `lib/features/map/celebration_globe_widget.dart` |
| Discovery overlay | `lib/features/scan/discovery_overlay.dart` |
| Scan screen | `lib/features/scan/scan_screen.dart` |
| Map screen | `lib/features/map/map_screen.dart` |
| Providers | `lib/core/providers.dart` |
| Order confirmation | `lib/features/merch/merch_order_confirmation_screen.dart` |
| Merch preset model | `lib/features/merch/merch_preset.dart` |
| Merch customisation sheet | `lib/features/merch/merch_customisation_sheet.dart` |
| Printful placement mapper | `lib/features/merch/printful_placement_mapper.dart` |
| Merch option shared widgets | `lib/features/merch/merch_option_list_widgets.dart` |
| Merch context (shared layer) | `lib/features/merch/merch_context.dart` |
| Achievement merch screen | `lib/features/merch/achievement_merch_option_screen.dart` |
| Hero image view | `lib/features/shared/hero_image_view.dart` |
| Hero override picker | `lib/features/shared/hero_override_picker.dart` |
| Memory pulse service | `lib/features/memory/memory_pulse_service.dart` |
| Memory pulse card | `lib/features/memory/memory_pulse_card.dart` |
| Thumbnail channel | `lib/features/shared/thumbnail_channel.dart` |
| Card background picker | `lib/features/cards/card_background_picker.dart` |
| Passport PDF service | `lib/features/cards/passport_pdf_service.dart` |
| Passport book screen | `lib/features/cards/passport_book_screen.dart` |
| Year in Review | `lib/features/year_in_review/` |
| Thumbnail plugin (iOS) | `ios/Runner/ThumbnailPlugin.swift` |
| Scan bridge (Swift) | `ios/Runner/PhotoScanPlugin/` |
| Country lookup | `packages/country_lookup/lib/` |
| Region lookup | `packages/region_lookup/lib/` |

## Schema

Drift SQLite schema **v11** — tables: `photo_date_records` (v9 + `asset_id`), `user_added_countries`, `user_removed_countries`, `trips`, `region_visits`, `xp_events`, `hero_images` (M89).

## Tests (M72)

Flutter: ~800+ | Shared models: ~87 | `flutter analyze` clean
