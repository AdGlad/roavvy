# M29 — Mobile Commerce: Entry Points + Scan Nudge

**Milestone:** 29
**Phase:** 12 — Commerce & Mobile Completion
**Goal:** Users encounter the shop at peak motivation moments and are nudged back when they haven't scanned in 30+ days.

---

## Scope

**Included:**
- Scan summary State A: "Get a poster with your new discoveries" CTA → `MerchCountrySelectionScreen` pre-filtered to new codes only
- Map screen overflow menu: "Get a poster" item → `MerchCountrySelectionScreen` (all countries)
- Map screen: dismissible amber nudge banner when `lastScanAt > 30 days ago`; "Scan now" navigates to Scan tab; dismissed per-session

**Excluded:**
- Changes to `scheduleNudge` push notification (already exists in `NotificationService`)
- Travel card share screen changes (share happens via OS share sheet; CTA is in the overflow menu)
- Web changes

---

## Tasks

### Task 111 — Scan summary "Get a poster" CTA (State A)

**Deliverable:**
- `MerchCountrySelectionScreen` accepts optional `preSelectedCodes: List<String>?`; when set, only those codes start selected (all others are deselected)
- `_NewDiscoveriesState` shows a `TextButton` "Get a poster with your new discoveries →" above the primary "Explore your map" button
- Tapping navigates to `MerchCountrySelectionScreen(preSelectedCodes: widget.newCodes)`

**Acceptance criteria:**
- `MerchCountrySelectionScreen(preSelectedCodes: ['GB', 'FR'])` starts with only GB and FR checked; all other effective visits are unchecked
- `MerchCountrySelectionScreen()` (no param) behaves exactly as before — all countries checked
- The "Get a poster" TextButton is visible on `_NewDiscoveriesState` above the "Explore your map" FilledButton
- `flutter analyze` zero issues; existing merch tests pass

---

### Task 112 — Map "Get a poster" overflow menu entry

**Deliverable:**
- `_MapMenuAction` enum gains a `shop` value
- `PopupMenuItem` "Get a poster" (icon: `Icons.shopping_bag_outlined`) added to the MapScreen overflow menu
- Shown only when `hasVisits` is true
- Positioned after "Share travel card" and before "Clear travel history"
- Tapping pushes `MerchCountrySelectionScreen()` (all countries, normal flow)

**Acceptance criteria:**
- "Get a poster" menu item appears when user has visited countries
- "Get a poster" menu item does not appear when `hasVisits` is false
- Tapping navigates to `MerchCountrySelectionScreen`
- Existing map screen menu items unaffected
- `flutter analyze` zero issues

---

### Task 113 — Map 30-day scan nudge banner

**Deliverable:**
- `lastScanAtProvider = FutureProvider<DateTime?>` in `providers.dart`; reads `visitRepositoryProvider.loadLastScanAt()`
- `scanNudgeDismissedProvider = StateProvider<bool>((ref) => false)` in `providers.dart`; not persisted (resets on app restart)
- In `MapScreen.build()`, show a dismissible amber banner when all of: `hasVisits`, `lastScanAt != null`, `DateTime.now().difference(lastScanAt) >= const Duration(days: 30)`, and `!dismissed`
- Banner: amber background, text "It's been a while — time for a new scan", "Scan now" TextButton (calls `onNavigateToScan?.call()`), X `IconButton` (sets `scanNudgeDismissedProvider` to `true`)
- Banner is a `Positioned` widget inside the existing MapScreen Stack, anchored at the bottom just above the `StatsStrip` area

**Acceptance criteria:**
- Banner shown when `hasVisits && lastScanAt` is 30+ days ago and not dismissed
- Banner not shown when `lastScanAt` is < 30 days ago
- Banner not shown when `hasVisits` is false
- Tapping "Scan now" navigates to Scan tab
- Tapping X hides the banner for the session; does not reappear until app restart
- `flutter analyze` zero issues; map screen widget tests pass

---

## Dependencies

- Task 111 depends on: `MerchCountrySelectionScreen` (already built, M20)
- Task 112 depends on: `MapScreen` overflow menu (already built)
- Task 113 depends on: `VisitRepository.loadLastScanAt()` (already built, used in `ScanScreen`); `onNavigateToScan` callback (already wired via `MainShell`)
- All three tasks are independent of each other and can be built in any order

---

## Risks / Open Questions

1. **`preSelectedCodes` + `effectiveVisitsProvider`**: `MerchCountrySelectionScreen` derives its country list from `effectiveVisitsProvider`. `preSelectedCodes` may contain codes no longer in `effectiveVisitsProvider` (e.g. user deleted history between scan and tapping the CTA). Guard: filter `preSelectedCodes` against the loaded visits list before applying; silently drop unknown codes.
2. **Nudge banner Z-order**: The MapScreen Stack has several Positioned children (XpLevelBar, StatsStrip, RovyBubble, TimelineScrubberBar). Ensure the nudge banner does not overlap RovyBubble or StatsStrip. Position it with sufficient bottom offset to clear the StatsStrip.
3. **`onNavigateToScan` may be null** in tests: guard with `?.call()` — already the convention in MapScreen.
