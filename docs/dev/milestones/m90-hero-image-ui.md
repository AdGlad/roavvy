# M90 — Hero Image UI Surfaces

**Branch:** `milestone/m90-hero-image-ui`
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (hero_images table + heroForTripProvider)
**Status:** Not started

---

## 1. Milestone Goal

Surface the hero images produced by M89 in the three screens where users already look at their travel data: the journal (trip cards), the country detail sheet, and the scan summary. Add a user override picker so users can swap their hero image without leaving the context they are already in.

---

## 2. Product Value

M89 is invisible to the user. M90 is the payoff — every trip card and country card gains a visual identity. The app shifts from a data tracker to a memory keeper.

---

## 3. Scope

**In:**
- `lib/features/journal/journal_screen.dart`
- `lib/features/map/country_detail_sheet.dart`
- `lib/features/scan/scan_summary_screen.dart`
- `lib/features/scan/hero_image_repository.dart` (T8 from M89 — `setUserSelected`)
- New shared widget: `lib/features/shared/hero_image_view.dart`

**Out:** Memory Pulse, share cards, title generation, recap screen, web, Android.

---

## 4. UX Design

### 4a. Journal screen — trip card header

Each trip card gains a full-bleed photo header above the trip metadata row.

```
┌──────────────────────────────────────────┐
│                                          │
│    [HERO IMAGE — full bleed, 160 dp]     │
│                                          │
│  ✏ (top-right: override picker trigger)  │
├──────────────────────────────────────────┤
│  Greece · 12 Jul – 18 Jul 2024           │
│  7 days · Aegean Coast · 23 photos       │
└──────────────────────────────────────────┘
```

- If `rank=1` hero exists: show it via `PHImageManager.requestImage` (thumbnail size)
- If no hero yet (analysis still running): show a shimmer placeholder; update reactively when `heroForTripProvider` emits
- If hero is tombstoned (`rank=-1`) or `assetId` unavailable: show a solid colour tile derived from the country's continent colour (reuse existing map depth colour)

### 4b. Country detail sheet — cover image

The country detail sheet header currently shows flag + country name + stat chips. Add a full-bleed hero image behind/above the existing header content.

```
┌──────────────────────────────────────────┐
│                                          │
│    [BEST HERO across all trips to GR]    │   ← highest heroScore where rank=1
│           (full-bleed, 200 dp)           │
│                                          │
│  [GR flag]  Greece            ✏         │
│  14 visits  3 trips  2019–2024           │
├──────────────────────────────────────────┤
│  ... existing sheet content ...          │
```

- Selects the single highest-scoring `rank=1` hero across all trips for that `countryCode`
- Shimmer while loading; country colour tile fallback

### 4c. Scan summary screen — "best shot" moment

At the bottom of the scan summary, if any new trips were discovered in this scan, show:

```
┌──────────────────────────────────────────┐
│  Best shot from this scan                │
│                                          │
│    [HERO IMAGE]        Greece, Jul 2024  │
│                        beach · sunset    │
└──────────────────────────────────────────┘
```

- Only shown when ≥1 new trip was discovered AND hero analysis has completed
- Shows the highest-scoring hero across new trips only
- Labels (`primaryScene`, `mood[0]`) shown as small chips below country + date
- If hero analysis has not completed by the time the screen loads: section is hidden entirely (no shimmer)

### 4d. Hero override picker

Tapping the `✏` pencil icon on any hero image opens a bottom sheet:

```
┌──────────────────────────────────────────┐
│  Choose your hero image                  │
│  ─────────────────────────────────────── │
│  [img1 ★]   [img2]   [img3]             │  ← horizontal scroll, rank 1/2/3
│                                          │
│  [Use this photo]   [Reset to auto]      │
└──────────────────────────────────────────┘
```

- Shows up to 3 candidate thumbnails (`rank` 1/2/3 for that tripId)
- `★` marks the current selection
- "Use this photo": calls `HeroImageRepository.setUserSelected(assetId, tripId)` → sets `isUserSelected=true` on chosen row, clears it on previous
- "Reset to auto": sets `isUserSelected=false` on all rows for that trip; next re-scan will re-evaluate
- If only 1 candidate exists: picker shows single image with "This is your only candidate" note

---

## 5. Shared Widget: `HeroImageView`

```dart
/// Displays a hero image loaded from a local PHAsset assetId.
///
/// Shows a shimmer while loading, and a [fallbackColor] tile if the asset
/// is unavailable or no hero exists.
class HeroImageView extends StatelessWidget {
  const HeroImageView({
    required this.assetId,       // null → show fallback immediately
    required this.fallbackColor,
    this.height = 160.0,
    this.onEditTap,              // null → no edit icon
    this.fit = BoxFit.cover,
  });
}
```

