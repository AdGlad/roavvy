# M154 — Distance Estimate

**Branch:** `milestone/m154-distance-estimate`
**Phase:** 22 — Stats Depth
**Depends on:** M147
**Status:** Backlog

---

## Goal

Users see an estimated total distance travelled — computed entirely offline from their visited countries' capital coordinates — expressed in both km and a fun real-world comparison ("1.2× around the Earth").

---

## Screen Layout

```
DistanceEstimateCard (inline on Stats screen, after StatsGrid)
  Dark navy gradient card (space/exploration feel)
  Plane icon + "Distance Travelled" header
  Large animated counter: "~48,320 km"
  Subheader: "That's 1.2× around the Earth"
  Secondary comparisons row (horizontal scroll):
    · "X× London to Sydney"
    · "X× Moon distance"
    · "Equivalent to Y flights"
```

---

## Scope

### In
- `packages/shared_models/lib/src/country_capitals.dart` — `kCapitalCoordinates: Map<String, LatLng>` (ISO code → lat/lng). Bundled static data for all 195 countries.
- `lib/features/stats/widgets/distance_estimate_card.dart` — card widget
- Distance computation: sort visited countries by `firstSeen` date; compute great-circle distance between consecutive capitals; sum total.
- Animated counter: `TweenAnimationBuilder<double>` 0 → total km.
- Comparisons: Earth circumference 40,075 km; Moon 384,400 km; London-Sydney 16,993 km.
- Card hidden if countryCount < 2 (need at least 2 points for a distance).

### Out
- Actual flight paths (great-circle approximation is sufficient)
- Trip-level granularity (country-level is sufficient for v1)
- Web version

---

## Acceptance Criteria

- [ ] Given visits to France (Paris) and Japan (Tokyo), distance = Haversine(Paris, Tokyo) ≈ 9,718 km.
- [ ] Given a single visited country, card is not shown.
- [ ] Counter animates from 0 to total on first render.
- [ ] "Around the Earth" comparison is correct to 1 decimal place.
- [ ] All distance computation is local — no network calls.

---

## Technical Notes

- Haversine formula implemented in `distance_utils.dart`:
  ```dart
  double haversineKm(double lat1, double lon1, double lat2, double lon2)
  ```
- Sort visited countries by `firstSeen` ascending before chaining distances.
- `kCapitalCoordinates` — approximately 6 KB of Dart const data; no JSON parsing overhead.
- `LatLng` type: use `latlong2` package already in pubspec, or define a simple `(double lat, double lng)` record.
- Round to nearest 10 km for display ("~48,320 km").

---

## Dependencies

- Depends on: M147
- Blocks: nothing

---

## Definition of Done

- [ ] `flutter analyze` — no new issues.
- [ ] Unit test: `haversineKm` for known city pairs (London–NYC ≈ 5,570 km).
- [ ] Unit test: chain distance for 3 countries matches manual sum.
- [ ] `current_state.md` updated.
