# T4 — Widget Tests

**Status:** Complete — 2026-06-03
**Depends on:** T1, T2, T3 complete (service coverage ≥ 70%)

## Goal

Achieve 40%+ coverage of UI components, prioritising screens in the critical revenue and onboarding workflows. Detect UI regressions before they reach users.

---

## Why Widget Tests Have a Lower Target

Widget tests are inherently more coupled to implementation detail than unit tests. A layout refactor that produces an identical user experience can break a widget test that was asserting on an intermediate widget type. The 40% target is deliberately conservative — it means every critical screen is covered, but peripheral and low-stakes screens are not forced into coverage. Quality over quantity.

---

## Standard Test Setup

```dart
Widget buildTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

// In testWidgets:
await tester.pumpWidget(
  buildTestApp(
    MerchCartScreen(),
    overrides: [
      cartRepositoryProvider.overrideWithValue(fakeCartRepository),
    ],
  ),
);
await tester.pumpAndSettle();
```

Use `ProviderScope(overrides: [...])` to inject controlled test state. Do not rely on real providers. Do not make real network calls.

Platform channel calls must be stubbed using `TestDefaultBinaryMessengerBinding` where the widget under test triggers them.

---

## Tasks

### T4.1 — Merch: Cart screen (Priority 1 — Critical revenue)

**New or extend:** `test/features/merch/merch_cart_screen_test.dart`

Cover:
- Cart renders all items with correct name, quantity, and price
- Quantity increment button increases displayed count
- Quantity decrement to zero removes item from list
- Remove button removes item immediately
- Total line reflects item changes
- "Checkout" button is visible when cart is non-empty
- "Checkout" button is absent or disabled when cart is empty
- Empty cart shows empty state message

---

### T4.2 — Merch: Customisation sheet (Priority 1)

**New or extend:** `test/features/merch/merch_customisation_sheet_test.dart`

Cover:
- Colour picker chips are rendered
- Tapping a colour chip updates the selected colour indicator
- Layout toggle (if present) switches between layout options
- Preview area updates after colour change
- "Apply" or equivalent CTA is tappable

---

### T4.3 — Merch: Country selection screen (Priority 1)

**New or extend:** `test/features/merch/merch_country_selection_screen_test.dart`

Cover:
- Country list renders with correct country names
- Tapping a country toggles its selected state (checkbox or highlight)
- Selection count badge updates as countries are toggled
- "Continue" button is enabled only when at least one country is selected
- Deselecting all countries disables "Continue"

---

### T4.4 — Merch: Variant screen (Priority 1)

**New or extend:** `test/features/merch/merch_variant_screen_test.dart`

Cover:
- Size options are rendered
- Colour options are rendered
- "Add to Cart" is enabled only when both size and colour are selected
- Selecting size and colour enables "Add to Cart"
- Tapping "Add to Cart" calls the expected repository method

---

### T4.5 — Scan: Scan screen (Priority 2)

**New or extend:** `test/features/scan/scan_screen_test.dart`

Cover (with photo scan channel stubbed):
- "Scan my photos" button is present before scan starts
- Tapping the button triggers the channel call (verify via stub)
- Progress indicator appears during scan
- Completion state shows country count
- Scan error state shows error message

---

### T4.6 — Scan: Scan summary screen (Priority 2)

**New or extend:** `test/features/scan/scan_summary_screen_test.dart`

Cover:
- Country count is displayed correctly for fixture data
- New countries are visually distinguished from previously known ones
- "View map" CTA is present
- "Done" CTA is present
- Zero new countries shows the correct empty-delta message

---

### T4.7 — Challenge: Daily challenge screen (Priority 2)

**New or extend:** `test/features/challenge/daily_challenge_screen_test.dart`

Cover:
- First clue is visible on load
- "Reveal next clue" button appears before all clues are shown
- Tapping "Reveal next clue" shows the next clue
- After all clues are revealed, the reveal button is absent
- Guess input field accepts text
- Submitting a correct guess shows the success result
- Submitting a wrong guess shows the "try again" feedback
- Solved state shows the correct site name and score

---

### T4.8 — Achievements: Achievements screen (Priority 2)

**New or extend:** `test/features/stats/achievements_screen_test.dart`

Cover:
- Locked achievements are visually distinct from unlocked ones
- Unlocked achievement shows the badge and unlock date
- Progress bar is rendered for achievements with a count target
- Correct achievement count is displayed in the header

---

### T4.9 — Onboarding: Onboarding flow (Priority 3 — extend existing)

**Edit:** nearest existing onboarding test

Add:
- First step is visible on launch
- "Next" button advances to the next step
- Final step shows the "Scan my photos" CTA
- Back navigation returns to the previous step

---

### T4.10 — Auth: Sign-in screen (Priority 3 — extend existing)

**Edit:** nearest existing auth test

Add:
- "Sign in with Apple" button is present
- "Continue without signing in" (anonymous) option is present
- Tapping Apple sign-in triggers the auth flow (stub the sign-in call)

---

### T4.11 — Shell: Main navigation (Priority 3)

**New or extend:** `test/features/shell/main_shell_test.dart`

Cover:
- Bottom navigation bar renders with the correct tab labels
- Tapping the Map tab shows the map screen area
- Tapping the Stats tab shows the stats screen area
- Active tab indicator is on the correct tab after selection

---

### T4.12 — Map: Map screen + country detail (Priority 3)

**New or extend:** `test/features/map/map_screen_test.dart`

Cover (globe rendering stubbed where necessary):
- Map widget renders without error with a fixture visit set
- Tapping a visited country opens the country detail sheet
- Country detail sheet shows country name and flag
- Country detail sheet shows the first visit date

---

## File Map

```
test/
  features/
    merch/
      merch_cart_screen_test.dart                NEW
      merch_customisation_sheet_test.dart        NEW
      merch_country_selection_screen_test.dart   NEW
      merch_variant_screen_test.dart             NEW
    scan/
      scan_screen_test.dart                      NEW
      scan_summary_screen_test.dart              NEW
    challenge/
      daily_challenge_screen_test.dart           NEW
    stats/
      achievements_screen_test.dart              NEW
    onboarding/
      onboarding_flow_test.dart                  EDIT — extend
    auth/
      sign_in_screen_test.dart                   EDIT — extend
    shell/
      main_shell_test.dart                       NEW
    map/
      map_screen_test.dart                       NEW
```

---

## Definition of Done

- [ ] UI component coverage ≥ 40% (verify with `make coverage`).
- [ ] Overall application coverage ≥ 50% (verify with `make coverage`).
- [ ] All 12 task areas have widget tests added or extended.
- [ ] `flutter test` exits with zero failures after each task area.
- [ ] No widget test triggers a real network call, Firestore write, or Printful call.
- [ ] Platform channel is stubbed in any test that exercises the scan screen.
- [ ] Providers are overridden with controlled test values; no real providers in widget tests.
- [ ] No production Firebase, real payment flow, or live Printful endpoint was used.
