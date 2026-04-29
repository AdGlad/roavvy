# M94 — Year in Review

**Branch:** `milestone/m94-year-in-review`
**Phase:** 19 — Personalisation & Memory
**Depends on:** M89 (hero images + labels), M90 (HeroImageView)
**Status:** Not started

---

## 1. Milestone Goal

A full-screen "Year in Review" experience that presents the user's travel year as a timeline of hero images, key statistics, and label-derived highlights. Accessible from the map screen. Shareable as a single image. Triggers annually (New Year period) as a push notification.

---

## 2. Product Value

Year in Review is a high-engagement, high-shareability feature. It synthesises everything Roavvy knows about the user's year into a single beautiful screen. When shared to social media it is Roavvy's most effective organic marketing surface.

---

## 3. Scope

**In:**
- New `lib/features/memory/year_in_review_screen.dart`
- New `lib/features/memory/year_in_review_service.dart`
- `lib/features/map/map_screen.dart` (entry point — "Year in Review" button, conditional on data)
- `lib/core/notification_service.dart` (New Year notification)
- `lib/features/cards/card_image_renderer.dart` (shareable YIR card image)

**Out:** Video generation, server-side rendering, web, multi-year comparison, social API posting.

---

## 4. UX Design

### 4a. Entry point

A "Year in Review" chip/button appears on the map screen stats strip during December and January. Only shown when the user has ≥ 3 trips in the past calendar year AND hero images exist for at least half of those trips.

```
[2025 in Review ✦]   ← amber chip, right side of stats strip
```

Tapping navigates to `YearInReviewScreen`.

### 4b. Year in Review screen structure

Full-screen, dark themed. Scrollable vertical timeline.

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   Your 2025                                    [✕]  │
│   12 countries · 18 trips · 94 days abroad          │
│                                                     │
├─────────────────────────────────────────────────────┤
│  [HERO IMAGE — full bleed, 280 dp]                  │
│                                                     │
│  January · United Arab Emirates                    │
│  beach · golden_hour                               │
│  3 days · Dubai                                    │
│                                                     │
├─────────────────────────────────────────────────────┤
│  [HERO IMAGE]                                       │
│  March · Japan                                      │
│  city · night                                      │
│  10 days                                           │
│                                                     │
├─────────────────────────────────────────────────────┤
│  ... (one section per trip, ordered by startedOn)   │
├─────────────────────────────────────────────────────┤
│  Highlights for 2025                                │
│                                                     │
│  Most visited:  Greece (3 trips)                    │
│  Furthest from home:  Australia                     │
│  Longest trip:  New Zealand · 14 days               │
│  Most common scene:  beach (7 trips)               │
│  Most common mood:  sunset (5 trips)               │
│  First trip:  Jan 3 · UAE                          │
│  Last trip:  Dec 18 · Portugal                     │
│                                                     │
├─────────────────────────────────────────────────────┤
│  [Share your 2025 →]                                │
└─────────────────────────────────────────────────────┘
```

### 4c. Shareable card

Tapping "Share your 2025" renders a fixed-size (1080×1920 px) shareable card via `CardImageRenderer`:

```
┌──────────────────────────────────────────┐
│  2025                            [ROAVVY]│
│                                          │
│  [3×3 grid of hero image thumbnails]     │
│                                          │
│  12 countries · 18 trips                 │
│  94 days abroad                          │
│                                          │
│  Top scenes: beach · mountain · city     │
│  Top mood: sunset                        │
│                                          │
│  [Country flag row]                      │
└──────────────────────────────────────────┘
```

Uses the top 9 hero images (by `heroScore` across the year), arranged in a 3×3 mosaic. Shared via the existing iOS share sheet.

### 4d. New Year push notification

Scheduled for January 1st at 10:00 AM local time:

```
Title: "Your 2025 in review is ready ✦"
Body:  "12 countries, 18 trips, 94 days. See your year."
```

Tapping deep-links to `YearInReviewScreen` for the previous year.

---

## 5. Year in Review Data Model

```dart
class YearInReview {
  final int year;
  final int countryCount;
  final int tripCount;
  final int daysAbroad;
  final List<TripHero> trips;       // ordered by startedOn
  final YearHighlights highlights;
  final List<HeroImage> topHeroes;  // top 9 by heroScore for shareable card
}

class TripHero {
  final TripRecord trip;
  final HeroImage? hero;            // null → show fallback colour
  final String? regionOrCity;       // from regionCode if available
}

