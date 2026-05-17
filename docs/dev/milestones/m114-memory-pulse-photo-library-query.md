# M114 — Memory Pulse: Photo Library Anniversary Query

**Phase:** 22 — Engagement & Personalisation
**Depends on:** M91 (memory pulse foundation), M95 (question-style copy)
**Status:** Not started
**Created:** 2026-05-17

---

## Goal

Replace the hero-image-based anniversary lookup with a direct `photo_manager` query.
On the anniversary date the app queries the device photo library for photos taken on
today's month+day in any past year, picks the best photo per year, and shows up to 3
pulse cards. If no photos exist for that date, no pulse fires.

---

## Problem with current approach

`MemoryPulseService.checkToday()` queries the `hero_images` Drift table for rank-1
records whose `captured_at` matches today's month+day. This means:

- A pulse only fires if the scan pipeline selected a hero image for that trip.
- Trips with no hero image (scan incomplete, no rank-1 record) are invisible.
- The set of photos available is limited to one pre-selected image per trip.
- Trips added manually (no photos) can never trigger a pulse.

The user's actual photo library is richer. Querying it directly produces more pulses,
more personal photos, and removes the dependency on the hero selection pipeline.

---

## New approach

1. On anniversary check, call `photo_manager` to fetch all photos whose creation date
   matches today's month+day in any year at least 1 year ago.
2. Group results by year (descending — most recent anniversaries first).
3. For each year, pick the single best photo (see selection criteria below).
4. Resolve country code and trip ID for each photo via Drift (`scan_photos` table).
5. Return up to 3 `MemoryAnniversaryPhoto` records. No photos → no pulse.

### Best photo selection within a year

Priority order within photos sharing the same year:
1. Has a matching `scan_photos` row (country known) AND `isFavorite == true`
2. Has a matching `scan_photos` row (country known), highest pixel area (`width × height`)
3. Has a matching `scan_photos` row (country known), any
4. `isFavorite == true` (no country match)
5. Highest pixel area (no country match)

If no photos exist for a given year after filtering, that year produces no card.

---

## New data model

Introduce `MemoryAnniversaryPhoto` in
`lib/features/memory/memory_anniversary_photo.dart`:

```dart
class MemoryAnniversaryPhoto {
  const MemoryAnniversaryPhoto({
    required this.assetId,
    required this.capturedAt,
    this.countryCode,
    this.tripId,
  });

  /// photo_manager local identifier — used to load the thumbnail and full image.
  final String assetId;

  /// Original capture date of the photo.
  final DateTime capturedAt;

  /// ISO country code resolved from Drift scan_photos, or null if not scanned.
  final String? countryCode;

  /// Trip ID resolved from Drift trips table, or null if no matching trip.
  final String? tripId;

  /// Years between capturedAt and today.
  int yearsAgo(DateTime today) => today.year - capturedAt.year;
}
```

---

## Changes required

### New file
- `lib/features/memory/memory_anniversary_photo.dart` — `MemoryAnniversaryPhoto` model

### Modified files

#### `lib/features/memory/memory_pulse_service.dart`
- Add `checkTodayFromPhotoLibrary(DateTime today)` — new primary entry point:
  - Requests photo library permission (read-only, already granted for scan).
  - Fetches `AssetEntity` list filtered by month+day across all years ≥ 1 year ago.
  - Groups by year, picks best photo per year using the selection criteria above.
  - Resolves `countryCode` and `tripId` via `ScanPhotoRepository` (or direct Drift query).
  - Returns `List<MemoryAnniversaryPhoto>` (max 3, most recent year first).
- Update `scheduleNextAnniversaryNotification` to query photo_manager instead of
  `HeroImageRepository.getHeroesForRank1()`:
  - Fetch all photos grouped by month+day.
  - Find the next future month+day that has at least one photo from a past year.
  - Schedule notification for that date.
