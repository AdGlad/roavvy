# M56 — Bugs and Small Enhancements

**Milestone:** 56
**Phase:** Cross-cutting / Quality
**Status:** 📋 In Planning (2026-04-02)

**Goal:** Resolve known UX bugs and deliver a focused set of small enhancements across the scan celebration flow, map interaction, and country navigation. No new feature systems. Scope is deliberately narrow — additional tasks may be appended to this milestone before architecture begins.

---

## Tasks

### M56-01 — Confetti celebration should use flag colours

**Problem statement:**
The country celebration confetti effect uses generic colours. This misses an opportunity to personalise each celebration moment and make it feel more emotionally resonant.

**Desired outcome:**
The confetti palette is derived from the flag colours of the country being celebrated. Each celebration feels unique and tied to that specific country.

**Acceptance criteria:**
- [ ] Confetti particle colours are derived from the flag SVG/palette for the country being celebrated
- [ ] Colours are visually balanced — no single colour dominates or becomes unreadable
- [ ] A fallback palette is used when a flag palette cannot be derived (e.g. unknown country, missing asset)
- [ ] The change is isolated to the confetti colour source; no other celebration behaviour changes
- [ ] Unit test: palette derivation returns expected colours for a known flag
- [ ] `flutter analyze` clean

---

### M56-02 — Fix confetti layout on the final pre–Explore Your Map screen

**Problem statement:**
On the final screen that shows all detected countries before the "Explore Your Map" action, confetti appears stuck at the top of the screen in a small, constrained window. Particles do not fall naturally downward.

**Desired outcome:**
Confetti flows across the full intended celebration area and falls downward naturally.

**Acceptance criteria:**
- [ ] Confetti is no longer clipped to a small top region
- [ ] Particles fall downward across the visible screen space as expected
- [ ] Fix works correctly on different device sizes and aspect ratios
- [ ] No overflow or z-index layering issues with the country summary UI beneath
- [ ] Widget test: confetti widget fills available height constraint
- [ ] `flutter analyze` clean

---

### M56-03 — Queue celebrations so they do not overlap

**Problem statement:**
When multiple countries are discovered in a single scan, celebrations are triggered too quickly and overlay each other. The result is a chaotic, low-quality celebration experience.

**Desired outcome:**
Each country celebration completes before the next begins. The sequence feels deliberate and premium.

**Architectural note (ADR-108):**
The existing `_pushDiscoveryOverlays()` in `scan_summary_screen.dart` already uses a sequential `await Navigator.push()` loop — the correct pattern. No separate queue class or `StreamController` should be introduced. The fix is surgical:
1. Remove the `_kMaxOverlays = 5` constant and the `.take(5)` guard — all discovered countries must be shown.
2. Insert `await Future.delayed(const Duration(milliseconds: kCelebrationGapMs))` after each `await push` in the loop body, gated by `if (!mounted || skipped) break`.
3. Extract the gap constant `kCelebrationGapMs = 300` to the top level of `discovery_overlay.dart`.

**Acceptance criteria:**
- [ ] Only one `DiscoveryOverlay` is shown at a time (guaranteed by the sequential await loop)
- [ ] Each overlay is fully dismissed before the next is pushed
- [ ] A 300 ms inter-celebration gap is inserted between overlays; gap duration is controlled by `kCelebrationGapMs` constant in `discovery_overlay.dart`
- [ ] No overlapping confetti, banners, cards, or animations at any point in the sequence
- [ ] The sequence works reliably when 15+ countries are discovered simultaneously (no cap on queue length)
- [ ] Unit test: `_pushDiscoveryOverlays()` with 6 discovered countries drives all 6 overlays in order with the expected gap
- [ ] Existing overlay tests updated to remove 5-overlay cap assumption
- [ ] `flutter analyze` clean

---

### M56-04 — Add celebration audio

**Problem statement:**
Country celebrations are visually rewarding but silent. A well-chosen audio effect would significantly increase the emotional impact of each celebration moment.

**Desired outcome:**
A short, pleasant audio effect plays when a country celebration is shown. The sound is celebratory but not intrusive.

**Architectural note (ADR-109):**
- Add `audioplayers: ^6.0.0` (or latest stable) to `apps/mobile_flutter/pubspec.yaml`. Do not add to any package.
- Bundle a single audio asset at `assets/audio/celebration.mp3` (≤ 100 KB, < 2 s). Register in `pubspec.yaml`.
- `DiscoveryOverlay._DiscoveryOverlayState.initState()` creates an `AudioPlayer`, calls `player.play(AssetSource('audio/celebration.mp3'))`, and disposes it in `dispose()`. No singleton, no shared state.
- iOS `AVAudioSession` ambient mode (the `audioplayers` default) is silenced by the hardware silent switch — no custom mute detection code needed.
- Because ADR-108 guarantees only one `DiscoveryOverlay` is mounted at a time, audio cannot overlap by construction.
- In widget tests (host environment), wrap the `player.play(...)` call in try/catch to suppress `MissingPluginException`.

