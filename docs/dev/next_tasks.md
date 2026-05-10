# M109 — Accurate Departure & Arrival Coordinates

**Branch:** milestone/m109-accurate-departure-arrival-coordinates
**Status:** In Progress

## Goal

Replace country-centroid departure/arrival points in the cinematic travel replay with actual GPS coordinates derived from trip photos. Travel arcs originate and terminate at real locations (e.g. Sydney → Santorini instead of Australia centroid → Greece centroid).

## Key Architectural Finding

GPS coordinates are currently discarded after country/region resolution (ADR-002). `TripRecord` and `photo_date_records` carry no GPS. To implement this milestone:
1. Extend `resolveBatch` to track per-photo GPS during batch processing (in-memory only)
2. After `inferTrips`, match GPS records to trips by time window to extract first/last coordinates
3. Store trip GPS endpoints as nullable fields in `TripRecord` + Drift `Trips` table (schema v12)
4. Document as ADR-157 (extension of ADR-002)

---

## Tasks

- [ ] 1. ADR-157 — Trip GPS endpoint storage extending ADR-002 (`docs/architecture/decisions/adr-recent.md`)
- [ ] 2. `PhotoGpsRecord` + `BatchResult.photoGps` — track raw GPS per photo in `resolveBatch` (`scan_screen.dart`)
- [ ] 3. `TripRecord` GPS fields — add nullable `firstLat/firstLng/lastLat/lastLng` to shared_models `TripRecord`
- [ ] 4. Drift schema v12 + TripRepository — add nullable GPS columns to `Trips` table; migration; regenerate `.g.dart`; update `upsertAll`/`_rowToRecord`
- [ ] 5. Scan pipeline GPS enrichment — `_extractTripGps` helper; apply GPS to trips before `upsertAll`
- [ ] 6. `TravelLeg` GPS fields + `TravelReplayScriptBuilder` — nullable GPS fields on `TravelLeg`; use trip GPS endpoints when building legs
- [ ] 7. `GlobeReplayPainter` — prefer leg GPS over centroid for arc endpoints + departure dot + arrival pulse
- [ ] 8. `TravelReplayController` — use leg GPS for camera pan targets in `_runDepartureSettle` + `_runFlight`
- [ ] 9. `flutter analyze` — 0 new warnings; update docs + milestone status
