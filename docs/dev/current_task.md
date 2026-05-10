# Active Task: M109 — Accurate Departure & Arrival Coordinates

Branch: milestone/m109-accurate-departure-arrival-coordinates

## Status: Complete (2026-05-11)

## Delivered

- ADR-157: Trip GPS endpoint storage extending ADR-002
- `PhotoGpsRecord` + `BatchResult.photoGps` — raw GPS tracked during scan batch resolution
- `TripRecord` — nullable `firstLat/firstLng/lastLat/lastLng` GPS endpoint fields
- Drift schema v12 — `Trips` table gains four nullable REAL GPS columns; migration added
- `TripRepository` — `upsertAll` + `_rowToRecord` persist/load GPS fields
- `_applyTripGps` helper in scan pipeline — matches GPS records to trips by time window after `inferTrips`
- `TravelLeg` — `fromLat/fromLng/toLat/toLng` nullable GPS fields + `hasFromGps`/`hasToGps` helpers
- `TravelReplayScriptBuilder` — populates leg GPS from `trip.lastLat/lastLng` (departure) + `trip.firstLat/firstLng` (arrival)
- `GlobeReplayPainter` — `_resolveUnit`/`_resolveProject` helpers prefer GPS over centroid for arc + dots + pulse
- `TravelReplayController` — `_runDepartureSettle` + `_runFlight` use leg GPS for camera pan targets
- flutter analyze: 0 new issues
