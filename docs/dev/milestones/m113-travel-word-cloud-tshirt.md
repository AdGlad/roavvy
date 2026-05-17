# M113 — Travel Word Cloud T-Shirt Design

**Phase:** 20 — Commerce Experience
**Depends on:** M103 (expanded merch template variety), M102 (merch context system)
**Status:** Complete (2026-05-17)

---

## Goal

Add a new `CardTemplateType.wordCloud` merch image type where country names are rendered
as a typographic word cloud. Visit frequency (trip count) controls text size so repeat
travellers see their most-visited destinations appear largest.

---

## What was built

### New file
- `apps/mobile_flutter/lib/features/cards/word_cloud_card.dart`
  - `TravelWordCloudCard` — StatefulWidget, square (1:1) aspect ratio
  - Visit-frequency weighting via `TripRecord` list
  - `WordCloudColorMode` enum: `monochrome | pastel | continentColor`
  - Transparent background support for t-shirt compositing
  - Title and subtitle branding strips (ADR-157 convention)
  - `onAssetsLoaded` callback following the BadgeCard protocol

### Modified files
- `packages/shared_models/lib/src/travel_card.dart` — added `wordCloud` variant
- `apps/mobile_flutter/pubspec.yaml` — added `word_cloud: ^1.0.3`
- `apps/mobile_flutter/lib/features/cards/card_image_renderer.dart` — wordCloud case
- `apps/mobile_flutter/lib/features/cards/card_type_picker_screen.dart` — picker list
- `apps/mobile_flutter/lib/features/cards/card_editor_screen.dart` — preview + render
- `apps/mobile_flutter/lib/features/cards/card_generator_screen.dart` — template builder
- `apps/mobile_flutter/lib/features/cards/artwork_confirmation_screen.dart` — label
- `apps/mobile_flutter/lib/features/merch/merch_template_ranker.dart` — rankings

---

## ADR notes

No new ADR required. Pattern follows ADR-153 (BadgeCard) for the onAssetsLoaded
protocol and ADR-157 for title/subtitle branding conventions.

---

## Acceptance criteria — met

- [x] new image type renders correctly
- [x] text size reflects visit count
- [x] transparent export works
- [x] shirt colour adaptation works via `WordCloudColorMode`
- [x] title/subtitle integration works
- [x] achievement suggestions include word cloud (merch_template_ranker)
- [x] existing purchase flow unchanged
- [x] flutter analyze: zero new warnings
