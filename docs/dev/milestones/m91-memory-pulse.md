# M91 — Memory Pulse

**Branch:** `milestone/m91-memory-pulse`
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (hero labels), M90 (HeroImageView widget)
**Status:** Not started

---

## 1. Milestone Goal

On travel anniversaries — days when the user was in a country exactly N years ago — show a rich in-app memory card and an optional local push notification. The notification is copy-written using the hero image's labels to feel personal and evocative rather than generic.

---

## 2. Product Value

Memory Pulse is Roavvy's emotional engagement layer. While the map and journal are active-browse features, Memory Pulse is ambient — it surfaces memories the user didn't know they were about to feel. It drives daily active use and creates moments worth sharing.

Examples:
- *"3 years ago today — Aegean sunrise 🌅 Greece"*
- *"You were hiking in the Alps 2 years ago today"*
- *"On this day in 2022 — beach days in the Seychelles"*

---

## 3. Scope

**In:**
- New `lib/features/memory/memory_pulse_service.dart`
- New `lib/features/memory/memory_pulse_card.dart`
- `lib/core/notification_service.dart` (add `scheduleMemoryPulse`, `scheduleDailyMemoryCheck`)
- `lib/features/map/map_screen.dart` (in-app memory card surface)
- `lib/core/providers.dart` (new `todaysMemoriesProvider`)

**Out:** Server-side notifications, Firebase Cloud Messaging for Memory Pulse, social sharing of memory cards (separate milestone), web.

---

## 4. UX Design

### 4a. In-app memory card — on map screen

When the user opens the app on a day that is an anniversary of a past trip, a dismissible memory card appears at the top of the map screen, above the globe:

```
┌─────────────────────────────────────────────────────┐
│  [HERO IMAGE — 80×80 rounded]                       │
│                                                     │
│  3 years ago today                                  │
│  Aegean sunrise in Greece  🌅                       │
│  12 Jul 2022 · 7 days · beach · golden_hour         │
│                                                     │
│  [View trip]                          [✕ Dismiss]   │
└─────────────────────────────────────────────────────┘
```

- Card appears at top of map screen, slides down with spring animation
- Hero image loaded via existing `HeroImageView` (M90)
- Tap "View trip" → navigates to journal screen filtered to that trip
- Tap `✕` → dismissed for the day (preference stored in SharedPreferences keyed by `tripId:date`)
- If multiple anniversaries today: show as horizontal paged cards (max 3)
- If no anniversaries: card is not shown (no empty state)

### 4b. Push notification — anniversary

Delivered via `flutter_local_notifications` (already in the app), scheduled the morning of the anniversary day:

```
Title:  "On this day · 3 years ago in Greece 🌅"
Body:   "Aegean sunrise at the coast — 7 days of golden_hour and beach"
```

Tapping the notification:
- Deep-links to the memory card on the map screen (via `tab:0` payload + `memoryTripId:{id}`)
- If app is cold-started from the notification, the map opens and the memory card is shown

### 4c. Notification copy generation

Copy is generated locally from hero labels — no network call, no AI:

```dart
String buildNotificationTitle(HeroImage hero, int yearsAgo) {
  final country = kCountryNames[hero.countryCode] ?? hero.countryCode;
  final mood = hero.mood.isNotEmpty ? _moodEmoji(hero.mood.first) : '';
  return 'On this day · $yearsAgo ${yearsAgo == 1 ? "year" : "years"} ago in $country $mood';
}

String buildNotificationBody(HeroImage hero) {
  final scene = hero.primaryScene;
  final mood = hero.mood.isNotEmpty ? hero.mood.first : null;
  final activity = hero.activity.isNotEmpty ? hero.activity.first : null;
  // e.g. "Aegean sunrise at the coast — 7 days of golden_hour and beach"
  // Falls back gracefully if labels are sparse
}
```

Mood emoji map (local constant):
```
sunset → 🌅  sunrise → 🌄  golden_hour → 🌅  night → 🌃
beach → 🏖   mountain → ⛰   snow → 🌨   city → 🏙   forest → 🌲
food → 🍽   boat → ⛵   hiking → 🥾   people → 👥
```

---

## 5. Anniversary Detection Logic

### Definition of "anniversary"

A trip has an anniversary today if:
```
trip.startedOn.month == today.month &&
trip.startedOn.day   == today.day   &&
today.year > trip.startedOn.year
```

Only trips where a `rank=1` hero image exists are considered (no hero → no pulse).

### Scheduling strategy

Two scheduling modes:

**Mode A — Daily check at app launch (primary)**
- `MemoryPulseService.checkToday()` called from `initState` of `MapScreen` (or app shell)
- Checks today's anniversaries from Drift
- If any found: emits via `todaysMemoriesProvider`
- Idempotent: repeated calls on the same day return the same result

**Mode B — Scheduled morning notification (secondary)**
- After scan completes (or on app launch each day), schedule a `zonedSchedule` notification for 9:00 AM the next anniversary date found in the user's trips
- Uses `tz.TZDateTime` in device local timezone
- Only one notification scheduled at a time (`_kMemoryPulseNotificationId = 2`)
- Re-scheduled after the notification fires (or on next app launch)

### Edge cases
- Trip lasted more than 1 day: anniversary fires on the `startedOn` day only
- Multiple trips in the same country on the same calendar date across years: show all (max 3)
- User dismisses: store `dismissed:{tripId}:{iso-date}` in SharedPreferences; do not re-show same day

