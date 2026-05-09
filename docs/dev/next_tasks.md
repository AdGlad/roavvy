# M100 — Expanded Template Variety

Branch: milestone/m100-expanded-template-variety

## Goal

The merch selection screen offers four distinct card design types — Passport, Flags, Heart Flags, and Tour Dates — giving users meaningful visual choice. Previously only three template groups were generated; Heart Flags was excluded from the merch pipeline because `HeartFlagsCard` had no `onAssetsLoaded` hook, causing the off-screen renderer to capture emoji fallbacks instead of SVG flags.

## Scope

**In:**
- `card_templates.dart` — add `onAssetsLoaded` + async-guard fields to `HeartFlagsCard`
- `card_image_renderer.dart` — include `CardTemplateType.heart` in the `assetsCompleter` branch; pass `onAssetsLoaded` to `HeartFlagsCard`
- `merch_context.dart` — add heart group to every `_build*Items()` method (between Flags and Tour Dates)
- `pulse_merch_option_screen.dart` — add heart to the groups constant
- `backlog_active.md` — add M100 entry and mark complete
- `docs/architecture/decisions/_index.md` — ADR-151

**Out:**
- Route, typography, explorer, vintage templates (new painting engines — M101+)
- Entry-only passport variant (M101)
- `shared_models` changes
- Web, Android
- `CardEditorScreen` changes

## Tasks

- [ ] 1. Add `onAssetsLoaded` to `HeartFlagsCard` — `card_templates.dart`
  - Deliverable: `HeartFlagsCard` gains `onAssetsLoaded: VoidCallback?` param; `_HeartFlagsCardState` gains `_preloadStarted` + `_onAssetsLoadedFired` guards; `_preloadSvgsForSize` tracks pending SVG loads with `Future.wait` and fires callback exactly once when all complete (or next frame if all already cached)
  - Acceptance: `onAssetsLoaded` fires exactly once; no double-fire from repeated LayoutBuilder calls

- [ ] 2. Wire heart into `CardImageRenderer` — `card_image_renderer.dart`
  - Deliverable: `assetsCompleter` created for passport, grid, AND heart; `_cardWidget` passes `onAssetsLoaded` to `HeartFlagsCard`
  - Acceptance: `CardImageRenderer.render(ctx, CardTemplateType.heart, codes: [...])` produces PNG bytes with SVG flags (not emoji)

- [ ] 3. Add heart group to `MerchContext` — `merch_context.dart`
  - Deliverable: All six `_build*Items()` methods include a Heart Flags group (between Flags and Tour Dates)
  - Acceptance: Achievement merch option screen shows 4 template groups; heart thumbnail renders correctly

- [ ] 4. Add heart group to `PulseMerchOptionScreen` — `pulse_merch_option_screen.dart`
  - Deliverable: `groups` constant includes `(label: 'Heart Flags', template: CardTemplateType.heart)` between Flags and Tour Dates
  - Acceptance: Memory Pulse shirt screen shows 4 template groups including Heart Flags

- [ ] 5. `flutter analyze` — 0 new warnings

## Dependencies

- M99 complete (MerchContext shared layer) ✅
- No new packages required

## Risks

| Risk | Mitigation |
|---|---|
| `HeartFlagsCard.onAssetsLoaded` fires multiple times if LayoutBuilder rebuilds | `_preloadStarted` guard prevents re-entry after first call |
| `Future.wait` never resolves if `FlagTileRenderer.loadSvgToCache` hangs | `CardImageRenderer.render()` already has `assetsTimeout` (default 10s) — heart also covered |
| Heart thumbnail looks odd at small size (72×92 px) | HeartLayoutEngine adapts density at any canvas size; recognizable even at thumbnail size |
