# M93 — Hero Image Share Card Background

**Branch:** `milestone/m93-hero-share-card-background`
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (hero images in SQLite), M90 (HeroImageView + thumbnail channel)
**Status:** Not started

---

## 1. Milestone Goal

Allow the user to optionally use their hero image (or any photo from their library) as a background layer behind the stamp artwork on a passport card, or as a full background on grid/heart cards. The card editor gains a "Photo background" toggle. The selected photo is composited at print resolution for sharing and merch.

---

## 2. Product Value

Cards become personalised to the user's actual trips rather than abstract graphics. A passport stamp card over an Aegean beach photo is a premium shareable product that no generic travel app can produce.

---

## 3. Scope

**In:**
- `lib/features/cards/card_editor_screen.dart`
- `lib/features/cards/card_templates.dart` (PassportStampsCard, GridCard — add background layer)
- `lib/features/cards/card_image_renderer.dart` (render with background photo)
- New `lib/features/cards/card_background_picker.dart`
- `ios/Runner/ThumbnailPlugin.swift` (full-resolution fetch for render; M90 adds thumbnails only)

**Out:** Heart card background (complex heart-shaped clip — deferred), video backgrounds, web card generator, merch-specific background enforcement.

---

## 4. UX Design

### 4a. Card editor — background toggle

In the passport overlay controls (top panel), after the size/scatter sliders, add:

```
[Photo background]  ○ Off   ● Hero photo   ○ Choose…
```

- **Off** (default): existing parchment/transparent background
- **Hero photo**: auto-selects `rank=1` hero for the current trip selection
- **Choose…**: opens `CardBackgroundPicker` — shows candidates from hero images + a "Browse library" option (uses `PHPickerViewController`)

When a background photo is active, a small thumbnail swatch is shown in the controls row.

### 4b. Background rendering — passport card

```
Layer stack (bottom → top):
  1. Background photo     — full card area, BoxFit.cover, 70% opacity
  2. Gradient overlay     — bottom 30% darkens to black (stamp readability)
  3. Parchment texture    — blended at 20% opacity (maintains stamp feel)
  4. Stamp layer          — unchanged
  5. Title + branding     — unchanged
```

- Background photo is fetched at card canvas resolution via `ThumbnailPlugin` (full-res path)
- Opacity, gradient, and texture blend are hardcoded constants (not user-adjustable in M93)

### 4c. Background rendering — grid card

```
Layer stack:
  1. Background photo     — full card, BoxFit.cover, 55% opacity
  2. Gradient overlay     — full card, subtle dark vignette
  3. Flag tiles           — unchanged (flags have white/transparent bg; blend naturally)
  4. Title + branding     — unchanged
```

### 4d. Print / share behaviour

When a background photo is selected:
- `CardImageRenderer.render()` receives `backgroundAssetId: String?`
- Swift side fetches the photo at the render canvas pixel size via `PHImageManager.requestImage(targetSize:)` with `PHImageRequestOptions.deliveryMode = .highQualityFormat`
- Composited onto the offscreen canvas before stamp/flag layers are drawn
- `RepaintBoundary` WYSIWYG capture (passport editor) already captures the background in the preview — no extra step needed

---

## 5. Data Model Extension

`CardImageRenderer.render()` gains one new optional parameter:

```dart
static Future<CardImageResult> render(
  BuildContext context,
  CardTemplateType template, {
  ...existing params...
  String? backgroundAssetId,       // NEW — null = no photo background
  double backgroundOpacity = 0.70, // NEW — hardcoded for M93; user-adjustable later
})
```

The `backgroundAssetId` is stored transiently in the card editor state (`_backgroundAssetId`). It is **not** persisted to Firestore or the card record in M93 — persistence is a follow-up.

---

## 6. Implementation Tasks

### T1 — Full-resolution photo fetch in ThumbnailPlugin
**File:** `ios/Runner/ThumbnailPlugin.swift`
**Deliverable:** Add `getFullResolutionImage({assetId: String, targetWidth: int}) → Uint8List?` method on the same `roavvy/thumbnail` channel. Uses `PHImageManager.requestImage` with `deliveryMode = .highQualityFormat`, `isNetworkAccessAllowed = false`. Returns JPEG bytes at native resolution capped at `targetWidth`.
**Acceptance:** Returns full-res bytes for valid local asset. Returns null for unavailable/iCloud-only asset. Does not block main thread.

