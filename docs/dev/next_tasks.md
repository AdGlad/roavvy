# M103 — Expanded Merch Template Variety

Branch: milestone/m103-expanded-merch-template-variety

## Goal

Add `CardTemplateType.typography` and `CardTemplateType.badge`, implement their renderers, add shirt colour intelligence, and update MerchContext builders for richer per-achievement curation.

## Scope

**In:**
- `packages/shared_models/lib/src/travel_card.dart` — add `typography`, `badge` enum values
- `apps/mobile_flutter/lib/features/cards/card_templates.dart` — `TypographyCard`, `BadgeCard`
- `apps/mobile_flutter/lib/features/cards/card_image_renderer.dart` — support new templates
- `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart` — labels, `merchBackCardAspectRatio`, `merchSuggestShirtColor`
- `apps/mobile_flutter/lib/features/merch/pulse_merch_option.dart` — `suggestedShirtColor` field
- `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart` — `initialColour` param
- `apps/mobile_flutter/lib/features/merch/merch_context.dart` — typography+badge in builders
- `apps/mobile_flutter/lib/features/cards/card_editor_screen.dart` — stub cases
- `apps/mobile_flutter/lib/features/cards/artwork_confirmation_screen.dart` — cases
- `apps/mobile_flutter/lib/features/cards/card_type_picker_screen.dart` — cases

**Out:**
- Route/vintage/scrapbook/minimalist templates
- Full card editor support for new templates (stub only)
- Printful, Shopify, checkout, web, Android

## Tasks

- [x] 1. Add `CardTemplateType.typography` and `CardTemplateType.badge`; update all exhaustive switches
  - **Files:** `travel_card.dart`; `merch_option_list_widgets.dart`; `card_image_renderer.dart`; `card_editor_screen.dart`; `artwork_confirmation_screen.dart`; `card_type_picker_screen.dart`
  - **Acceptance:** compiles; `merchTemplateLabel(CardTemplateType.badge)` = `'Explorer Badge'`; `merchTemplateLabel(CardTemplateType.typography)` = `'Typography'`; `merchBackCardAspectRatio(CardTemplateType.badge)` = `1.0`

- [x] 2. Implement `TypographyCard` widget in `card_templates.dart`
  - **Deliverable:** `TypographyCard({required List<String> codes, String? titleOverride, bool transparentBackground})` CustomPaint widget; stacked two-column country names with alternating size/opacity; single-country = centred headline; truncates at 24 items with "+ N more"; dark navy background unless transparentBackground
  - **Acceptance:** `CardImageRenderer.render(ctx, CardTemplateType.typography, codes: ['FR','DE','IT'])` returns non-empty bytes for 1, 5, 20, 50 countries

- [x] 3. Implement `BadgeCard` widget in `card_templates.dart`
  - **Deliverable:** `BadgeCard({required List<String> codes, String? scopeLabel, bool transparentBackground})` CustomPaint widget; outer tick ring; up to 12 flag thumbnails in arc; central scope label; outer letterpress ring text; `onAssetsLoaded` callback following HeartFlagsCard pattern; 1:1 square canvas
  - **Acceptance:** `CardImageRenderer.render(ctx, CardTemplateType.badge, codes: ['FR'])` and `codes: 12 countries` both complete without error

- [x] 4. Add `suggestedShirtColor` to `PulseMerchOption`; `initialColour` to `LocalMockupPreviewScreen`; wire through `MerchOptionCard._navigate()`
  - **Files:** `pulse_merch_option.dart`; `local_mockup_preview_screen.dart`; `merch_option_list_widgets.dart`
  - **Acceptance:** Tapping option with `suggestedShirtColor: 'Navy'` opens mockup with Navy pre-selected; existing callers unchanged

- [x] 5. Extract `merchSuggestShirtColor`; update `MerchContext._addGroup`
  - **Files:** `merch_option_list_widgets.dart`; `merch_context.dart`
  - **Acceptance:** All emitted `PulseMerchOption` have non-null `suggestedShirtColor`; badge suggests `'Navy'`

- [x] 6. Update `MerchContext` builders to include Typography and Badge; improve curation
  - **File:** `merch_context.dart`
  - **Acceptance:** `_buildFirstCountryItems()` contains badge entry; `_buildCountryItems()` for 10 countries contains typography entry; badge skipped when `codes.length > 15`

- [x] 7. ADR-153 + `flutter analyze` — 0 new warnings

## Dependencies

- M102 complete ✅
- `kCountryNames`, `FlagImageCache`, `HeartFlagsCard.onAssetsLoaded` pattern all available ✅

## Risks

| Risk | Mitigation |
|---|---|
| BadgeCard SVG flag load timeout | Follow HeartFlagsCard.onAssetsLoaded pattern exactly |
| card_editor_screen switch cases for new templates | Stub fallthrough to grid behaviour; full editor deferred |
| Typography 50+ countries crowded | Truncate at 24 with "+ N more" |