**Acceptance criteria:**
- [ ] `audioplayers` added to `pubspec.yaml`; `flutter pub get` succeeds
- [ ] `assets/audio/celebration.mp3` bundled and registered; asset loads without error on device
- [ ] Audio plays at the start of each `DiscoveryOverlay` (aligned with haptic in `initState`)
- [ ] Audio clip is < 2 seconds in duration
- [ ] Multiple sequential celebrations do not produce overlapping audio (guaranteed by sequential overlay queue)
- [ ] Audio is silent when iOS silent switch is on; audio respects system volume on Android
- [ ] `flutter analyze` clean

---

### M56-05 — Add first-visited date to country discovered screens

**Problem statement:**
The country discovered screen currently shows only the country name and flag. There is no information about when the user first visited the country, which reduces the emotional resonance of the moment.

**Desired outcome:**
Each discovered country screen includes the first-visited date for that country, making the celebration more meaningful and personal.

**Acceptance criteria:**
- [ ] First-visited date is shown on the country discovered screen
- [ ] Date is the earliest valid visit derived from photo evidence (existing trip/scan data)
- [ ] Date is formatted consistently with app style (e.g. "First visited: March 2019")
- [ ] If no first-visited date can be determined, a sensible fallback is shown (e.g. "First visited: unknown" or the date field is omitted)
- [ ] Widget test: date renders correctly with a known trip record; fallback renders when no date is available
- [ ] `flutter analyze` clean

---

### M56-06 — Fix country discovered flow so all countries are shown before navigating away

**Problem statement:**
When multiple discovered country screens are queued, pressing Next can navigate prematurely to the main map before all countries in the queue have been shown. For example, with 12 countries found, the app may navigate away at around the fifth screen.

**Root cause (ADR-108):**
`_pushDiscoveryOverlays()` in `scan_summary_screen.dart` applies `.take(_kMaxOverlays)` where `_kMaxOverlays = 5`. The loop exits and calls `widget.onDone()` (→ Main Map) after only 5 overlays regardless of how many countries were discovered. **This task is resolved as part of M56-03** — removing the `_kMaxOverlays` cap fixes the premature navigation.

**Desired outcome:**
Every discovered country screen in the queue is shown in order before automatic transition to the main map. The sequence is reliable regardless of queue size.

**Acceptance criteria:**
- [ ] Next always advances to the next undisplayed discovered country screen while any remain in the queue
- [ ] Navigation to the main map occurs only after the final discovered country screen has been shown
- [ ] The fix works for batches of 1, 5, and 15+ discovered countries (verified: no `.take(N)` cap exists)
- [ ] No countries in the queue are skipped unintentionally
- [ ] Widget test: with 12 discovered countries, all 12 `DiscoveryOverlay` screens are pushed before `widget.onDone()` is called
- [ ] `flutter analyze` clean

**Builder note:** implement together with M56-03. Both tasks modify `_pushDiscoveryOverlays()` in `scan_summary_screen.dart` and should be a single commit.

---

### M56-07 — Skip All navigates to the Main Map screen

**Problem statement:**
The Skip All action in the discovered country flow does not reliably navigate to the Main Map screen. The navigation destination is inconsistent or broken.

**Root cause (ADR-108):**
Skip All inside `DiscoveryOverlay` sets `skipped = true` and pops the current overlay. The loop in `_pushDiscoveryOverlays()` detects the flag and breaks. `widget.onDone()` is then called — which is correct. The navigation failure is in the `onDone` caller: `ReviewScreen` / `ScanSummaryScreen`'s `onDone` callback must pop to the Main Map. Verify and fix the `onDone` callback at the call site rather than inside `_pushDiscoveryOverlays()`. Additionally, the `onSkipAll` parameter on the last overlay in the batch was set to `null` due to the `_kMaxOverlays` cap condition `i == overlayCount - 1` — removing the cap (M56-03) may expose this: ensure `onSkipAll` is non-null for every overlay except the true final one (`i == widget.newCodes.length - 1`).

**Desired outcome:**
Tapping Skip All always navigates directly and cleanly to the Main Map screen, dismissing any remaining celebration screens.

**Acceptance criteria:**
- [ ] Tapping Skip All always navigates to the Main Map screen (verified at the `onDone` call site)
- [ ] Any remaining queued celebration screens are not pushed after Skip All sets the `skipped` flag
- [ ] No broken navigation state remains after Skip All
- [ ] `onSkipAll` is non-null for all overlays except the final one (`currentIndex == totalCount - 1`)
- [ ] Works correctly whether 1 or 15 screens remain in the queue
- [ ] Widget test: Skip All from index 2 of a 12-country sequence calls `onDone` once and leaves no overlay on the navigator stack
- [ ] `flutter analyze` clean

