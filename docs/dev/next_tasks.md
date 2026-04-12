# M64 — Stamp Color in T-Shirt Design Stage: Next Tasks

**Goal:** Passport stamp color selection moves from card creation into the t-shirt design stage. Shirt color is chosen first; the system auto-suggests the best stamp color; bad combos are hard-disabled. Layout is unchanged when recoloring.

---

## Scope

**Included:**
- Remove `_PassportColorPicker` from `CardEditorScreen`
- Remove `passportColorMode` from `_CardParams`
- Remove `ArtworkConfirmationScreen` push from `CardEditorScreen._onPrint()`; navigate directly to `LocalMockupPreviewScreen`
- Move `PassportColorMode` + `_PassportParams` extension to a scope accessible from `LocalMockupPreviewScreen`
- Add `_passportColorMode` state to `LocalMockupPreviewScreen`
- Auto-suggest stamp color when shirt color changes
- Hard-disable invalid combos
- Wire `PassportColorMode` → `_artworkVariantIndex`
- Add `_PassportStampColorPicker` UI in `LocalMockupPreviewScreen` (passport + t-shirt only)
- Remove vertical swipe variant cycling

**Excluded:**
- Changes to non-passport templates (Grid, Heart, Timeline)
- Changes to Poster product flow
- Printful or Firebase Functions changes
- Web commerce flow
- `ArtworkConfirmationScreen` class deletion (keep as class, just not used in this path)

---

## Tasks

### Task 1 — Move `PassportColorMode` to shared scope ⬅ IN PROGRESS
**Deliverable:** `PassportColorMode` enum and its `stampColor`/`dateColor`/`transparentBackground` extension are accessible to both `card_editor_screen.dart` and `local_mockup_preview_screen.dart`.
**Acceptance criteria:**
- `PassportColorMode` defined in `apps/mobile_flutter/lib/features/merch/merch_stamp_color.dart` (new file)
- Extension `PassportColorParams` on `PassportColorMode` provides `.stampColor`, `.dateColor`, `.transparentBackground`
- Both `card_editor_screen.dart` and `local_mockup_preview_screen.dart` import this new file
- No duplicate definition of the enum
- `dart analyze` clean

---

### Task 2 — Remove `_PassportColorPicker` from `CardEditorScreen`
**Deliverable:** `CardEditorScreen` no longer shows or uses a stamp color picker for passport template.
**Acceptance criteria:**
- `_PassportColorPicker` widget removed from passport controls row in `CardEditorScreen`
- `passportColorMode` field removed from `_CardParams`
- `_CardParams` equality check still works on remaining fields (`templateType`, `countryCodes`, `aspectRatio`, `entryOnly`, `order`, `yearStart`, `yearEnd`, `titleOverride`)
- `CardEditorScreen` always renders with `stampColor: null, dateColor: null, transparentBackground: false`
- `dart analyze` clean

---

### Task 3 — Remove `ArtworkConfirmationScreen` push; navigate direct to `LocalMockupPreviewScreen`
**Deliverable:** `CardEditorScreen._onPrint()` navigates directly to `LocalMockupPreviewScreen` without pushing `ArtworkConfirmationScreen` first.
**Acceptance criteria:**
- `_onPrint()` pre-renders artwork via `CardImageRenderer.render()` with `stampColor: null, dateColor: null, transparentBackground: false`
- Pushes `LocalMockupPreviewScreen` directly with `artworkConfirmationId: null` (no prior confirmation)
- `stampColor: null, dateColor: null, transparentBackground: false` passed to `LocalMockupPreviewScreen`
- No `ArtworkConfirmationScreen.push()` call remains in the passport→merch path
- Non-passport templates (Grid, Heart, Timeline) navigation is unchanged
- `dart analyze` clean

---

### Task 4 — Add `_passportColorMode` state + suggest/disable logic to `LocalMockupPreviewScreen`
**Deliverable:** Screen has `PassportColorMode _passportColorMode` state and pure functions for suggestion and disabled combos.
**Acceptance criteria:**
- `PassportColorMode _passportColorMode` field initialised to `_suggestStampColor(_colour)` in `initState()`
- `_suggestStampColor(String shirtColour) → PassportColorMode` pure function:
  - Black → white
  - White → black
  - Navy → white
  - Heather Grey → black
  - Red → white
  - default → black
