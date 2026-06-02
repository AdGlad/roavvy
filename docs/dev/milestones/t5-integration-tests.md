# T5 — Integration Tests

**Depends on:** T1–T4 complete (overall coverage ≥ 50%, all unit/service/widget tests passing)

## Goal

Validate eight critical end-to-end user journeys through the complete running Flutter application against mocked backends. Catch journey-level regressions that individual layer tests cannot detect.

---

## Why Integration Tests Are a Separate Phase

Widget tests validate components in isolation. Integration tests validate that components connect correctly — that navigation works, that state flows across screens, that a user completing a multi-screen journey arrives at the correct outcome. A bug in a Riverpod provider wiring or a navigation route can be invisible to widget tests but immediately obvious in an integration test.

Integration tests run on a simulator, not in the Dart VM. They are slower — a single journey may take 10–30 seconds. The suite is therefore small by design: eight carefully chosen journeys, not exhaustive coverage.

---

## Setup Tasks

### T5.0 — Create integration_test infrastructure

**New directory:** `apps/mobile_flutter/integration_test/`

**New file:** `integration_test/app_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roavvy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Roavvy integration tests', () {
    setUp(() async {
      // Inject test configuration:
      // - Firebase emulator or fake
      // - Stub photo scan channel
      // - Clear local database
    });

    // Journey tests go here (T5.1–T5.8)
  });
}
```

**Stub the photo scan channel** in test setup:

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('roavvy/photo_scan'),
  (MethodCall call) async {
    if (call.method == 'startScan') {
      return kFixtureScanResults; // JSON from test/fixtures/visits/
    }
    return null;
  },
);
```

**Define `kFixtureScanResults`** as a constant in `integration_test/fixtures/scan_fixture.dart` using the `multi_continent_30_countries.json` fixture.

---

## Journey Tests

### T5.1 — New user onboarding → first scan → map (Priority 1)

**Screens:** Onboarding → Scan → Scan Summary → Map

Steps:
1. App launches; onboarding first step is visible.
2. Tap "Next" through all onboarding steps.
3. Tap "Scan my photos" on the final step.
4. Stub returns fixture scan results.
5. Scan summary shows the correct country count from the fixture.
6. Tap "View map".
7. Map screen is visible.
8. Visited country polygons are present.

---

### T5.2 — Daily challenge: guess → result (Priority 1)

**Screens:** Daily Challenge → Clue reveals → Guess → Result → Stats

Steps:
1. Navigate to the Daily Challenge tab.
2. First clue is visible.
3. Tap "Reveal next clue" twice more (3 clues shown).
4. Enter a wrong guess; "incorrect" feedback appears.
5. Enter the correct answer; success state appears.
6. Tap "See my stats".
7. Challenge stats screen shows streak incremented by 1.

---

### T5.3 — Scan → achievement unlock → stats (Priority 1)

**Screens:** Scan → Achievement Unlock Sheet → Stats Screen

Setup: fixture scan data that triggers at least one achievement qualification.

Steps:
1. Trigger a scan using the fixture data.
2. Scan summary appears.
3. Achievement unlock sheet appears (or navigate to achievements).
4. Achievement name and badge are visible.
5. Dismiss the sheet.
6. Navigate to Stats → Achievements.
7. The unlocked achievement is marked as unlocked.

---

### T5.4 — Merchandise creation → cart (Priority 1 — Critical revenue)

**Screens:** Merch Shop → Country Selection → Customisation → Variant → Cart

Steps:
1. Navigate to the merch shop entry point.
2. Country selection screen shows visited countries.
3. Select 3 countries; count badge shows 3.
4. Tap "Continue".
5. Customisation sheet opens; select a colour.
6. Tap "Apply" or equivalent.
7. Variant screen opens; select a size and colour.
8. Tap "Add to Cart".
9. Cart screen opens; item is present with correct details.
10. Total is non-zero.

---

### T5.5 — Cart → checkout handoff (Priority 1 — Critical revenue)

**Screens:** Cart → Checkout (Printful call mocked)

Setup: Cart pre-populated via fixture; Printful HTTP call mocked to return a fixture checkout URL.

Steps:
1. Cart screen has one item.
2. Tap "Checkout".
3. Checkout URL is opened (verify the URL open call is made with the correct fixture URL).
4. Order confirmation screen appears (or app returns to a post-checkout state).

---

### T5.6 — Manual visit edit → saved on map (Priority 2)

**Screens:** Map → Country Detail → Visit Edit → Saved

Steps:
1. Map shows visited countries from fixture.
2. Tap a visited country.
3. Country detail sheet opens with correct country name.
4. Tap "Edit" or navigate to the visit edit sheet.
5. Remove the country.
6. Confirm the removal.
7. Map no longer shows that country's polygon as visited.

---

### T5.7 — Travel card share (Priority 2)

**Screens:** Stats → Card Selection → Share Sheet

Steps:
1. Navigate to Stats.
2. Tap "Create travel card" or equivalent.
3. Card type picker is visible.
4. Select a card type.
5. Card preview is rendered.
6. Tap "Share".
7. Share sheet is triggered (verify via share plugin call stub).

---

### T5.8 — Account deletion → signed out → onboarding (Priority 2)

**Screens:** Settings → Delete Account → Confirmation → Onboarding

Steps:
1. Navigate to Settings.
2. Tap "Delete account".
3. Confirmation dialog appears.
4. Confirm deletion.
5. Auth is signed out.
6. App returns to the onboarding screen.
7. No user data is visible.

---

## Running Integration Tests

```bash
# From apps/mobile_flutter/
# Boot an iOS simulator first, then:
flutter test integration_test/app_test.dart
```

For CI (macOS runner required for iOS simulator):

```yaml
- name: Run integration tests
  run: flutter test integration_test/app_test.dart
  working-directory: apps/mobile_flutter
```

---

## File Map

```
apps/mobile_flutter/
  integration_test/
    app_test.dart                    NEW — test entry point + all 8 journeys
    fixtures/
      scan_fixture.dart              NEW — kFixtureScanResults constant
```

---

## Definition of Done

- [ ] All 8 journey tests pass on iOS simulator.
- [ ] `integration_test/app_test.dart` runs via `flutter test integration_test/` without manual setup beyond simulator boot.
- [ ] Photo scan channel is stubbed; no real photo library access occurs.
- [ ] Firebase is replaced with emulator or fakes; no production Firestore is written.
- [ ] Printful HTTP calls are mocked; no real Printful endpoint is called.
- [ ] CI macOS runner runs the integration tests on each pull request.
- [ ] All existing unit, service, and widget tests still pass after this milestone.
- [ ] No production Firebase, real payment flow, or live Printful endpoint was used.