---

### T2 — `CardBackgroundPicker` widget
**File:** `lib/features/cards/card_background_picker.dart`
**Deliverable:** Bottom sheet. Shows: "No background" option, top 3 hero candidates (thumbnails from M90), "Choose from library" option (opens `PHPickerViewController` via existing photo permission flow). Returns selected `assetId?` (null = no background).
**Acceptance:** Picker shows hero candidates. Library picker returns assetId without storing the photo. "No background" clears selection.

---

### T3 — Background layer in `PassportStampsCard`
**File:** `lib/features/cards/card_templates.dart`
**Deliverable:** Add `backgroundAssetId` and `backgroundOpacity` params to `PassportStampsCard`. In the card paint pipeline, if `backgroundAssetId` is non-null: draw background photo as the first canvas layer (fetched via `ThumbnailPlugin`), draw gradient overlay, then existing parchment + stamps layers on top.
**Acceptance:** Card renders correctly with and without background. Background is visible beneath stamps. Parchment texture still present.

---

### T4 — Background layer in `GridCard`
**File:** `lib/features/cards/card_templates.dart`
**Deliverable:** Same as T3 for `GridCard`. Background photo drawn before flag tiles.
**Acceptance:** Flag tiles remain readable against background. Grid card renders correctly with and without background.

---

### T5 — `CardImageRenderer` background support
**File:** `lib/features/cards/card_image_renderer.dart`
**Deliverable:** Pass `backgroundAssetId` through to the card template widgets in the offscreen render tree. Swift side fetches full-res photo bytes and passes them down as `Uint8List` before render. Background photo is composited at render canvas resolution.
**Acceptance:** Share/print output includes background photo at full render resolution. WYSIWYG: background visible in editor matches background in printed output.

---

### T6 — Card editor: background controls
**File:** `lib/features/cards/card_editor_screen.dart`
**Deliverable:** Add `_backgroundAssetId` state. In `_PassportTopOverlay` (and equivalent non-passport controls for grid), add background picker row after sliders. Three-way toggle: Off / Hero photo / Choose…. Tapping "Choose…" opens `CardBackgroundPicker`. Selected thumbnail shown as a small swatch. Pass `backgroundAssetId` to preview card and to `CardImageRenderer` at print/share time.
**Acceptance:** Toggle works. Selecting "Hero photo" auto-selects rank=1 hero for current trips. Choosing from library updates the swatch. Removing background returns to parchment. Background is captured in RepaintBoundary WYSIWYG at print time.

---

## 7. Build Order

```
T1  Full-res photo fetch (Swift)    (blocks T5)
T2  CardBackgroundPicker            (standalone UI)
T3  PassportStampsCard background   (independent)
T4  GridCard background             (independent, parallel with T3)
T5  CardImageRenderer support       (depends on T1, T3, T4)
T6  Card editor controls            (depends on T2, T3, T4, T5)
```

---

## 8. Privacy Note

`backgroundAssetId` is a PHAsset local identifier. It follows the same rules as all other `assetId` values in the codebase:
- Stored locally in card editor state only (transient in M93)
- Never written to Firestore
- The photo itself is never uploaded to Printful or any server
- The rendered card PNG (which composites the photo) is uploaded to Printful — this is the same as any share/print flow and is user-initiated and expected

---

## 9. ADR

**ADR-138 — M93 Hero Photo Background Layer in Card Templates**

An optional background photo layer is added to `PassportStampsCard` and `GridCard` below the existing stamp/flag layers. Background photos are fetched at render resolution via `PHImageManager` (`isNetworkAccessAllowed = false`). The `backgroundAssetId` is passed transiently through the card editor state and render pipeline; it is not persisted to Firestore in M93. The rendered card PNG (containing the composited photo) is the user's intended shareable output — upload to Printful is expected and user-initiated. Heart card background is deferred due to clipping complexity.
