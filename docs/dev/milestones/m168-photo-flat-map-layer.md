# M168 — Photo Thumbnails: Flat Map Layer

**Branch:** `feature/photo-map-thumbnails`
**Phase:** 29 — Photo Map Thumbnails
**Depends on:** M167 ✅
**Status:** Not started.

---

## Goal

Add photo thumbnails to the 2D flutter_map with zoom-based progressive loading.
At low zoom: clustered dot badges. At city zoom (≥ 10): individual rounded thumbnails.
Zero impact on pan/zoom responsiveness.

---

## UX Behaviour

| Zoom level | Display |
|------------|---------|
| < 5        | Nothing (continent-level, too cluttered) |
| 5 – 9      | Cluster circles: coloured dot + count label, grouped by ~50 km radius |
| ≥ 10       | Individual photo thumbnails at exact GPS, max 40 visible in viewport |

Tap a cluster → map animates to zoom in on cluster bounds.
Tap an individual thumbnail → opens `PhotoGalleryScreen` deep-linked to that photo.

---

## Architecture

### `PhotoClusterLayer` widget
New file: `lib/features/map/photo_cluster_layer.dart`

- Watches `photoLocationsProvider`
- At zoom ≥ 10: renders `MarkerLayer` with `_PhotoThumbnailMarker` widgets
- At zoom 5–9: renders `MarkerLayer` with `_ClusterMarker` widgets
  - Cluster algorithm: simple grid-cell binning (0.5° lat/lng cells at zoom 5–7,
    0.1° cells at zoom 8–9)
- Viewport culling: only process markers within `FlutterMapCamera.visibleBounds`
  expanded by 20% to avoid pop-in

### `_PhotoThumbnailMarker` widget
- `FutureBuilder` over `ThumbnailChannel.getThumbnail(assetId, size: 96)`
- While loading: grey placeholder circle (same size)
- Loaded: `ClipRRect(borderRadius: 8)` image with 1.5 px white border + drop shadow
- Size: 48×48 logical pixels
- `GestureDetector.onTap` → `Navigator.push(PhotoGalleryScreen(initialAssetId: assetId))`

### `_ClusterMarker` widget
- Filled circle, colour from `Theme.colorScheme.primary`
- Count label centred in white bold text
- Tap → `MapController.move(clusterCentroid, currentZoom + 2)`

### Performance constraints
- `MarkerLayer` with `rotate: false` — markers stay upright, no per-marker matrix math
- Thumbnails requested lazily (only when `FutureBuilder` first builds in viewport)
- `ThumbnailChannel` NSCache prevents duplicate decoding
- Hard cap: if viewport contains > 40 individual thumbnails at zoom ≥ 10, subsample
  by picking the 40 most recently taken (by `capturedAt` desc from DB)

---

## Scope

### In
- `lib/features/map/photo_cluster_layer.dart` — new file
- `map_screen.dart` — add `PhotoClusterLayer()` to the `FlutterMap.children` list
- `providers.dart` — add `mapZoomProvider` (watches `MapController` zoom; used to
  switch cluster vs thumbnail mode)
- `visit_repository.dart` — add `loadPhotoLocationsInBounds(LatLngBounds bounds)`
  that joins `photo_gps_cache` + `PhotoDateRecords` and returns assetId+lat+lng

### Out
- Globe thumbnail overlay (M157)
- Clustering animation / smooth transitions (M158)
- Tap-to-zoom animation on cluster (deferred: M158)
- Web

---

## Acceptance Criteria

- [ ] Thumbnails visible on flat map at zoom ≥ 10 at correct GPS positions
- [ ] Cluster badges visible at zoom 5–9 with correct photo counts
- [ ] Nothing shown at zoom < 5
- [ ] Pan and zoom remain smooth (no frame drops during marker layer rebuild)
- [ ] Tapping a thumbnail opens `PhotoGalleryScreen` at that photo
- [ ] `flutter analyze` — no new issues

---

## Tasks

1. Add `loadPhotoLocationsInBounds` to `VisitRepository` / `PhotoGpsRepository`
2. Add `mapZoomProvider` 
3. Write `_ClusterMarker` widget
4. Write `_PhotoThumbnailMarker` widget with `ThumbnailChannel` FutureBuilder
5. Write `PhotoClusterLayer` with viewport culling + zoom-mode switch
6. Wire `PhotoClusterLayer` into `map_screen.dart` FlutterMap children
7. `flutter analyze`, commit
