# M95 — Memory Pulse 2.0: Question-Based Reveal + Share

**Phase:** 19 — Personalisation & Memory
**Depends on:** M91 (MemoryPulseService, MemoryPulseCard, NotificationService), M90 (HeroImageView, photo_manager thumbnail path)
**Status:** Not started

---

## Goal

Upgrade the existing M91 Memory Pulse from a passive "here is your memory" card into an active
curiosity-first engagement loop: ask a question, hide the answer, animate the reveal, then offer
sharing. Add question-style notification copy and smart morning/evening timing. Add a post-scan
pulse trigger. All on-device; no photos leave the device.

---

## What M91 already built (do NOT rebuild)

- `MemoryPulseService.checkToday()` — anniversary detection via strftime SQL
- `MemoryPulseService.buildCopy()` — label-driven copy (title + body)
- `MemoryPulseService.scheduleNextAnniversaryNotification()` — picks next anniversary, schedules at 9 AM
- `MemoryPulseService.dismiss()` — per-trip dismiss with SharedPreferences
- `MemoryPulseCard` widget — compact 100pt card, thumbnail + copy + "View trip" + dismiss
- `NotificationService.scheduleMemoryPulse()` — `flutter_local_notifications`, payload `memoryPulse:{tripId}`
- `todaysMemoriesProvider` + `memoriesDismissedProvider` — Riverpod state
- Map screen `_MemoryPulseSection` — slide-in animation, tap routing from notification cold-start

---

## M95 delta — what is NEW

### 1. Question generator
New method `MemoryPulseService.buildQuestion(HeroImage hero, int yearsAgo) → String`.

Question templates (pick by priority):

| Condition | Question |
|---|---|
| yearsAgo == 1 | "Do you remember where you were exactly one year ago?" |
| yearsAgo == 5 or 10 | "Can you believe it's been {X} years since {country}?" |
| hero has landmark label | "Remember visiting {landmark} in {country}?" |
| hero has beach/island/mountain | "Do you remember this {scene} in {country}?" |
| default | "Where were you {X} years ago today?" |

Rules: short, natural, no full stop, no emoji in the question itself.

---

### 2. Compact card — question teaser mode

Update `MemoryPulseCard._CardBody`:
- Replace the copy title with the **question string** (bold, 2 lines max)
- Replace "View trip" link with a **"Reveal ▸"** filled chip
- Tapping "Reveal ▸" opens `MemoryRevealSheet` (modal bottom sheet)
- Dismiss button (×) remains unchanged

The compact card is now a curiosity hook, not a reveal.

---

### 3. Memory reveal sheet (`memory_reveal_sheet.dart`)

Full-screen modal bottom sheet (drag-to-dismiss). Two phases driven by `_revealed: bool` state:

**Phase 1 — Question (initial state):**
```
[question text, large, centred, white]
[subtle hint: "Tap to reveal your memory"]
[ Reveal ] — FilledButton, amber
```

**Phase 2 — Revealed (after tap):**
Animates in with 350ms `FadeTransition` + `SlideTransition` (bottom→up, 12pt):
```
[HeroImageView — full width, 260pt height, thumbnailSize = screenWidthPx]
[gradient overlay — bottom 120pt, black80→transparent]
  [flag emoji + country name — bold, 20pt]
  [date string: "12 June 2022 · 2 years ago"]
  [top labels as chips: "beach" "sunset"]
[Share button — FilledButton.icon(Icons.share_outlined)]
[View trip — TextButton → navigates to TripDetailScreen]
```

Privacy: hero image loaded via `HeroImageView` (photo_manager, on-device only).

---

### 4. Memory share card (`memory_share_service.dart`)

`MemoryShareService.generateAndShare(BuildContext, HeroImage)` — fully on-device:

1. Load hero image bytes via `AssetEntity.fromId` at 1080×1080px
   (`ThumbnailOption.ios(deliveryMode: highQualityFormat, resizeMode: exact)`)
2. Composite via `ui.PictureRecorder` + `Canvas` at 1080×1080:
   - Full-bleed hero photo (or fallback: continent gradient)
   - Bottom gradient (transparent → black, bottom 40%)
   - Flag emoji (72pt) + country name (bold 36pt, white)
   - Date string (22pt, white70)
   - "Roavvy" wordmark (bottom-right, 18pt, white54)
3. Encode to PNG via `image.toByteData(format: ImageByteFormat.png)`
4. Write to `getTemporaryDirectory()/roavvy_memory.png`
5. Open iOS share sheet via `Share.shareXFiles([XFile(path)])` (share_plus)

Fallback when no hero assetId: use continent colour gradient + flag emoji centred.

---

### 5. Notification copy — question style

Update `MemoryPulseService.buildCopy()`:

- **title** → question string (same as `buildQuestion` output) + `" 👀"`
  - e.g. `"Where were you 2 years ago today? 👀"`
