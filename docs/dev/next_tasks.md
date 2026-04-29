# M91 — Memory Pulse

**Branch:** `milestone/m91-memory-pulse`
**Phase:** 19 — Personalisation & Memory
**Status:** In Progress

## Goal

On travel anniversaries, show a dismissible in-app memory card on the map screen and schedule an optional 9 AM local push notification, using hero image labels for personal copy. Fully on-device; no server scheduling.

## Scope

**In:**
- `lib/features/memory/memory_pulse_service.dart` (new)
- `lib/features/memory/memory_pulse_card.dart` (new)
- `lib/core/notification_service.dart` (extend: scheduleMemoryPulse, pendingMemoryTripId)
- `lib/features/scan/hero_image_repository.dart` (extend: getHeroesWithAnniversaryToday)
- `lib/core/providers.dart` (new todaysMemoriesProvider)
- `lib/features/map/map_screen.dart` (surface MemoryPulseCard)

**Out:** Firebase Cloud Messaging, server-side notifications, social sharing of memory cards, web, Android.

## Tasks

- [ ] T3 — HeroImageRepository: getHeroesWithAnniversaryToday
  - File: `lib/features/scan/hero_image_repository.dart`
  - Deliverable: Add `getHeroesWithAnniversaryToday(DateTime today)` — queries `hero_images` using `strftime('%m-%d', capturedAt / 1000, 'unixepoch')` matching today's MM-DD. Filters: rank = 1, capturedAt at least 1 year before today.
  - Acceptance: Unit tests for: correct anniversary match, no match when < 1 year old, tombstoned rows (rank = -1) excluded.

- [ ] T1 — MemoryPulseService
  - File: `lib/features/memory/memory_pulse_service.dart`
  - Deliverable: `checkToday(DateTime today)` → calls `HeroImageRepository.getHeroesWithAnniversaryToday`, filters out dismissed entries (SharedPreferences key `dismissed:{tripId}:{yyyy-MM-dd}`). Returns `List<HeroImage>` max 3. `scheduleNextAnniversaryNotification()` → finds next future anniversary across all trips with rank=1 heroes; cancels existing pulse notification; schedules `zonedSchedule` at 9:00 AM local. `buildCopy(HeroImage hero, int yearsAgo)` → returns `MemoryPulseCopy(title, body)` from label-to-copy rules using mood emoji map.
  - Acceptance: Unit tests for: anniversary match with labels, copy generation with full labels, copy generation with no labels (graceful fallback), dismissed entry filtered out.

- [ ] T2 — NotificationService extension
  - File: `lib/core/notification_service.dart`
  - Deliverable: Add `const _kMemoryPulseNotificationId = 2`. Add `final ValueNotifier<String?> pendingMemoryTripId = ValueNotifier(null)`. Add `scheduleMemoryPulse({required String title, required String body, required String tripId, required DateTime deliverAt})` using `zonedSchedule` with payload `memoryPulse:$tripId`. Update `_onTap` to handle `memoryPulse:` prefix — sets `pendingMemoryTripId.value`. Update `getLaunchTab` equivalent for cold-start: expose `getLaunchMemoryTripId()` that reads launch notification payload. Existing nudge and achievement notifications unaffected.
  - Acceptance: New method compiles; `_onTap` sets `pendingMemoryTripId`; existing notification IDs 0 and 1 unaffected.

- [ ] T4 — todaysMemoriesProvider
  - File: `lib/core/providers.dart`
  - Deliverable: `todaysMemoriesProvider` as `FutureProvider<List<HeroImage>>` that calls `MemoryPulseService.checkToday(DateTime.now())`. Add `memoriesDismissedProvider` as `StateProvider<Set<String>>` (holds dismissed tripIds for the current session, so the card disappears instantly without re-querying DB).
  - Acceptance: Provider returns empty list when no anniversaries. Does not throw on first launch (no hero data).

- [ ] T5 — MemoryPulseCard widget
  - File: `lib/features/memory/memory_pulse_card.dart`
  - Deliverable: Card matching Section 4a design. 80×80 rounded `HeroImageView`. Shows "{N} years ago today", country name + top mood emoji, formatted date, trip duration, top 2 label chips. "View trip" navigates to journal screen at tripId. Dismiss button stores `dismissed:{tripId}:{yyyy-MM-dd}` in SharedPreferences, adds tripId to `memoriesDismissedProvider`. When multiple memories: wrap in `PageView` + dots indicator (max 3 cards).
  - Acceptance: Widget tests: renders with labels, renders with no labels (graceful), dismiss stores preference, "View trip" calls correct navigation.

- [ ] T6 — Map screen integration
  - File: `lib/features/map/map_screen.dart`
  - Deliverable: Watch `todaysMemoriesProvider` and `memoriesDismissedProvider`. Filter out dismissed. If non-empty: show `MemoryPulseCard` at top of map Stack, above globe, positioned below safe area. Wrap card in `AnimatedSlide` (offset 0,-1 → 0,0) + `AnimatedOpacity` for slide-in. Handle cold-start: in `initState`-equivalent listen, check `NotificationService.pendingMemoryTripId`; if set, scroll to the matching memory card.
  - Acceptance: Card absent when no anniversaries. Card slides in. Dismissed card removes immediately. Multiple memories shown as paged cards with dots.

## Build Order

```
T3 (Repository) → T1 (Service) + T2 (Notification) → T4 (Provider) → T5 (Card) → T6 (Map)
```

## Risks

| Risk | Mitigation |
|---|---|
| strftime SQL date comparison differs from Dart date logic | Add unit test confirming millisecond epoch → MM-DD string matches expected |
| `flutter_local_notifications` `zonedSchedule` requires timezone init | `tz.initializeTimeZones()` already called in main; no change needed |
| SharedPreferences key collision | Use prefix `memoryPulse:dismissed:` to namespace |
| Map screen becomes StatefulWidget to use AnimationController | Convert only the map body area; keep existing ConsumerWidget structure by extracting animated card into a separate StatefulWidget child |
