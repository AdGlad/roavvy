# M163 — UNESCO Nearby Explorer

**Status: Not Started**

## Vision

Turn Roavvy into a travel companion you open *before* a trip, not just after. The UNESCO Nearby Explorer lets users discover World Heritage Sites within a chosen radius of their current location — with rich content, instant distance calculations, and one tap to navigate. It surfaces hidden treasures near wherever the user happens to be.

Emotional goal: **"I didn't know that was so close."**

---

## Prerequisites

- M119 (UNESCO data + `WorldHeritageLookupService`) — **complete**
- M129 (heritage markers on map) — **complete**
- `geolocator` ^13.0.0 already in `pubspec.yaml`
- `url_launcher` ^6.3.1 already in `pubspec.yaml`
- No new packages required

---

## Architecture Overview

```
UnescoNearbyExplorerScreen
  └─ UnescoNearbyService        (filter + sort WorldHeritageLookupService.allSites)
  └─ UnescoNearbyNotifier       (Riverpod AsyncNotifier — location + slider state)
  └─ UnescoNearbySiteCard       (list item widget)
  └─ UnescoSiteDetailSheet      (bottom sheet — extends/wraps HeritageDetailSheet)
  └─ NativeMapsLauncher         (url_launcher deep link to Apple/Google Maps)
  └─ DistanceUtils              (haversine, bearing, speed estimates — pure functions)
```

**Data flow:**
1. Screen opens → request location permission via `geolocator`
2. On permission granted → get current position
3. `UnescoNearbyService.sitesWithin(lat, lng, radiusKm)` iterates `WorldHeritageLookupService.allSites`, deduplicates by `siteId`, computes haversine distance, filters to radius, sorts ascending by distance
4. Slider changes → debounced (300 ms) → re-filter → update list
5. Tap site card → open `UnescoSiteDetailSheet`
6. Tap "Get Directions" → `NativeMapsLauncher.open(lat, lng, name)`

---

## Existing Code to Reuse

| What | Where |
|---|---|
| Site data | `WorldHeritageLookupService.allSites` (in-memory, ~1200 sites) |
| Visited site lookup | `HeritageRepository.loadVisitedSiteIds()` — cross-reference by siteId |
| Haversine | `WorldHeritageLookupService._haversineKm` is private — copy/extract to `DistanceUtils` |
| Detail sheet | `heritage_detail_sheet.dart` — extend / reuse for the detail view |
| Category colour/icon | Pattern from `_HeritageSiteCard` in `country_profile_screen.dart` |
| Country name + flag | `kCountryNames` + `_flagEmoji` from `country_names.dart` |

---

## Screen: `UnescoNearbyExplorerScreen`

### Layout

