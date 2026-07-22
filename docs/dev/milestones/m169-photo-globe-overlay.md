# M169 — Photo Thumbnails: Globe Overlay

**Branch:** `feature/photo-map-thumbnails`
**Phase:** 29 — Photo Map Thumbnails
**Depends on:** M167 ✅
**Status:** Not started.

---

## Goal

Display photo thumbnails on the 3D rotating globe using a Stack overlay above the
`GlobeMapWidget` canvas. Thumbnails fade in when the globe settles after rotation
and fade out when the user starts rotating again, keeping the globe interaction
completely fluid.

---

## Architecture

The globe is a `CustomPaint` — Flutter widgets cannot be embedded inside it.
The solution is a `Stack` with a `IgnorePointer`-wrapped `PhotoGlobeOverlay`
positioned on top of the canvas.

`GlobeProjection.project(lat, lng, canvasSize)` already returns `Offset?`
(null = back-facing hemisphere). We use this for each photo in `photoLocationsProvider`.

### `PhotoGlobeOverlay` widget

New file: `lib/features/map/photo_globe_overlay.dart`

```
Stack(
  children: [
    GlobeMapWidget(),           // existing
    PhotoGlobeOverlay(),        // new — absorbs no pointer events
  ],
)
```

**Selection algorithm** (runs when globe settles):
1. Load `photoLocationsProvider` list
2. For each `(lat, lng)`, call `projection.project(lat, lng, canvasSize)` via
   the projection obtained from `GlobeMapWidget`'s exposed `GlobeProjection`
3. Filter: keep only non-null projections (visible hemisphere)
4. Sort by distance from canvas centre (nearest to pole of view first)
5. Take top 25 — display as `_GlobeThumbnailMarker` at each `Offset`

**Rotation detection:**
- `GlobeMapWidget` exposes `bool isRotating` via a `ValueNotifier<bool>` already
  tracked by its pan gesture handlers
- `PhotoGlobeOverlay` wraps its children in `AnimatedOpacity`:
  - `opacity: isRotating ? 0.0 : 1.0`
  - `duration: Duration(milliseconds: 300)` (fade in), 150 ms fade out

**Position updates:**
- When `isRotating` transitions to `false`, recompute all 25 positions once
  using the settled `GlobeProjection`
- Positions are static `Positioned` widgets until next rotation
- No per-frame recomputation (no `AnimatedBuilder` overhead on the paint loop)

### `_GlobeThumbnailMarker` widget

- 44×44 logical pixel square
- `ClipRRect(borderRadius: 8)` image thumbnail
- White 1.5 px border, drop shadow with `boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)]`
- `FutureBuilder` over `ThumbnailChannel.getThumbnail(assetId, size: 88)` (2× for Retina)
- Tap → `showModalBottomSheet` with trip context (country, date), action row: Map | Gallery

### `GlobeMapWidget` changes

- Expose `GlobeProjection get projection` getter (already computed internally as `_projection`)
- Expose `ValueNotifier<bool> get isRotating` (track in existing `onPanStart`/`onPanEnd`)

---

## Scope

### In
- `lib/features/map/globe_map_widget.dart` — expose `projection` getter + `isRotating` notifier
- `lib/features/map/photo_globe_overlay.dart` — new file
- `lib/features/map/map_screen.dart` — wrap globe in Stack with `PhotoGlobeOverlay`

### Out
- Clustering on globe (globe view is always "zoomed out" — 25 cap is sufficient)
- Tap-to-country navigation from globe thumbnail (deferred: M158)
- Globe zoom-in progressive loading (globe has no tile-based zoom levels)
- Web

---

## Acceptance Criteria

- [ ] Photo thumbnails appear on globe for photos with GPS coords
- [ ] Thumbnails are positioned correctly at their lat/lng on the visible hemisphere
- [ ] Thumbnails fade out immediately when the user starts rotating
- [ ] Thumbnails fade in (300 ms) after rotation stops
- [ ] Globe rotation is unaffected (no frame rate drop, no input lag)
- [ ] Back-facing photos (other side of globe) are never shown
- [ ] `flutter analyze` — no new issues

---

## Tasks

1. Add `isRotating` `ValueNotifier<bool>` to `GlobeMapWidget`, set in pan handlers
2. Add `projection` getter to `GlobeMapWidget`
3. Write `_GlobeThumbnailMarker` with `ThumbnailChannel` FutureBuilder
4. Write `PhotoGlobeOverlay` with selection algorithm + `AnimatedOpacity`
5. Wire `PhotoGlobeOverlay` into `map_screen.dart` globe Stack
6. Manual test: rotate globe, verify fade in/out, verify correct positions
7. `flutter analyze`, commit