**Builder note:** implement together with M56-03 and M56-06 (same file, same function).

---

### M56-08 — Zoom map out so the full world can be seen on the pre-Explore screen

**Problem statement:**
On the final map screen shown prior to "Explore Your Map", the default map zoom is too close and the user cannot see the full world. The global context of their travel is not immediately visible.

**Desired outcome:**
The default map view is zoomed out to show the full world (or close to it), allowing users to immediately understand the global spread of their visited countries.

**Acceptance criteria:**
- [ ] Default map view on this screen shows the full world or a wide world view
- [ ] Framing works well on common iPhone screen sizes (iPhone SE through iPhone Pro Max)
- [ ] Country markers and overlays remain visible and legible at the default zoom level
- [ ] `flutter analyze` clean

---

### M56-09 — Allow manual zoom in and out on the pre-Explore map screen

**Problem statement:**
The map on the final pre-Explore screen does not support pinch-to-zoom or manual pan. Users cannot explore their map before pressing Explore Your Map.

**Desired outcome:**
Users can pinch-to-zoom and pan the map on this screen, giving them time to inspect their world travel before continuing.

**Acceptance criteria:**
- [ ] Pinch-to-zoom is enabled on this map
- [ ] Pan gesture is enabled
- [ ] Zoom and pan do not conflict with surrounding scroll or swipe gestures
- [ ] Map state remains stable during zooming
- [ ] `flutter analyze` clean

---

### M56-10 — Double tap map opens Main Map screen

**Problem statement:**
The pre-Explore map preview has no shortcut gesture to go directly into the full map experience. Double tapping the map does nothing.

**Desired outcome:**
Double tapping the map on the pre-Explore screen navigates the user directly to the Main Map screen, providing an intuitive shortcut.

**Acceptance criteria:**
- [ ] Double tap on the map navigates to the Main Map screen
- [ ] The gesture fires reliably and does not conflict with single-tap or pinch interactions
- [ ] Navigation preserves expected context (user should land on the main map in its normal state)
- [ ] Widget test: double tap triggers navigation
- [ ] `flutter analyze` clean

---

### M56-11 — Use pastel region colours on country maps

**Problem statement:**
When displaying regions on country maps, all regions use the same colour or near-identical colours. It is difficult to distinguish one region from another.

**Desired outcome:**
Regions are rendered using a pastel colour palette. Adjacent regions are visually distinguishable. The map feels softer and more premium.

**Acceptance criteria:**
- [ ] Regions are filled using a defined pastel colour palette
- [ ] Palette contains at least 12 distinct colours
- [ ] Colours cycle if a country has more than 12 regions (no region is left uncoloured)
- [ ] Adjacent or nearby regions are assigned distinct colours where practical
- [ ] Colours remain readable with any map overlays, selection states, and region labels
- [ ] Styling is consistent across all country map views in the app
- [ ] Widget test: 12+ region country produces 12 distinct fill colours cycling through the palette
- [ ] `flutter analyze` clean

---

### M56-12 — Ensure navigation to countries and regions from the Main Map

**Problem statement:**
From the Main Map, the paths to country views and region views are incomplete or broken. Users cannot reliably drill down from world → country → region.

**Desired outcome:**
The Main Map acts as the central navigation hub. Users can tap any visited country to enter the country view, and from there access region views where region data exists.

**Acceptance criteria:**
- [ ] Tapping a country on the Main Map navigates to the country detail view
- [ ] From the country detail view, tapping a region navigates to the region detail view
- [ ] Region navigation is only available where region visit data exists
- [ ] Back navigation returns users to the expected previous map level at each step
- [ ] Navigation works reliably with no broken state on any tested path
- [ ] Widget test: country tap from map navigates to country screen; region tap navigates to region screen
- [ ] `flutter analyze` clean

---

### M56-13 — Incremental scanning: process new images only after initial scan

**Problem statement:**
After the initial full scan, each subsequent scan reprocesses the entire photo library. For large photo libraries this is slow, wastes battery, and creates a poor user experience.

**Desired outcome:**
After the first full scan, subsequent scans only process newly added images. The app is faster, smarter, and more production-ready.

**Architectural note (ADR-110):**
The infrastructure for incremental scanning already exists. Do not introduce new tables, new files, or new models.