```
┌────────────────────────────────────────────┐
│  ← UNESCO Nearby                    [🔍]   │  AppBar
├────────────────────────────────────────────┤
│  📍 North Curl Curl, NSW                    │  Location pill
│  ──────────────────────────────────────── │
│  Radius  ●━━━━━━━━━━━○  50 km   12 sites  │  Slider row
│                                            │
│  ┌─────────────────────────────────────┐  │
│  │ 🏛  Blue Mountains                  │  │  Site card
│  │ 🇦🇺 Australia · Cultural · 65 km W  │  │
│  │ "Ancient sandstone wilderness…"     │  │
│  │ 🚶 13 h  🚲 4.3 h  🚗 1.3 h  ✅    │  │
│  └─────────────────────────────────────┘  │
│  ┌─────────────────────────────────────┐  │
│  │ 🌿  Greater Blue Mountains          │  │  …
│  └─────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

### Slider

- `Slider` widget, `min: 5`, `max: 500`, `divisions: 99`
- Label: `${radiusKm.round()} km`
- Debounce: 300 ms `Timer` — only refilter after user stops moving
- Site count label: `"${count} site${count == 1 ? '' : 's'}"` updates immediately after debounce

### Location pill

Shows `"📍 [suburb/city]"` using `geolocator`'s `placemarkFromCoordinates` — or just coordinates if reverse geocoding fails (no network dependency — use built-in iOS `CLGeocoder` path via geolocator's `Placemark`).

---

## `UnescoNearbySiteCard` widget

Each list card:

```
┌───────────────────────────────────────────┐
│ [120×80 image]  │ 🏛 Site Name             │
│                 │ 🇯🇵 Japan · Cultural       │
│                 │ 42.3 km  North-East  ↗   │
│                 │ "Short description…"      │
│                 │ 🚶3h  🚲1h  🚗25min  [✅] │
└───────────────────────────────────────────┘
```

- **Image**: `Image.network(site.imageUrl, fit: BoxFit.cover)` in a `ClipRRect`; fallback: category icon in an accent-coloured container
- **Category badge**: coloured chip — Gold (Cultural), Mint (Natural), Coral (Mixed) — matching existing pattern
- **Visited badge**: gold `✅` stamp if `siteId` is in visited set
- **Travel times**: row of icon + time labels, prefixed with "~" to signal estimates; hidden if distance > 200 km (driving estimate > 4 h becomes less meaningful)
- **Direction**: compass bearing converted to 8-point label (N, NE, E, SE, S, SW, W, NW) + matching arrow icon

---

## `UnescoSiteDetailSheet` (bottom sheet)

Extends / wraps the existing `HeritageDetailSheet`. Opens as a `showModalBottomSheet` with `isScrollControlled: true`.

Sections (top to bottom):

1. **Hero image** — full width, 200 px, `BoxFit.cover`; category-gradient fallback
2. **Name + flag + country** — `titleLarge`
3. **Category badge + inscription year** — row
4. **Distance + direction** — `"42.3 km · North-East ↗"`
5. **Travel time estimates** — three tiles: 🚶 Walk · 🚲 Cycle · 🚗 Drive; labelled "approximate"
6. **Short description** — `site.shortDescription`
7. **Criteria** — if `site.criteria.isNotEmpty`: `"Inscribed for criteria: (i), (iii), (vi)"`
8. **Visited status** — green banner if already visited via Roavvy scan
9. **Action buttons**:
   - `FilledButton` "Get Directions" → `NativeMapsLauncher.open(...)`
   - `OutlinedButton` "View on Globe" → pops sheet, navigates to Map tab, centres on site

---

## `DistanceUtils` (pure functions)

```dart
// lib/features/heritage/distance_utils.dart

/// Haversine distance in km between two WGS-84 coordinates.
static double haversineKm(double lat1, double lng1, double lat2, double lng2);

/// Compass bearing in degrees (0–360, clockwise from north).
static double bearingDeg(double lat1, double lng1, double lat2, double lng2);

/// 8-point compass label for a bearing.
static String bearingLabel(double deg);  // "North", "North-East", …

/// Estimated travel time string for a given distance and speed.
/// Returns "42 min" or "3 h 12 min".
static String travelTime(double distanceKm, double speedKmh);
```

Speed constants:
- Walking: 5 km/h
- Cycling: 15 km/h
- Driving: 50 km/h

---

## `NativeMapsLauncher`

```dart
// lib/features/heritage/native_maps_launcher.dart

/// Opens the native maps app with [lat],[lng] as the destination.
///
/// iOS:  https://maps.apple.com/?daddr={lat},{lng}&dirflg=d
/// Android: google.navigation:q={lat},{lng}  (falls back to
///          https://maps.google.com/?daddr={lat},{lng} if intent fails)
///
/// Uses url_launcher (already in project). No routing data returned.
static Future<void> open(double lat, double lng, String label);
```

---

## `UnescoNearbyService`

```dart
// lib/features/heritage/unesco_nearby_service.dart

class NearbySiteResult {
  final WorldHeritageSite site;
  final double distanceKm;
  final double bearingDeg;
  final String bearingLabel;
  final bool isVisited;
}

class UnescoNearbyService {
  /// Returns all sites within [radiusKm] of the given position, sorted
  /// nearest first. Deduplicates transboundary sites by siteId.
  /// Visited site IDs are cross-referenced for badge display.
  List<NearbySiteResult> sitesWithin(
    double lat,
    double lng,
    double radiusKm,
    Set<String> visitedSiteIds,
  );
}
```

All computation is synchronous and in-memory. The full dataset (~1200 sites after dedup) filters in < 1 ms.

---

## `UnescoNearbyNotifier` (Riverpod)

```dart
// AsyncNotifier<UnescoNearbyState>

