# M167 — Photo GPS Cache

**Branch:** `feature/photo-map-thumbnails`
**Phase:** 29 — Photo Map Thumbnails
**Depends on:** M147 ✅
**Status:** Not started.

---

## Goal

Build the GPS coordinate cache layer that underpins all photo-map thumbnail features.
ADR-002 means GPS is not stored in the DB — this milestone fixes that gap by fetching
lat/lng from PhotoKit via `photo_manager`, caching in SQLite, and exposing a Riverpod
provider. Everything in M156–M158 depends on this data.

---

## Background

During the scan pipeline, `{lat, lng, capturedAt, assetId}` is streamed from Swift but
lat/lng is intentionally discarded after country-code resolution (ADR-002). `PhotoDateRecords`
only stores `(countryCode, capturedAt, assetId)`. To place thumbnails at exact photo
locations we must fetch GPS from `AssetEntity.latlngAsync()` at runtime.

This is a one-time background fetch per assetId, cached permanently in SQLite.

---

## ADR-159 — Photo GPS Cache table

New Drift table `photo_gps_cache`:

```dart
class PhotoGpsCache extends Table {
  TextColumn get assetId => text()();           // primary key
  RealColumn get lat     => real()();
  RealColumn get lng     => real()();
  @override Set<Column> get primaryKey => {assetId};
}
```

Schema version bump required (Drift migration).

---

## Scope

### In
- `roavvy_database.dart` — add `PhotoGpsCache` table; bump schema version; add migration
- New `photo_gps_repository.dart` in `lib/data/`:
  - `storeLocation(assetId, lat, lng)` — upsert
  - `loadAll()` → `List<PhotoLocation>` (record type: `(String assetId, double lat, double lng)`)
  - `hasLocation(assetId)` — bool, used to skip already-cached assetIds
- New `PhotoGpsFetchService` in `lib/features/map/`:
  - `fetchAndCache()` — loads all uncached assetIds from `PhotoDateRecords`, batches calls to
    `AssetEntity.fromId(assetId)` then `.latlngAsync()`, stores valid (non-null) results
  - Processes in batches of 50 to avoid blocking the main thread
  - Uses `Isolate.run` or `compute` for the batch to keep UI free
  - Skips assetIds that return null GPS (photo has no EXIF location)
- New `photoLocationsProvider` (Riverpod `FutureProvider`) in `providers.dart`:
  - Returns `List<PhotoLocation>` from the cache table
  - Invalidated after `fetchAndCache()` completes
- Wire `PhotoGpsFetchService.fetchAndCache()` into `MapScreen.initState` (runs once,
  after `WidgetsBinding.instance.addPostFrameCallback`) so it starts silently on first
  map open without blocking rendering

### Out
- Showing any thumbnails (M156, M157)
- Clustering (M158)
- Re-fetching GPS if a user deletes + re-scans a photo (acceptable limitation for now)
- Web

---

## Acceptance Criteria

- [ ] `photo_gps_cache` table exists in the Drift schema; migration runs without error
- [ ] `PhotoGpsFetchService.fetchAndCache()` completes without blocking map interactions
  (tested: map rotates smoothly during background fetch)
- [ ] `photoLocationsProvider` returns correct `(lat, lng)` for a known assetId after fetch
- [ ] Photos without EXIF GPS are silently skipped (no crash, no null entries in DB)
- [ ] `flutter analyze` — no new issues

---

## Tasks

1. Add `PhotoGpsCache` table to `roavvy_database.dart`, bump schema, write migration
2. Write `PhotoGpsRepository` with upsert + loadAll + hasLocation
3. Write `PhotoGpsFetchService` with batch fetch (50 at a time, `compute`)
4. Add `photoLocationsProvider` to `providers.dart`
5. Wire `fetchAndCache()` into `MapScreen.initState` post-frame callback
6. Add unit tests for repository (in-memory DB)
7. `flutter analyze`, commit
