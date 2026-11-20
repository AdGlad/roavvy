# Roavvy — Current State (updated M189, 2026-11-20)

v1.0 is the **free launch**: everything below ships free, and commerce (T-shirts, prints,
shop, cart, checkout, orders, T-Shirt Studio V2) is built but **off** (ADR-180).

## The commerce flag (ADR-180, M184–M187)

| Piece | Where | What it does |
|---|---|---|
| Build flag | `lib/core/commerce/commerce_flag.dart` | `kCommerceBuild = bool.fromEnvironment('ROAVVY_COMMERCE')`, default false. Off → commerce code is tree-shaken |
| Remote kill switch | Remote Config `commerce_enabled` | Can turn commerce off in a commerce build; can never turn it on in a free build |
| Effective flag | `commerceEnabledProvider` | `kCommerceBuild && commerce_enabled` |
| The seam | `lib/features/commerce_entry/commerce_entry.dart` | `CommerceEntry` openers (no-op when off) + `CommerceGate` (builds nothing when off). Hide, never disable |
| Guard test | `test/architecture/commerce_boundary_test.dart` | Fails if code outside `features/merch/`, `features/studio_v2*/` or the seam imports a commerce screen or calls a commerce callable |
| Shell | `lib/features/shell/main_shell.dart` | Named tabs: Map · Journey · Stats · (Shop, commerce only) · Play |
| Server | `getMerchPrices`, `createMerchCart` | Refuse with `failed-precondition` unless Functions param `COMMERCE_ENABLED` is true (`.env.roavvy-prod` false, `.env.roavvy-dev` true) |
| Terms | `lib/features/legal/` | Terms text and version follow `kCommerceBuild` (free v1.2, commerce v1.1) |
| Release build | `scripts/build_ios_release.sh` | Refuses `ROAVVY_COMMERCE`, `STUDIO_V2`, `STUDIO_V2_TRACE`, non-release modes, any target but `lib/main.dart`. `main.dart` also throws in release if `STUDIO_V2` is set |

Run commerce locally: `flutter run --dart-define=ROAVVY_COMMERCE=true`. Studio V2:
`flutter run -t lib/main_studio_v2.dart --dart-define=ROAVVY_COMMERCE=true`.

## What ships in 1.0

| Area | Notes |
|---|---|
| Photo scan | PhotoKit bridge; GPS → country offline (`country_lookup`); assetId dedup; live globe, stamps and replay during scan; scan summary |
| World map | Globe (default) or flat map; depth colouring; timeline scrubber; UNESCO sites; stats strip |
| Countries and regions | ISO 3166-2 admin1 (`region_lookup`); `CountryProfileScreen` with heritage, photos, trips |
| Trips and journal | `TripInference`; Journey tab; photo galleries; hero images (on-device Vision) |
| Achievements and XP | 8 levels; country, continent, region, trip, UNESCO achievements; level-up and unlock sheets |
| Travel cards | Grid, Heart, Passport, Typography, Badge, Timeline, Journeys templates; AI and rule-based titles; Passport Book PDF; share sheet |
| Memory reminders | Trip anniversaries (Memory Pulse) with local notifications |
| Year in Review and travel story | Year screen, mosaic card, Wrapped-style story |
| Travel replay | Cinematic globe replay with audio; summary with Replay Again (Share hidden until wired, M189) |
| Daily UNESCO challenge | Wordle-style, hot/cold feedback, streaks |
| Account | Anonymous → Apple / Google / email sign-in; account and data deletion in Settings |
| Sync | Firestore: visited countries and dates, trips, achievements only (no photos) |
| Legal | In-app Terms v1.2 (free); website Terms, Privacy, Refund updated for a free app (M188) |

## Built but off in 1.0

- Merch and print (`features/merch/`), cart, Shopify checkout, orders, Printful mockups.
- T-Shirt Studio V2 (`features/studio_v2/`, `features/studio_v2_commerce/`).
- Web commerce (`apps/web_nextjs` `/shop`).

## Not built

- Web password reset (M31); web checkout (M28).
- Social / friends features.
- iPad layout (iPhone-only).
- A share target for the travel replay summary.

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
| Travel replay engine | `lib/features/globe_replay/travel_replay_engine.dart` |
| Travel replay controller | `lib/features/globe_replay/travel_replay_controller.dart` |
| Replay audio controller | `lib/features/globe_replay/replay_audio_controller.dart` |
| Replay widget | `lib/features/globe_replay/globe_replay_widget.dart` |
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
| Daily challenge notifier | `lib/features/challenge/daily_challenge_notifier.dart` |
| Daily challenge screen | `lib/features/challenge/daily_challenge_screen.dart` |
| Challenge stats service | `lib/features/challenge/daily_challenge_stats.dart` |
| Hot/cold feedback | `lib/features/challenge/hot_cold_feedback.dart` |

## Schema

Drift SQLite schema **v16**. Tables include `photo_date_records`, `user_added_countries`,
`user_removed_countries`, `trips`, `region_visits`, `xp_events`, `hero_images`,
`daily_challenge_progress`, `challenge_stats`.

## Tests (M189)

Flutter: ~2,400 tests, 0 failures with `ROAVVY_COMMERCE` off and on. `flutter analyze`: 0 errors.
Shared models: ~87.