- **body** → rich answer hint (current label-driven body is good, keep it)
  - e.g. `"Sunset in Greece — 2 years ago"`

This makes the notification a curiosity hook that matches the in-app question card.

---

### 6. Smart notification timing (`AppOpenTracker`)

New `AppOpenTracker` (single static method, SharedPreferences):

```dart
// Called from main_shell.dart initState (fire-and-forget)
AppOpenTracker.recordNow();

// Returns preferred delivery hour (local time) based on last open:
// last open was 6 AM–12 PM → 8  (morning)
// last open was 4 PM–11 PM → 18 (evening)
// no data or other hours   → 9  (default morning)
static Future<int> preferredHour();
```

Update `MemoryPulseService.scheduleNextAnniversaryNotification()`:
- Call `AppOpenTracker.preferredHour()` instead of hardcoded `9`
- Deliver at that hour on the anniversary date

---

### 7. Structured state + dedup

Extend SharedPreferences keys in `MemoryPulseService`:

```
memoryPulse:lastShownDate          → 'YYYY-MM-DD'
memoryPulse:lastNotificationDate   → 'YYYY-MM-DD'
memoryPulse:revealed:{tripId}:{date} → bool
```

Guards:
- `scheduleNextAnniversaryNotification`: skip if `lastNotificationDate == today`
- `checkToday`: existing dismissed guard is sufficient (no change needed)
- Reveal sheet writes `revealed:{tripId}:{date}` on first expand; used for analytics later

---

### 8. Post-scan pulse trigger

After `ScanSummaryScreen.onDone` is called (scan complete, user has seen summary):
- Read `todaysMemoriesProvider` (already populated)
- If non-empty and `lastShownDate != today`: show `MemoryPulseCard` in a `showModalBottomSheet`
  as a lightweight standalone tray (not full-screen; uses existing compact card layout)
- Show max 3 memories (existing limit)
- Write `lastShownDate = today` after showing

Trigger location: `ScanScreen._navigateAfterScan()` or `ScanSummaryScreen` via a callback,
after the discovery overlay sequence completes. Do NOT interrupt the overlay animations.

---

## Scope

**In:**
- `memory_pulse_service.dart` (extend: `buildQuestion`, update `buildCopy`, dedup guard, `lastShownDate`)
- `memory_pulse_card.dart` (update: question teaser, "Reveal ▸" button)
- New `memory_reveal_sheet.dart`
- New `memory_share_service.dart`
- New `app_open_tracker.dart` (6 lines)
- `main_shell.dart` (record open time)
- `scan_screen.dart` or `scan_summary_screen.dart` (post-scan trigger)
- `notification_service.dart` (no structural change; used via existing `scheduleMemoryPulse`)

**Out:**
- Firestore: no changes
- `shared_models` package: no changes
- Drift schema: no changes
- Web: no changes
- Android: no changes
- Weekly summary: future milestone
- Contextual triggers (journal/map/card): future milestone
- Milestone/first-visit question type: needs trip ordering logic, defer to M96+

---

## ADR

**ADR-141 — M95 Memory Pulse 2.0: Question-First Reveal, Share Card, Smart Timing**

Decision 1: Compact card becomes a question teaser; reveal is deferred to `MemoryRevealSheet`.
This preserves the curiosity gap and makes the notification → card → reveal a coherent loop.

Decision 2: Share card composited on-device via `ui.PictureRecorder` at 1080×1080 using the same
pattern as `CardImageRenderer`. No new packages required. Photo bytes used locally only (extends ADR-002).

Decision 3: Smart timing via `AppOpenTracker` in SharedPreferences. No server-side scheduling.
Falls back to 9 AM if no usage signal. Stored as Unix timestamp, compared at scheduling time.

Decision 4: Post-scan pulse uses existing `todaysMemoriesProvider`; shown via `showModalBottomSheet`
after discovery overlay sequence to avoid interrupting celebration animations.

---

## Acceptance criteria

- [ ] Compact card shows question text, not the answer
- [ ] Tapping "Reveal ▸" opens the reveal sheet
- [ ] Reveal sheet shows question phase first, answer hidden
- [ ] Tapping "Reveal" animates the hero image and metadata in
- [ ] Share button generates and opens share sheet with a local card image
- [ ] Share card includes hero photo, country, date, branding; no uploads
- [ ] Notification title is question-style with 👀
- [ ] Notification scheduling respects `lastNotificationDate` — no same-day duplicates
- [ ] Smart timing: morning-user gets 8 AM, evening-user gets 6 PM
- [ ] Post-scan: up to 3 memory cards shown after scan summary + discovery overlay
- [ ] Post-scan pulse shown at most once per day
- [ ] All photo access is on-device only; no bytes leave the device
- [ ] `flutter analyze` clean; no regressions