- **Scan boundary**: `ScanMetadata.lastScanAt` (nullable TEXT, ISO 8601) in Drift `scan_metadata` table is the sole boundary marker. `null` = no full scan has ever completed.
- **What is "new"**: photos with `PHAsset.creationDate > lastScanAt`. The Swift bridge already accepts `sinceDate` via `startPhotoScan({DateTime? sinceDate})` (ADR-012).
- **Incremental path**: pass `sinceDate: lastScanAt` to `startPhotoScan`. Full scan path: omit `sinceDate`.
- **Timestamp capture**: record the scan start time **before** calling `startPhotoScan` and write it to `ScanMetadata.lastScanAt` on success — do not use the end time, to avoid silently skipping photos taken during the scan.
- **Merge safety**: `VisitRepository.upsert` and `TripRepository.upsert` already handle duplicates. No additional deduplication logic is needed.
- **First-scan guard**: check `lastScanAt != null` before offering or triggering an incremental scan (used by M56-14 and M56-15). Expose this as a `hasCompletedFirstScan` boolean on the `ScanMetadata` access layer.
- **Fallback**: if `lastScanAt` is null or the value fails to parse as a valid date, fall back to a full scan silently.

**Acceptance criteria:**
- [ ] After the initial full scan completes, `ScanMetadata.lastScanAt` is set to the pre-scan UTC timestamp
- [ ] Subsequent scans pass `sinceDate: lastScanAt` to `startPhotoScan`; no photos before `lastScanAt` are re-processed
- [ ] Incremental scan results merge cleanly via existing upsert semantics; no duplicate country/trip rows are introduced
- [ ] If `lastScanAt` is null or unparseable, a full scan is triggered instead; no error is surfaced to the user
- [ ] No new Drift table, migration, or model is introduced — `lastScanAt` is the only state needed
- [ ] Unit test: incremental scan called with a known `lastScanAt` value passes the correct `sinceDate` to `startPhotoScan`
- [ ] Unit test: null `lastScanAt` triggers full scan (no `sinceDate` argument)
- [ ] `flutter analyze` clean

---

### M56-14 — Add user control for incremental scan vs full scan

**Problem statement:**
After incremental scanning is implemented, users have no manual way to trigger a full rescan. There is no UI control for this choice.

**Desired outcome:**
A UI control allows the user to choose between an incremental scan and a full scan. Incremental scan remains the default; full scan is available when the user wants to start fresh.

**Acceptance criteria:**
- [ ] UI provides clearly labelled options for **Incremental Scan** and **Full Scan**
- [ ] The difference between the two options is explained or clearly implied in the UI
- [ ] Selecting Full Scan triggers a complete rescan of all eligible photos
- [ ] Selecting Incremental Scan processes only photos since the last scan state
- [ ] Control is placed in a discoverable and appropriate location (e.g. Scan tab or settings)
- [ ] Widget test: selecting Full Scan triggers full scan behaviour; selecting Incremental Scan triggers incremental behaviour
- [ ] `flutter analyze` clean

---

### M56-15 — Auto-run incremental scan on app open after first scan

**Problem statement:**
After the user completes their first scan, newly added photos are not discovered unless the user manually triggers a scan. The app does not proactively keep the user's travel data up to date.

**Desired outcome:**
After the first successful scan, the app automatically triggers an incremental scan each time the app is opened. Newly added photos are discovered with minimal user effort.

**Acceptance criteria:**
- [ ] On app open, an incremental scan is triggered automatically if a first full scan has already completed
- [ ] The auto-scan does not trigger before the first full scan has been completed
- [ ] A full rescan is not triggered on app open — only an incremental scan
- [ ] If an incremental scan is already in progress, a duplicate is not launched
- [ ] Scan startup is controlled and does not feel disruptive to the user
- [ ] Appropriate progress messaging is shown only when the incremental scan finds new countries
- [ ] Integration test: app open with existing scan state triggers incremental scan, not full scan
- [ ] `flutter analyze` clean

---

## Notes

- More tasks may be added to this milestone before Architect is invoked.
- Tasks are ordered approximately by user-facing impact, not implementation order.
- Tasks M56-13 through M56-15 form a logical group (incremental scanning) and should be scoped as a sub-group during architecture.
- Tasks M56-01 through M56-07 relate to the celebration/scan flow and share state concerns — the queue mechanism (M56-03) likely affects both M56-04 (audio timing) and M56-05/M56-06 (navigation sequencing). Architect should evaluate dependencies.

---

# M57 — Passport Stamp Image Improvements

**Milestone:** 57
**Phase:** Phase 18 — Passport Stamp Image Quality
**Status:** 📋 In Planning (2026-04-02)

**Goal:** Improve visual correctness, layout, realism, usability, and year-based rendering of passport stamp compositions used for cards and merchandise. All stamps must be visible, correctly bounded, and dynamically scaled. On-the-fly rendering replaces any static layout approach. Further stamp enhancements may be appended before Architect is invoked.

---

## Tasks

### M57-01 — Ensure all passport stamps are visible within the image