Image is loaded via the existing `MethodChannel("roavvy/hero_analysis")` or a new dedicated `roavvy/thumbnail` channel that returns a JPEG byte array for a given `assetId` at the requested pixel size. Result is cached in memory for the session.

---

## 6. Implementation Tasks

### T1 — `HeroImageView` shared widget
**File:** `lib/features/shared/hero_image_view.dart`
**Deliverable:** Widget described in Section 5. Requests thumbnail via MethodChannel at `imageSize * devicePixelRatio` (cap 600 px). Shows shimmer during load (`shimmer` package already in pubspec or use `AnimatedContainer` pulse). Fallback to solid `fallbackColor`.
**Acceptance:** Widget test: loads shimmer, transitions to image, shows fallback when assetId is null.

---

### T2 — iOS thumbnail MethodChannel
**File:** `ios/Runner/ThumbnailPlugin.swift`
**Channel:** `roavvy/thumbnail`
**Method:** `getThumbnail({assetId: String, size: int}) → Uint8List? (JPEG bytes)`
**Deliverable:** `PHImageManager.requestImage` for given assetId at requested size. `isNetworkAccessAllowed = false`. Returns nil (Dart `null`) for unavailable/iCloud-only assets. Results cached in `NSCache` keyed by `assetId+size`.
**Acceptance:** Returns bytes for a valid local asset. Returns null for a non-existent assetId. Does not access network.

---

### T3 — Journal screen: trip card hero header
**File:** `lib/features/journal/journal_screen.dart`
**Deliverable:** Add `HeroImageView` above each trip card. Read `heroForTripProvider(trip.id)` — pass `assetId` (or `null` if no hero) + continent fallback colour. Pencil icon triggers override picker.
**Acceptance:** Trip cards show hero images. Shimmer shown while hero analysis pending. Fallback colour shown for trips with no hero.

---

### T4 — Country detail sheet: hero cover
**File:** `lib/features/map/country_detail_sheet.dart`
**Deliverable:** New `bestHeroForCountryProvider(countryCode)` — queries `HeroImageRepository.getBestHeroForCountry(countryCode)` (highest `heroScore` where `rank >= 1`). Add `HeroImageView` as sheet cover. Pencil triggers override picker (shows candidates across all trips for that country).
**Acceptance:** Sheet shows hero image for countries where hero analysis has run. Graceful fallback for countries with no hero.

---

### T5 — Scan summary: best shot section
**File:** `lib/features/scan/scan_summary_screen.dart`
**Deliverable:** `bestHeroFromScanProvider(newTripIds)` — queries `HeroImageRepository.getBestHeroFromTrips(tripIds)`. Section only rendered when provider emits a non-null result. Shows hero image + country + date + top 2 labels as chips.
**Acceptance:** Section not rendered when no new trips. Section not rendered when hero analysis has not completed yet. Section appears (reactively) when analysis finishes.

---

### T6 — Hero override picker bottom sheet
**File:** `lib/features/shared/hero_override_picker.dart`
**Deliverable:** `showHeroOverridePicker(context, tripId)` — bottom sheet with horizontal scroll of candidate thumbnails (rank 1/2/3). "Use this photo" and "Reset to auto" actions. Calls `HeroImageRepository.setUserSelected` / `clearUserSelected`.
**Acceptance:** Selection persists after sheet dismiss. `isUserSelected` is correctly set/cleared in Drift. Provider updates and UI refreshes without full rebuild.

---

### T7 — `bestHeroForCountryProvider` + `bestHeroFromScanProvider`
**File:** `lib/features/scan/hero_providers.dart` (extends T11 from M89)
**Deliverable:** Two additional Riverpod providers. `bestHeroForCountryProvider(countryCode)` streams the single highest-scoring row for the country. `bestHeroFromScanProvider(tripIds)` returns a `Future<HeroImage?>`.
**Acceptance:** Provider unit tests with mock repository.

---

## 7. Build Order

```
T2  iOS thumbnail channel        (blocks T1)
T1  HeroImageView widget         (blocks T3, T4, T5)
T6  Override picker              (standalone)
T7  Providers                    (blocks T3, T4, T5)
T3  Journal hero header          (independent, highest value)
T4  Country detail cover         (independent)
T5  Scan summary best shot       (independent, lowest priority)
```

---

## 8. ADR

**ADR-135 — M90 Hero Image Display: MethodChannel Thumbnail Fetch + Reactive HeroImageView**

Hero image thumbnails are fetched on-demand via a dedicated `roavvy/thumbnail` MethodChannel backed by `PHImageManager`. Results are cached per session in `NSCache`. Thumbnails are never written to the Flutter asset bundle or Firestore. `HeroImageView` accepts a nullable `assetId`; null shows a deterministic continent-colour fallback. Override picker sets `isUserSelected=true` which permanently protects the row from re-scan replacement (ADR-134). All three display surfaces (journal, country detail, scan summary) react to the same `heroForTripProvider` stream — no polling.
