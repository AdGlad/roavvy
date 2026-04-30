# M94 — Year in Review

**Branch:** `milestone/m94-year-in-review`
**Phase:** 19 — Personalisation & Memory
**Status:** In Progress (2026-05-01)

## Goal
Full-screen annual travel summary shown in Dec/Jan: hero-image trip timeline, key stats,
label-driven highlights, shareable mosaic card, New Year push notification.

## Scope
In: year_in_review_service.dart, year_in_review_screen.dart, year_in_review_card.dart,
    providers.dart (yearInReviewDataProvider), notification_service.dart (scheduleYearInReview),
    map_screen.dart (_YearInReviewBanner)
Out: Firestore sync, CardEditorScreen, web, shared_models, Android

## Tasks

- [ ] T1 -- YearInReviewService + YearInReviewData
- [ ] T2 -- yearInReviewDataProvider (Riverpod)
- [ ] T3 -- YearInReviewCard widget (mosaic card)
- [ ] T4 -- YearInReviewScreen (full-screen summary + share)
- [ ] T5 -- _YearInReviewBanner in map_screen.dart
- [ ] T6 -- NotificationService: scheduleYearInReview (ID 3)

---

## T1 -- YearInReviewService + YearInReviewData
**File:** `lib/features/year_in_review/year_in_review_service.dart`

YearInReviewData fields: year, List<TripRecord> trips (sorted by startedOn, filtered to year),
Map<String, HeroImage?> heroByTripId, int countryCount, tripCount, totalPhotos,
String? topScene, topMood, topActivity, topCountry.

YearInReviewService.getDataForYear(int year) -> Future<YearInReviewData?>
- Null if no trips. Pure. trips sorted asc by startedOn.
- topScene = most frequent non-null primaryScene across heroes.

AC: null for empty year; trips sorted; aggregates correct.

---

## T2 -- yearInReviewDataProvider
**File:** `lib/core/providers.dart`

FutureProvider.family<YearInReviewData?, int> using tripRepositoryProvider + heroImageRepositoryProvider.

AC: Follows existing FutureProvider.family pattern.

---

## T3 -- YearInReviewCard widget
**File:** `lib/features/year_in_review/year_in_review_card.dart`

AspectRatio 9:16, dark bg (0xFF0D1117).
- Top: gold year + "Your Year in Travel" subtitle
- Middle: 3x3 hero thumbnail grid (up to 9); blank = flag emoji tile
- Bottom: "N countries . N trips . N photos" amber stats
- Highlight chip if topScene present; "made with Roavvy" branding

_YearInReviewCardLoader StatefulWidget loads thumbs via ThumbnailChannel, passes
Map<String, Uint8List?> thumbs to YearInReviewCard.

YearInReviewCard({required YearInReviewData data, required Map<String, Uint8List?> thumbs})

AC: Renders with all-null heroes (flag fallback); AspectRatio enforced.

---

## T4 -- YearInReviewScreen
**File:** `lib/features/year_in_review/year_in_review_screen.dart`

Full-screen ConsumerStatefulWidget, CustomScrollView:
1. Header: year badge + counts
2. Highlights row: emoji chips (topScene/mood/activity), hidden if no labels
3. Trip timeline: _TripTile (HeroImageView thumb, country name, date range, photo count)
4. "Share Card" amber button

Share: RepaintBoundary GlobalKey on Offstage _YearInReviewCardLoader.
boundary.toImage(pixelRatio:3) -> PNG -> Share.shareXFiles. Button disabled until thumbs loaded.

YearInReviewScreen({required int year})

AC: Empty state when data null; share invokes system sheet; no upload.

---

## T5 -- _YearInReviewBanner in map_screen.dart
**File:** `lib/features/map/map_screen.dart`

ConsumerStatefulWidget in bottom Column after _ScanNudgeBanner.
- Dec: reviewYear = currentYear; Jan: reviewYear = currentYear - 1
- Shown when month in {12,1} AND data non-null AND not dismissed
- Dismissed via SharedPreferences `yirDismissed:{year}`
- Taps -> YearInReviewScreen(year: reviewYear)
- Listens to pendingYearInReviewYear; auto-opens on match
- Schedules notification once per year (guarded by `yirScheduled:{nextYear}`)

AC: Not shown outside Dec/Jan; not shown when no data; dismissal persists.

---

## T6 -- NotificationService: scheduleYearInReview
**File:** `lib/core/notification_service.dart`

1. const int _kYearInReviewNotificationId = 3
2. final ValueNotifier<int?> pendingYearInReviewYear = ValueNotifier(null)
3. _onTap: `yearInReview:` payload -> pendingYearInReviewYear.value = int
4. Future<int?> getLaunchYearInReviewYear() cold-start routing
5. Future<void> scheduleYearInReview({required int forYear}):
   - Cancel ID 3, schedule Jan 1 forYear 9:00 AM UTC
   - Title: "Your ${forYear-1} in Travel is ready"
   - Body: "See every country, trip, and highlight from last year."
   - Payload: `yearInReview:{forYear-1}`

AC: ID 3 no conflict; no-op when !_initialized; cold-start routing works.