**Problem statement:**
Not all stamps appear to be shown in the composed image. Some may be clipped, missing, or placed outside the visible canvas area, resulting in an incomplete output that cannot be used for cards or merchandise.

**Desired outcome:**
All generated stamps for the selected filter are included in the final image. No stamp is cut off or partially hidden by the canvas boundary.

**Acceptance criteria:**
- [ ] All stamps selected for rendering are included in the output image
- [ ] No stamp overlaps the image boundary
- [ ] No stamp is clipped or partially hidden
- [ ] Layout adapts dynamically to the number of stamps present
- [ ] The rendered result is suitable for preview and printing
- [ ] `flutter analyze` clean

---

### M57-02 — Adjust Create Card layout to maximise image space

**Problem statement:**
The current Create Card screen does not provide enough space for the passport stamp image, making it hard to confirm whether all stamps are shown correctly. The image preview area is too small relative to the screen.

**Desired outcome:**
The passport stamp image becomes the primary focus of the screen. More room is given to the preview image so all stamps can be inspected clearly before proceeding.

**Acceptance criteria:**
- [ ] The image container is expanded to maximise visible area
- [ ] The layout defaults to portrait presentation
- [ ] Non-essential UI elements are reduced, compressed, or repositioned to prioritise the image
- [ ] Layout works across common phone screen sizes (iPhone SE through iPhone Pro Max) without breaking usability
- [ ] `flutter analyze` clean

---

### M57-03 — Dynamically scale stamps so all stamps fit on the page

**Problem statement:**
Stamp sizes currently do not reliably fit within the page when many stamps are present. The layout can overflow or produce overcrowded compositions that obscure individual stamps.

**Desired outcome:**
All stamps fit cleanly within the page regardless of count. Visual density still feels natural and realistic.

**Acceptance criteria:**
- [ ] Stamp size scales based on total number of visible stamps
- [ ] Minimum and maximum scale limits are enforced to prevent stamps from being too small or too large
- [ ] Layout avoids overcrowding or excessive empty space
- [ ] All stamps remain fully visible within safe margins
- [ ] Unit test: scaling function returns expected size values for known stamp counts at boundary conditions
- [ ] `flutter analyze` clean

---

### M57-04 — Prevent stamp clipping by enforcing safe placement boundaries

**Problem statement:**
Stamps can extend beyond the visible image area. Because the resulting image is used for t-shirt printing, any clipped stamp produces an incomplete and unprofessional printed result.

**Desired outcome:**
The composed image always contains complete, printable stamps. Stamps feel naturally placed without any part being cut off.

**Acceptance criteria:**
- [ ] Safe inset margins are defined and applied within the canvas
- [ ] Stamp placement logic respects these boundaries before finalising any stamp position
- [ ] Overlap between stamps is allowed only where it does not push either stamp beyond the canvas edge
- [ ] Every stamp is fully visible in the final image at all supported stamp counts
- [ ] Unit test: placement algorithm with a known stamp count produces no out-of-bounds positions
- [ ] `flutter analyze` clean

---

### M57-05 — Improve year filter so all stamps for the selected year are correctly displayed in one image

**Problem statement:**
The current year or country slide behaviour does not appear to be working correctly for stamps. Selecting a year may not produce a complete image — stamps from the selected year may be omitted, or stamps from other years may appear incorrectly.

**Desired outcome:**
Selecting a year produces one complete image containing all stamps for that year. No stamps from the selected year are omitted, and no stamps from other years appear incorrectly.

**Acceptance criteria:**
- [ ] Each selected year renders one complete composed image containing all stamps for that year
- [ ] No year-filtered composition drops stamps unexpectedly
- [ ] No stamps from outside the selected year appear in the filtered result
- [ ] Behaviour is consistent and predictable when switching between years and "All Years"
- [ ] Unit test: year filter applied to a known dataset returns the correct stamp set
- [ ] `flutter analyze` clean

---

### M57-06 — Use on-the-fly composition rendering for year-filtered passport stamp images

**Problem statement:**
The current approach may rely on static layouts that pre-bake all stamps and then hide/show them per filter. This can produce incomplete or misaligned compositions when the stamp count changes per filter. The image must be regenerated from the filtered dataset each time.

**Desired outcome:**
The rendered image always matches the currently selected year/filter and layout settings. Year changes produce correct, complete, and bounded stamp compositions.

**Acceptance criteria:**
- [ ] The image is regenerated when the selected year, orientation, or relevant stamp dataset changes
- [ ] Rendering uses the filtered stamp set as the source of truth, not a cached all-years layout
- [ ] Layout is recalculated for the active stamp set rather than hiding/showing stamps from a fixed layout
- [ ] The same inputs always produce a stable and consistent layout result (deterministic)
- [ ] `flutter analyze` clean

---

### M57-07 — Preserve fast preview performance while rendering on the fly

