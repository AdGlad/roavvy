# Roavvy — Current State (updated M78, 2026-04-24)

## What is built

| Feature area | Status | Notes |
|---|---|---|
| Photo scan | ✅ | PhotoKit bridge; GPS → country (offline, `country_lookup`); unified scan UX (M78): always-visible globe + country list + passport stamps pre-populated at rest, live-animated during scan; all scan outcomes navigate through ScanSummaryScreen; assetId-based dedup (M77) |
| World map | ✅ | `flutter_map`; dark navy/gold; depth colouring; timeline scrubber; gamified visual states (5 states) |
| Country/region detection | ✅ | ISO 3166-2 admin1 via `region_lookup`; region progress chips + detail sheet |
| Trips / Journal | ✅ | `TripInference`; trip region map; journal screen; photo gallery per country/trip |
| Achievements + XP | ✅ | 8 XP levels; milestone cards at [5,10,25,50,100]; `LevelUpSheet`; achievement gallery |
| Celebrations | ✅ | `DiscoveryOverlay` with animated globe, per-country confetti; celebration carousel (M72) |
| Travel cards | ✅ | Grid (SVG flags, M67), Heart (SVG flags + title rendering, M67), Passport templates; `CardEditorScreen`; AI + fallback titles (year-free, M70) |
| Sharing | ✅ | Share sheet; `/share/[token]` web page; token revocation |
| Commerce (mobile) | ✅ | T-shirt + poster; Printful mockup (front+back, strict-only, no local fallback post-approval, M73); front placement options (left/center/right/none); back placement (center/none); left_chest uses named Printful placement + small chest PNG (M76); strict checkout gate; Shopify checkout; post-purchase poll |
| Commerce (web) | ✅ | `/shop` public landing; auth-aware CTA; web checkout in M28 (not started) |
| Firebase | ✅ | Anonymous auth; Apple Sign-In; Firestore sync (visits, trips, achievements, merch configs) |
| Web app | ✅ | `/sign-in`, `/sign-up`, `/map`, `/shop`, `/share/[token]`, `/privacy` |
| Onboarding | ✅ | 3-screen `OnboardingFlow`; bypassed for returning users |
| Notifications | ✅ | Achievement unlock + 30-day nudge; tap routing to correct tab |
| Rovy mascot | ✅ | `RovyBubble`; 5 trigger types; 4s auto-dismiss |

## What is NOT built

- M28: Web commerce checkout (country select → Shopify cart on web)
- M31: Web password reset flow
- M61: Grid Card real-flag SVG upgrade (currently emoji-based)
- M66: Heart Card gapless SVG repack
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
| Scan bridge (Swift) | `ios/Runner/PhotoScanPlugin/` |
| Country lookup | `packages/country_lookup/lib/` |
| Region lookup | `packages/region_lookup/lib/` |

## Schema

Drift SQLite schema **v10** — tables: `photo_date_records` (v9 + `asset_id`), `user_added_countries`, `user_removed_countries`, `trips`, `region_visits`, `xp_events`.

## Tests (M72)

Flutter: ~800+ | Shared models: ~87 | `flutter analyze` clean
