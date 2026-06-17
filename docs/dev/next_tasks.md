# M163 — UNESCO Nearby Explorer — Task List

## Status: In Progress

## Tasks

- [x] T0: Branch created (milestone/m163-unesco-nearby-explorer)
- [ ] T1: DistanceUtils — haversine, bearing, travel time pure functions + unit tests
- [ ] T2: NativeMapsLauncher — url_launcher Apple/Google Maps deep link
- [ ] T3: UnescoNearbyService — NearbySiteResult + sitesWithin() filter/sort/dedup
- [ ] T4: UnescoNearbyNotifier — Riverpod AsyncNotifier (location + radius + sites)
- [ ] T5: UnescoNearbySiteCard — list item widget (image, category, distance, times, badge)
- [ ] T6: UnescoSiteDetailSheet — bottom sheet (metadata, travel times, Get Directions)
- [ ] T7: UnescoNearbyExplorerScreen — main screen (slider, list, permission states)
- [ ] T8: Entry point — UNESCO Nearby chip on map screen
- [ ] T9: Service + distance utils unit tests

## Key facts
- geolocator ^13.0.0 already in pubspec; permission wired in heritage_detail_sheet.dart
- url_launcher already in pubspec; launchUrl pattern exists in heritage_detail_sheet.dart
- WorldHeritageLookupService.allSites — flat iterable, ~1200 sites, in-memory
- HeritageRepository.loadAll() — returns all visited VisitedHeritageSite
- haversine already private in world_heritage_lookup_service.dart — extract to DistanceUtils
- Map screen: _DailyChallengeChip pattern for the new chip
- No new packages needed