class UnescoNearbyState {
  final Position? position;
  final String? locationLabel;
  final double radiusKm;
  final List<NearbySiteResult> sites;
  final LocationPermissionStatus permissionStatus;
}
```

Responsibilities:
- Request and check `geolocator` permission
- Fetch current position (`LocationAccuracy.low` — no need for GPS precision here)
- Load visited site IDs from `HeritageRepository`
- Filter sites via `UnescoNearbyService`
- Re-filter on slider change (UI debounces, notifier just receives the final value)

---

## Entry Points

**Primary**: Map screen action bar — add a `"🌍 UNESCO Nearby"` chip alongside the existing heritage toggle. Tapping pushes `UnescoNearbyExplorerScreen`.

**Secondary**: Country profile screen (`CountryProfileScreen`) UNESCO section header — add a small `"Explore nearby →"` text link.

---

## Permission Fallback UX

| State | UI |
|---|---|
| Permission denied | Friendly explanation + `"Grant Location Access"` button (opens app settings via `geolocator.openAppSettings()`) |
| Permission permanently denied | Same as above + explanation that the user must go to Settings |
| Location unavailable | `"Could not determine your location"` + retry button |
| No sites in radius | Empty state: compass illustration + `"No UNESCO sites within ${radius} km"` + `"Try a larger radius"` nudge |
| Dataset not initialised | Graceful error — should never happen (initialised at startup) |

---

## Design Direction

Visual tone: **explorer / treasure map** — adventurous, premium, consistent with Roavvy's dark-navy globe identity.

- AppBar: dark navy background, gold accent for site count
- Site cards: dark card surface, category badge in gold/mint/coral, distance in accent colour
- Slider: accent-coloured active track
- Empty state: large compass icon, muted text
- Visited badge: gold stamp icon (reuse `_AllVisitedBanner` gold palette)
- Direction arrows: `Icons.navigation` rotated to bearing
- Travel time row: small icon + muted text, not cluttered

No heavy animations. List uses basic `AnimatedList` or plain `ListView` — smooth on older iPhones.

---

## Tasks

### T1 — `DistanceUtils` pure functions
`lib/features/heritage/distance_utils.dart`

- `haversineKm()` — extract from `WorldHeritageLookupService._haversineKm`
- `bearingDeg()` — new
- `bearingLabel()` — new (8-point)
- `travelTime()` — new

Unit tests: `test/features/heritage/distance_utils_test.dart`
- haversine spot-check (Sydney→Melbourne ≈ 714 km)
- bearing: north, south-east, south-west
- travelTime: < 1 h returns minutes, ≥ 1 h returns h+min

### T2 — `NativeMapsLauncher`
`lib/features/heritage/native_maps_launcher.dart`

- `open(lat, lng, label)` — platform-branch via `Platform.isIOS`
- iOS: Apple Maps URL
- Android: Google Maps intent with URL fallback

### T3 — `UnescoNearbyService`
`lib/features/heritage/unesco_nearby_service.dart`

- `NearbySiteResult` value class
- `sitesWithin()` — deduplicate by siteId, haversine filter, sort, cross-reference visited
- Unit tests: known coordinate → expected nearest sites

### T4 — `UnescoNearbyNotifier`
`lib/features/heritage/unesco_nearby_notifier.dart` + provider in `providers.dart`

- `AsyncNotifier<UnescoNearbyState>`
- Permission check + position fetch via `geolocator`
- Calls `UnescoNearbyService.sitesWithin()` with current state
- `setRadius(double km)` method — called by slider (after debounce)

### T5 — `UnescoNearbySiteCard` widget
`lib/features/heritage/unesco_nearby_site_card.dart`

- Image + fallback gradient
- Category badge
- Distance + bearing label + rotated arrow icon
- Travel time strip (walk/cycle/drive)
- Visited badge
- `onTap` callback

### T6 — `UnescoSiteDetailSheet`
`lib/features/heritage/unesco_site_detail_sheet.dart`

- Hero image
- All metadata sections (description, criteria, inscription year)
- Travel time tiles
- Visited banner
- "Get Directions" button → `NativeMapsLauncher.open()`
- "View on Globe" button → pop + switch to Map tab + centre globe
- Reuse `HeritageDetailSheet`'s existing enrichment lookup pattern

### T7 — `UnescoNearbyExplorerScreen`
`lib/features/heritage/unesco_nearby_explorer_screen.dart`

- `ConsumerStatefulWidget`
- AppBar: "UNESCO Nearby" + site count badge
- Location pill (reverse geocode via geolocator)
- Slider row with debounce (300 ms `Timer`)
- `AsyncValue.when` for loading/error/data
- Permission denied / empty state views
- `ListView.builder` of `UnescoNearbySiteCard`

### T8 — Entry point wiring
- Map screen: add `"🌍 UNESCO Nearby"` chip to the action bar (next to existing heritage toggle)
- `CountryProfileScreen`: small "Explore nearby →" link in the UNESCO section header

### T9 — Tests
- `distance_utils_test.dart` (T1 already covers this)
- `unesco_nearby_service_test.dart`: filter/sort/dedup correctness with a mocked site list
- Widget smoke test for `UnescoNearbyExplorerScreen` in permission-denied state (no real location needed)

---

## File Map

```
apps/mobile_flutter/lib/features/heritage/
  distance_utils.dart               NEW  — haversine, bearing, travel time
  native_maps_launcher.dart         NEW  — url_launcher deep link
  unesco_nearby_service.dart        NEW  — filter + NearbySiteResult
  unesco_nearby_notifier.dart       NEW  — Riverpod AsyncNotifier
  unesco_nearby_explorer_screen.dart NEW — main screen
  unesco_nearby_site_card.dart      NEW  — list item widget
  unesco_site_detail_sheet.dart     NEW  — bottom sheet (extends heritage detail)
  [world_heritage_lookup_service.dart  NO CHANGE]
  [heritage_detail_sheet.dart          NO CHANGE — reused]
  [heritage_repository.dart            NO CHANGE — loadVisitedSiteIds() called]

