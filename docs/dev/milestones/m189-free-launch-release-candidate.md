# M189 — Release candidate 1.0 (commerce off) → TestFlight → App Store

**Phase:** Free Launch (M184–M189)
**Depends on:** M184–M188
**Status:** In progress (T1–T3, T6 done; T4–T5 need the owner and a device)
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

- [x] The release script refuses a commerce or dev build.
- [x] `flutter analyze` reports 0 errors and `flutter test` passes in both modes.
- [ ] The TestFlight build passes the full QA walk on a device.
- [ ] Submitted to App Review.

## 4. As built (2026-11-20, branch `feat/m189-release-hardening`)

- **T1** `54fff3a2`: `scripts/build_ios_release.sh` (checked with `--dry-run`: clean args pass;
  `ROAVVY_COMMERCE`, `STUDIO_V2`, env `STUDIO_V2_TRACE`, `-t lib/main_studio_v2.dart`, `--debug`
  are each refused). `main.dart` throws in release if `STUDIO_V2` is set (a real check, since
  `assert` is stripped in release).
- **T2** `54fff3a2`: removed the `kDebugMode` auth-gate bypass and `/dev/quokka` route from
  `app.dart` (manual revert of `8bf74e38`; the globe default was already restored and the
  dev FAB already gone). `QuokkaPreviewScreen` is now unused but kept. Removed
  `studio_v2_trace.dart` and every `v2trace`/`v2bump` call.
- **T3** `8fc6ba7b`: 55 failures → 0, in both modes (2405 pass commerce off, 2404 + 1 skip on).
  Deleted 7 Studio V2 files (40 tests) that tapped removed stage tabs; the `*_customise` and
  `review_buy` tests cover the current flow. Dropped one stage-navigation case in
  `startup_idle_test`. `merch_variant_screen_test` gets a ProviderScope with stubbed prices
  (13). `merch_template_ranker_test` follows the deliberate grid-first change (1).
- **Extra** `5201b1be`: the replay summary's Share button showed "Share coming soon"; it is now
  hidden (App Review 2.1 risk).
- **T6**: `docs/dev/current_state.md` rewritten for 1.0 and the commerce flag.

## 5. Owner steps left

1. **T4 device QA** on a physical iPhone, release build from `scripts/build_ios_release.sh`.
   Walk the list in T4 above; confirm App Attest gives no 403 and that a network capture of a
   full session shows no `getMerchPrices` / `createMerchCart` / Shopify calls.
2. **T5** `scripts/build_ios_release.sh --build-number <n>` (pubspec is already `1.0.0+1`) →
   upload with Transporter or Xcode Organizer → TestFlight internal ≥ 3 days, Crashlytics clean →
   submit with `docs/product/app_store_listing_v1.md`.
3. Before submitting: M187 prod functions deploy, M188 sign-off and website deploy.
