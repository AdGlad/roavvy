# Milestone 89 — Journal Redesign: 3D Trip Carousel & Immersive Details

## Goal
Transform the Journal into a premium, immersive travel archive by replacing the standard scrolling list with a vertical 3D rolodex carousel and rich, memory-focused trip detail screens.

## Current UX Problems
- **Functional but flat:** The current list-based Journal feels like a database view rather than a travel diary.
- **Lack of immersion:** Small hero images and standard transitions don't do justice to the user's travel memories.
- **Limited detail:** Navigation goes directly to a technical map view, skipping the emotional connection of a curated trip summary.

## Proposed Journal UX
- **Vertical 3D Carousel:** Trips are presented as a stack of large, photographic cards that rotate through a perspective arc.
- **Immersive Cards:** Full-bleed hero images with elegant text overlays (title, dates, photo count).
- **Seamless Motion:** Cards scale up and reach full opacity as they enter the focus zone.

## Carousel Animation Design
Using `flutter_custom_carousel`, we will implement a "Rolodex" effect:
1.  **Alignment Arc:** Cards move from `topCenter` to `bottomCenter` along a vertical path.
2.  **3D Rotation:** Cards rotate around the X-axis (`rotateX`), tilting back as they enter from the top and forward as they exit the bottom.
3.  **Dynamic Scale:** Cards pulse to 1.0x scale at the center and shrink to ~0.7x at the edges.
4.  **Perspective:** A strong perspective value (e.g., 0.001) will be applied to the rotation to enhance the 3D depth.

## flutter_custom_carousel Implementation Approach
- **Controller:** Use `CustomCarouselController` to manage scroll state.
- **Effects Builder:** Utilize `effectsBuilderFromAnimate` for declarative animation chaining.
- **Order of Operations:** `align` -> `rotateX` -> `scale` -> `fade`. This ensures cards follow a physical arc rather than a linear path.
- **Curves:** Apply `Curves.easeOut` to alignment and `Curves.easeInOut` to rotation for a mechanical, weighted feel.

## Trip Card Design
- **Base:** `Stack` with `HeroImageView` as the full-bleed background.
- **Overlay:** Black-to-transparent gradient (bottom-up and top-down) to ensure text legibility.
- **Header (Top):** Country flag and name in a clean, minimal row.
- **Footer (Bottom):** Trip title (prominent) + Date range and Photo count (secondary).

## Trip Detail Screen Design
A new `TripDetailScreen` replacing the direct jump to the globe:
- **Top Half (Flexible Header):** `RegionGlobePainter` focused on the trip's country, with regions visited on *that specific trip* highlighted in amber.
- **Map Overlays:** Float the trip dates, duration, and photo count over the map surface.
- **Bottom Half (SliverList/Grid):** A beautiful gallery of all photos from the trip, utilizing `photo_manager` for high-performance local thumbnails.

## Data Model Requirements
- Uses existing `TripRecord`.
- Leverages `heroForTripProvider` for high-quality hero selection.
- Requires `RegionRepository` to filter visited regions by `tripId`.

## Navigation Behaviour
- **Journal -> Detail:** Tap card to push `TripDetailScreen`.
- **Persistence:** The `CustomCarouselController` will be stored in a Riverpod `ChangeNotifierProvider` (or similar) to ensure the user returns to the exact same trip they just viewed.

## Performance Considerations
- **Image Caching:** Reuse the existing `NSCache` logic in `ThumbnailPlugin.swift`.
- **Lazy Rendering:** `CustomCarousel` natively supports lazy loading of off-screen items.
- **Decoding Guard:** Avoid loading full-resolution hero images for cards that are far from the focus zone.

## 📌 Tasks

### Phase 1: Foundation & Card UI
- [ ] **T1: Add Dependencies & State**
  - Add `flutter_custom_carousel` and `flutter_animate` to `pubspec.yaml`.
  - Create `journalCarouselProvider` to persist scroll index.
- [ ] **T2: Premium Trip Card Component**
  - Implement `TripCarouselCard` widget with full-bleed hero, gradients, and typography.
  - Add `onEditHero` entry point via long-press or dedicated button.

### Phase 2: Carousel Implementation
- [ ] **T3: 3D Rolodex Carousel**
  - Replace `_JournalList` with `CustomCarousel`.
  - Implement the 3D effect stack: `align` -> `rotateX` -> `scale` -> `fade`.
  - Fine-tune perspective and easing curves.

### Phase 3: Trip Detail Screen
- [ ] **T4: Trip Detail Layout & Map**
  - Create `TripDetailScreen` with a `NestedScrollView` architecture.
  - Implement the "Map Header" with `RegionGlobePainter` and overlay metadata.
- [ ] **T5: Integrated Photo Gallery**
  - Build a high-performance photo grid using `photo_manager`.
  - Implement tap-to-view full screen photo.

### Phase 4: Wiring & Polish
- [ ] **T6: Navigation & State Sync**
  - Wire card tap to `TripDetailScreen`.
  - Ensure scroll position is preserved on return.
- [ ] **T7: Performance Optimization**
  - Verify 60 FPS on physical device.
  - Implement `RepaintBoundary` for the carousel if needed.

## 🧪 Acceptance Criteria
- [ ] Journal displays a vertical carousel of full-image trip cards.
- [ ] Carousel uses a 3D "Rolodex" style animation (rotation + scale + fade).
- [ ] Scroll position is maintained when navigating back from a trip.
- [ ] `TripDetailScreen` shows a trip-filtered globe map and a photo gallery.
- [ ] Text remains legible over varied hero images via gradient overlays.
- [ ] Performance remains smooth (no frame drops) during carousel interaction.

## 🚀 Recommended Build Order
1.  Add `flutter_custom_carousel`.
2.  Build `TripCarouselCard` (UI only).
3.  Implement basic vertical `CustomCarousel` in `JournalScreen`.
4.  Add 3D effects and curves to the carousel.
5.  Build `TripDetailScreen` (Map header).
6.  Add Photo Gallery to `TripDetailScreen`.
7.  Wire navigation and persistence.