- Keep `buildCopy()` and `buildQuestion()` — adapt to accept `MemoryAnniversaryPhoto`
  instead of `HeroImage`. Scene/mood/landmark fields will be null (fall back to
  default copy templates gracefully).
- Keep `dismiss()`, `markRevealed()`, `markShownToday()`, `wasShownToday()` —
  change dismiss key from `tripId` to `assetId` (always non-null).

#### `lib/features/memory/memory_pulse_card.dart`
- Change `List<HeroImage> memories` → `List<MemoryAnniversaryPhoto> memories`.
- Change dismiss key from `hero.tripId` to `hero.assetId`.
- Hide "View trip" button when `hero.tripId == null`.
- `HeroImageView(assetId: hero.assetId, ...)` — no change needed (assetId field name
  is the same).

#### `lib/features/memory/memory_reveal_sheet.dart`
- Change `HeroImage hero` → `MemoryAnniversaryPhoto hero`.
- Update `show()` factory and all internal references accordingly.
- Country chip: show only when `hero.countryCode != null`.
- "View trip" button: show only when `hero.tripId != null`.

#### `lib/features/map/map_screen.dart` (or wherever `checkToday` is called)
- Call `checkTodayFromPhotoLibrary(today)` instead of `checkToday(today)`.

#### `lib/features/memory/app_open_tracker.dart`
- No change required.

### Deprecated (do not delete yet)
- `HeroImageRepository.getHeroesWithAnniversaryToday()` — no longer called by
  memory pulse. Leave in place; other callers may exist.
- `HeroImageRepository.getHeroesForRank1()` — no longer called by notification
  scheduling. Leave in place.

---

## photo_manager query strategy

`photo_manager` does not support a native month+day filter. The query approach:

```dart
// Fetch all assets sorted by creation date descending.
// Filter in Dart: capturedAt.month == today.month &&
//                 capturedAt.day   == today.day   &&
//                 today.year - capturedAt.year    >= 1
```

For large photo libraries this could be slow. Mitigation:
- Use `AssetType.image` only (no videos).
- Limit the initial fetch to a reasonable page size (e.g. 2000 most recent photos),
  then expand if insufficient matches are found.
- Run the check in a background isolate or at least off the main frame.

---

## Notification scheduling

New logic for `scheduleNextAnniversaryNotification`:

1. Fetch all `AssetEntity` images (up to a reasonable cap, e.g. 5000).
2. Build a set of `(month, day)` pairs that have at least one photo ≥ 1 year old.
3. Starting from tomorrow, find the nearest future date whose `(month, day)` is in
   the set.
4. Schedule the notification for that date at the user's preferred hour.

---

## Acceptance criteria

- [ ] On a date with anniversary photos, up to 3 pulse cards appear, one per year,
      most recent first.
- [ ] Each card shows the actual photo from the device library (not a pre-selected
      hero image).
- [ ] On a date with no anniversary photos, no pulse card appears.
- [ ] Pulse card dismiss works correctly using `assetId` as the key.
- [ ] "View trip" button is hidden when no matching trip exists in Drift.
- [ ] Country chip is hidden when the photo has no Drift scan entry.
- [ ] Reveal sheet opens correctly for photo-library-sourced memories.
- [ ] Notification scheduling finds the next anniversary date from photo library.
- [ ] Existing `HeroImage`-based code compiles without errors (not deleted).
- [ ] `flutter analyze`: zero new warnings.

---

## Out of scope

- Removing `HeroImageRepository` anniversary queries (deprecated, not deleted).
- Backfilling scene/mood/landmark metadata from photo_manager EXIF.
- Android support.
- Showing more than 3 pulse cards.

---

## Technical risks

| Risk | Severity | Mitigation |
|---|---|---|
| Large photo library scan is slow | Medium | Page-limited fetch; run async |
| Photo library permission not granted | Low | Guard with permission check; no pulse if denied |
| `assetId` changes after iCloud restore | Low | Same risk exists with current hero images |
| Month+day filter returns 0 results despite photos existing | Low | Unit-test the filter logic |