- `_disabledStampColors(String shirtColour) → Set<PassportColorMode>` pure function:
  - Black → {black, multicolor}
  - White → {white}
  - Navy → {black, multicolor}
  - Red → {multicolor}
  - Heather Grey → {}
  - default → {}
- `dart analyze` clean

---

### Task 5 — Wire `_passportColorMode` → `_artworkVariantIndex`
**Deliverable:** Changing `_passportColorMode` updates `_artworkVariantIndex` and triggers variant load if not yet cached.
**Acceptance criteria:**
- Mapping: `multicolor → 0`, `black → 1`, `white → 2`
- `_setPassportColorMode(PassportColorMode mode)` method that sets `_passportColorMode`, updates `_artworkVariantIndex`, and calls the existing `_loadArtworkVariant(index)` mechanism if `_artworkVariants[index] == null`
- `_artworkVariants[0]` is the initial multicolor render (from `widget.artworkImageBytes`)
- `_artworkVariants[1]` re-renders with `stampColor: Color(0xFF1A1A1A), transparentBackground: true`
- `_artworkVariants[2]` re-renders with `stampColor: Colors.white, transparentBackground: true`
- `dart analyze` clean

---

### Task 6 — Auto-apply stamp color suggestion when shirt color changes
**Deliverable:** Every time `_colour` changes, `_passportColorMode` is updated to the suggested value and `_artworkVariantIndex` follows.
**Acceptance criteria:**
- In `_onVariantOptionChanged()` (where shirt colour is updated), after setting `_colour`, call `_setPassportColorMode(_suggestStampColor(_colour))` when template is passport and product is t-shirt
- Auto-suggest does NOT fire when user manually changes stamp color (only when shirt color changes)
- Pre-load the suggested variant immediately on shirt color change
- `dart analyze` clean

---

### Task 7 — Add `_PassportStampColorPicker` UI widget
**Deliverable:** A row of stamp color chips appears in the controls area of `LocalMockupPreviewScreen` when template is passport and product is t-shirt.
**Acceptance criteria:**
- Three chips: `Multicolor`, `Black ink`, `White ink`
- Chips use the same visual style as colour swatches in `_buildOptionsBar` (circle or chip style consistent with existing design)
- Selected chip has visual highlight (border or fill)
- Disabled chips are greyed and non-tappable (use `_disabledStampColors(_colour)` to determine)
- Tapping an enabled, unselected chip calls `_setPassportColorMode(mode)`
- Picker only visible when `_isTshirt && _template == CardTemplateType.passport`
- Picker appears in the horizontal controls bar below the shirt colour swatches
- `dart analyze` clean

---

### Task 8 — Remove vertical swipe variant cycling
**Deliverable:** Vertical swipe on `_ShirtFlipView` no longer cycles through stamp color variants.
**Acceptance criteria:**
- `onNextVariant` (or equivalent vertical swipe handler) removed from `_ShirtFlipView` call site
- `_ShirtFlipView` itself: remove any `onNextVariant` callback param if it exists; or simply stop wiring it
- Variant cycling no longer occurs on vertical swipe
- `dart analyze` clean

---

### Task 9 — Tests
**Deliverable:** Tests cover stamp color logic and UI.
**Acceptance criteria:**
- Unit tests for `_suggestStampColor`: all 5 shirt colors return correct suggestion
- Unit tests for `_disabledStampColors`: all 5 shirt colors return correct disabled set
- Widget test: stamp color picker visible for passport + t-shirt template, hidden for other templates
- Widget test: disabled chip is non-tappable
- Widget test: shirt color change updates stamp color selection
- All existing tests pass (no regressions)

---

## Dependencies

```
Task 1 (PassportColorMode moved) → Tasks 2, 4, 5, 6, 7
Task 2 (remove picker) → Task 3
Task 3 (direct navigation) → depends on Tasks 2
Task 4 (state + logic) → Tasks 5, 6, 7
Task 5 (wire variant index) → Task 6, 7
Tasks 1-7 → Task 9
```

Tasks 2 + 3 land together. Tasks 4–7 all in `local_mockup_preview_screen.dart` — implement together.

---

## Risks

1. `_artworkVariantIndex` load mechanism (`_loadArtworkVariant`) — builder must read its exact implementation before wiring Task 5.
2. `_CardParams` equality check — removing `passportColorMode` must not break the re-confirmation shortcut for non-passport templates.
3. Non-passport navigation paths through `CardEditorScreen._onPrint()` must be unchanged.