apps/mobile_flutter/lib/core/
  providers.dart                    EDIT — add unescoNearbyNotifierProvider

apps/mobile_flutter/lib/features/map/
  map_screen.dart                   EDIT — add UNESCO Nearby chip to action bar
  country_profile_screen.dart       EDIT — "Explore nearby →" link in UNESCO section

apps/mobile_flutter/test/features/heritage/
  distance_utils_test.dart          NEW
  unesco_nearby_service_test.dart   NEW
```

---

## ADRs

- **ADR-014:** `UnescoNearbyService` uses `WorldHeritageLookupService.allSites` directly — no Firestore or network call. All filtering is synchronous in-memory. Dataset size (~1200 sites after dedup) makes this acceptable.
- **ADR-015:** `NativeMapsLauncher` uses deep links only. No routing API is called. Roavvy receives no route data back from the maps app. Turn-by-turn navigation is delegated entirely to the native maps application.
- **ADR-016:** `DistanceUtils` extracts the haversine function that currently lives privately in `WorldHeritageLookupService`. The original private method is retained unchanged; `DistanceUtils` is a new sibling utility with no coupling to the lookup service.

---

## Definition of Done

- [ ] UNESCO Nearby Explorer accessible from the map screen action bar
- [ ] Location permission requested with friendly explanation; denial handled gracefully
- [ ] Slider (5–500 km, default 50 km) updates site list after 300 ms debounce
- [ ] Sites sorted nearest first; transboundary sites not duplicated
- [ ] Each card shows image (or fallback), category badge, distance, bearing, travel estimates, visited badge
- [ ] Detail sheet shows full metadata, travel times, and "Get Directions" button
- [ ] "Get Directions" opens Apple Maps (iOS) or Google Maps (Android) with destination pin
- [ ] "View on Globe" closes sheet and switches to Map tab
- [ ] Empty state shown when no sites in radius
- [ ] No paid APIs added (no Google Maps API key, no Mapbox, no routing service)
- [ ] `DistanceUtils` unit tests pass
- [ ] `UnescoNearbyService` unit tests pass
- [ ] `flutter analyze` shows zero new warnings
- [ ] Existing scan, globe, daily challenge, and purchase flows unchanged
