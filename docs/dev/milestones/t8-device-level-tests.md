# T8 — Device-Level Tests

**Depends on:** T1–T7 complete (CI quality gates active, all tests passing on every PR)**
**Trigger:** Release candidate only (`v*.*.*-rc.*` tag). Not required on every PR.**

## Goal

Validate real-device behaviour that cannot be confirmed in the Dart VM or on a simulator: iOS photo library permission flows, real photo scanning with GPS-tagged fixture images, platform channel reliability under load, and rendering performance.

---

## Why Device Tests Come Last

Every earlier phase can run on CI without physical hardware. Device tests require real iOS devices, real iOS permission dialogs, and real PhotoKit behaviour. They are expensive to run and slow to iterate on. They are reserved for the question that only a real device can answer: *does the complete production stack work on the hardware a real user will hold?*

Device tests gate release candidate submissions, not individual pull requests.

---

## Setup Tasks

### T8.0 — Configure Firebase Test Lab

1. Enable Firebase Test Lab in the `roavvy-prod` Firebase project.
2. Create a service account with `Firebase Test Lab Admin` role.
3. Add the service account JSON as a GitHub Actions secret: `FIREBASE_TEST_LAB_SA`.
4. Identify the target device matrix (minimum: iPhone 15, iOS 17).

**Edit:** `.github/workflows/device_tests.yml` (new file — see T8.5)

---

### T8.1 — Prepare GPS-tagged fixture photo library

Real photo scanning requires real photos with known GPS coordinates embedded in EXIF metadata.

**New directory:** `integration_test/device/fixtures/photos/`

Create 10–20 JPEG images with embedded GPS coordinates spanning at least 5 countries. Each image must be:
- Minimal file size (1×1 pixel is sufficient — only EXIF metadata matters)
- GPS coordinates known and documented in `integration_test/device/fixtures/photo_manifest.json`
- Named `{countryCode}_{index}.jpg` for clarity

```json
// photo_manifest.json
{
  "photos": [
    { "file": "GB_1.jpg", "lat": 51.5, "lng": -0.1, "expectedCountry": "GB" },
    { "file": "FR_1.jpg", "lat": 48.8, "lng": 2.3, "expectedCountry": "FR" },
    { "file": "JP_1.jpg", "lat": 35.7, "lng": 139.7, "expectedCountry": "JP" }
  ]
}
```

These images are used to seed the device's photo library before each test run.

---

### T8.2 — Photo library permission flow

**New file:** `integration_test/device/permission_test.dart`

Test 1 — Permission prompt appears:
1. Fresh install (or cleared data).
2. Tap "Scan my photos".
3. Verify the iOS photo library permission dialog appears.

Test 2 — Denial is handled gracefully:
1. Deny photo library access.
2. Verify the app shows an appropriate explanation, not a crash.
3. Verify the "Scan" button remains available (to retry permission).

Test 3 — Full access enables scan:
1. Grant full photo library access.
2. Tap "Scan my photos".
3. Verify the scan begins (progress indicator appears).

---

### T8.3 — Scan pipeline end-to-end with fixture photos

**New file:** `integration_test/device/scan_pipeline_test.dart`

Prerequisites: Fixture photos are loaded into the device's photo library before the test runs.

Test 1 — Correct country codes from known GPS:
1. Trigger a scan.
2. After completion, verify the detected country set matches the known countries from the fixture manifest.
3. No extra countries appear; no expected country is missing.

Test 2 — Re-scan deduplication:
1. Trigger a scan.
2. Trigger a second scan with the same photo library.
3. Verify the visit count has not increased (deduplication works).
4. Verify no duplicate rows exist in the local database.

---

### T8.4 — Platform channel reliability under load

**New file:** `integration_test/device/channel_reliability_test.dart`

Test 1 — Large batch completes within time limit:
1. Load 2,000 photos into the device library (or use a test library with 2,000 images).
2. Trigger a scan.
3. Verify the scan completes within 60 seconds.
4. Verify no channel timeout or partial result.

Test 2 — Channel delivers all results:
1. Known fixture: 50 photos, 10 countries.
2. Trigger a scan.
3. Verify exactly the 10 expected country codes are returned.
4. Run 3 consecutive times; verify the same result every time.

---

### T8.5 — Globe rendering performance

**New file:** `integration_test/device/rendering_test.dart`

Test 1 — Globe renders at acceptable frame rate:
1. Navigate to the Map screen with 30+ visited countries loaded.
2. Apply a rotation gesture.
3. Record frame times for 5 seconds of gesture input.
4. Verify fewer than 5% of frames exceed 16.7ms (60fps threshold).

Test 2 — No jank on country tap:
1. Navigate to the Map screen.
2. Tap a visited country polygon.
3. Verify the country detail sheet opens within 500ms.
4. Verify no dropped frame is recorded during the tap-to-open transition.

---

### T8.6 — Notification permission

**New file:** `integration_test/device/notification_test.dart`

Test 1 — Notification permission prompt at correct moment:
1. Complete a first scan.
2. Dismiss the scan summary.
3. Verify the notification permission dialog appears at the configured trigger point.

Test 2 — Daily challenge notification is scheduled:
1. Complete the daily challenge.
2. Verify a local notification is scheduled for the next day via the notifications framework.

---

### T8.7 — CI device test workflow

**New file:** `.github/workflows/device_tests.yml`

```yaml
name: Device Tests (Release Candidate)

on:
  push:
    tags:
      - 'v*.*.*-rc.*'

jobs:
  device-tests:
    name: Firebase Test Lab
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Build integration test IPA
        working-directory: apps/mobile_flutter
        run: |
          flutter build ios integration_test/device/
          # Package as XCTest bundle for Firebase Test Lab

      - name: Authenticate with Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.FIREBASE_TEST_LAB_SA }}

      - name: Run on Firebase Test Lab
        run: |
          gcloud firebase test ios run \
            --type xctest \
            --test integration_test/device/ \
            --device model=iphone15,version=17,locale=en_GB \
            --timeout 10m
```

---

## File Map

```
integration_test/device/
  fixtures/
    photos/
      GB_1.jpg                         NEW — 1×1 pixel, GPS in EXIF
      FR_1.jpg                         NEW
      JP_1.jpg                         NEW
      (... additional country fixtures)
    photo_manifest.json                NEW — GPS → expected country mapping
  permission_test.dart                 NEW — T8.2
  scan_pipeline_test.dart              NEW — T8.3
  channel_reliability_test.dart        NEW — T8.4
  rendering_test.dart                  NEW — T8.5
  notification_test.dart               NEW — T8.6

.github/workflows/
  device_tests.yml                     NEW — T8.7 (triggers on rc tags only)
```

---

## Definition of Done

- [ ] All 5 test files pass on at least one physical iPhone (iPhone 15 or later, iOS 17+).
- [ ] Scan pipeline test produces the correct country set from fixture photos.
- [ ] Re-scan deduplication produces no extra rows.
- [ ] 2,000-photo scan completes within 60 seconds.
- [ ] Globe frame rate ≥ 60fps (< 5% frames dropped) on the target device.
- [ ] `device_tests.yml` workflow triggers on release candidate tags.
- [ ] Firebase Test Lab is configured and the service account is in GitHub secrets.
- [ ] No production Firestore, real payment flow, or live Printful endpoint was used.
- [ ] All tests pass before every App Store or TestFlight submission.