**Problem statement:**
The current experience feels near-instant. The improved on-the-fly rendering approach must preserve that responsive feel. Introducing per-change re-renders without care could cause noticeable lag or UI flicker, especially during rapid year switching.

**Desired outcome:**
Passport image updates remain fast and smooth when changing year or viewing the preview. The user experience does not feel laggy.

**Acceptance criteria:**
- [ ] Preview rendering remains near-instant for normal stamp counts on target devices
- [ ] Preview generation uses screen-appropriate resolution rather than full print resolution
- [ ] Re-rendering only occurs when relevant inputs change (year, orientation, stamp dataset)
- [ ] Cached results are reused where appropriate — identical inputs do not trigger a redundant re-render
- [ ] Rapid filter changes do not leave the UI in a broken or flickering state
- [ ] `flutter analyze` clean

---

### M57-08 — Add full-screen preview on double tap

**Problem statement:**
Users cannot inspect the composed passport stamp image in detail before using it for a card or product. The preview area is small and there is no affordance to view the image larger.

**Desired outcome:**
Users can view the image in a larger immersive preview. Stamp details and overall composition can be checked more easily before printing.

**Acceptance criteria:**
- [ ] Double tap on the passport stamp image opens a full-screen preview
- [ ] The full-screen preview displays the same currently selected image/filter
- [ ] Dismiss interaction is intuitive and smooth (e.g. swipe down or tap to dismiss)
- [ ] Zoom and pan are supported within the full-screen preview
- [ ] Widget test: double tap triggers navigation to the full-screen preview
- [ ] `flutter analyze` clean

---

### M57-09 — Improve realism with varied stamp styling

**Problem statement:**
The composed image does not sufficiently replicate real passport pages. Stamps may feel mechanically uniform in colour and presentation, reducing the authenticity and appeal of the final card or merchandise design.

**Desired outcome:**
Stamps feel authentic and varied like real-world passport pages. The final merch image gives the impression that the t-shirt itself has been stamped.

**Acceptance criteria:**
- [ ] Stamp ink colours vary across a realistic set (e.g. blue, red, purple, black, green) — no single colour applied uniformly to all stamps
- [ ] Slight variation in rotation, opacity, and scale is applied per stamp
- [ ] Variation is tasteful and not chaotic — the overall composition remains legible and visually coherent
- [ ] No two adjacent stamps feel mechanically identical unless intentionally so
- [ ] Variation is deterministic for a given set of inputs (same countries + year → same variation pattern)
- [ ] `flutter analyze` clean

---

### M57-10 — Keep the passport stamp image background transparent

**Problem statement:**
The generated image needs to work cleanly when applied to merchandise (t-shirts) and cards. A solid background would prevent stamps from sitting naturally on the product surface.

**Desired outcome:**
Only the stamps are rendered. The background remains transparent. The output integrates cleanly into downstream product and card rendering flows.

**Acceptance criteria:**
- [ ] Output image preserves alpha transparency
- [ ] No unwanted solid background colour is introduced by the renderer
- [ ] Transparency works correctly in the card preview, share image, and merchandise mockup flows
- [ ] Unit test: rendered output image has transparent pixels outside stamp bounds
- [ ] `flutter analyze` clean

---

### M57-11 — Review and improve country/year slide logic related to passport stamp display

**Problem statement:**
The current country slide or selection behaviour may be contributing to missing or incorrectly displayed stamps. Slide state or indexing logic may not correctly map to the intended stamp dataset, causing omissions that are difficult to diagnose.

**Desired outcome:**
The data shown in the image always matches the selected year/filter and intended set of countries. Navigation or slide state does not cause stamp omissions.

**Acceptance criteria:**
- [ ] Slide or selection state correctly maps to the intended stamp dataset at all times
- [ ] No stamps disappear because of selection/indexing logic errors
- [ ] Behaviour is verified across multiple years, "All Years", and mixed stamp counts
- [ ] Any identified slide/index logic bugs are fixed as part of this task
- [ ] `flutter analyze` clean

---

## Notes

- More tasks may be added to this milestone before Architect is invoked.
- Tasks are grouped by concern: layout/visibility (M57-01, M57-03, M57-04), UX (M57-02, M57-08), rendering correctness (M57-05, M57-06, M57-11), performance (M57-07), realism (M57-09), output quality (M57-10).
- M57-06 (on-the-fly rendering) is the foundational change; M57-05, M57-07, and M57-11 are likely downstream of it. Architect should evaluate dependencies and sequencing.
- M57-01 and M57-04 address the same root symptom (stamps outside canvas) from different angles — layout inclusion vs. placement clamping. Architect should determine whether these collapse into a single implementation concern.
- M57-09 (realism) is independent and can be scoped as a lower-risk follow-on if the rendering changes in M57-06 are large.

