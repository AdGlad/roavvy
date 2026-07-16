# M170 — Photo Map: Cluster Polish & Performance Tuning

**Branch:** `feature/photo-map-thumbnails`
**Phase:** 29 — Photo Map Thumbnails
**Depends on:** M168 ✅, M169 ✅
**Status:** Not started.

---

## Goal

Polish the flat-map cluster experience with animated zoom-into-cluster, smooth
thumbnail fade-in on zoom, a Dart-side LRU thumbnail cache to cap memory usage,
and a settings toggle to let users disable photo thumbnails entirely.

---

## Scope

### Cluster tap → zoom animation (flat map)
- Tap `_ClusterMarker` → `MapController.animateCamera` to cluster bounds
  (use `flutter_map`'s `CameraFit.bounds` with 40 px padding)
- Springy ease-in-out 600 ms animation

### Thumbnail fade-in on zoom
- `_PhotoThumbnailMarker` wraps image in `AnimatedOpacity`
- Starts at `opacity: 0.0`, animates to `1.0` over 200 ms when image loads
- Prevents pop-in during pan

### Dart-side LRU thumbnail cache
- `_ThumbnailCache` class: `LinkedHashMap<String, Uint8List>` capped at 60 entries
  (FIFO eviction). Complements NSCache (which manages device memory) with a fast
  synchronous Dart lookup that avoids redundant async channel calls.
- Singleton; used by both `_PhotoThumbnailMarker` and `_GlobeThumbnailMarker`

### Photo thumbnails toggle
- New `showPhotoThumbnailsProvider` (`StateProvider<bool>`, default `true`)
  persisted via `shared_preferences`
- Settings screen toggle: "Show photos on map"
- `PhotoClusterLayer` and `PhotoGlobeOverlay` both gate on this provider

### Empty-state grace
- If `photoLocationsProvider` returns 0 results (user has no geotagged photos
  or GPS fetch not yet complete), show nothing — no empty markers, no error UI

---

## Acceptance Criteria

- [ ] Tapping a cluster animates zoom smoothly to cluster contents
- [ ] Photo thumbnails fade in (200 ms) after loading, no pop-in
- [ ] LRU cache prevents re-fetching the same thumbnail within a session
- [ ] "Show photos on map" toggle persists across app restarts
- [ ] 0 geotagged photos → map shows normally, no errors
- [ ] `flutter analyze` — no new issues

---

## Tasks

1. Wire `MapController.animateCamera` on cluster tap (flat map)
2. Add `AnimatedOpacity` to `_PhotoThumbnailMarker` image load
3. Write `_ThumbnailCache` LRU class; plug into both marker widgets
4. Add `showPhotoThumbnailsProvider` + persist with `shared_preferences`
5. Add toggle in settings screen
6. `flutter analyze`, commit
