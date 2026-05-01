# Milestone 89 — Journal Redesign: 3D Trip Carousel & Immersive Details

## Goal
Transform the Journal into a premium, immersive travel archive by replacing the standard scrolling list with a vertical 3D rolodex carousel and rich, memory-focused trip detail screens.

## Tasks

- [ ] **T1 — Add Dependencies & State**
  - **Files:** `pubspec.yaml`, `lib/features/journal/journal_providers.dart`
  - **Deliverable:** Add `flutter_custom_carousel` and `flutter_animate`. Create `journalCarouselProvider` to persist scroll index.
  - **Acceptance Criteria:** `pub get` passes; provider correctly stores and restores integer index.

- [ ] **T2 — Premium Trip Card Component**
  - **Files:** `lib/features/journal/trip_carousel_card.dart`
  - **Deliverable:** Create `TripCarouselCard` widget with full-bleed hero image, dual-gradient overlays (top/bottom), and premium typography for country, title, and dates.
  - **Acceptance Criteria:** Text is readable on light/dark images; layout matches the "editorial" design target.

- [ ] **T3 — 3D Rolodex Carousel Implementation**
  - **Files:** `lib/features/journal/journal_screen.dart`
  - **Deliverable:** Replace `_JournalList` with `CustomCarousel`. Implement `align` -> `rotateX` -> `scale` -> `fade` effects stack. Fine-tune perspective (0.001) and Curves.
  - **Acceptance Criteria:** Vertical scrolling feels physical and snappy; cards arc realistically.

- [ ] **T4 — Trip Detail Screen: Map Header**
  - **Files:** `lib/features/journal/trip_detail_screen.dart`
  - **Deliverable:** Implement `TripDetailScreen` with `NestedScrollView`. Use `RegionGlobePainter` in the header to show the trip's country with visited regions highlighted. Overlay trip metadata.
  - **Acceptance Criteria:** Header collapses gracefully; map correctly reflects trip-specific region visits.

- [ ] **T5 — Trip Detail Screen: Photo Gallery**
  - **Files:** `lib/features/journal/trip_detail_screen.dart`
  - **Deliverable:** Add a sliver-based photo grid to the detail screen. Integrate with `photo_manager` and reuse `HeroImageView` for high-quality thumbnails.
  - **Acceptance Criteria:** All photos from the trip are displayed; performance is smooth during scroll.

- [ ] **T6 — Navigation & State Wiring**
  - **Files:** `lib/features/journal/journal_screen.dart`, `lib/main_shell.dart`
  - **Deliverable:** Wire card tap to `TripDetailScreen`. Ensure `journalCarouselProvider` is used to restore scroll position on back navigation.
  - **Acceptance Criteria:** Seamless push/pop transitions; carousel index is preserved.

- [ ] **T7 — Performance Optimization & QA**
  - **Files:** `lib/features/journal/journal_screen.dart`
  - **Deliverable:** Optimize image decoding (cache control); add `RepaintBoundary` if needed; verify 60 FPS on real hardware.
  - **Acceptance Criteria:** No jank during fast scrolling; memory usage remains within bounds.