---

# M58 — Virtual Passport Book Experience

**Milestone:** 58
**Phase:** Phase 18 — Passport Stamp Image Quality
**Status:** 📋 In Planning (2026-04-02)

**Goal:** Transform the current stamp view — entered via a world search icon — into a premium, immersive Virtual Passport Book. The book includes a cover, structured internal pages, and an end page. Pages display stamp compositions in a realistic passport layout with page-turning interaction. The passport is also exportable as a printable product. Further enhancements may be appended before Architect is invoked.

---

## Tasks

### M58-01 — Replace world search icon with entry point to Virtual Passport Book

**Problem statement:**
The current entry point to passport stamps is a world search icon at the top of the card screen. This does not convey the richness or identity of the feature. Users have no indication that they are entering a premium passport-style experience.

**Desired outcome:**
Users enter a premium "passport book" experience rather than a basic stamp view. The feature feels like a core product experience, not a utility.

**Acceptance criteria:**
- [ ] World search icon is replaced with a clear, branded entry point to the Virtual Passport Book
- [ ] Entry point is visually aligned with Roavvy branding
- [ ] Tapping the entry point opens the Virtual Passport Book experience
- [ ] Transition into the book feels smooth and intentional
- [ ] `flutter analyze` clean

---

### M58-02 — Introduce Virtual Passport Book structure (cover, pages, end)

**Problem statement:**
There is no book-level structure around the stamp experience. Stamps are shown in a flat list or grid without the framing of a physical passport. Users do not experience the sense of browsing a personal travel document.

**Desired outcome:**
The experience mimics a real passport format — cover, internal pages, and end page — while remaining uniquely Roavvy. Users feel like they are browsing a physical passport.

**Acceptance criteria:**
- [ ] Book includes a front cover, one or more internal content pages, and a final/end page
- [ ] Cover design is premium and brand-aligned; it is not styled as a replica of any real country's passport
- [ ] Pages follow a consistent structure and layout throughout the book
- [ ] Navigation through the book is linear and intuitive
- [ ] `flutter analyze` clean

---

### M58-03 — Design passport-style page layouts with background textures

**Problem statement:**
Current stamp views have no page-level visual context. Stamps appear on a plain background with no cues that reinforce the passport metaphor. Pages need texture and structure to feel authentic.

**Desired outcome:**
Pages feel authentic and tactile. The design enhances the realism of the stamp experience and makes the book feel like a physical object.

**Acceptance criteria:**
- [ ] Pages include subtle background textures or patterns consistent with a passport page aesthetic
- [ ] Layout provides a clear visual area for stamp placement
- [ ] Content remains readable and uncluttered at standard preview sizes
- [ ] Visual design is performant on mobile devices (no frame drops during page render)
- [ ] `flutter analyze` clean

---

### M58-04 — Integrate passport stamp compositions into book pages

**Problem statement:**
Stamp compositions currently exist outside any page context. They must be embedded within the new page layouts so that stamps appear as if they have been stamped onto real passport pages.

**Desired outcome:**
Stamps appear as if they are stamped onto the pages. The experience ties directly to the existing stamp engine and benefits from all M57 stamp quality improvements.

**Acceptance criteria:**
- [ ] Stamp compositions from the existing stamp engine are correctly placed within page boundaries
- [ ] Layout supports varying numbers of stamps per page without clipping
- [ ] Stamps remain fully visible and unclipped within each page
- [ ] Page design enhances stamp visibility rather than competing with it
- [ ] `flutter analyze` clean

---

### M58-05 — Add realistic page-turning interaction

**Problem statement:**
Simple swipe or slide transitions do not reinforce the physical passport metaphor. The navigation between pages should feel like turning pages in a real book.

**Desired outcome:**
Users experience a realistic page-turning interaction when navigating forward and backward through the passport. The interaction feels premium and distinguishes the book from a standard screen flow.

**Acceptance criteria:**
- [ ] Page transitions simulate turning pages (e.g. curl animation, fold, or high-quality swipe consistent with a page-turn metaphor)
- [ ] Interaction is smooth and responsive; no jank on target devices
- [ ] Users can navigate forward and backward through pages
- [ ] Interaction does not conflict with scroll or other touch gestures
- [ ] `flutter analyze` clean

---

### M58-06 — Define page grouping logic (e.g. by year or country)

**Problem statement:**
There is no defined strategy for how stamps are distributed across pages. Without grouping logic, pages will either be overcrowded or poorly balanced, and users cannot understand how their travel history is organised.

**Desired outcome:**
Pages are structured and meaningful. Users can navigate through the book and understand how their travel history is organised — for example, by year, region, or continent.

