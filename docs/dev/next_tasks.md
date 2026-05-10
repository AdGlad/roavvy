# M107 — Title & Subtitle Rules and Design Screen Editing [COMPLETE]

Branch: milestone/m107-title-subtitle-rules-and-design-screen-editing

## Goal

Emotional, count-free titles + "Roavvy: N Countries •…" structured subtitles on every shirt.
Both fields editable and regeneratable on the Design Your T-Shirt screen.
Text colour auto-adapts to shirt colour.

## Non-Negotiable Rules

1. Title MUST NOT include country count
2. Subtitle MUST begin with `Roavvy:`
3. Subtitle MUST include country count
4. Title/subtitle backgrounds MUST remain transparent
5. Text colour MUST adapt to shirt colour

## Tasks

- [ ] Task 1: Audit `CardTextRenderer.drawTitle` + `drawBranding` — confirm transparency,
  `textColor` threading, current branding content; identify what `subtitleOverride` needs to add
- [ ] Task 2: Build `TitleWordbank` — curated travel-inspired title phrases per context
  (country/continent/trip/year/all-time); randomised selection that avoids consecutive repeats
- [ ] Task 3: Rewrite `MerchStory.forOption()` — titles use `TitleWordbank` (no count);
  subtitles use "Roavvy: N Countries • [Region] • [Year]" format
- [ ] Task 4: Add `subtitleOverride` to `GridFlagsCard`, `CardTextRenderer.drawBranding`,
  and `CardImageRenderer.render`; plumb through all relevant card templates
- [ ] Task 5: Wire `MerchStory.subtitle` as the `subtitleOverride` throughout the merch
  rendering pipeline (MerchOptionCard → LocalMockupPreviewScreen → CardImageRenderer)
- [ ] Task 6: Add title + subtitle edit fields and per-field Regenerate buttons to
  `LocalMockupPreviewScreen`; re-render artwork on change; preserve shirt colour and other state
- [ ] Task 7: Verify text colour auto-adaptation covers all tshirtColors; ensure textColor
  flows to card artwork for all template types in the merch pipeline
- [ ] Task 8: ADR-157 + update current_state.md, backlog_active.md + flutter analyze clean
