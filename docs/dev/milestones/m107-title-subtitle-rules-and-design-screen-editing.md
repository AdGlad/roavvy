# M107 — Title & Subtitle Rules and Design Screen Editing

**Branch:** `milestone/m107-title-subtitle-rules-and-design-screen-editing`
**Status:** Complete
**Created:** 2026-05-10

---

Overhaul how title and subtitle text is generated, rendered, and edited in the merch design flow.

The goal is to make every generated shirt feel premium: an emotional, whimsical title with no
country-count metadata; a structured supporting subtitle that starts with "Roavvy:" and provides
context. Both must be editable and regeneratable directly on the Design Your T-Shirt screen.

Do not break existing card templates (Passport, Heart, Tour Dates).
Do not change the purchase or Printful pipeline.
Do not touch the Memory Pulse or non-merch card flows unless directly required.

---

## Goal

- Shirts show an emotional, travel-inspired title (never "5 Countries" or "Flags")
- A structured subtitle ("Roavvy: N Countries • Region • Year") appears on the shirt
- Both fields are editable and regeneratable on `LocalMockupPreviewScreen`
- Text colour auto-adapts to shirt colour (dark text on light shirts, light on dark)
- Title and subtitle backgrounds are fully transparent (no opaque text boxes)

---

## Scope

### What changes

1. **`MerchStory.forOption()`** — rewrite title generation to produce emotional, count-free
   phrases; rewrite subtitle to produce "Roavvy: N Countries • …" format
2. **`CardTextRenderer`** — update branding zone to render "Roavvy: N Countries • …" subtitle;
   confirm full transparency; confirm `textColor` is correctly threaded everywhere
3. **`GridFlagsCard` + `CardImageRenderer`** — add `subtitleOverride` param for the structured
   "Roavvy:…" line; plumb through the rendering pipeline
4. **`LocalMockupPreviewScreen`** — add editable title field, editable subtitle field, and
   separate Regenerate buttons for each; wire to artwork re-render
5. **Regeneration wordbank** — build a varied set of travel-inspired title phrases per context
   type (continent, country, trip, year); ensure regeneration cycles never repeat the same phrase
   consecutively

### What does NOT change

- Printful/mockup integration
- Purchase/checkout flow
- Passport, Heart, Tour Dates card rendering logic
- Memory Pulse
- Web app

---

## Tasks

- [x] Task 1: Audit `CardTextRenderer.drawTitle` + `drawBranding`
- [x] Task 2: Build `MerchTitleWordbank` — curated wordbanks per context; seed-based rotation
- [x] Task 3: Rewrite `MerchStory.forOption()` — emotional titles; "Roavvy: N Countries • ..." subtitles
- [x] Task 4: Add `subtitleOverride` to `GridFlagsCard`, `TimelineCard`, `CardTextRenderer.drawBranding`, `CardImageRenderer`
- [x] Task 5: Wire `artworkSubtitle` from `PulseMerchOption` → `MerchOptionCard` → `LocalMockupPreviewScreen`
- [x] Task 6: Add title + subtitle edit fields with Regenerate buttons to `LocalMockupPreviewScreen`
- [x] Task 7: Fixed `isDark` heuristic to include 'Blue' in `tshirtColors`
- [x] Task 8: ADR-157 written; `flutter analyze` clean

---

## Acceptance Criteria

- No shirt title contains a country count, "X Countries", or other robotic metadata
- Every generated title is emotional, travel-inspired, and varies across regeneration presses
- Subtitle always starts with "Roavvy:" and always includes country count
- Subtitle format: `Roavvy: N Countries • [optional region] • [optional year range]`
- Title and subtitle are editable in `LocalMockupPreviewScreen`
- Each field has its own Regenerate button
- Regenerated titles vary significantly and never repeat consecutively
- Text colour is dark on light shirts and light on dark shirts for all tshirtColors
- Title and subtitle backgrounds are fully transparent (no solid boxes)
- Existing card exports (Passport, Heart, PDF) are not regressed
- `flutter analyze` passes

---

## Non-Negotiable Rules (from product brief)

1. Title MUST NOT include country count
2. Subtitle MUST begin with `Roavvy:`
3. Subtitle MUST include country count
4. Title/subtitle backgrounds MUST remain transparent
5. Text colour MUST adapt to shirt colour

---

## Key Files

| File | Role |
|---|---|
| `lib/features/merch/merch_story.dart` | Title + subtitle generation |
| `lib/features/cards/card_text_renderer.dart` | Canvas text rendering |
| `lib/features/cards/card_templates.dart` | GridFlagsCard, branding zone |
| `lib/features/cards/card_image_renderer.dart` | Render pipeline |
| `lib/features/merch/local_mockup_preview_screen.dart` | Design screen |
| `lib/features/merch/merch_option_list_widgets.dart` | MerchOptionCard display |

---

## Dependencies

- `MerchStory` (M104/ADR-154) — being rewritten
- `CardTextRenderer` — text colour already partially threaded (M105 region)
- `LocalMockupPreviewScreen` — already has `titleOverride` and shirt-colour logic

## Risks

- `subtitleOverride` must be plumbed to all card types that show a branding strip;
  passport/heart/timeline need to remain unaffected if not applicable
- Wordbank titles must be culturally appropriate and not feel generic — needs careful curation
- Editing title/subtitle on the design screen without layout jank requires careful state management
  (don't trigger full Printful mockup re-fetch on every keypress)