**Acceptance criteria:**
- [ ] Pages are grouped by a consistent and logical criterion (e.g. year, region, or continent — to be confirmed during architecture)
- [ ] All stamps are included and correctly assigned to their respective pages
- [ ] No stamp is duplicated or omitted across pages
- [ ] Grouping logic is consistent and predictable when the underlying visit data changes
- [ ] Unit test: grouping function distributes a known dataset of stamps correctly across pages
- [ ] `flutter analyze` clean

---

### M58-07 — Ensure all stamps remain fully visible within pages

**Problem statement:**
Stamp placement within pages must respect boundaries. Stamps must not be clipped by page edges, page margins, or adjacent page decorations.

**Desired outcome:**
Each page feels like a complete passport page. No stamps are clipped or hidden.

**Acceptance criteria:**
- [ ] All stamps are fully visible within page boundaries
- [ ] Safe inset margins are enforced on all page sides
- [ ] Layout adapts dynamically based on stamp count per page
- [ ] No stamp overflows into page margins, decorative borders, or adjacent pages
- [ ] `flutter analyze` clean

---

### M58-08 — Enable full-screen viewing of passport pages

**Problem statement:**
The default book view may not be large enough for users to inspect individual stamp details. Users need a way to examine pages and stamps more closely.

**Desired outcome:**
Users can zoom into their passport experience. Stamp details and overall page composition are clearly visible in a larger view.

**Acceptance criteria:**
- [ ] Individual pages can be viewed in a full-screen mode
- [ ] Zoom and pan are supported within the full-screen page view
- [ ] Transition to and from full-screen is smooth and intuitive
- [ ] Full-screen view shows the same page content as the book view
- [ ] Widget test: full-screen page view opens from the correct page
- [ ] `flutter analyze` clean

---

### M58-09 — Support printable passport book output for shop integration

**Problem statement:**
The virtual passport has no path to physical merchandise. Users should be able to purchase a printed physical version of their passport book, consistent with Roavvy's commerce model.

**Desired outcome:**
Users can initiate a purchase of a physical printed passport from within the Virtual Passport Book experience. The design translates cleanly to a printable format.

**Acceptance criteria:**
- [ ] Passport pages can be exported in a print-ready format (sufficient resolution and margins)
- [ ] Layout includes print-safe margins on all pages
- [ ] Cover and all internal pages are included in the print output
- [ ] Print output integrates with the existing shop and print-on-demand workflow
- [ ] A clear CTA within the book experience initiates the print/shop flow
- [ ] `flutter analyze` clean

---

### M58-10 — Maintain transparent and reusable stamp assets within pages

**Problem statement:**
Stamp rendering must continue to work cleanly within the new book format. Stamps must retain transparency so that they sit naturally on the page texture rather than introducing solid background artefacts.

**Desired outcome:**
Stamp assets remain reusable and visually consistent across both the standalone stamp view and the new book pages. Visual quality is maintained in preview and print.

**Acceptance criteria:**
- [ ] Stamp images retain alpha transparency when composited onto page backgrounds
- [ ] No unintended solid background rectangles or artefacts appear behind stamps
- [ ] Rendering quality is consistent across screen preview and print export outputs
- [ ] Stamp reuse does not require duplicating or forking the existing stamp engine
- [ ] `flutter analyze` clean

---

### M58-11 — Preserve performance and responsiveness across the book experience

**Problem statement:**
A book with multiple pages, textures, animations, and stamp compositions could easily degrade performance. The experience must remain smooth on target devices without sacrificing visual quality.

**Desired outcome:**
The experience feels premium but fast. Page navigation and stamp rendering do not feel laggy or block interaction.

**Acceptance criteria:**
- [ ] Page transitions are smooth with no visible frame drops on target devices
- [ ] Stamp rendering does not block the UI thread
- [ ] Heavy rendering operations (texture compositing, stamp layout) are handled asynchronously where needed
- [ ] Rapid page navigation does not leave the UI in a broken or flickering state
- [ ] Performance is acceptable on iPhone SE (minimum supported device)
- [ ] `flutter analyze` clean

---

## Notes

- More tasks may be added to this milestone before Architect is invoked.
- M58 builds on top of M57 (stamp image quality). Architect should confirm whether M57 must be complete before M58 begins, or whether the two milestones can run partially in parallel.
- M58-04 (stamp integration into pages) depends on M57-06 (on-the-fly rendering) and M57-10 (transparent background) being stable.
- M58-05 (page-turning interaction) is high complexity and high risk; Architect should evaluate whether a simplified page-turn approach is appropriate for the first iteration.
- M58-06 (grouping logic) is a key design decision — the grouping criterion (year vs. region vs. continent) should be confirmed in the architecture phase before implementation begins.
- M58-09 (print output) is the commerce integration task; it may be deferred to a follow-on milestone if the book experience itself proves complex enough to warrant its own milestone.
