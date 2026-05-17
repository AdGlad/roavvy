# M114 — Memory Pulse: Photo Library Anniversary Query

**Branch:** milestone/m114-memory-pulse-photo-library-query
**Status:** In Progress

## Goal

Replace the hero-image-based anniversary lookup with a direct `photo_manager` query.
On the anniversary date the app queries the device photo library for photos taken on
today's month+day in any past year, picks the best photo per year, and shows up to 3
pulse cards. If no photos exist for that date, no pulse fires.

## Tasks

- [ ] 1. Create `MemoryAnniversaryPhoto` model in `lib/features/memory/memory_anniversary_photo.dart`
- [ ] 2. Add `checkTodayFromPhotoLibrary(DateTime today)` to `MemoryPulseService`
        — request photo library permission, fetch AssetEntity list filtered by month+day
        across all years ≥ 1 year ago, group by year, pick best photo per year (selection
        criteria from milestone doc), resolve countryCode via photo_date_records and tripId
        via hero_images Drift tables, return List<MemoryAnniversaryPhoto> (max 3)
- [ ] 3. Update `scheduleNextAnniversaryNotification` in `MemoryPulseService`
        — fetch photo library assets, build set of (month, day) pairs with photos ≥ 1 year old,
        find nearest future date in that set, schedule notification
- [ ] 4. Update `buildCopy()` and `buildQuestion()` in `MemoryPulseService`
        — accept `MemoryAnniversaryPhoto` instead of `HeroImage`; scene/mood/landmark will
        be null; fall back to default copy templates gracefully
- [ ] 5. Update providers — wire `checkTodayFromPhotoLibrary` in map_screen.dart (or wherever
        `checkToday` is called); update any Riverpod providers that reference `HeroImage` pulse
- [ ] 6. Update `MemoryPulseCard` — change `List<HeroImage>` → `List<MemoryAnniversaryPhoto>`;
        dismiss key from `hero.tripId` → `hero.assetId`; hide "View trip" when tripId is null
- [ ] 7. Update `MemoryRevealSheet` — change `HeroImage hero` → `MemoryAnniversaryPhoto hero`;
        hide country chip when countryCode is null; hide "View trip" when tripId is null
- [ ] 8. Validate: `flutter analyze` zero new warnings; confirm HeroImage-based code still compiles;
        update milestone doc status, backlog, current_state.md, run `python3 scripts/index_docs.py`
