# M109 — Accurate Departure & Arrival Coordinates

**Status:** Complete (2026-05-11)
**Branch:** `milestone/m109-accurate-departure-arrival-coordinates`

## Goal

Replace country-centroid departure/arrival points in the cinematic travel replay with actual GPS coordinates derived from trip photos. Travel paths should start and end at the real locations where photos were taken, making replays personal, authentic, and geographically believable.

## Problem

Currently `TravelReplayScriptBuilder` resolves each `TravelLeg`'s from/to positions via `kCountryCentroids`. This means:

- Every trip to Australia departs/arrives at the same dead-centre point
- Routes feel robotic and generic
- Personal travel stories are lost

## Solution

Extend `TravelLeg` to carry explicit `fromLat/fromLng` and `toLat/toLng`. `TravelReplayScriptBuilder` populates these from the first/last valid GPS image in each trip segment, falling back only when no GPS data is available.

---

## Coordinate Selection Rules

### Country-to-Country Travel

| Point | Source |
|-------|--------|
| Departure | Last valid GPS image from the **previous** trip segment |
| Arrival | First valid GPS image from the **destination** trip segment |

### Trip Replay (single trip)

| Point | Source |
|-------|--------|
| Start | First GPS image in the trip |
| End | Last GPS image in the trip |

### Fallback Order (when GPS is missing)

1. Nearest valid GPS image within the same trip
2. City coordinate (if city-level data available)
3. Country centroid (last resort only)

---

## Data Model Changes

### `TravelLeg` — extend with explicit coordinates

```dart
class TravelLeg {
  final String fromCode;        // ISO 3166-1 alpha-2
  final String toCode;
  final DateTime date;

  // Explicit GPS coordinates — preferred over centroid lookup
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const TravelLeg({
    required this.fromCode,
    required this.toCode,
    required this.date,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  // Resolved coordinates: prefer explicit GPS, fall back to centroid
  LatLng get resolvedFrom => (fromLat != null && fromLng != null)
      ? LatLng(fromLat!, fromLng!)
      : kCountryCentroids[fromCode]!;

  LatLng get resolvedTo => (toLat != null && toLng != null)
      ? LatLng(toLat!, toLng!)
      : kCountryCentroids[toCode]!;
}
```

### `TravelReplayScriptBuilder` — GPS extraction logic

```dart
// For each leg transition: prev segment → next segment
TravelLeg _buildLeg(TripSegment from, TripSegment to) {
  final depCoord = _lastValidGps(from.images);
  final arrCoord = _firstValidGps(to.images);
  return TravelLeg(
    fromCode: from.countryCode,
    toCode: to.countryCode,
    date: to.startedOn,
    fromLat: depCoord?.latitude,
    fromLng: depCoord?.longitude,
    toLat: arrCoord?.latitude,
    toLng: arrCoord?.longitude,
  );
}

LatLng? _firstValidGps(List<PhotoRecord> images) =>
    images.firstWhereOrNull((p) => p.latitude != null && p.longitude != null)
        .let((p) => p == null ? null : LatLng(p.latitude!, p.longitude!));

LatLng? _lastValidGps(List<PhotoRecord> images) =>
    images.lastWhereOrNull((p) => p.latitude != null && p.longitude != null)
        .let((p) => p == null ? null : LatLng(p.latitude!, p.longitude!));
```

---

## Scope

### In scope

- Extend `TravelLeg` model with `fromLat`, `fromLng`, `toLat`, `toLng` nullable fields
- Add `resolvedFrom` / `resolvedTo` getters to `TravelLeg` (centroid fallback)
- Update `TravelReplayScriptBuilder` to extract first/last valid GPS per trip segment
- Update `GlobeReplayPainter` and `TravelReplayController` to use `resolvedFrom`/`resolvedTo` instead of centroid lookup
- Implement fallback chain: GPS image → city coordinate → country centroid
- Unit tests for `TravelReplayScriptBuilder` GPS extraction and fallback logic

### Out of scope

- Changes to `PhotoRecord` or `TripRecord` models (existing GPS fields used as-is)
- City coordinate database (fallback level 2 deferred; centroid covers level 3)
- Visual UI changes to replay playback
- Video/audio export hooks (unchanged from M108)
- Android / web

---

## Architecture

### Modified files

| File | Change |
|------|--------|
| `lib/features/globe_replay/travel_replay_engine.dart` | Extend `TravelLeg` with GPS fields + `resolvedFrom`/`resolvedTo`; update `TravelReplayScriptBuilder` |
| `lib/features/globe_replay/globe_replay_painter.dart` | Use `leg.resolvedFrom` / `leg.resolvedTo` instead of centroid map lookup |
| `lib/features/globe_replay/travel_replay_controller.dart` | Use `leg.resolvedFrom` / `leg.resolvedTo` for globe rotation target |

### No new files required

The centroid fallback is already provided by `lib/core/country_centroids.dart` (created in M108).

---

## Tasks

1. **Extend `TravelLeg`** — add nullable `fromLat`, `fromLng`, `toLat`, `toLng`; add `resolvedFrom`/`resolvedTo` getters with centroid fallback.
2. **Update `TravelReplayScriptBuilder`** — extract `_firstValidGps` and `_lastValidGps` helpers; populate coordinates when building each leg.
3. **Update painter + controller** — replace all centroid lookups with `leg.resolvedFrom` / `leg.resolvedTo`.
4. **Unit tests** — GPS-available case, GPS-missing case (centroid fallback), mixed case (one end GPS, one end centroid).
5. **Manual QA** — replay a trip with known GPS photos; verify arcs originate at real locations, not country centres.

---

## Acceptance Criteria

- [ ] `TravelLeg` carries optional GPS coordinates; existing centroid behaviour unchanged when GPS is absent
- [ ] `TravelReplayScriptBuilder` populates `fromLat/fromLng` from last GPS image of previous segment
- [ ] `TravelReplayScriptBuilder` populates `toLat/toLng` from first GPS image of destination segment
- [ ] `GlobeReplayPainter` arcs originate/terminate at resolved GPS points, not country centres
- [ ] Fallback to `kCountryCentroids` fires only when no GPS image exists in the trip
- [ ] Unit tests pass for GPS, fallback, and mixed scenarios
- [ ] `flutter analyze` reports 0 new issues
- [ ] Replay remains smooth at 60 fps on iPhone 12+

---

## Future Integration Hooks (deferred)

- **City coordinate fallback (level 2):** look up nearest city centroid before falling back to country centroid
- **Per-photo replay mode:** animate the marker between individual photo GPS points within a trip leg
- **Heatmap overlay:** density plot of GPS origins to show where in a country the user actually explored