class YearHighlights {
  final String mostVisitedCountry;
  final int mostVisitedCount;
  final String longestTripCountry;
  final int longestTripDays;
  final String mostCommonScene;
  final String mostCommonMood;
  final DateTime firstTripDate;
  final DateTime lastTripDate;
}
```

---

## 6. Implementation Tasks

### T1 — `YearInReviewService`
**File:** `lib/features/memory/year_in_review_service.dart`
**Deliverable:** `buildForYear(int year) → Future<YearInReview?>`. Queries `TripRepository` for trips in the given year. Queries `HeroImageRepository` for heroes. Computes all `YearHighlights` stats. Returns `null` if fewer than 3 trips or no hero data. Label aggregation: count `primaryScene` and `mood` across all heroes to find most-common.
**Acceptance:** Unit tests for: highlight computation, null return when insufficient data, correct year filtering, label frequency counting.

---

### T2 — `YearInReviewScreen`
**File:** `lib/features/memory/year_in_review_screen.dart`
**Deliverable:** Full-screen dark scrollable screen as designed in Section 4b. Each trip section uses `HeroImageView` (M90). Highlights section at bottom. "Share your 2025" button triggers T3. Dismiss button / back gesture.
**Acceptance:** Screen renders with mock data. Trips ordered by date. Fallback colour shown for trips without hero. Highlights shown correctly.

---

### T3 — Shareable YIR card render
**File:** `lib/features/cards/card_image_renderer.dart` (new `renderYearInReview` static method)
**Deliverable:** Off-screen render at 1080×1920. 3×3 hero image mosaic. Stats text. Country flag strip (reuse existing flag rendering). Roavvy branding. Returns `Uint8List` PNG. Shared via `Share.shareXFiles`.
**Acceptance:** Rendered card shows correct year, country count, trip count, days. Hero images composited at correct positions. Graceful fallback (country colour) for missing hero images.

---

### T4 — Map screen entry point
**File:** `lib/features/map/map_screen.dart`
**Deliverable:** `yearInReviewAvailableProvider` — returns `true` when current date is in Dec/Jan AND `YearInReviewService.buildForYear` would return non-null (≥3 trips + hero data). Add amber "Year in Review" chip to the stats strip, visible only when provider is true. Tapping navigates to `YearInReviewScreen` for the previous calendar year.
**Acceptance:** Chip only visible in Dec/Jan. Chip not visible if insufficient data. Navigation works.

---

### T5 — New Year notification
**File:** `lib/core/notification_service.dart`
**Deliverable:** `scheduleYearInReviewNotification(int year)` — schedules `zonedSchedule` for Jan 1 at 10:00 AM local time. Notification ID `_kYearInReviewNotificationId = 3`. Payload `yearInReview:{year}`. Called from `YearInReviewService` when data is available (called on app launch in December). Update `_onTap` to handle `yearInReview:` prefix, setting `pendingYearInReviewYear` on a `ValueNotifier`.
**Acceptance:** Notification scheduled for correct date/time. Cold-start from notification opens YearInReviewScreen for correct year.

---

## 7. Build Order

```
T1  YearInReviewService      (foundation — pure Dart, testable alone)
T3  Shareable card render    (depends on M90 HeroImageView + T1 data)
T2  YearInReviewScreen       (depends on T1, M90 HeroImageView)
T5  New Year notification    (depends on T1)
T4  Map screen entry point   (depends on T1, T2)
```

---

## 8. ADR

**ADR-139 — M94 Year in Review: On-Device Annual Travel Summary**

Year in Review is computed entirely on-device from `TripRepository` + `HeroImageRepository`. No server-side rendering, no API calls. The shareable card is rendered via an off-screen `CardImageRenderer` pass at 1080×1920 using `PHImageManager` thumbnail fetches. Highlight stats (most-visited, longest trip, most-common scene) are computed in `YearInReviewService` using label frequency counts from the `hero_images` table. The feature is gated on ≥3 trips with hero data to ensure the YIR has visual substance. The New Year notification uses the existing `flutter_local_notifications` `zonedSchedule` infrastructure. No user data is transmitted in the process.

---

## 9. Summary: Full M89–M94 Feature Arc

| Milestone | What it builds | User sees |
|---|---|---|
| M89 | Pipeline: labels + scores in SQLite | Nothing yet |
| M90 | Hero images in journal + country + scan summary | Photo on every trip card |
| M91 | Memory Pulse: anniversary notifications + map card | "3 years ago in Greece 🌅" |
| M92 | Label-powered card titles | "Aegean Sunset" instead of "Greece 2024" |
| M93 | Hero photo as card background | Personal photo behind passport stamps |
| M94 | Year in Review: shareable annual summary | "Your 2025 in review" |