---

## 6. Data Flow

```
App launches / MapScreen init
        ↓
MemoryPulseService.checkToday()
        ↓
HeroImageRepository.getTripsWithAnniversaryToday()
  → SELECT hero_images JOIN trip anniversary logic
  → returns List<HeroImage> where startedOn matches today mm/dd
        ↓
Filter: rank=1, not dismissed today
        ↓
todaysMemoriesProvider emits List<HeroImage>
        ↓
MapScreen shows MemoryPulseCard (if list non-empty)

Separately (daily, non-blocking):
MemoryPulseService.scheduleNextAnniversaryNotification()
  → find next future anniversary across all trips
  → cancel existing pulse notification
  → schedule new zonedSchedule for 9:00 AM that date
```

---

## 7. Implementation Tasks

### T1 — `MemoryPulseService`
**File:** `lib/features/memory/memory_pulse_service.dart`
**Deliverable:** `checkToday()` → queries `HeroImageRepository` for trips with anniversary today. `scheduleNextAnniversaryNotification()` → finds next future anniversary and calls `NotificationService`. `buildCopy(HeroImage, yearsAgo)` → returns `MemoryPulseCopy(title, body)` using label-to-copy rules.
**Acceptance:** Unit tests for: anniversary match logic, copy generation with various label combinations, copy generation with no labels (graceful fallback).

---

### T2 — `NotificationService` extension
**File:** `lib/core/notification_service.dart`
**Deliverable:** Add `scheduleMemoryPulse({title, body, tripId, deliverAt})` using `zonedSchedule` at `deliverAt` time. Notification ID `_kMemoryPulseNotificationId = 2`. Payload `memoryPulse:$tripId`. Update `_onTap` to handle `memoryPulse:` prefix — sets `pendingMemoryTripId` on a new `ValueNotifier`.
**Acceptance:** Notification scheduled correctly. `_onTap` sets `pendingMemoryTripId`. Existing nudge and achievement notifications unaffected.

---

### T3 — `HeroImageRepository` extension
**File:** `lib/features/scan/hero_image_repository.dart`
**Deliverable:** Add `getHeroesWithAnniversaryToday(DateTime today)` — queries `hero_images` where `strftime('%m-%d', captured_at / 1000, 'unixepoch') = '{mm}-{dd}'` and `captured_at` is at least 1 year before today and `rank = 1`.
**Acceptance:** Unit tests for: correct anniversary match, no match when < 1 year old, no match for tombstoned rows.

---

### T4 — `todaysMemoriesProvider`
**File:** `lib/core/providers.dart`
**Deliverable:** `todaysMemoriesProvider` — `FutureProvider<List<HeroImage>>` that calls `MemoryPulseService.checkToday()` once per app session. Exposed as a `StateProvider` so the map screen can filter dismissed entries client-side.
**Acceptance:** Provider returns empty list when no anniversaries. Does not throw on first launch (no hero data yet).

---

### T5 — `MemoryPulseCard` widget
**File:** `lib/features/memory/memory_pulse_card.dart`
**Deliverable:** Card widget as designed in Section 4a. Uses `HeroImageView` (M90). Shows country, years-ago copy, date, top 2 labels as chips. "View trip" button navigates to journal filtered to `tripId`. Dismiss button stores `dismissed:{tripId}:{today}` in `SharedPreferences` and removes card from `todaysMemoriesProvider` state.
**Acceptance:** Widget tests: renders with and without labels. Dismiss stores preference. "View trip" calls correct navigation.

---

### T6 — Map screen integration
**File:** `lib/features/map/map_screen.dart`
**Deliverable:** Add `MemoryPulseCard` at top of map screen body (above globe). Wrap in `AnimatedSlide` + `AnimatedOpacity` for slide-in on first render. When `todaysMemoriesProvider` returns multiple memories, wrap in `PageView` (max 3 cards, dots indicator). Handle cold-start from notification: check `NotificationService.pendingMemoryTripId` in `initState`; if set, scroll to/highlight the matching memory card.
**Acceptance:** Card does not appear when no anniversaries. Card slides in on first render. Multiple memories shown as paged cards. Cold-start from notification highlights correct card.

---

## 8. Build Order

```
T3  Repository extension    (foundation)
T1  MemoryPulseService      (depends on T3)
T2  NotificationService ext (parallel with T1)
T4  todaysMemoriesProvider  (depends on T1)
T5  MemoryPulseCard widget  (depends on M90 HeroImageView)
T6  Map screen integration  (depends on T4, T5)
```

---

## 9. ADR

**ADR-136 — M91 Memory Pulse: Anniversary Detection and Label-Driven Copy**

Memory Pulse anniversary detection runs entirely on-device using a SQL date-pattern query against the `hero_images` table (`strftime('%m-%d')`). No server-side scheduling. Notifications are delivered via `flutter_local_notifications` `zonedSchedule` at 9:00 AM device local time. Only trips with a `rank=1` hero image trigger a pulse (label data required for copy). Notification copy is generated from normalized Roavvy labels — no AI or network call. User dismissal is stored in SharedPreferences keyed by `tripId:iso-date`; the same memory is never shown twice in one day. The `memoryPulse:{tripId}` notification payload extends the existing tab-routing system.
