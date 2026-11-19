# M189 — Release candidate 1.0 (commerce off) → TestFlight → App Store

**Phase:** Free Launch (M184–M189)
**Depends on:** M184–M188
**Status:** Todo
**Primary target:** release build · `apps/mobile_flutter` · CI

---

## 1. Why this exists

This milestone turns the commerce-off app into a build Apple accepts, and clears the
stabilisation debt found in the 2026-11-20 state review.

## 2. Tasks

- **T1 Release build guard.** Add `scripts/build_ios_release.sh`. It builds with the release
  defines and **fails** in any of these cases:
  - `ROAVVY_COMMERCE`, `STUDIO_V2` or `STUDIO_V2_TRACE` is set;
  - the target is not `lib/main.dart`.
  Add a `kReleaseMode` assert in `main.dart` that `kStudioV2Enabled` is false.
- **T2 Strip dev instrumentation.**
  - Remove `[v2trace]`: `studio_v2_trace.dart` plus its calls in `studio_v2_app`,
    `studio_v2_screen`, `garment_preview`, `shirt_preview` and `studio_v2_entry`.
  - Revert the dev-aids commit noted in the device-build memory.
- **T3 Test suite green.** 41 Studio V2 widget tests fail because they look up stage tabs
  (`v2-stage-direction`, …) that the M11 Instant redesign removed. Studio isn't shipping, but
  the suite must be green for CI to mean anything. Rewrite them against the current flow, or
  delete them if the newer end-to-end tests already cover the behaviour. Run the whole suite in
  both modes (`ROAVVY_COMMERCE` on and off).
- **T4 Device QA** on a physical iPhone, release config, commerce off. Covers:
  - fresh install → onboarding → photo permission → scan;
  - map, stats, achievements, cards share, journal, Year in Review, replay;
  - account sign-in and deletion;
  - notifications;
  - App Check / App Attest verified with no 403.
- **T5 Version and ship.**
  - Bump `pubspec` to `1.0.0+<build>`.
  - Archive and upload to TestFlight.
  - Internal testers for ≥ 3 days, Crashlytics clean.
  - Submit for review with the M188 metadata.
- **T6 Docs.** Rewrite `docs/dev/current_state.md` (last updated M162) to describe the shipped
  1.0 and the commerce flag.

## 3. Acceptance

- [ ] The release script refuses a commerce or dev build.
- [ ] `flutter analyze` reports 0 errors and `flutter test` passes in both modes.
- [ ] The TestFlight build passes the full QA walk on a device.
- [ ] Submitted to App Review.
