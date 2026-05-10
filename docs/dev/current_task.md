# Active Task: M100 — Expanded Template Variety

Branch: milestone/m100-expanded-template-variety

## Status: ✅ Complete (2026-05-08)

## Goal

Four merch template groups (Passport, Flags, Heart Flags, Tour Dates) available in both Memory Pulse and Achievement merch screens. Heart Flags renders correctly using SVG flags via a new `onAssetsLoaded` hook on `HeartFlagsCard`.

## Tasks

- [x] 1. Add `onAssetsLoaded` to `HeartFlagsCard` — `lib/features/cards/card_templates.dart`
- [x] 2. Wire heart into `CardImageRenderer` — `lib/features/cards/card_image_renderer.dart`
- [x] 3. Add heart group to `MerchContext` — `lib/features/merch/merch_context.dart`
- [x] 4. Add heart group to `PulseMerchOptionScreen` — `lib/features/merch/pulse_merch_option_screen.dart`
- [x] 5. `flutter analyze` — 0 new warnings
