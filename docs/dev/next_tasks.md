# M39 — Achievement & Level-Up Commerce Triggers

**Goal:** After a country-count milestone or XP level-up, users are prompted to create a travel card — driving commerce through emotional peak moments.

---

## Scope

**Included:**
- `LevelUpRepository` — SharedPreferences-backed, tracks last shown level (default 1)
- `LevelUpSheet` — celebratory modal shown when user reaches a new XP level during/after scan
- Wire level-up check into `ScanSummaryScreen` (after milestone check, before `onDone`)
- "Create a travel card" CTA added to `MilestoneCardSheet` → navigates to `CardGeneratorScreen`

**Excluded:**
- Level-up triggers from non-scan paths (share, manual add) — scan is the primary emotional peak
- Commerce CTA on `AchievementUnlockSheet` — deferred to M40
- Variant/product selection directly from level-up or milestone sheets — card creation is the gateway per Phase 13b strategy

---

## Tasks

### Task 137 — LevelUpRepository + LevelUpSheet widget

**Deliverable:**
- `apps/mobile_flutter/lib/data/level_up_repository.dart` — `LevelUpRepository` stores `lastShownLevel` (int, default 1) in SharedPreferences key `level_up_shown_v1`; methods: `getLastShownLevel()` and `markShown(int level)`
- `apps/mobile_flutter/lib/features/scan/level_up_sheet.dart` — `LevelUpSheet` widget
  - Constructor: `LevelUpSheet({required String levelLabel})`
  - Static convenience: `LevelUpSheet.show(BuildContext context, {required String levelLabel})`
  - Layout: level emoji (mapped from label) + "You're now a [levelLabel]!" headline + subtext + buttons
  - "Create a travel card" `FilledButton` → pops sheet, pushes `CardGeneratorScreen`
  - "Later" `TextButton` → pops sheet
- `levelUpRepositoryProvider` registered in `apps/mobile_flutter/lib/core/providers.dart`
- Unit tests: `apps/mobile_flutter/test/data/level_up_repository_test.dart`

**Level emoji map (defined in `level_up_sheet.dart`):**
- Traveller → 🌱
- Explorer → 🧭
- Navigator → 🗺️
- Globetrotter → ✈️
- Pathfinder → 🌍
- Voyager → ⚓
- Pioneer → 🔭
- Legend → 🏆

**Acceptance criteria:**
- `LevelUpRepository.getLastShownLevel()` returns 1 when no key exists
- `markShown(3)` persists; `getLastShownLevel()` subsequently returns 3
- `LevelUpSheet` renders level emoji + headline + both buttons
- Tests pass: `flutter test apps/mobile_flutter/test/data/level_up_repository_test.dart`

---

### Task 138 — Wire level-up check into ScanSummaryScreen

**Deliverable:**
- `_checkAndShowLevelUp(VoidCallback next)` method in `ScanSummaryScreen`
  - Reads `xpNotifierProvider.state.level` for current level
  - Reads `levelUpRepositoryProvider.getLastShownLevel()` for last shown level
  - If `currentLevel > lastShownLevel`: calls `markShown(currentLevel)`, shows `LevelUpSheet`, then calls `next`
  - Otherwise calls `next` directly
- Update `_handleDone` call chain:
  `_checkAndShowMilestone(() => _checkAndShowLevelUp(() => _pushDiscoveryOverlays()))`
- Update `_handleCaughtUp` call chain:
  `_checkAndShowMilestone(() => _checkAndShowLevelUp(widget.onDone))`
- Widget tests: `apps/mobile_flutter/test/features/scan/level_up_sheet_test.dart`
  - `LevelUpSheet` displays correct headline for each level label
  - "Later" button dismisses

**Acceptance criteria:**
- When `xpState.level > lastShownLevel`, `LevelUpSheet` shown before discovery overlays / `onDone`
- When `xpState.level == lastShownLevel`, no sheet shown
- Level is marked shown before the sheet appears
- Existing scan summary tests continue to pass

---

### Task 139 — Add commerce CTA to MilestoneCardSheet

**Deliverable:**
- `MilestoneCardSheet` gains `onCreateCard: VoidCallback?` optional parameter
- `showMilestoneCardSheet` gains `onCreateCard: VoidCallback?` optional parameter; passes through to widget
- If `onCreateCard != null`, a "Create a travel card" `FilledButton` shown above the Share button
- In `ScanSummaryScreen._checkAndShowMilestone()`, pass `onCreateCard` that pops the sheet and pushes `CardGeneratorScreen`

**Acceptance criteria:**
- `MilestoneCardSheet` renders "Create a travel card" button when `onCreateCard` is non-null
- `MilestoneCardSheet` renders without the button when `onCreateCard` is null (backward-compatible)
- Tapping "Create a travel card" invokes `onCreateCard` callback

---

## Dependencies

- Task 137 before Task 138 (repository + widget required before wiring)
- Task 139 is independent of 137/138

## Risks

- **XP state at mount time:** XP is awarded in `ScanScreen` before navigating to `ScanSummaryScreen`, so `xpNotifierProvider.state.level` reflects the post-scan level. The SharedPreferences `lastShownLevel` comparison is therefore reliable.
- **Navigator context in sheet callbacks:** Using `onCreateCard` callback passed from `ScanSummaryScreen` (not from inside the sheet widget) ensures the correct navigator context is used.
