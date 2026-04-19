# Docs Topic Index

Grep this file for a keyword → get ADRs + source files to read.
To read a specific ADR: grep its header in `adr-recent.md` or `adr-archive.md` for the line number, then Read with offset.

```
grep -n "## ADR-125" docs/architecture/decisions/adr-recent.md
# → 812: ## ADR-125 — …
# → Read(adr-recent.md, offset=812, limit=50)
```

---

## scan, photo-scan, PhotoKit, sinceDate, incremental, EventChannel
ADR: 012, 022, 023, 058, 059, 095, 108, 110 → `adr-archive.md`
Files: `ios/Runner/PhotoScanPlugin/`, `lib/features/scan/scan_screen.dart`, `lib/core/providers.dart`

## country-detection, country_lookup, polygon, offline, GPS, coordinate-bucketing
ADR: 004, 005, 015, 017, 020 → `adr-archive.md`
Files: `packages/country_lookup/lib/`, `lib/core/providers.dart`

## region, region_lookup, admin1, ISO-3166-2, RegionRepository
ADR: 049, 050, 051, 069, 070, 072, 081, 091 → `adr-archive.md`
Files: `packages/region_lookup/lib/`, `lib/features/stats/region_breakdown_sheet.dart`

## merge, user-edits, tombstone, override, manual-add, manual-remove
ADR: 006, 008, 033 → `adr-archive.md`
Files: `lib/data/visit_repository.dart`, `lib/features/scan/review_screen.dart`

## drift, schema, SQLite, migration, persistence, source-of-truth
ADR: 003, 016, 022, 036, 047, 048, 050, 051, 053, 060 → `adr-archive.md`
Files: `lib/data/roavvy_database.dart`, `lib/data/visit_repository.dart`
Schema: v10 — `photo_date_records`, `user_added_countries`, `user_removed_countries`, `trips`, `region_visits`, `xp_events`

## firestore, sync, flushDirty, firebase, auth, anonymous, Apple-Sign-In
ADR: 026–032, 037, 039, 043, 075, 087 → `adr-archive.md`
Files: `lib/data/firestore_sync_service.dart`, `lib/features/auth/apple_sign_in.dart`, `lib/core/providers.dart`

## map, flutter_map, PolygonLayer, polygon-rendering, CountryPolygonLayer, depth-colour, navy
ADR: 014, 015, 017, 020, 066, 076, 077, 080 → `adr-archive.md`
Files: `lib/features/map/map_screen.dart`, `lib/features/map/country_polygon_layer.dart`

## trips, TripInference, TripRecord, Journal, trip-region-map
ADR: 047, 048, 058, 082, 083, 090 → `adr-archive.md`
Files: `lib/data/trip_repository.dart`, `lib/features/journal/journal_screen.dart`, `lib/features/map/trip_map_screen.dart`

## achievements, XP, level, LevelUpSheet, MilestoneCard, MilestoneRepository
ADR: 034, 036, 038, 094 → `adr-archive.md`
Files: `lib/data/achievement_repository.dart`, `lib/features/scan/level_up_sheet.dart`, `lib/data/level_up_repository.dart`

## celebration, DiscoveryOverlay, globe, confetti, GlobePainter, carousel, CelebrationGlobeWidget
ADR: 068, 084, 095, 108, 109, 123, 126 → `adr-recent.md`
Files: `lib/features/scan/discovery_overlay.dart`, `lib/features/map/celebration_globe_widget.dart`

## card-editor, CardEditorScreen, CardTemplateType, template-picker, card-generator
ADR: 092, 099, 101, 102, 103, 107, 119b → `adr-recent.md`
Files: `lib/features/cards/card_editor_screen.dart`, `lib/features/cards/card_templates.dart`

## passport, stamp, PassportStampsCard, PassportLayoutEngine, StampPainter, StampStyle, seed, shuffle
ADR: 096, 097, 113, 117, 125 → `adr-recent.md`
Files: `lib/features/cards/card_templates.dart`, `lib/features/cards/passport_layout_engine.dart`, `lib/features/cards/stamp_painter.dart`

## heart, HeartFlagsCard, HeartLayoutEngine, heart-mask, SVG-flags, FlagTileRenderer, gapless
ADR: 098 → `adr-recent.md`
Files: `lib/features/cards/heart_layout_engine.dart`, `lib/features/cards/flag_tile_renderer.dart`

## grid, GridFlagsCard, emoji-flags, SVG-grid, tile-size, adaptive
ADR: 102, 118 → `adr-recent.md`
Files: `lib/features/cards/card_templates.dart`

## title, title-generation, AI-title, AiTitlePlugin, fallback, rule-based, year, region-names
ADR: 125 → `adr-recent.md`
Files: `ios/Runner/AiTitlePlugin.swift`, `lib/features/cards/title_generation/rule_based_title_generator.dart`

## sharing, share-token, share-sheet, TravelCardService, share-page
ADR: 040, 041, 042, 078 → `adr-archive.md`
Files: `lib/features/cards/travel_card_service.dart`, `lib/features/auth/privacy_account_screen.dart`
Web: `apps/web_nextjs/src/app/share/[token]/`

## commerce, merch, Shopify, Printful, createMerchCart, MerchConfig, checkout, mockup
ADR: 062–065, 073, 074, 079, 085–089, 093, 099, 107, 114, 115, 120, 121 → `adr-archive.md` (pre-100) + `adr-recent.md` (100+)
Files: `lib/features/merch/`, `lib/features/merch/local_mockup_preview_screen.dart`, `apps/functions/src/index.ts`

## package-boundaries, DAG, shared_models, country_lookup, cross-package
ADR: 004, 007, 049 → `adr-archive.md`
Files: `docs/engineering/package_boundaries.md`, `packages/`

## onboarding, OnboardingFlow, first-launch, permission-timing
ADR: 053 → `adr-archive.md`
Files: `lib/features/onboarding/onboarding_flow.dart`, `lib/app.dart`

## notifications, push, flutter_local_notifications, nudge, tap-routing
ADR: 056 → `adr-archive.md`
Files: `lib/core/notification_service.dart`

## web, Next.js, sign-in, sign-up, map-route, shop, password-reset
ADR: 044, 045, 046, 078, 079 → `adr-archive.md`
Files: `apps/web_nextjs/src/app/`
Not built: M28 (web checkout), M31 (password reset)

## Riverpod, providers, state-management, provider-graph, effectiveVisitsProvider
ADR: 018 → `adr-archive.md`
Files: `lib/core/providers.dart`
Key providers: `effectiveVisitsProvider`, `tripListProvider`, `regionProgressProvider`, `xpNotifierProvider`, `achievementRepositoryProvider`
