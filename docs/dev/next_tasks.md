# Roavvy — Task History & Active Milestone

## Completed tasks

| Task | Name | Milestone | Key ADRs |
|------|------|-----------|----------|
| 1 | Build `packages/country_lookup` | 1–5 | ADR-004, ADR-009 |
| 2 | Replace SharedPreferences with Drift SQLite | 1–5 | ADR-003, ADR-011 |
| 3+4 | Swift EventChannel streaming + background isolate | 1–5 | ADR-010, ADR-013 |
| 5 | Migrate to typed domain model; retire `CountryVisit` | 1–5 | ADR-008 |
| 6 | Expose polygon geometry from `country_lookup` | 6 | ADR-017 |
| 7 | `MapScreen`: world map polygon rendering | 6 | ADR-014, ADR-015 |
| 8 | Country tap → detail bottom sheet | 6 | ADR-019, ADR-020 |
| 9 | Bottom nav shell; Riverpod providers; rename to `RoavvyApp` | 6 | ADR-018, ADR-021 |
| 10 | Travel stats strip on map screen | 6 | — |
| 11 | Permission state handling in `ScanScreen` | 7 | — |
| 12 | Incremental scan via `sinceDate` + Drift metadata table | 7 | ADR-012, ADR-022 |
| 13 | Post-scan result summary ("nothing new" state) | 7 | ADR-024 |
| 14 | Delete travel history | 7 | ADR-025 |
| 15 | Map empty state (first-use overlay) | 7 | — |
| 16 | Firebase SDK setup (`firebase_core`, `firebase_auth`) | 8 | ADR-026 |
| 17 | Anonymous auth on first launch + `authStateProvider` | 8 | ADR-027 |
| 18 | Sign in with Apple (credential upgrade) | 8 | ADR-028 |
| 19 | Firestore initial sync (push all dirty records on sign-in) | 8 | ADR-029, ADR-030 |
| 20 | Ongoing Firestore sync (flush dirty after each repository write) | 8 | ADR-030 |
| 21 | Startup dirty-row flush + explicit offline persistence | 8+ | ADR-031, ADR-032 |
| 22 | Achievement domain model + rules engine | 9 | ADR-034, ADR-035 |
| 23 | Achievement Drift persistence + repository | 9 | ADR-036 |
| 24 | Achievement evaluation at write sites + Firestore sync | 9 | ADR-037, ADR-038 |
| 25 | Achievement UI: stats strip count + unlock SnackBar | 9 | ADR-038 |
| 26 | Auth persistence: remove forced sign-out + add sign-out action | 9.5 | ADR-039 |
| 27 | Travel card widget | 10 | ADR-040 |
| 28 | Capture card as image + share via iOS share sheet | 10 | ADR-040 |
| 29 | Share token generation + Firestore write (Flutter) | 11 | ADR-041 |
| 30 | Web share page: data read + world map rendering | 11 | ADR-041 |
| 31 | Privacy settings screen + share token revocation | 12 | ADR-042, ADR-043 |
| 32 | Account deletion | 12 | ADR-042, ADR-043 |
| 33 | Firebase Auth JS SDK + `/sign-in` page (Google + Apple) | 13 | — |
| 34 | Authenticated `/map` route + Firestore effective-visits read | 13 | — |
| 35 | `effectiveVisits.ts` TypeScript merge logic | 13 | — |
| 36 | Firestore rules tightened to user-scoped reads | 13 | — |
| 37 | `TripRecord` + `TripInference` in `shared_models` | 15 | — |
| 38 | `trips` Drift table (schema v5) + `TripRepository` | 15 | — |
| 39 | Scan pipeline + `BootstrapService` produce `TripRecord`s | 15 | — |
| 40 | `TripEditSheet` — manual trip date editing | 15 | — |
| 41 | Trip count + trip list in `CountryDetailSheet` | 15 | — |
| 42 | Build `packages/region_lookup` | 16 | ADR-049, ADR-051 |
| 43 | Schema v7: PhotoDateRecord.regionCode + scan pipeline region resolution | 16 | ADR-051 |
| 44 | RegionVisit domain model + region_visits Drift table + RegionRepository | 16 | ADR-051 |
| 45 | Scan pipeline + bootstrap: produce RegionVisit records | 16 | ADR-051 |
| 46 | Region count + region list in CountryDetailSheet | 16 | ADR-019 |
| 47 | 4-tab `MainShell` (Map · Journal · Stats · Scan) | 17 | ADR-052 |
| 48 | `JournalScreen` — trip list grouped by year | 17 | ADR-052 |
| 49 | `StatsScreen` — stats panel + achievement gallery; `AchievementRepository.loadAllRows()`; `regionCountProvider` | 17 | ADR-052 |
| 50 | `OnboardingFlow` — 3-screen first-launch flow | 18 | ADR-053 |
| 51 | `ScanSummaryScreen` — post-scan discovery hero | 18 | ADR-054 |
| 52 | Confetti + row-stagger animation on scan summary | 18 | ADR-055 |
| 53 | `AchievementUnlockSheet` — replaces unlock SnackBar | 18 | ADR-054, ADR-055 |

---

## Milestone 18 — Phase 8: Celebrations & Delight (Mobile)

**Goal:** A first-time user experiences a guided onboarding; after every scan, a celebratory summary screen shows what was discovered.

**Scope — included:**
- Onboarding flow (3 screens, shown on first launch only)
- Scan summary screen: post-save hero showing new countries, new trips, achievements unlocked
- Country/continent celebration: confetti animation + sequential fade-in of new countries within scan summary
- Achievement unlock sheet: slide-up detail sheet replacing the current SnackBar; tappable from scan summary and Stats screen
- All animations respect `MediaQuery.disableAnimations` / `reduceMotion`

**Scope — excluded:**
- Map reveal animation (countries highlight one-by-one) — complex, deferred
- Animated globe for continent celebration — deferred
- Push notifications — Phase 9
- Onboarding illustrations / Lottie animations — Phase 9 polish

---

## Task 50 — Onboarding flow

**Milestone:** 18
**Phase:** 8 — Celebrations & Delight

**Why:** First-time users open the app to an empty map with no guidance. Without onboarding, the scan permission prompt appears with no context, and new users may deny it. Onboarding establishes the value proposition before asking for photo access.

**Deliverable:** `OnboardingFlow` widget (3 screens) shown once on first launch; `hasSeenOnboarding` flag persisted locally.

**Acceptance criteria:**
- [ ] Three screens in sequence: Welcome ("Your travels, automatically discovered"), How It Works ("Roavvy reads GPS from your existing photos — nothing is uploaded"), Scan CTA ("Ready? Scan your photos")
- [ ] Each screen has a title, body copy, a coloured illustration placeholder (`Container` with `colorScheme.primaryContainer`), and a primary `FilledButton` CTA
- [ ] "Skip" `TextButton` on all three screens; tapping it immediately sets `hasSeenOnboarding = true` and navigates to the Scan tab
- [ ] Final screen CTA sets `hasSeenOnboarding = true` and navigates to the Scan tab
- [ ] `hasSeenOnboarding` persisted via Drift `app_meta` table (single-row key/value, or a new `onboarding_complete` boolean column in `scan_metadata` — Architect to confirm)
- [ ] Onboarding is not shown on subsequent launches
- [ ] Onboarding is not shown if the user already has visits (returning user with data, edge case of reinstall)
- [ ] `dart analyze` reports zero issues
- [ ] 4+ widget tests: shown on first launch; not shown on subsequent launches; skip works; CTA navigates correctly

**Files to change:**
- `lib/features/onboarding/onboarding_flow.dart` — new
- `lib/data/db/roavvy_database.dart` — add `hasSeenOnboarding` persistence (Architect to specify schema change)
- `lib/app.dart` — route to `OnboardingFlow` on first launch instead of `MainShell`
- `test/features/onboarding/onboarding_flow_test.dart` — new

**Dependencies:** None. Independent — build first.

---

## Task 51 — Scan summary screen

**Milestone:** 18
**Phase:** 8 — Celebrations & Delight

**Why:** After a scan + review save, the app currently navigates directly to the Map with no acknowledgement of what was found. A dedicated scan summary screen makes the discovery moment explicit and celebratory — it is the core delight moment of the product.

**Deliverable:** `ScanSummaryScreen` shown after `ReviewScreen` save completes; replaces the direct navigate-to-Map.

**Acceptance criteria:**
- [ ] `ScanSummaryScreen` receives two parameters: `List<EffectiveVisitedCountry> newCountries`, `List<String> newAchievementIds` (IDs of achievements unlocked this scan)
- [ ] **New countries found variant**: hero stat "X countries discovered" (bold, large); list of new countries (flag emoji + name, one row each); achievements section (see Task 53 for sheet; here just show achievement titles as chips); "Explore your map" `FilledButton` → pop to Map tab (index 0)
- [ ] **Nothing new variant** (empty `newCountries`): copy "Nothing new this scan"; subtext showing last scan date; "Back to map" button
- [ ] If any new country is the user's first on a continent: continent callout banner "First country in [Continent]!" shown inline
- [ ] `ReviewScreen` computes the delta: countries in `newCountries` = countries added this scan that were not in `effectiveVisitsProvider` before this save. Architect to specify how to capture the pre-save snapshot.
- [ ] `dart analyze` reports zero issues
- [ ] 5+ widget tests: new-countries variant renders correctly; nothing-new variant renders correctly; continent callout shown when applicable; CTA navigates to map; achievement chips shown

**Files to change:**
- `lib/features/scan/scan_summary_screen.dart` — new
- `lib/features/visits/review_screen.dart` — capture pre-save country snapshot; navigate to `ScanSummaryScreen` instead of Map after save
- `test/features/scan/scan_summary_screen_test.dart` — new

**Dependencies:** Task 50 (onboarding must land first so the post-scan flow is consistent).

---

## Task 52 — Country celebration animation

**Milestone:** 18
**Phase:** 8 — Celebrations & Delight

**Why:** The scan summary screen needs a visual delight moment to make the discovery of new countries feel rewarding. A confetti burst on screen entry + sequential fade-in of country rows achieves this without requiring a third-party animation library.

**Deliverable:** Confetti animation on `ScanSummaryScreen` entry (new-countries variant only); sequential staggered fade-in for country list rows.

**Acceptance criteria:**
- [ ] Confetti uses the `confetti` pub.dev package (`ConfettiWidget`); fires once on screen entry when `newCountries.isNotEmpty`
- [ ] Confetti colours use `colorScheme.primary` and `colorScheme.tertiary` palette; duration ≤ 3 seconds
- [ ] Country list rows animate in sequentially: each row fades in with 80 ms stagger using `AnimationController` + `FadeTransition` (no third-party dependency for this part)
- [ ] When `MediaQuery.disableAnimations` is true: confetti does not fire; rows appear instantly (no animation)
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: animation absent when `disableAnimations = true`; confetti widget present in tree when new countries exist; confetti widget absent in nothing-new variant

**Files to change:**
- `apps/mobile_flutter/pubspec.yaml` — add `confetti` dependency (Architect to confirm version)
- `lib/features/scan/scan_summary_screen.dart` — add animation logic (from Task 51)
- `test/features/scan/scan_summary_screen_test.dart` — add animation tests

**Dependencies:** Task 51 (lives within scan summary screen).

---

## Task 53 — Achievement unlock sheet

**Milestone:** 18
**Phase:** 8 — Celebrations & Delight

**Why:** The current achievement unlock notification is a SnackBar — easy to miss and impossible to share. A dedicated bottom sheet gives the moment appropriate weight and exposes the share action that users need to show off a new achievement.

**Deliverable:** `AchievementUnlockSheet` bottom sheet; replaces SnackBar at unlock sites; also tappable from `StatsScreen` achievement gallery for already-unlocked achievements.

**Acceptance criteria:**
- [ ] `AchievementUnlockSheet` takes `Achievement achievement` and `DateTime unlockedAt`
- [ ] Sheet contents: large icon (`emoji_events_outlined`, amber, 48px); achievement `title` (headline); achievement `description` (body); unlock date ("Unlocked 14 Jan 2024"); "Share" `FilledButton`; "Done" `TextButton` (dismisses)
- [ ] "Share" button invokes the existing iOS share sheet with a plain-text message: "[Title] — [Description]. Unlocked on [date]. Discovered with Roavvy." (no image required; Architect may optionally extend to image share in a later task)
- [ ] Sheet is shown via `showModalBottomSheet` with `isScrollControlled: false`
- [ ] `ScanSummaryScreen`: tapping an achievement chip (Task 51) opens `AchievementUnlockSheet`
- [ ] `StatsScreen`: tapping an unlocked achievement card opens `AchievementUnlockSheet` (locked cards do nothing)
- [ ] SnackBar unlock notification in `ReviewScreen` / write sites is removed; replaced by this sheet triggered from `ScanSummaryScreen`
- [ ] `dart analyze` reports zero issues
- [ ] 5+ widget tests: sheet renders correct title/description/date; share button present; done dismisses; tapping locked card does not open sheet; tapping unlocked card opens sheet

**Files to change:**
- `lib/features/scan/achievement_unlock_sheet.dart` — new
- `lib/features/scan/scan_summary_screen.dart` — wire achievement chips → sheet
- `lib/features/stats/stats_screen.dart` — wire unlocked card tap → sheet
- `lib/features/visits/review_screen.dart` — remove SnackBar unlock notification
- `test/features/scan/achievement_unlock_sheet_test.dart` — new

**Dependencies:** Task 51 (sheet is opened from scan summary). Can be built in parallel with Task 52.

---

## Key risks and open questions

1. **Pre-save country snapshot for delta computation (Task 51)** — `ReviewScreen` must know which countries existed *before* the save to compute `newCountries`. Options: (a) read `effectiveVisitsProvider` before calling save, capture the set, diff after; (b) pass the pre-scan country set into `ReviewScreen` from `ScanScreen`. Architect must specify.

2. **`hasSeenOnboarding` persistence (Task 50)** — Drift preferred (consistent with offline-first ADR-003), but requires a schema bump. SharedPreferences is simpler but introduces a second persistence mechanism. Architect must decide.

3. **`confetti` package binary size (Task 52)** — Check package size impact before committing. If too large, implement a simple custom `CustomPainter`-based confetti instead.

4. **Achievement share format (Task 53)** — Plain text is simplest. If image share is wanted, it requires a `RepaintBoundary` screenshot of the sheet — defer to a follow-up task rather than blocking M18.

5. **Onboarding skip for returning users (Task 50)** — If `effectiveVisitsProvider` returns a non-empty list on launch, skip onboarding regardless of the `hasSeenOnboarding` flag. Prevents re-showing onboarding after a reinstall with Firestore data present.

**Build order:** Task 50 → Task 51 → (Task 52 ∥ Task 53). Tasks 52 and 53 are independent of each other and may be built in parallel after Task 51 lands.

---

## Architect sign-off — Milestone 18 (Tasks 50–53)

**Review complete: 2026-03-19**

**ADRs written:** ADR-053 (onboarding persistence), ADR-054 (scan summary delta + navigation), ADR-055 (confetti library + stagger animation).

### Corrections to Planner task specs

**Task 50 — onboarding persistence and routing:**
- `hasSeenOnboarding` is stored as a nullable `TextColumn hasSeenOnboardingAt` on the existing `ScanMetadata` Drift table (schema v8 migration). SharedPreferences is not used (ADR-053).
- A new `onboardingCompleteProvider` (`FutureProvider<bool>`) is added to `lib/core/providers.dart`. It returns `true` if `hasSeenOnboardingAt != null` OR if `effectiveVisitsProvider` is non-empty.
- `RoavvyApp` (`lib/app.dart`) becomes a `ConsumerWidget`, watching `onboardingCompleteProvider`. It routes to `OnboardingFlow` when the provider returns `false`, else `MainShell`.
- `onboardingCompleteProvider` must be overridden in all widget tests that pump `RoavvyApp` or `MainShell`.
- Files list update: add `lib/core/providers.dart` (new provider); `lib/app.dart` (consumer routing); no `VisitRepository` changes — write `hasSeenOnboardingAt` via a new `MetaRepository.markOnboardingComplete()` method or directly through the `ScanMetadata` table accessor. Architect recommends a thin `markOnboardingComplete()` method on the existing DB class rather than a new repository class.

**Task 51 — delta computation and navigation:**
- Pre-save snapshot: `ref.read(effectiveVisitsProvider).valueOrNull?.map((v) => v.countryCode).toSet() ?? {}` captured immediately before the save call (ADR-054).
- Post-save re-read: `await ref.refresh(effectiveVisitsProvider).future` — required because the provider is invalidated by the repository write.
- `newAchievementIds` computed identically from `achievementRepositoryProvider.loadAll()` before and after save.
- Navigation: `ScanSummaryScreen` is a full-screen `MaterialPageRoute` pushed from `ReviewScreen`. It takes `VoidCallback onDone`; `ReviewScreen` passes its own `onScanComplete` callback through as `onDone`.
- `ScanSummaryScreen` has **no Riverpod providers** — it receives all data as constructor parameters. This makes widget tests trivial.
- Achievement SnackBar removed from `ReviewScreen` save path only. Other write sites (manual add, startup flush) are unaffected and remain SnackBar-free already.

**Task 52 — animation:**
- `confetti` package accepted (ADR-055), subject to binary size gate (< 200 KB compiled delta). Builder runs `flutter build ipa --analyze-size` before PR.
- `kContinentEmoji` lives in `lib/core/continent_emoji.dart` — not in `shared_models`.
- `ConfettiController` disposed in `dispose()`. Animation controllers for row stagger also disposed.

**Task 53 — achievement sheet:**
- Share format: plain text only (ADR-054). Image share deferred.
- Opening from `StatsScreen`: `_achievementsFuture` data is already loaded in `initState` — the tap handler reads from the resolved future data already in the widget state. No new provider watch needed.

### Confirmed structural decisions

1. Drift schema v8 adds `hasSeenOnboardingAt TEXT` (nullable) to `ScanMetadata`. Migration is additive; no existing data is affected.
2. `ScanSummaryScreen` is NOT part of the `IndexedStack`. It lives above `MainShell` in the Navigator stack and is popped on completion.
3. The `onDone` callback on `ScanSummaryScreen` is the only navigation hook — no direct `Navigator` calls inside the screen.
4. `confetti` size gate is a hard blocker for Task 52 PR approval.

**Builder may proceed. Start with Task 50.**

---

## Milestone 19 — Phase 9: App Store Readiness

**Goal:** The app passes App Store Review and is publicly available on the iOS App Store.

**Scope — included:**
- App icon integrated into iOS project (all required sizes)
- Privacy policy web page at `/privacy` (required URL in App Store metadata)
- "Get Roavvy" App Store CTA on `/share/[token]` web page
- Local push notifications: opt-in prompt, achievement unlock, 30-day scan nudge
- iPad layout decision: declare iPhone-only OR implement basic adaptive layout

**Scope — excluded (operational, not code):**
- App Store Connect listing setup (metadata, title, subtitle, description, keywords, category)
- Marketing screenshots — captured from device/simulator after icon and layout are finalised
- App preview video — captured from device
- APNs certificate setup in Apple Developer account (prerequisite for push)
- Privacy policy copy wording — must be approved by owner before publishing

**Prerequisites (must be complete before submission, not code tasks):**
- Active Apple Developer Program membership
- 1024×1024 PNG app icon file provided (design deliverable)
- Privacy policy copy finalised and approved
- APNs key/certificate configured in Firebase Console (for push notifications)
- App Store Connect app listing created with metadata filled in

---

## Task 54 — App icon integration

**Milestone:** 19
**Phase:** 9 — App Store Readiness

**Why:** The app currently uses a Flutter default placeholder icon. App Store submission requires a custom icon at all required sizes; without it, the app cannot be submitted.

**Deliverable:** Final app icon at all required iOS sizes integrated into `Runner/Assets.xcassets/AppIcon.appiconset/`; `Contents.json` updated to reference all sizes.

**Acceptance criteria:**
- [ ] `AppIcon.appiconset/` contains the icon PNG at all sizes required by App Store Connect (1024×1024 for App Store; standard device sizes for home screen)
- [ ] `Runner.xcodeproj` references the icon set correctly — confirmed by running the app on simulator and seeing the icon on the home screen
- [ ] No default Flutter blue placeholder icons remain in the asset set
- [ ] `flutter build ios --no-codesign` completes without icon-related warnings
- [ ] Icon complies with Apple Human Interface Guidelines: no transparency, no rounded corners (iOS applies rounding automatically), no text smaller than 12pt equivalent

**Files to change:**
- `apps/mobile_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/` — replace placeholder assets
- `apps/mobile_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` — update references

**Dependencies:** Requires 1024×1024 icon PNG from designer (external deliverable). This task cannot start until the design file is provided.

---

## Task 55 — Privacy policy web page

**Milestone:** 19
**Phase:** 9 — App Store Readiness

**Why:** App Store submission requires a privacy policy URL. The URL must point to a live page that explains what data Roavvy collects, how it is used, and user rights. The web app is the natural host.

**Deliverable:** Static `/privacy` route in the Next.js app; the page renders the Roavvy privacy policy in readable HTML.

**Acceptance criteria:**
- [ ] `apps/web_nextjs/src/app/privacy/page.tsx` exists and renders the privacy policy
- [ ] Page is accessible without authentication (no auth guard)
- [ ] Policy covers at minimum: data collected (GPS metadata, country codes), data not collected (photos, images, precise location), data storage (Firestore, device-local), user rights (deletion via in-app account deletion), contact information
- [ ] Page links back to `roavvy.app` home
- [ ] Page is responsive (readable on mobile)
- [ ] `npm run build` in `apps/web_nextjs/` completes without errors

**Files to change:**
- `apps/web_nextjs/src/app/privacy/page.tsx` — new

**Dependencies:** Privacy policy copy must be provided by the owner before this task can be written. Planner can scaffold the page structure; copy is a prerequisite.

**Open question:** Should the privacy policy page be linked from the app's Settings screen (`PrivacyAccountScreen`)? Flag for Architect — likely yes, via `url_launcher`.

---

## Task 56 — "Get Roavvy" CTA on share page

**Milestone:** 19
**Phase:** 9 — App Store Readiness

**Why:** When a user shares their travel card, the recipient sees the web share page. Adding an App Store CTA converts share viewers into app installs — this is the primary organic growth mechanism.

**Deliverable:** "Get Roavvy on the App Store" banner/button added to `/share/[token]` page; tapping opens the App Store listing.

**Acceptance criteria:**
- [ ] A prominent call-to-action is visible on `/share/[token]` below the travel map; it reads "Get Roavvy — discover your travels" (or similar approved copy)
- [ ] Tapping the CTA opens the App Store listing URL in a new tab (`target="_blank"`)
- [ ] CTA includes the App Store badge image (Apple-provided SVG/PNG) or styled button — must comply with Apple badge usage guidelines
- [ ] CTA is visible on mobile viewport (375px+) without scrolling past the map
- [ ] Existing share page functionality (map rendering, country list) is unchanged
- [ ] `npm run build` completes without errors

**Files to change:**
- `apps/web_nextjs/src/app/share/[token]/page.tsx` — add CTA section

**Dependencies:** App Store listing must be created in App Store Connect to obtain the App Store URL. Task 54 (icon) should be complete first so the listing looks finished when linked.

**Open question:** App Store URL is not known until the listing is created. Builder should use a placeholder URL initially and update once the listing is live.

---

## Task 57 — Local push notifications

**Milestone:** 19
**Phase:** 9 — App Store Readiness

**Why:** Push notifications for achievement unlocks and scan nudges increase retention. Implemented as local notifications (scheduled on-device) to avoid the need for a Cloud Functions backend.

**Deliverable:** `flutter_local_notifications` integrated; opt-in permission prompt shown after first scan; achievement unlock schedules an immediate local notification; 30-day scan nudge scheduled after each scan (reset on next scan).

**Acceptance criteria:**
- [ ] `flutter_local_notifications` added to `pubspec.yaml`; `dart analyze` passes
- [ ] iOS `Info.plist` includes required notification usage description key
- [ ] Permission prompt is shown once, after the first successful scan completes (not at launch)
- [ ] If permission is denied, the app continues normally — no re-prompting
- [ ] After an achievement unlock (detected in `ScanSummaryScreen`), a local notification is scheduled immediately: title = achievement title, body = achievement description
- [ ] After every scan completion, a 30-day nudge notification is scheduled: "Time to discover new travels — scan your recent photos." Previous nudge is cancelled before scheduling the new one.
- [ ] Tapping the achievement notification opens the app and navigates to the Stats tab
- [ ] Tapping the scan nudge notification opens the app and navigates to the Scan tab
- [ ] All notification logic is isolated in a `NotificationService` class in `lib/core/notification_service.dart`
- [ ] `dart analyze` reports zero issues
- [ ] 3+ unit tests on `NotificationService`: scheduling, cancellation, permission guard (using a mock plugin)

**Files to change:**
- `apps/mobile_flutter/pubspec.yaml` — add `flutter_local_notifications`
- `apps/mobile_flutter/ios/Runner/Info.plist` — add notification usage description
- `apps/mobile_flutter/lib/core/notification_service.dart` — new
- `apps/mobile_flutter/lib/features/scan/scan_summary_screen.dart` — call service after achievement unlock
- `apps/mobile_flutter/lib/features/shell/main_shell.dart` — handle notification tap navigation
- `apps/mobile_flutter/test/core/notification_service_test.dart` — new

**Dependencies:** Task 51 (ScanSummaryScreen must exist). APNs key must be configured in Apple Developer account and Firebase Console before testing on a real device.

**Note:** This task uses local notifications only. Remote push (FCM Cloud Functions) is deferred. Local notifications cover both use cases without backend infrastructure.

---

## Task 58 — iPhone-only declaration (or basic iPad layout)

**Milestone:** 19
**Phase:** 9 — App Store Readiness

**Why:** If the app targets iPad (the default), App Store Review tests it on iPad. Without an adaptive layout, the app renders in iPhone letterbox mode on iPad, which Apple may reject or which looks unprofessional. The minimum viable option is to declare iPhone-only.

**Deliverable:** Either (A) declare the app as iPhone-only in `Info.plist` and `project.pbxproj`, OR (B) implement a basic adaptive layout for iPad that passes App Store Review.

**Acceptance criteria (Option A — iPhone-only, recommended for M19):**
- [ ] `UIRequiredDeviceCapabilities` in `Info.plist` includes `iphone-performance` or the equivalent declaration that restricts the app to iPhone
- [ ] `TARGETED_DEVICE_FAMILY` in `project.pbxproj` is set to `1` (iPhone only; `1,2` includes iPad)
- [ ] App Store Connect listing confirms iPhone-only targeting
- [ ] `flutter build ios --no-codesign` completes without errors

**Acceptance criteria (Option B — basic iPad layout, deferred to M20+):**
- Full adaptive layout as specified in `docs/ux/mobile_ux_spec.md` — out of scope for M19.

**Files to change (Option A):**
- `apps/mobile_flutter/ios/Runner/Info.plist`
- `apps/mobile_flutter/ios/Runner.xcodeproj/project.pbxproj`

**Dependencies:** None.

**Decision needed:** Owner must confirm whether to target iPhone-only (faster, simpler) or invest in iPad layout now. Planner recommends iPhone-only for M19 and iPad as a separate milestone after App Store launch.

---

## Risks and open questions — Milestone 19

1. **Icon design** — The 1024×1024 icon PNG must be delivered externally before Task 54 can start. This is the most likely blocker for M19.

2. **Privacy policy copy** — The exact wording of the privacy policy requires owner approval. The scaffolded page can go live without copy, but App Store submission requires the final text.

3. **APNs certificate for push** — Requires Apple Developer account access. If the certificate is not set up, push notifications cannot be tested on a real device. Task 57 can be implemented and tested on simulator first.

4. **App Store URL** — The App Store URL for Task 56's CTA is not known until the app listing is created in App Store Connect. Use a placeholder during development.

5. **App Store Review** — Apple may raise issues not anticipated in this plan (e.g., missing permission strings, UI issues, metadata policy). Budget time for a review iteration.

6. **Screenshots and app preview video** — These are operational (not code) tasks. Screenshots must be captured on a real device or Simulator at 6.9" (iPhone 16 Pro Max) resolution. App preview video is optional but recommended for conversion. These block submission and must be completed before Task 56's App Store URL is finalised.

**Build order:** Tasks 54, 55, 56, 57, 58 are all independent and may be built in any order. Task 56 depends on knowing the App Store URL (operational prerequisite). Task 54 depends on receiving the icon design file.

**Recommended sequence:** 58 (iPhone-only declaration — 30 mins) → 55 (privacy policy page) → 57 (push notifications) → 56 (CTA, once App Store URL is known) → 54 (icon, once design is delivered).

---

## Architect sign-off — Milestone 19 (Tasks 54–58)

**Review complete: 2026-03-19**

**ADRs written:** ADR-056 (local push notifications: package, prompt timing, tap-routing), ADR-057 (iPhone-only targeting + bundle identity fix).

### Corrections to Planner task specs

**Task 54 — App icon + bundle identity:**
- `CFBundleDisplayName` is currently `"Mobile Flutter"` and `CFBundleName` is `"mobile_flutter"` — both must be updated to `"Roavvy"` in `Info.plist` as part of this task. This fix is independent of the icon design file and can be committed immediately.
- `CFBundleIdentifier` must match the registered App ID in Apple Developer. The current value is `$(PRODUCT_BUNDLE_IDENTIFIER)` (a build variable). Builder must confirm the correct reverse-domain identifier (e.g. `com.roavvy.app`) is set in Xcode build settings — this is an operational check, not a code change.
- Icon asset integration blocked on 1024×1024 PNG from designer. Bundle name fix is not blocked. Builder should do the bundle name fix in a first commit and leave a TODO comment where the icon assets will land.

**Task 55 — Privacy policy page:**
- Add a link to the privacy policy from `PrivacyAccountScreen` (Flutter). This requires `url_launcher` — check `pubspec.yaml` first; if not present, add it (app layer only). One `TextButton` or `ListTile` labelled "Privacy Policy" calling `launchUrl(Uri.parse('https://roavvy.app/privacy'))`.
- The Next.js privacy page must NOT be behind an auth guard — it must be publicly accessible.
- No new route in the Flutter app; the link opens in the system browser via `url_launcher`.

**Task 56 — "Get Roavvy" CTA:**
- App Store URL format: `https://apps.apple.com/app/id{NUMERIC_APP_ID}`. The numeric App ID is only known after the App Store Connect listing is created. Builder must use `const _kAppStoreUrl = 'https://apps.apple.com/app/id0000000000'; // TODO: replace with final App Store ID` and document this as a known placeholder.
- Apple badge: Use the official "Download on the App Store" SVG from Apple's marketing resources (`https://developer.apple.com/app-store/marketing/guidelines/`). Do not improvise a badge. Place the SVG in `apps/web_nextjs/public/app-store-badge.svg`.

**Task 57 — Local push notifications:**
- `AppDelegate.swift` requires **no changes**. `FlutterAppDelegate` satisfies the `UNUserNotificationCenterDelegate` requirements that `flutter_local_notifications` needs.
- `Runner.entitlements` requires **no changes**. The `aps-environment` entitlement is not needed for local notifications.
- `Info.plist` requires **no new keys** for notifications on iOS.
- `NotificationService` is a **singleton** (not a Riverpod provider) — the plugin uses static callback registration outside the Riverpod graph. Initialize it in `main()` after `Firebase.initializeApp()`.
- Payload schema: `"tab:2"` for Stats tab, `"tab:3"` for Scan tab. Parse in `NotificationService._onNotificationTap`.
- Tab index values: Stats = 2, Scan = 3 (per ADR-052 `MainShell` contract — Map=0, Journal=1, Stats=2, Scan=3).
- Foreground notifications: iOS suppresses local notifications while the app is in the foreground by default. This is correct behaviour — the achievement sheet is already visible. No `UNNotificationPresentationOptions` override needed.
- Permission prompt site: `ScanSummaryScreen._requestNotificationPermissionIfNeeded()` — called in `initState` if `newCountries.isNotEmpty`. Guard with a `NotificationService.hasRequestedPermission()` check (stored in `ScanMetadata` or via the plugin's own permission API response). Architect recommends reading the system permission status via `flutter_local_notifications`'s `checkPermissions()` — if status is `notDetermined`, request; otherwise skip.

**Task 58 — iPhone-only + bundle fix:**
- Architect has resolved the Planner's "Decision needed" open question: **use Option A (iPhone-only)**. iPad layout is deferred. No owner confirmation required — this is consistent with the M19 minimum-viable-submission goal.
- `TARGETED_DEVICE_FAMILY` must be updated in **all three** build configuration sections of `project.pbxproj` (Debug, Release, Profile) — grep confirms three occurrences at lines 465, 597, 651.
- Remove `UISupportedInterfaceOrientations~ipad` from `Info.plist` (dead config).
- Do NOT use `UIRequiredDeviceCapabilities` to restrict to iPhone — the correct mechanism is `TARGETED_DEVICE_FAMILY`. The Planner's reference to `iphone-performance` in `UIRequiredDeviceCapabilities` is incorrect; omit it.

### Confirmed structural decisions

1. Push notifications are local-only for M19. FCM Cloud Functions deferred.
2. `NotificationService` is a singleton with a `ValueNotifier<int?> pendingTabIndex` field. `MainShell` subscribes in `initState`.
3. Cold-start tab routing: `MainShell.initState()` calls `NotificationService.getLaunchTab()` (wraps `getNotificationAppLaunchDetails()`).
4. Privacy policy page at `/privacy` in Next.js — no auth guard, publicly accessible.
5. iPhone-only declaration is confirmed for M19. `TARGETED_DEVICE_FAMILY = "1"` in all three build configurations.

**Builder may proceed. Start with Task 58.**

---

## Task 21 — Startup dirty-row flush + explicit Firestore offline persistence

**Why:** ADR-030's write-site-only `flushDirty` triggers do not cover the case where the app is killed while offline (pending `await set()` is lost). On next launch, `isDirty = 1` rows sit unsynced until the user scans or edits again. ADR-031 closes this by flushing at startup. ADR-032 makes the offline-persistence dependency explicit rather than relying on iOS defaults.

**Acceptance criteria:**
- [ ] `FirebaseFirestore.instance.settings` is set to `persistenceEnabled: true, cacheSizeBytes: CACHE_SIZE_UNLIMITED` in `main()` immediately after `Firebase.initializeApp()`, before any Firestore access
- [ ] `main()` creates a `VisitRepository(db)` and calls `unawaited(FirestoreSyncService().flushDirty(uid, repo))` after auth is confirmed, if `uid != null`
- [ ] The startup flush completes before `runApp` can see dirty rows — i.e. it is fire-and-forget, not blocking `runApp`
- [ ] `dart analyze` reports zero warnings
- [ ] No existing widget tests broken

**Files to change:**
- `lib/main.dart` — add Settings call after `Firebase.initializeApp()`; add startup flush after auth

**Dependencies:** Tasks 19 + 20 (complete).

---

## Milestone 9 — Achievements

**Goal:** Award travel achievements based on visited countries and surface them in the app.

**Scope — included:**
- Achievement domain model and rules engine in `packages/shared_models` (offline, pure computation)
- Drift persistence for unlocked achievements (`unlocked_achievements` table)
- Achievement evaluation triggered after each scan, review save, and startup flush
- Firestore sync for unlocked achievements (same fire-and-forget pattern as visits)
- UI surface: achievement count in stats strip + unlock notification (SnackBar)

**Scope — excluded:**
- Achievement sharing or export
- Continent-level map colouring (deferred)
- Retroactive achievement backdating
- Per-achievement detail screens (deferred to M10+)

**Note:** Tasks 25 and 26 have user-facing components — invoke UX Designer before Architect for those tasks.

---

## Task 22 — Achievement domain model + rules engine

**Milestone:** 9
**ADRs:** ADR-034, ADR-035

**Why:** The achievement engine must be pure offline computation in `packages/shared_models`, consistent with ADR-007 (zero-dependency, dual-language). All unlock logic lives here; app layers only store and display results.

**Deliverable:** `AchievementEngine` class and continent map in `packages/shared_models`.

**Acceptance criteria:**
- [ ] `Achievement` value type defined: `id` (String), `title`, `description`
- [ ] `const List<Achievement> kAchievements` catalogue defined (minimum 8 — see ADR-034)
- [ ] `AchievementEngine.evaluate(List<EffectiveVisitedCountry> visits)` returns `Set<String>` of unlocked achievement IDs; pure static function, no I/O
- [ ] `const Map<String, String> kCountryContinent` defined (ISO 3166-1 → continent name, 6 inhabited continents, territories mapped to administering country's continent — see ADR-035)
- [ ] Countries absent from `kCountryContinent` are ignored gracefully (no exception)
- [ ] All new types exported from `shared_models.dart`
- [ ] `dart analyze` reports zero issues in `packages/shared_models`
- [ ] ≥ 20 unit tests: each achievement rule, empty list, exactly-at-threshold, one-below-threshold, missing continent key

**Files to change:** `packages/shared_models/`

**Dependencies:** None. (Task 21 complete.)

---

## Task 23 — Achievement Drift persistence + repository

**Milestone:** 9
**ADR:** ADR-036

**Why:** Unlocked achievements must survive app restarts (ADR-003) and be dirty-flagged for Firestore sync (ADR-030 pattern).

**Deliverable:** `unlocked_achievements` Drift table, `AchievementRepository`, and provider.

**Acceptance criteria:**
- [ ] `unlocked_achievements` table added to `RoavvyDatabase` — schema v4; columns: `achievementId` (TEXT PK), `unlockedAt` (INTEGER ms-since-epoch UTC), `isDirty` (INTEGER default 1), `syncedAt` (INTEGER nullable)
- [ ] `RoavvyDatabase.schemaVersion` incremented to 3 → 4; `onUpgrade` creates table with `CREATE TABLE IF NOT EXISTS`
- [ ] `AchievementRepository` exposes: `upsertAll(Set<String> ids, DateTime unlockedAt)`, `loadAll()` → `List<String>`, `loadDirty()` → rows, `markClean(String id, DateTime syncedAt)`
- [ ] `VisitRepository.clearAll()` does **not** purge `unlocked_achievements` (achievements persist across history delete — ADR-036)
- [ ] `achievementRepositoryProvider` added to `lib/core/providers.dart`
- [ ] `dart analyze` reports zero issues
- [ ] Unit tests: upsert idempotency, load, loadDirty, markClean — all via in-memory Drift DB

**Files to change:** `lib/data/db/roavvy_database.dart`, `lib/data/achievement_repository.dart` (new), `lib/core/providers.dart`

**Dependencies:** Task 22.

---

## Task 24 — Achievement evaluation at write sites + Firestore sync

**Milestone:** 9
**ADRs:** ADR-037, ADR-038 (partial)

**Why:** Achievements must be re-evaluated after visits change. Newly unlocked achievements must be persisted locally and synced to Firestore (ADR-030 pattern).

**Deliverable:** `AchievementEngine.evaluate()` called after scan and review save; `FirestoreSyncService.flushDirty` extended with optional `achievementRepo` parameter; `main.dart` startup flush updated.

**Acceptance criteria:**
- [ ] After scan completion (in `ScanScreen`) and after review save (in `ReviewScreen`): call `achievementRepo.loadAll()` (before), then `AchievementEngine.evaluate(effectiveVisits)`, then `achievementRepo.upsertAll(newIds, now)`. Capture newly unlocked IDs (set difference) for Task 25 SnackBar.
- [ ] `AchievementEngine.evaluate()` is **not** called in `main()` startup — startup only flushes already-dirty rows from prior sessions
- [ ] `SyncService.flushDirty` signature: `Future<void> flushDirty(String uid, VisitRepository repo, {AchievementRepository? achievementRepo})` (optional named parameter — ADR-037)
- [ ] `FirestoreSyncService.flushDirty` pushes dirty achievement rows to `users/{uid}/unlocked_achievements/{achievementId}` with `{unlockedAt: <ISO string>, syncedAt: <ISO string>}`; marks clean on success; silent failure on exception
- [ ] `NoOpSyncService.flushDirty` accepts the new named parameter and ignores it
- [ ] `main.dart` startup flush passes `achievementRepo: AchievementRepository(db)` so achievement dirty rows are flushed on startup
- [ ] `firestore.rules` — no change required; existing `users/{userId}/{document=**}` wildcard covers the new subcollection (ADR-037)
- [ ] `dart analyze` reports zero issues
- [ ] Unit tests: evaluate-and-upsert at scan site; evaluate-and-upsert at review site; `FirestoreSyncService` achievement flush (FakeFirebaseFirestore)

**Files to change:** `lib/data/firestore_sync_service.dart`, `lib/features/scan/scan_screen.dart`, `lib/features/visits/review_screen.dart`, `lib/main.dart`

**Dependencies:** Tasks 22 + 23.

---

## Task 25 — Achievement UI: stats strip count + unlock SnackBar

**Milestone:** 9
**ADR:** ADR-038

**Why:** Users need to know achievements exist and be notified when they unlock one.

**Deliverable:** Achievement count in `StatsStrip`; `SnackBar` on new unlock.

**Acceptance criteria:**
- [ ] `TravelSummary` gains `final int achievementCount` (default `0`); `fromVisits()` is unchanged and returns `achievementCount: 0`
- [ ] `travelSummaryProvider` reads `achievementRepositoryProvider.loadAll()` and sets `achievementCount` (ADR-038)
- [ ] `StatsStrip` displays achievement count as a fourth stat (e.g. "🏆 3")
- [ ] After scan completes or review saves, if `newlyUnlockedIds.isNotEmpty`: show one `SnackBar` per newly unlocked achievement with its `Achievement.title`
- [ ] If no new achievements: no SnackBar shown
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: `StatsStrip` renders `achievementCount`; SnackBar appears on new unlock; no SnackBar when already unlocked; `travelSummaryProvider` override in tests uses non-zero count

**Files to change:** `packages/shared_models/src/travel_summary.dart`, `lib/core/providers.dart`, `lib/features/map/stats_strip.dart`, `lib/features/scan/scan_screen.dart`, `lib/features/visits/review_screen.dart`

**Dependencies:** Tasks 22 + 23 + 24.

---

## Architect sign-off — Milestone 9 + Task 26 corrections

**Plan validated.** One planner error corrected: `AchievementEngine.evaluate()` is NOT called in `main()` startup (Task 24); startup only flushes pre-existing dirty achievement rows. Risks 1–4 from the planner are resolved by ADRs 034–038.

**Build order:** Task 22 → 23 → 24 → 25. No task may start before its dependencies are complete.

---

## Next: Task 26 (auth persistence + sign-out)

---

## Task 26 — Auth persistence: remove forced sign-out + add sign-out action

**Milestone:** 9.5 (auth polish, prerequisite for M10)
**ADR:** ADR-039

**Why:** `main.dart` contains a `// TEMP: force sign-out` call that defeats Firebase Auth's built-in iOS Keychain session persistence. Every launch shows `SignInScreen`, even for users who previously signed in with Apple. The `SignInScreen` also exposes an email/password form that is not part of the intended user flow and should be removed. A sign-out action is needed so users can deliberately end their session.

**Acceptance criteria:**

- [ ] `FirebaseAuth.instance.signOut()` removed from `main.dart`; the TEMP comment is removed
- [ ] `SignInScreen` no longer contains email/password fields or `signInWithEmailAndPassword`; it shows only: app name/logo placeholder, "Sign in with Apple" button, and "Continue anonymously" button
- [ ] Sign in with Apple nonce logic is extracted to `lib/features/auth/apple_sign_in.dart` — a top-level `Future<void> signInWithApple({required VisitRepository repo})` function; both `SignInScreen` and `MapScreen` call this function (no duplication); `MapScreen`'s `signInWithAppleOverride` test hook is preserved
- [ ] `MapScreen` overflow menu gains a "Sign out" item (always visible); tapping it calls `FirebaseAuth.instance.signOut()`; `authStateProvider` emits `null`; `RoavvyApp` routes to `SignInScreen`
- [ ] "Sign in with Apple" and "Signed in with Apple ✓" items remain in the overflow menu as before
- [ ] `dart analyze` reports zero issues
- [ ] Tests: `map_screen_test.dart` — overflow menu shows "Sign out"; tapping it does not crash (auth state transitions are handled by `authStateProvider` reactivity, not testable in unit widget tests without mock sign-out); `sign_in_screen_test.dart` (new) — "Continue anonymously" button exists, no email field present

**Files to change:**
- `lib/main.dart` — remove `signOut()` call
- `lib/features/auth/apple_sign_in.dart` (new) — shared Apple sign-in helper
- `lib/features/auth/sign_in_screen.dart` — remove email/password; add Sign in with Apple button calling shared helper
- `lib/features/map/map_screen.dart` — add "Sign out" overflow item; replace inline Apple sign-in with call to shared helper
- `test/features/map/map_screen_test.dart` — add sign-out menu item test
- `test/features/auth/sign_in_screen_test.dart` (new) — UI shape tests

**Dependencies:** Milestone 9 complete.

**Risks:**
- Anonymous users who sign out will start a new anonymous session on next "Continue anonymously"; their Firestore-synced data will not reappear (local SQLite data remains intact on device). No fix needed — this is correct behaviour per ADR-027.
- Moving Sign in with Apple logic from `MapScreen` to `SignInScreen` means the Apple sign-in flow runs before the user reaches the map. The post-sign-in flush (`FirestoreSyncService.flushDirty`) must still be triggered. This can be done via `authStateProvider` listener in `RoavvyApp` or `MainShell`.

---

## Milestone 10 — Sharing Cards

**Goal:** A user can share a travel card image — showing their country count, year range, and achievement count — via the iOS share sheet.

**Scope — included:**
- A `TravelCardWidget`: self-contained Flutter widget rendering travel stats as a stylised card
- Off-screen capture of `TravelCardWidget` as a PNG using `RepaintBoundary`
- Share via `share_plus` (iOS share sheet — AirDrop, Messages, Photos, etc.)
- Entry point: "Share my map" button in `MapScreen` overflow menu (or FAB equivalent)

**Scope — excluded:**
- Photo uploads or map screenshot (ADR-002; only derived stat text is shown)
- Shareable URLs / web-backed sharing (deferred to M11)
- Custom card theming or branding beyond basic styling
- Android (deferred to M12)

---

## Task 27 — Travel card widget

**Milestone:** 10
**ADR:** ADR-040

**Why:** The card must be renderable both on-screen (preview) and off-screen (capture). A self-contained widget with no external state makes both modes simple.

**Acceptance criteria:**

- [ ] `TravelCardWidget` defined in `lib/features/sharing/travel_card_widget.dart`; accepts a `TravelSummary` positional argument; no Riverpod dependency (pure widget)
- [ ] Card displays: country count (large, prominent), year range (`{earliest} – {latest}` or `—` if none), achievement count (`🏆 N`), and the text "Roavvy" as a brand label
- [ ] Card has a fixed aspect ratio (e.g. 3:2 landscape) and a self-contained background colour; renders correctly when wrapped in `RepaintBoundary` at 3× device pixel ratio
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: card renders correct count; year range displays `—` when no dates; achievement count shows 0 when none

**Files to change:**
- `lib/features/sharing/travel_card_widget.dart` (new)
- `test/features/sharing/travel_card_widget_test.dart` (new)

**Dependencies:** Task 26.

---

## Task 28 — Capture card as image + share via iOS share sheet

**Milestone:** 10
**ADR:** ADR-040

**Why:** Captures the `TravelCardWidget` as PNG bytes using `RenderRepaintBoundary.toImage()` and passes them to `share_plus` `ShareXFiles` — the standard Flutter approach for sharing generated images without uploading them.

**Acceptance criteria:**

- [ ] `share_plus` and `path_provider` added to `apps/mobile_flutter/pubspec.yaml` (no `screenshot` package — use `RepaintBoundary` directly per ADR-040)
- [ ] `MapScreen` places `TravelCardWidget` in an `Offstage(offstage: true, child: RepaintBoundary(key: _cardKey, child: TravelCardWidget(summary)))` inside its build Stack; `_cardKey` is a `GlobalKey` held on `_MapScreenState`
- [ ] `MapScreen` overflow menu gains a "Share my map" item; visible only when `travelSummaryProvider` has data and `summary.visitedCodes.isNotEmpty`
- [ ] Tapping "Share my map" calls `captureAndShare(_cardKey, 'My Roavvy travel map')` from `lib/features/sharing/travel_card_share.dart`
- [ ] `captureAndShare` in `travel_card_share.dart`: calls `boundary.toImage(pixelRatio: 3.0)`, encodes to PNG, writes to `getTemporaryDirectory()`, calls `Share.shareXFiles([XFile(path)])` — plain async function, no Riverpod
- [ ] `dart analyze` reports zero issues
- [ ] Widget test: "Share my map" item appears in overflow when visits exist; item is absent when no visits (override `travelSummaryProvider` to cover both states)

**Files to change:**
- `pubspec.yaml` — add `share_plus`, `path_provider` (if absent)
- `lib/features/sharing/travel_card_share.dart` (new)
- `lib/features/map/map_screen.dart` — add overflow item + call share function
- `test/features/map/map_screen_test.dart` — add overflow item visibility tests

**Dependencies:** Task 27.

---

## Milestone 11 — Web App: Public Shareable Travel Map

**Goal:** A signed-in Flutter user can generate a public URL that anyone can open in a browser to see their visited countries highlighted on a world map.

**Scope — included:**
- Share token generation in the Flutter app (opaque UUID, stable per user, cached locally)
- Public `sharedTravelCards/{token}` Firestore collection with denormalized visited country codes
- "Share my map URL" overflow menu item in `MapScreen` (signed-in non-anonymous users only)
- Web `/share/[token]` page that reads the token document and renders a Leaflet world map with visited countries highlighted
- GeoJSON polygon asset (`countries.geojson`) bundled in `apps/web_nextjs/public/data/`
- Updated Firestore security rules to allow public read of `sharedTravelCards/{token}`

**Scope — excluded:**
- Authenticated web dashboard or "my map" view (deferred)
- Achievement or stats display on the share page (deferred)
- Custom domain configuration or deployment (Vercel etc.)
- Android support
- Token revocation ("stop sharing") UI

**Current state of the web app:** `apps/web_nextjs/` is already scaffolded with Next.js 16, TypeScript, Tailwind, Firebase SDK v12, and Leaflet. The route `/share/[token]` exists and reads from `sharedTravelCards/{token}` in Firestore. The `DynamicMap` and `Map` components exist but have an interface bug (`userVisits` prop was removed from `DynamicMapProps`). Several unused spike pages (`/dashboard`, `/auth`, `/map`) exist and may be left in place.

**Risks / open questions:**
1. **Token guessability:** UUIDs are 128-bit random — not guessable. No revoke mechanism exists for now; flag in ADR.
2. **GeoJSON resolution:** Use Natural Earth 110m (~400 KB). The `ne_countries.bin` in the Flutter app is derived from Natural Earth data so ISO codes match.
3. **Firestore rules:** The new `sharedTravelCards` collection requires a separate `allow read: if true` rule. This must not widen access to `users/{uid}/...`.
4. **Token storage:** Store in a new `app_settings` Drift table (key TEXT PK, value TEXT). Requires schema migration v4 → v5. If the `unlocked_achievements` table was added at v4 in Task 23 but Task 21–25 are complete, confirm current schema version before writing the migration.
5. **Anonymous users:** "Share my map URL" is only available to non-anonymous signed-in users (anonymous UIDs are ephemeral and Firestore writes would be lost on sign-out).

**Build order:** Task 29 → Task 30. Task 29 (Flutter) and Task 30 (web) may be developed in parallel once ADR-041 defines the shared Firestore document schema.

---

## Task 29 — Share token generation + Firestore write (Flutter)

**Milestone:** 11
**ADR:** ADR-041

**Why:** The Flutter app must generate a stable, opaque token for each user, write the user's current visited country codes to `sharedTravelCards/{token}`, and expose a "Share my map URL" action. The token is reused across sessions so the user always gets the same URL.

**Acceptance criteria:**

- [ ] `app_settings` table added to `RoavvyDatabase` — schema v5; columns: `key` (TEXT PK), `value` (TEXT NOT NULL); `onUpgrade` handles v4 → v5 with `CREATE TABLE IF NOT EXISTS`
- [ ] `VisitRepository` gains `getShareToken()` → `String?` and `saveShareToken(String token)` using the `app_settings` table
- [ ] `ShareTokenService` in `lib/features/sharing/share_token_service.dart`: `Future<String> getOrCreateToken(VisitRepository repo)` — reads stored token; if null, generates a UUID v4 (using `dart:math` + `dart:convert`, no new package), saves it, and returns it
- [ ] `ShareTokenService.publishVisits(String token, String uid, List<EffectiveVisitedCountry> visits)` — writes `sharedTravelCards/{token}` document: `{uid, visitedCodes: [...], countryCount: N, createdAt: <ISO string>}`; fire-and-forget (logs errors, does not throw)
- [ ] `MapScreen` overflow menu gains a "Share my map URL" item; visible only when `!isAnonymous && hasVisits`
- [ ] Tapping "Share my map URL": calls `getOrCreateToken`, then `publishVisits`, then shares the URL `https://roavvy.app/share/{token}` via `Share.shareXFiles` (text-only share) or `Share.share`
- [ ] Firestore rules updated: `sharedTravelCards/{token}` — `allow read: if true; allow write: if request.auth != null && request.auth.uid == request.resource.data.uid`
- [ ] `dart analyze` reports zero issues
- [ ] Unit tests: `VisitRepository` — `getShareToken` returns null initially, `saveShareToken` persists, `getShareToken` returns saved value; `ShareTokenService` — `getOrCreateToken` returns same token on second call; `publishVisits` (mock Firestore or FakeFirebaseFirestore)
- [ ] Widget test: `MapScreen` — "Share my map URL" visible when signed-in + has visits; hidden when anonymous; hidden when no visits

**Files to change:**
- `lib/data/db/roavvy_database.dart` — add `app_settings` table, bump schema to v5
- `lib/data/visit_repository.dart` — add `getShareToken` / `saveShareToken`
- `lib/features/sharing/share_token_service.dart` (new)
- `lib/features/map/map_screen.dart` — add overflow item
- `firestore.rules` — add `sharedTravelCards` match block
- `test/data/visit_repository_test.dart` — add token tests
- `test/features/sharing/share_token_service_test.dart` (new)
- `test/features/map/map_screen_test.dart` — add URL share item tests

**Dependencies:** Task 28 complete. Milestone 10 complete.

---

## Task 30 — Web share page: data read + world map rendering

**Milestone:** 11
**ADR:** ADR-041

**Why:** The web app already has a `/share/[token]` route and Leaflet map components, but the `DynamicMap` interface has a bug (`userVisits` prop missing), no GeoJSON asset exists, and the page has not been tested against the actual Firestore schema defined in ADR-041.

**Acceptance criteria:**

- [ ] `apps/web_nextjs/public/data/countries.geojson` committed — Natural Earth 110m country polygons; features include `properties.ISO_A2` (ISO 3166-1 alpha-2 code); file size ≤ 600 KB
- [ ] `DynamicMap.tsx` interface restored: `export interface DynamicMapProps { geoJsonData: any; userVisits: string[] }` — both `DynamicMap` and `Map` accept and pass through `userVisits`
- [ ] `Map.tsx` styles: visited countries (`userVisits.includes(ISO_A2)`) filled `#2D6A4F`; unvisited `#D1D5DB`; border `#9CA3AF 0.5px` — matching Flutter map colours
- [ ] `share/[token]/page.tsx` reads the `visitedCodes: string[]` field from the Firestore document (not `userVisits`)
- [ ] Loading state shown while fetching; error state shown for missing/invalid token
- [ ] Page title shows "N countries visited · Roavvy" using `countryCount` from the Firestore document
- [ ] No authentication required to view the share page
- [ ] `npm run build` completes with zero TypeScript errors and zero ESLint errors
- [ ] Manual end-to-end test: Flutter generates token → Firestore document written → web URL opens and shows correct countries highlighted

**Files to change:**
- `apps/web_nextjs/public/data/countries.geojson` (new)
- `apps/web_nextjs/src/components/DynamicMap.tsx` — restore `userVisits` prop
- `apps/web_nextjs/src/components/Map.tsx` — fix colours, use correct prop
- `apps/web_nextjs/src/app/share/[token]/page.tsx` — use `visitedCodes`, fix title, fix error states

**Dependencies:** Task 29 (ADR-041 defines the Firestore document schema).

---

## Milestone 12 — Phase 2/3 Closeout

**Goal:** Close the remaining privacy-required gaps before Phase 4. Account deletion satisfies the GDPR right-to-erasure requirement stated in `docs/architecture/privacy_principles.md`. Token revocation is the matching "stop sharing" control.

**Build order:** Task 31 → Task 32. Account deletion reuses the token revocation logic introduced in Task 31.

**Note:** Both tasks have user-facing components — invoke UX Designer before Architect.

---

## Task 31 — Privacy settings screen + share token revocation

**Milestone:** 12
**ADRs:** ADR-042, ADR-043

**Why:** `privacy_principles.md` states users must be able to revoke a sharing card at any time. The current `sharedTravelCards` delete rule is broken (ADR-043 Part A). The UX Designer (ADR-042) moved sharing management out of the overflow menu into a new `PrivacyAccountScreen` push screen — destructive and privacy-related actions do not belong in a map action overflow.

**Acceptance criteria:**

- [ ] `firestore.rules`: `allow write` on `sharedTravelCards/{token}` split into `allow create, update` (using `request.resource.data.uid`) and `allow delete` (using `resource.data.uid`); owning user can now delete their document (ADR-043 Part A)
- [ ] `VisitRepository` gains `Future<void> clearShareToken()` — deletes the row where `id = 1` from `share_tokens`
- [ ] `ShareTokenService` gains:
  - `Future<void> revokeToken(String token, String uid)` — deletes Firestore doc AND calls `clearShareToken()` on the repo; fire-and-forget; logs errors; does not throw
  - `Future<void> revokeFirestoreOnly(String token, String uid)` — deletes Firestore doc only, no local state change (used by Task 32 account deletion, which handles local state via `clearAll()`)
- [ ] `MapScreen` overflow menu: "Share my map link" item **removed**; new "Privacy & account" item added (`Icons.security`); always visible to signed-in users; navigates (push) to `PrivacyAccountScreen`
- [ ] `PrivacyAccountScreen` (`lib/features/settings/privacy_account_screen.dart`) — new push `Scaffold` with a `ListView`:
  - Section header: "Sharing"
  - Row: shows sharing status — if token exists: "Your map is shared" with a "Remove link" `TextButton` (red); if no token: "Share your map" with a "Create link" `TextButton`
  - The screen loads the current token via `VisitRepository.getShareToken()` on `initState`; holds token in local state
- [ ] Tapping "Remove link" shows confirmation `AlertDialog`; copy per `docs/ux/tasks_31_32_privacy_actions.md`; on confirm calls `revokeToken`; screen reverts to no-token state
- [ ] Tapping "Create link" invokes the same share flow as the removed overflow item (calls `getOrCreateToken` + `publishVisits` + `Share.share`); token is cached in screen state after creation
- [ ] `dart analyze` reports zero issues
- [ ] Unit tests: `clearShareToken` deletes the row; `revokeToken` deletes Firestore doc and clears local token; `revokeFirestoreOnly` deletes Firestore doc and does NOT clear local token
- [ ] Widget tests: `MapScreen` — "Privacy & account" item visible; "Share my map link" absent; `PrivacyAccountScreen` — "Your map is shared" row visible when token exists; "Share your map" row visible when no token; confirmation dialog appears on "Remove link" tap

**Files to change:**
- `firestore.rules`
- `lib/data/visit_repository.dart` — add `clearShareToken()`
- `lib/features/sharing/share_token_service.dart` — add `revokeToken()` and `revokeFirestoreOnly()`
- `lib/features/map/map_screen.dart` — remove sharing overflow items; add "Privacy & account" item
- `lib/features/settings/privacy_account_screen.dart` (new)
- `test/data/visit_repository_test.dart`
- `test/features/sharing/share_token_service_test.dart`
- `test/features/map/map_screen_test.dart`
- `test/features/settings/privacy_account_screen_test.dart` (new)

**Dependencies:** Tasks 29–30 complete.

---

## Task 32 — Account deletion

**Milestone:** 12
**ADRs:** ADR-042, ADR-043

**Why:** `privacy_principles.md` and GDPR require that users can permanently delete their account and all associated data. Anonymous users can also delete their anonymous account.

**Acceptance criteria:**

- [ ] `PrivacyAccountScreen` gains an Account section (below the Sharing section):
  - Section header: "Account"
  - Row: "Delete account" with red label text; `Icons.delete_forever`; visible to all signed-in users including anonymous
- [ ] `AccountDeletionService` (`lib/features/account/account_deletion_service.dart`) — injectable class with constructor parameters `FirebaseAuth auth`, `FirebaseFirestore firestore`, `VisitRepository repo`, `ShareTokenService shareTokenService`; exposes `Future<void> deleteAccount(String uid, {String? shareToken})`
- [ ] Deletion sequence inside `deleteAccount` (per ADR-043):
  1. `await auth.currentUser!.delete()` — on `requires-recent-login`: rethrow; on other error: rethrow
  2. If `shareToken != null`: `unawaited(shareTokenService.revokeFirestoreOnly(shareToken, uid))`
  3. `await repo.clearAll()`
  4. Delete Firestore subcollections via batched `WriteBatch` (max 500 per batch), awaiting each batch:
     - `users/{uid}/inferred_visits/*`
     - `users/{uid}/user_added/*`
     - `users/{uid}/user_removed/*`
     - `users/{uid}/unlocked_achievements/*`
     Batch failures are logged and do not abort the sequence
- [ ] Tapping "Delete account" row in `PrivacyAccountScreen`:
  - Shows first `AlertDialog` (consequences); on confirm →
  - Shows second `AlertDialog` ("Are you sure?"); on confirm →
  - Shows non-dismissable loading `AlertDialog` ("Deleting your account…")
  - Calls `AccountDeletionService.deleteAccount`
  - On success: loading dialog auto-dismisses; `authStateProvider` emits `null`; `RoavvyApp` routes to `SignInScreen`
  - On `requires-recent-login`: loading dialog dismisses; `AlertDialog` shown with re-auth copy (per UX spec); no data deleted
  - On other error: loading dialog dismisses; `SnackBar` shown; `auth.signOut()` called; user routed to `SignInScreen`
- [ ] Anonymous users: `auth.delete()` does not throw `requires-recent-login`; deletion proceeds to completion
- [ ] `dart analyze` reports zero issues
- [ ] Unit tests (`account_deletion_service_test.dart`): all four Firestore subcollections deleted; `clearAll` called; `revokeFirestoreOnly` called when token provided; not called when token absent; `requires-recent-login` propagated to caller; Firestore batch failure does not prevent other steps
- [ ] Widget tests (`privacy_account_screen_test.dart`): "Delete account" row visible; two confirmation dialogs appear in sequence; loading dialog appears after second confirm

**Files to change:**
- `lib/features/account/account_deletion_service.dart` (new)
- `lib/features/settings/privacy_account_screen.dart` — add Account section + deletion flow
- `test/features/account/account_deletion_service_test.dart` (new)
- `test/features/settings/privacy_account_screen_test.dart` — extend with account deletion tests

**Dependencies:** Task 31 (`PrivacyAccountScreen` exists; `revokeFirestoreOnly` exists).

---

## Milestone 13 — Phase 4: Authenticated Web Map

**Goal:** A signed-in user can visit `roavvy.app/map` in a browser, sign in with Google, and see their visited countries highlighted on a world map.

**Background:**
Spike pages already exist in `apps/web_nextjs/`: `/app/auth/page.tsx`, `/app/map/page.tsx`, `/app/dashboard/page.tsx`, `contexts/AuthContext.tsx`, `lib/firebase/useUserVisits.ts`, `components/ProtectedRoute.tsx`, `components/SignInForm.tsx`, `components/SignUpForm.tsx`. Most must be replaced or substantially rewritten — they use email/password auth (wrong identity provider) and read from `users/{uid}/visits` (a Firestore path that does not exist; the correct paths are `inferred_visits`, `user_added`, `user_removed`).

**Build order:** Task 33 → Task 34 → Task 35. Each task can begin after the previous is complete.

**Risks / open questions:**
1. **Google-to-Apple account linking:** A user who signed in with Apple on mobile and signs in with Google on web will have two separate Firebase accounts. Their Firestore data lives under the Apple UID. The Google-signed-in web user will see an empty map. This is a known limitation for M13 — document it, do not solve it yet. Phase 4 will only work for users who have signed into the mobile app with an account that supports web sign-in (Google). Flag this in the UI if the map is empty: "No travel data found. Ensure you've scanned photos in the Roavvy app and are signed in with the same account."
2. **`npm run build` TypeScript strictness:** The spike pages have `any` types and console.log calls. The build must pass with zero TypeScript errors at the end of each task.
3. **Firestore rules:** The current `users/{userId}` wildcard allows `read, write`. Web should only read. This is acceptable for M13 (no write code paths in the web map page) but should be tightened in a future security review — flag in ADR.

**Architect sign-off:** Validated. ADR-044 (Google OAuth), ADR-045 (AuthContext + ProtectedRoute), ADR-046 (getDocs + effectiveVisits). Four corrections applied to the task specs below. No new packages required.

---

## Task 33 — Web sign-in page (Google OAuth)

**Milestone:** 13

**Why:** The `/map` page requires authentication. The existing spike uses email/password sign-in which is not the identity provider used on mobile. Replace it with Google Sign-In so users can sign in with the same Google-linked Firebase account. (Apple Sign-In on web is a separate OAuth flow with redirect complexity — deferred.)

**Scope — included:**
- `/sign-in` page (new route) with a single "Sign in with Google" button using `signInWithPopup` + `GoogleAuthProvider` from the Firebase Auth JS SDK
- On success, redirect to `/map`
- "View a shared map" link → `/` (home page) for unauthenticated visitors who want to use the share feature only
- Remove spike pages: `/app/auth/page.tsx`, `components/SignInForm.tsx`, `components/SignUpForm.tsx`
- `AuthContext.tsx` is retained with two targeted fixes (ADR-045): remove `setPersistence` call; register `onAuthStateChanged` directly (not inside an async function).
- `ProtectedRoute.tsx` is retained with one fix (ADR-045): redirect target `"/"` → `"/sign-in"`.

**Scope — excluded:**
- Apple Sign-In on web (deferred — complex redirect flow)
- Email/password sign-in (removed)

**Acceptance criteria:**
- [ ] `/sign-in` page renders with a "Sign in with Google" button and no other sign-in options
- [ ] Tapping the button calls `signInWithPopup(auth, new GoogleAuthProvider())`
- [ ] On successful sign-in, user is redirected to `/map`
- [ ] If user is already signed in and visits `/sign-in`, they are redirected to `/map` (no double sign-in)
- [ ] Spike pages (`/auth`, `SignInForm.tsx`, `SignUpForm.tsx`) are deleted
- [ ] `AuthContext.tsx`: `setPersistence` call removed; `onAuthStateChanged` registered synchronously in `useEffect` (ADR-044, ADR-045)
- [ ] `ProtectedRoute.tsx`: `router.push("/")` → `router.push("/sign-in")` only; no other changes (ADR-045)
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors

**Files to change:**
- `src/app/sign-in/page.tsx` (new)
- `src/contexts/AuthContext.tsx` — targeted fix only (remove `setPersistence` + async wrapper)
- `src/components/ProtectedRoute.tsx` — one-line fix only (redirect target)
- `src/app/auth/page.tsx` — delete
- `src/components/SignInForm.tsx` — delete
- `src/components/SignUpForm.tsx` — delete

**Dependencies:** None. Task 30 (web app scaffolded) complete.

---

## Task 34 — Effective visits TypeScript function + `useUserVisits` rewrite

**Milestone:** 13

**Why:** The existing `useUserVisits.ts` hook reads from `users/{uid}/visits` — a Firestore collection that does not exist. The actual schema (ADR-029) is three subcollections: `inferred_visits`, `user_added`, `user_removed`. The effective visited country set requires merging all three using the same logic as `effectiveVisitedCountries()` in `packages/shared_models` (Dart). This TypeScript equivalent must be written before the `/map` page can render real data.

**Acceptance criteria:**
- [ ] `src/lib/firebase/effectiveVisits.ts` (new) — pure function `effectiveVisits(inferred: string[], added: string[], removed: string[]): string[]` that returns the set of effective visited country codes: `(inferred ∪ added) − removed`. No Firestore or React dependency — pure logic.
- [ ] Unit tests for `effectiveVisits`: empty inputs return `[]`; inferred alone works; added adds countries not in inferred; removed suppresses both inferred and added entries; duplicates handled correctly; **all three inputs supplied simultaneously returns correct merged result** (ADR-046 requirement). Use Jest (already in the Next.js project).
- [ ] `src/lib/firebase/useUserVisits.ts` rewritten: reads `users/{uid}/inferred_visits`, `users/{uid}/user_added`, `users/{uid}/user_removed` using `getDocs` (one-shot — **not** `onSnapshot`); doc IDs are the country codes; calls `effectiveVisits()`; returns `{ visitedCodes: string[], loading: boolean, error: string | null }` (ADR-046)
- [ ] Remove console.log statements from `useUserVisits.ts`
- [ ] Old `CountryVisit` interface and `visits` field removed (replaced by `visitedCodes: string[]`)
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors
- [ ] Jest tests pass: `npm test`

**Files to change:**
- `src/lib/firebase/effectiveVisits.ts` (new)
- `src/lib/firebase/effectiveVisits.test.ts` (new)
- `src/lib/firebase/useUserVisits.ts` — rewrite

**Dependencies:** Task 33 complete (AuthContext stable).

---

## Task 35 — Production `/map` page

**Milestone:** 13

**Why:** The existing `/map/page.tsx` spike uses the wrong data hook, has console.logs, no stats header, no sign-out, and minimal error handling. Replace it with a production-quality page.

**Acceptance criteria:**
- [ ] `/map` page is protected: unauthenticated users are redirected to `/sign-in`
- [ ] On load, calls the rewritten `useUserVisits` hook to fetch visited country codes
- [ ] Stats header displays: "N countries visited" (N from `visitedCodes.length`); if 0 countries, shows "No travel data yet. Open the Roavvy app and scan your photos."
- [ ] Map renders using existing `DynamicMap` + `Map` components; visited countries highlighted green (`#2D6A4F`)
- [ ] Sign-out button in the header: calls `signOut(auth)`; on success, redirects to `/sign-in`
- [ ] Loading state: spinner or skeleton shown while `useUserVisits` is fetching
- [ ] Error state: user-facing message if Firestore fetch fails
- [ ] Empty-map state: message "No travel data yet. Open the Roavvy app and scan your photos." if `visitedCodes.length === 0`
- [ ] Spike pages `/app/dashboard/page.tsx` deleted; `/app/map/page.tsx` replaced (not amended)
- [ ] Remove all `console.log` statements
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors

**Files to change:**
- `src/app/map/page.tsx` — replace
- `src/app/dashboard/page.tsx` — delete

**Dependencies:** Tasks 33 + 34 complete.

---

## Milestone 14 — Phase 4: Shop & Merchandise

**Goal:** A user can visit `roavvy.app/shop`, browse travel merchandise, personalise a product with their visited countries, and complete a purchase via Shopify checkout.

**Background:**
This is the primary revenue milestone. The personalisation flow requires: (1) the user's country set from Firestore (requires sign-in), (2) a map preview generated from those countries, (3) a Shopify cart with the country list as a custom line item attribute for fulfilment.

**Risks / open questions before starting:**
1. **Shopify store prerequisite:** A Shopify store must exist, a Storefront API access token must be provisioned, and at least one product must be published before Task 36 can complete. This is a business/operations dependency — confirm before the Architect reviews.
2. **Canvas export feasibility:** The Leaflet map renders using SVG-based GeoJSON layers. `canvas.toDataURL()` only exports canvas elements. Leaflet's GeoJSON layer is SVG by default, not canvas. A spike (part of Task 37) must confirm whether `leaflet-canvas-renderer` or a SVG-to-canvas conversion (`html-to-image` or `dom-to-image`) can produce a clean PNG export at print resolution. This is the highest technical risk in M14.
3. **Shopify fulfilment:** The mechanism for passing the personalisation data (country codes) to a physical printer is not defined. M14 scopes to storing `visitedCodes` as a Shopify line item custom attribute — how the printer uses it is an operations problem, not a code problem.
4. **Apple Sign-In gap:** Users who signed in with Apple on mobile cannot sign into the web shop. They will not be able to personalise. This is the same limitation as M13. Consider offering a guest personalisation path (enter countries manually) in a later iteration.

**Build order:** Task 36 → Task 37 → Task 38.

---

## Task 36 — Shop landing page + Shopify Storefront API

**Milestone:** 14

**Why:** Establish the Shopify connection and build the public entry point for the shop. No sign-in required to browse products.

**Acceptance criteria:**
- [ ] Shopify Storefront API access token stored in `.env.local` as `NEXT_PUBLIC_SHOPIFY_STORE_DOMAIN` and `NEXT_PUBLIC_SHOPIFY_STOREFRONT_ACCESS_TOKEN` (or server-side env vars if using Server Components)
- [ ] `src/lib/shopify/client.ts` (new) — minimal Shopify Storefront API client using `fetch` and GraphQL; exports `getProducts(): Promise<Product[]>` (no third-party SDK — raw fetch)
- [ ] `Product` type: `{ id: string, title: string, description: string, priceRange: { minVariantPrice: { amount: string, currencyCode: string } }, images: { nodes: { url: string, altText: string | null }[] } }`
- [ ] `/shop` page (new): fetches products server-side (Next.js `async` Server Component); renders a product grid; each product card shows image, title, price, and a "Personalise" CTA button linking to `/shop/personalise?productId={id}`
- [ ] `/shop` is publicly accessible (no auth required)
- [ ] Loading and error states handled
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors

**Files to change:**
- `src/lib/shopify/client.ts` (new)
- `src/lib/shopify/types.ts` (new)
- `src/app/shop/page.tsx` (new)

**Dependencies:** Milestone 13 complete. Shopify store + Storefront API token available (operations prerequisite).

---

## Task 37 — Personalisation preview + Shopify cart + checkout

**Milestone:** 14

**Why:** The core commercial flow: user sees their map on the product, adds it to a Shopify cart, and checks out.

**Acceptance criteria:**
- [ ] `/shop/personalise` page (new): requires sign-in (redirect to `/sign-in?next=/shop/personalise` if not authenticated); reads `productId` query param; fetches product details from Shopify; fetches user's visited country codes via `useUserVisits`
- [ ] Personalisation preview: renders `DynamicMap` with the user's visited countries in a fixed-size container (matching the product's aspect ratio where possible); "Your map" label above the preview
- [ ] Map-to-image export: implement `captureMapImage(): Promise<Blob>` in `src/lib/mapExport.ts` using `html-to-image` or equivalent; exports the map preview container to a PNG `Blob`; if export fails, personalisation can still proceed without the image (graceful degradation — the `visitedCodes` custom attribute is the source of truth for fulfilment)
- [ ] "Add to Cart" button: calls Shopify Storefront API `cartCreate` mutation with line item `{ merchandiseId: variantId, quantity: 1, attributes: [{ key: "visitedCodes", value: JSON.stringify(visitedCodes) }] }`; on success, redirects to `cart.checkoutUrl`
- [ ] Loading state during cart creation; error state if cart creation fails
- [ ] If user has zero visited countries: show "No travel data yet" message instead of the personalisation UI; no "Add to Cart" button
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors

**Files to change:**
- `src/app/shop/personalise/page.tsx` (new)
- `src/lib/mapExport.ts` (new)
- `src/lib/shopify/client.ts` — add `getProduct(id)` and `cartCreate` mutation

**Dependencies:** Tasks 33 + 34 + 36 complete.

---

## Task 38 — Web share page: referral CTA

**Milestone:** 14

**Why:** The `/share/[token]` page is a natural acquisition touchpoint — someone receives a sharing link, sees the map, and downloads the app. Adding a "Get Roavvy" CTA closes the referral loop. This is low-effort, high-impact, and belongs in M14 (revenue milestone) because it also links to the shop.

**Acceptance criteria:**
- [ ] Bottom banner added to `/share/[token]/page.tsx`: "Make your own travel map — Download Roavvy" with an App Store badge linking to the Roavvy App Store listing URL (use a placeholder URL until the listing exists; put it in an env var `NEXT_PUBLIC_APP_STORE_URL`)
- [ ] Banner is visually distinct from the map content; does not obscure the map
- [ ] Banner also includes a "View in shop" link to `/shop`
- [ ] `npm run build` produces zero TypeScript errors and zero ESLint errors

**Files to change:**
- `src/app/share/[token]/page.tsx` — add referral banner

**Dependencies:** Task 36 complete (so the `/shop` link works).

---

## Milestone 15 — Phase 5: Polish & App Store Readiness

**Goal:** The iOS app is ready to submit to the App Store. First-launch experience is complete. The app can be reviewed and approved by Apple.

**Background:**
Phase 5 is the final milestone before public launch. The core functionality is complete. This milestone focuses on: (1) the first-time user experience (onboarding), (2) App Store compliance requirements (privacy manifest, entitlements), (3) app store assets, and (4) the achievement animation deferred from Phase 2. Push notifications and iPad layout are lower priority and may slip to post-launch.

**Build order:** Task 39 → Task 40 → Task 41 → Task 42. Task 39 (onboarding) is highest priority because it changes the app launch flow and must be stable before screenshots are taken.

**Risks / open questions:**
1. **Privacy manifest (`PrivacyInfo.xcprivacy`):** Apple has required privacy manifests for all apps since Spring 2024. Any SDK that uses "required reason APIs" (including `UserDefaults`, file timestamps, disk space) must declare its usage. If the current app or any dependency uses these without a manifest, App Store submission will be rejected. The Builder must audit dependencies.
2. **Photo library permission string:** The `NSPhotoLibraryUsageDescription` in `Info.plist` must clearly state that only location metadata (not images) is accessed. Apple reviewers may scrutinise this given the privacy-sensitive nature of the permission.
3. **App icon:** A final app icon must exist at all required sizes before screenshots can be taken. This may require design work outside the codebase.
4. **Achievement animation scope:** Keep simple — a slide-up sheet or overlay with the achievement title and icon. Do not block the build on complex animation work.

---

## Task 39 — Onboarding flow

**Milestone:** 15

**Why:** First-launch users currently see the map empty state ("Scan your photos to see where you've been") with no explanation of what the app does or why it needs photo access. Apple reviewers expect a clear permission rationale before the system prompt appears. Without onboarding, first-time user conversion (permission grant rate) will be low.

**Acceptance criteria:**
- [ ] `OnboardingScreen` widget (`lib/features/onboarding/onboarding_screen.dart`): shown only on first launch; consists of two pages in a `PageView`:
  - Page 1: App name + tagline "Your photos already know where you've been." + brief description + [Next] button
  - Page 2: Permission rationale "Roavvy reads when and where your photos were taken. Your photos never leave your device." + [Scan My Photos] primary button + [Not now] secondary button
- [ ] First-launch detection: `RoavvyApp` checks `VisitRepository.loadLastScanAt()` AND `VisitRepository.loadEffective()` on startup; if both return empty/null, onboarding is shown before the main shell
- [ ] [Scan My Photos] on page 2 dismisses onboarding, shows the main shell, and triggers the scan flow (navigates to Scan tab + starts scan)
- [ ] [Not now] dismisses onboarding and shows the main shell at the map screen (empty state)
- [ ] Once the user has completed at least one scan, onboarding is never shown again (governed by `loadLastScanAt()` returning non-null)
- [ ] Onboarding does NOT request photo permissions — it only provides rationale before the user taps [Scan My Photos], after which the existing permission request flow runs
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: onboarding shown when no scan history; onboarding not shown when scan history exists; [Not now] leads to main shell; [Scan My Photos] triggers scan navigation

**Files to change:**
- `lib/features/onboarding/onboarding_screen.dart` (new)
- `lib/app.dart` — add first-launch check before routing to `MainShell`
- `test/features/onboarding/onboarding_screen_test.dart` (new)

**Dependencies:** Task 32 complete. `VisitRepository.loadLastScanAt()` and `loadEffective()` exist.

---

## Task 40 — Achievement unlock animation

**Milestone:** 15

**Why:** The achievement unlock SnackBar (Task 25) is functional but not delightful. An animated overlay when a new achievement is unlocked creates a memorable moment and reinforces the gamification. This was deferred from Phase 2.

**Acceptance criteria:**
- [ ] `AchievementUnlockOverlay` widget (`lib/features/achievements/achievement_unlock_overlay.dart`): takes an `Achievement` as input; displays a slide-up, auto-dismissing overlay (bottom sheet or stack overlay) showing the achievement icon, title, and "Achievement Unlocked!" heading; duration 3 seconds; dismissable by tap
- [ ] The existing SnackBar shown on achievement unlock (Task 25) is replaced by `AchievementUnlockOverlay`; if multiple achievements unlock at once, show them in sequence (one at a time, each 3 seconds apart)
- [ ] Triggered from the same two sites as the SnackBar: after scan completes (`scan_screen.dart`) and after review saves (`review_screen.dart`)
- [ ] Animation: slide up from bottom (300 ms ease-in), hold, slide down (200 ms ease-out)
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: overlay appears with correct achievement title; overlay dismisses after tap; does not appear when no new achievements

**Files to change:**
- `lib/features/achievements/achievement_unlock_overlay.dart` (new)
- `lib/features/scan/scan_screen.dart` — replace SnackBar with overlay
- `lib/features/visits/review_screen.dart` — replace SnackBar with overlay
- `test/features/achievements/achievement_unlock_overlay_test.dart` (new)

**Dependencies:** Task 25 complete (achievement evaluation at write sites exists).

---

## Task 41 — Privacy manifest + App Store compliance

**Milestone:** 15

**Why:** Apple requires a `PrivacyInfo.xcprivacy` file for all apps submitted since Spring 2024. Without it, the submission will be rejected. The photo library permission description must also be accurate and specific. This task ensures the app passes App Store review on first submission.

**Acceptance criteria:**
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` created and added to the Xcode target; declares:
  - `NSPrivacyAccessedAPITypes`: any required-reason APIs used by the app or its dependencies (audit using `find . -name "*.xcprivacy"` on dependencies; check for `UserDefaults`, file timestamps, disk space APIs)
  - `NSPrivacyCollectedDataTypes`: `Location` (used for country detection from photo EXIF, not collected), `Photos` (metadata only, not images)
  - `NSPrivacyTrackingEnabled: false`
- [ ] `ios/Runner/Info.plist` — `NSPhotoLibraryUsageDescription` updated to: "Roavvy reads the location and date from your photos to build your travel map. Your photos never leave your device."
- [ ] App icon: all required sizes present in `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` (1024×1024 for App Store; 60×60, 87×87, 120×120, 180×180 for device); placeholder icon is acceptable for review if design is not complete
- [ ] `flutter build ios --release` completes without errors or warnings about missing icons or entitlements
- [ ] No API keys, credentials, or secrets appear in any committed file (audit `ios/`, `lib/`, `GoogleService-Info.plist` — the plist should be in `.gitignore` if it contains a real Firebase project)

**Files to change:**
- `ios/Runner/PrivacyInfo.xcprivacy` (new)
- `ios/Runner/Info.plist` — update permission string
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — add final icon sizes
- `ios/Runner.xcodeproj/project.pbxproj` — add PrivacyInfo.xcprivacy to build phases

**Dependencies:** Task 39 complete (app flow finalised before release build).

---

## Task 42 — App Store metadata + screenshots

**Milestone:** 15

**Why:** App Store submission requires metadata (title, subtitle, description, keywords, support URL, privacy policy URL) and screenshots. These cannot be skipped. Screenshots must be taken from the final build with real-looking data.

**Acceptance criteria:**
- [ ] App Store Connect listing prepared with:
  - Name: "Roavvy"
  - Subtitle: "Your Travel Map" (or equivalent ≤ 30 chars)
  - Description: ≥ 3 paragraphs covering core value prop, privacy stance, and sharing feature
  - Keywords: ≤ 100 chars total; include "travel map", "countries visited", "photo travel", "world map"
  - Support URL: valid URL (can be the `roavvy.app` domain with a support page or GitHub issues)
  - Privacy Policy URL: required; a minimal privacy policy page at `roavvy.app/privacy` referencing the privacy principles doc is sufficient
- [ ] Screenshots: 6.7" iPhone (iPhone 15 Pro Max) — 5 screenshots showing: (1) world map with visited countries, (2) scan in progress, (3) country detail sheet, (4) sharing card, (5) achievement SnackBar or overlay
- [ ] `docs/marketing/app_store_metadata.md` created with all the above text content committed to the repo (source of truth; copied into App Store Connect manually or via Fastlane)

**Files to change:**
- `docs/marketing/app_store_metadata.md` (new)
- No code changes — this task is content and ops

**Dependencies:** Task 40 complete (achievement animation done before screenshots). Task 41 complete (final build working).

---

## Planner sign-off — Milestone 13 (Tasks 33–35)

**Plan complete: 2026-03-17**
**Note:** Tasks 36–42 originally planned here (old M14 Shopify + M15 App Store) are superseded by the revised roadmap (2026-03-18). See new M15 plan below.

**Task sequence (M13 only):**

| Task | Name | Milestone | Component |
|------|------|-----------|-----------|
| 33 | Web sign-in page | 13 | Web |
| 34 | Effective visits TS function + `useUserVisits` rewrite | 13 | Web |
| 35 | Production `/map` page | 13 | Web |

---

## Milestone 15 — Trip Intelligence

**Goal:** Every country visit is broken into individual trips with inferred start/end dates. Users can see how many times they've been to each country, browse their trip history per country, and add or edit trips manually.

**Scope — included:**
- `PhotoDateRecord`: lightweight per-photo country + timestamp storage; populated during scan
- `TripRecord` domain model: id, countryCode, startedOn, endedOn, photoCount, isManual
- Trip inference engine: pure Dart function in `shared_models`; clusters photo dates by 30-day gap threshold
- Drift schema v4: two new tables (`photo_date_records`, `trips`); repositories for both
- Scan pipeline wiring: save `PhotoDateRecord`s as scan runs; run inference after scan completes
- Existing-user migration: bootstrap one trip per country from `firstSeen`/`lastSeen` on first launch after upgrade
- `CountryDetailSheet` extension: trip count + scrollable trip card list
- Manual trip: add, edit dates, delete
- `clearAll()` extended to wipe new tables
- Firestore sync: dirty/clean pattern extended to `trips` table; `users/{uid}/trips/{tripId}`

**Scope — excluded:**
- Region/city detection (M16)
- Photo gallery (M17)
- Journal tab and navigation redesign (M17)

**Architectural constraint — why we need `PhotoDateRecord`:**
The current scan pipeline aggregates all photos per country into a single `InferredCountryVisit` row (firstSeen, lastSeen, photoCount). Individual photo timestamps are discarded after aggregation. Trip inference requires multiple timestamps per country to detect gaps. The `PhotoDateRecord` table provides this: one lightweight row per geotagged photo (country_code + captured_at). Storage cost: ~50 bytes × 10,000 photos = 500 KB — acceptable for SQLite.

---

### Task 36 — `PhotoDateRecord` + Drift schema v4 + repositories

**Deliverable:**
- `PhotoDateRecord` class in `shared_models`: `countryCode`, `capturedAt` (non-nullable)
- `TripRecord` class in `shared_models`: `id` (UUID string), `countryCode`, `startedOn`, `endedOn`, `photoCount`, `isManual` (bool)
- Drift schema v4: adds `PhotoDateRecords` table (countryCode TEXT PK-free, capturedAt DATETIME) and `Trips` table (id TEXT PK, countryCode TEXT, startedOn DATETIME, endedOn DATETIME, photoCount INT, isManual INT, isDirty INT default 1, syncedAt TEXT nullable)
- `MigrationStrategy` in `RoavvyDatabase`: `from3to4` creates both new tables
- `TripRepository`: `upsertAll(List<TripRecord>)`, `loadAll()`, `loadByCountry(String)`, `loadDirty()`, `markClean(String id, DateTime)`, `delete(String id)`, `clearAll()`
- `VisitRepository` extended: `savePhotoDates(List<PhotoDateRecord>)`, `loadPhotoDates()`, `clearPhotoDates()`
- Tests: `TripRepository` unit tests (in-memory Drift DB); `VisitRepository` photo-date methods tested

**Acceptance criteria:**
- [ ] Drift schema migrates cleanly from v3 → v4 without data loss on existing install
- [ ] `TripRecord` and `PhotoDateRecord` are in `shared_models` with `==` and `hashCode`
- [ ] `TripRepository.upsertAll` + `loadByCountry` round-trips correctly
- [ ] `VisitRepository.savePhotoDates` + `loadPhotoDates` round-trips correctly
- [ ] All new repository methods covered by tests
- [ ] `dart run build_runner build` in `apps/mobile_flutter` regenerates `.g.dart` without errors

**Files to create/modify:**
- `packages/shared_models/lib/src/photo_date_record.dart` (new)
- `packages/shared_models/lib/src/trip_record.dart` (new)
- `packages/shared_models/lib/shared_models.dart` (export both)
- `apps/mobile_flutter/lib/data/db/roavvy_database.dart` (add tables + migration)
- `apps/mobile_flutter/lib/data/db/roavvy_database.g.dart` (regenerated)
- `apps/mobile_flutter/lib/data/trip_repository.dart` (new)
- `apps/mobile_flutter/lib/data/visit_repository.dart` (add photo-date methods)
- `apps/mobile_flutter/test/data/trip_repository_test.dart` (new)
- `apps/mobile_flutter/test/data/visit_repository_test.dart` (extend)

---

### Task 37 — Trip inference engine

**Deliverable:**
- `inferTrips(List<PhotoDateRecord> records, {Duration gap = const Duration(days: 30)}) → List<TripRecord>` pure function in `shared_models`
- Algorithm: group by `countryCode`; sort each group by `capturedAt`; walk the sorted list splitting on gaps ≥ `gap`; each cluster → one `TripRecord` (startedOn = first, endedOn = last, photoCount = count, isManual = false, id = UUID v4 deterministic from `"${countryCode}_${startedOn.toIso8601String()}"`)
- Test suite: ≥ 10 tests covering: empty input, single photo, two photos same country same day, two photos same country 60 days apart (→ 2 trips), mixed countries, gap exactly 30 days (→ boundary case), gap 29 days (→ same trip), manual trips not overwritten by inference (engine only produces isManual=false), large input (100 records, asserts correct trip count)

**Acceptance criteria:**
- [ ] `inferTrips([], ...)` returns `[]`
- [ ] Two photos in the same country 60 days apart → 2 trips
- [ ] Two photos in the same country 29 days apart → 1 trip
- [ ] Photos from different countries do not contaminate each other's clusters
- [ ] `TripRecord.startedOn` equals the earliest `capturedAt` in the cluster
- [ ] `TripRecord.endedOn` equals the latest `capturedAt` in the cluster
- [ ] `TripRecord.photoCount` equals the number of photos in the cluster
- [ ] All tests pass via `cd packages/shared_models && dart test`

**Files to create/modify:**
- `packages/shared_models/lib/src/trip_inference.dart` (new — pure function)
- `packages/shared_models/lib/shared_models.dart` (export)
- `packages/shared_models/test/trip_inference_test.dart` (new)

---

### Task 38 — Wire scan pipeline + existing-user migration

**Deliverable:**
- During scan: in `ScanScreen`'s batch handler, for each resolved `PhotoRecord` with a non-null `capturedAt` and a resolved `countryCode`, call `visitRepository.savePhotoDates([PhotoDateRecord(...)])` in the same batch write as `saveAllInferred`
- After scan: call `inferTrips(await visitRepository.loadPhotoDates())` and upsert results to `TripRepository`
- Existing-user bootstrap: on app startup (in `main()` or a `FutureProvider`), if `visitRepository.loadPhotoDates()` is empty AND `visitRepository.loadInferred()` is non-empty, synthesise one `TripRecord` per country using `firstSeen` as `startedOn`, `lastSeen` as `endedOn`, `photoCount` from the inferred row; upsert these; set a `bootstrapComplete` flag in `ScanMetadata` (or a new preference key) so this runs only once
- `VisitRepository.clearAll()` extended to also call `clearPhotoDates()` and `TripRepository.clearAll()`
- `tripRepositoryProvider` added to `lib/core/providers.dart`

**Acceptance criteria:**
- [ ] After a scan on a clean install, `TripRepository.loadAll()` returns ≥ 1 trip for each country with ≥ 1 geotagged photo
- [ ] Re-scanning does not duplicate trips (upsert by id is idempotent)
- [ ] `VisitRepository.clearAll()` wipes all three new table sets (photo_date_records, trips)
- [ ] On an existing install (v3 data, no photo_date_records), bootstrap runs once and produces one trip per country
- [ ] Bootstrap does not re-run on subsequent launches (flag persisted)
- [ ] Widget tests for `ScanScreen` still pass (use `NoOpSyncService`)

**Files to create/modify:**
- `apps/mobile_flutter/lib/features/scan/scan_screen.dart` (batch handler + post-scan inference)
- `apps/mobile_flutter/lib/data/visit_repository.dart` (extend `clearAll`)
- `apps/mobile_flutter/lib/core/providers.dart` (add `tripRepositoryProvider`)
- `apps/mobile_flutter/lib/main.dart` (bootstrap startup logic)

---

### Task 39 — Country detail: trip count + trip list

**Deliverable:**
- `CountryDetailSheet` reads from `tripRepositoryProvider` to get trips for the tapped country
- Sheet header updated: "X trips · First visited [year]" replaces the existing date-range text
- Below existing visit info: a scrollable list of trip cards; each card shows:
  - Date range: "14 Jul – 28 Jul 2023"
  - Duration: "14 days"
  - Photo count: "📷 43 photos" (from `TripRecord.photoCount`)
  - Manual badge if `isManual == true`
- If only 1 trip: show "1 trip" (singular)
- If 0 trips (manually added country with no photo data): show "No trip data — add a trip manually" with the add button
- [+ Add trip manually] button at the bottom of the list; taps open the add-trip sheet (implemented in Task 40)
- `CountryDetailSheet` widget test extended: test "X trips" label renders correctly; test empty-trips state

**Acceptance criteria:**
- [ ] Sheet renders trip count from repository (not hardcoded)
- [ ] Each trip card shows correct date range, duration, photo count
- [ ] Manually added trips show "Added manually" badge
- [ ] "0 trips" state shows empty-state copy and add button
- [ ] `CountryDetailSheet` widget tests pass

**Files to create/modify:**
- `apps/mobile_flutter/lib/features/map/country_detail_sheet.dart`
- `apps/mobile_flutter/test/features/map/country_detail_sheet_test.dart`

---

### Task 40 — Manual trip: add, edit, delete

**Deliverable:**
- **Add trip sheet**: modal bottom sheet with two date pickers (start date, end date); validates end ≥ start; on confirm, writes `TripRecord` with `isManual = true` to `TripRepository`; dismisses sheet and refreshes trip list
- **Edit trip sheet**: same sheet, pre-populated from existing `TripRecord`; on confirm, upserts with same id
- **Delete trip**: long-press or leading swipe action on trip card; shows confirmation `AlertDialog` ("Delete this trip?"); on confirm, calls `TripRepository.delete(id)`; refreshes list
- After any mutation: invalidate `travelSummaryProvider` (trip count feeds into stats strip eventually)

**Acceptance criteria:**
- [ ] Add trip with valid dates → appears in trip list immediately
- [ ] Add trip with end before start → validation error shown; no write
- [ ] Edit trip → updated dates shown immediately
- [ ] Delete trip → removed from list; confirmation required
- [ ] No crash if user dismisses add/edit sheet without saving
- [ ] Widget tests: add-trip sheet validation; delete confirmation dialog

**Files to create/modify:**
- `apps/mobile_flutter/lib/features/map/country_detail_sheet.dart` (add/edit/delete wiring)
- `apps/mobile_flutter/lib/features/visits/trip_edit_sheet.dart` (new — add/edit sheet)
- `apps/mobile_flutter/test/features/map/country_detail_sheet_test.dart` (extend)
- `apps/mobile_flutter/test/features/visits/trip_edit_sheet_test.dart` (new)

---

### Task 41 — Firestore sync for trips

**Deliverable:**
- `TripRepository.loadDirty()` returns all rows where `isDirty = 1`
- `TripRepository.markClean(String id, DateTime syncedAt)` sets `isDirty = 0` + `syncedAt`
- `FirestoreSyncService.flushDirty(uid, repo)` signature extended to accept `TripRepository`; flushes dirty trips to `users/{uid}/trips/{trip.id}` as `{countryCode, startedOn, endedOn, photoCount, isManual}`; marks clean on success
- `NoOpSyncService` updated to no-op the trip flush
- Called fire-and-forget at the same sites as existing dirty-flushes (post-scan, post-review-save)
- Firestore rules: `users/{uid}/trips/{tripId}` — allow read, write if `request.auth.uid == uid`

**Acceptance criteria:**
- [ ] After a scan with Apple sign-in active, dirty trip rows are flushed to Firestore
- [ ] Re-running flush on already-clean rows makes no Firestore writes
- [ ] `NoOpSyncService` satisfies the updated interface (widget tests unaffected)
- [ ] `FirestoreSyncService` unit tests cover trip flush (happy path + failure leaves row dirty)
- [ ] `firestore.rules` updated and passes existing security tests

**Files to create/modify:**
- `apps/mobile_flutter/lib/data/trip_repository.dart` (dirty/clean methods)
- `apps/mobile_flutter/lib/data/firestore_sync_service.dart` (extend interface + implementation)
- `apps/mobile_flutter/test/data/firestore_sync_service_test.dart` (extend)
- `firestore.rules` (add trips subcollection rule)

---

## Planner sign-off — Milestone 15

**Plan complete: 2026-03-18**

**Task sequence:**

| Task | Name | Milestone | Component |
|------|------|-----------|-----------|
| 36 | `PhotoDateRecord` + Drift schema v4 + repositories | 15 | Flutter + shared_models |
| 37 | Trip inference engine | 15 | shared_models |
| 38 | Wire scan pipeline + existing-user migration | 15 | Flutter |
| 39 | Country detail: trip count + trip list | 15 | Flutter |
| 40 | Manual trip: add, edit, delete | 15 | Flutter |
| 41 | Firestore sync for trips | 15 | Flutter + Firestore |

**Key risks and open questions:**

1. **PhotoDateRecord volume**: power users may have 50,000+ geotagged photos. 50k rows at ~50 bytes = 2.5 MB. Within SQLite limits; confirm with a realistic test device before declaring complete.
2. **Existing-user bootstrap accuracy**: bootstrap creates one trip per country from `firstSeen`/`lastSeen`. Users with multiple trips to one country will see a single inaccurate trip until they re-scan. Copy in the bootstrap state should be: "Scan your photos to discover all your trips." Must not create false confidence.
3. **`capturedAt` null rate**: `PhotoRecord.capturedAt` is nullable (photos without creation date). Photos with null `capturedAt` contribute to `InferredCountryVisit.photoCount` but cannot generate `PhotoDateRecord` rows — they are silently excluded from trip inference. This is acceptable; flag in comments.
4. **Trip id stability**: trip ids are derived from `"${countryCode}_${startedOn.toIso8601String()}"`. If a user edits trip dates, the id changes and the old Firestore document is orphaned. Architect must decide: stable UUID on creation (ignore date changes) vs. re-derive on edit. Recommend stable UUID assigned at creation.
5. **Drift code generation**: adding new tables requires running `dart run build_runner build` in `apps/mobile_flutter`. Builder must do this as part of Task 36. The `.g.dart` file must be committed.

---

## Architect sign-off — Milestone 15 (Tasks 36–41)

**Plan validated with the following corrections. All corrections are mandatory before the Builder starts.**

---

### Correction 1 — Schema version is v6, not v4 (affects Task 36)

The Planner refers to "Drift schema v4" throughout. **This is wrong.** The current `RoavvyDatabase.schemaVersion` is **5** (v4 added `unlocked_achievements`; v5 added `share_tokens`). M15 must migrate to **v6**.

**Builder must change:**
- `schemaVersion` → `6`
- Migration block: `if (from < 6) { ... }` (not `from3to4`)
- All task descriptions that say "schema v4" should be read as "schema v6"

---

### Correction 2 — Trip IDs: natural key for inferred, prefixed hex for manual (ADR-047)

The Planner's Task 37 says: `id = UUID v4 deterministic from "${countryCode}_${startedOn.toIso8601String()}"`. **Decision: use the natural key string directly, not a UUID derived from it.** (ADR-047)

**Rules:**
- **Inferred trips:** `id = "${countryCode}_${startedOn.toIso8601String()}"` (e.g. `"FR_2023-07-14T00:00:00.000Z"`). This is the Drift primary key. `upsertAll()` uses `insertOrReplace` — re-inference updates `endedOn` and `photoCount` in place.
- **Manual trips:** `id = "manual_${8-char random hex}"` (same RNG as share tokens, ADR-041). The `"manual_"` prefix prevents collisions with inferred keys.
- **Manual edit of `startedOn`:** Task 40 must call `TripRepository.delete(oldId)` then upsert with the new id, and queue the old Firestore document for deletion.

**Why natural key is stable:** Incremental scans only add photos after `sinceDate`. New photos extend `endedOn` and grow `photoCount` — they do not shift `startedOn`. So the key is stable across all normal use. Full re-scan edge case: if an earlier photo is found, `startedOn` shifts and the old Firestore document is orphaned. This is rare and the orphan is harmless.

**`inferTrips()` stays pure.** No DB reads needed before inference. The function derives IDs deterministically from its inputs.

---

### Correction 3 — `photo_date_records` must have a composite primary key (ADR-048)

The Planner's table definition has no primary key. **Without a PK, incremental re-scans create duplicate rows**, causing `photoCount` inflation and duplicate inferred trips.

**Builder must add:**
```dart
@override
Set<Column> get primaryKey => {countryCode, capturedAt};
```
to the `PhotoDateRecords` Drift table class.

---

### Correction 4 — Bootstrap flag location: `ScanMetadata.bootstrapCompletedAt` (ADR-048)

Task 38 leaves the bootstrap-complete flag location open ("ScanMetadata or a new preference key"). **Decision: add a `bootstrapCompletedAt TEXT nullable` column to `ScanMetadata` in the v6 migration.**

**Builder must add** in `roavvy_database.dart`:
- New column: `TextColumn get bootstrapCompletedAt => text().nullable()();` to `ScanMetadata`
- v6 migration: `await m.addColumn(scanMetadata, scanMetadata.bootstrapCompletedAt);`

`VisitRepository` gains:
- `saveBootstrapCompletedAt(DateTime)` → writes ISO 8601 string to `ScanMetadata` row id=1
- `loadBootstrapCompletedAt() → Future<DateTime?>` → reads it

Bootstrap check in Task 38: `if (await loadBootstrapCompletedAt() == null && photoDateRecords.isEmpty && inferred.isNotEmpty) { ... save bootstrap trips ... saveBootstrapCompletedAt(DateTime.now()); }`

---

### Correction 5 — `clearAll()` wipes `photo_date_records`, all `trips`, and `bootstrapCompletedAt` (ADR-048)

The Planner says `clearAll()` wipes the new tables. Clarification: **all trips are cleared, including `isManual = true` trips.** "Delete travel history" is a full reset. Manual trips are part of the travel record (same rationale as `UserAddedCountries`).

Additionally, `bootstrapCompletedAt` must be nulled so the bootstrap re-runs after a full reset (the user effectively starts fresh).

---

### Correction 6 — `CountryDetailSheet` must become a `ConsumerWidget`

`CountryDetailSheet` currently reads providers via `Consumer` or is passed data. Task 39 requires it to read `tripRepositoryProvider`. **Builder must convert `CountryDetailSheet` to a `ConsumerWidget`** (if not already) so it can call `ref.watch(tripRepositoryProvider)` directly. Do not pass the repository as a constructor parameter — use Riverpod.

---

### Confirmed unchanged

- Task sequence 36 → 37 → 38 → 39 → 40 → 41 is correct. No circular dependencies.
- `flushDirty` extension in Task 41 follows the optional-named-parameter pattern from ADR-037: `flushDirty(uid, repo, {achievementRepo, tripRepo})`. Consistent; acceptable.
- `clearAll()` does NOT clear `unlocked_achievements` (ADR-036) or `share_tokens` (ADR-041). Only travel-history tables.
- Privacy: `photo_date_records` stores `{countryCode, capturedAt}` — no coordinates. ADR-002 satisfied. ✓
- Package boundary: `inferTrips()` lives in `shared_models` with no app-layer dependencies. ✓

**Build order:** Task 36 → 37 → 38 → 39 → 40 → 41. Task 37 can begin as soon as `PhotoDateRecord` and `TripRecord` types exist in `shared_models` (first deliverable of Task 36). Tasks 39–41 require Task 38 complete (trips populated in DB).

**ADRs written:** ADR-047 (trip identity), ADR-048 (photo_date_records design, schema v6, bootstrap strategy).

---

## Milestone 16 — Phase 6 Slice 1: Region Detection (Mobile)

```
Goal: After a photo scan, users see which regions (admin1 level: states, provinces, counties) they visited within each country, resolved entirely offline from photo GPS data.

Scope — included:
- `packages/region_lookup`: offline ISO 3166-2 admin1 polygon lookup (Natural Earth admin1 boundaries; same compact binary architecture as country_lookup)
- `PhotoDateRecord` gains `regionCode TEXT nullable` column; Drift schema v7 migration
- Scan pipeline: background isolate calls resolveRegion(lat, lng) alongside resolveCountry; regionCode stored per PhotoDateRecord
- `RegionVisit(tripId, countryCode, regionCode, firstSeen, lastSeen, photoCount)` domain model in shared_models
- Drift `region_visits` table (schema v7): composite PK (tripId, regionCode); isDirty/syncedAt columns
- `RegionRepository`: upsertAll, loadByCountry, loadByTrip, clearAll
- Scan pipeline produces RegionVisits from PhotoDateRecords grouped by (tripId × regionCode) after trip inference
- Bootstrap service produces RegionVisits for existing users from existing PhotoDateRecords
- Region count shown in country detail sheet ("X regions")
- Region list in country detail (region names from kRegionNames static map)

Scope — excluded:
- City detection (different algorithm, different dataset — planned for a future milestone)
- Continent overlay on world map (planned for M17 navigation redesign)
- Region-level achievements (planned for a future milestone)
- Firestore sync for region_visits (planned for a future milestone — same dirty/clean pattern)
- User-edit override for region assignments (deferred)
- Mini-map with regions highlighted (Phase 7)
- Region data on trip detail screen (Phase 7)
```

**Tasks:**

| Task | Name | Milestone | Stack |
|------|------|-----------|-------|
| 42 | Build `packages/region_lookup` | 16 | Dart package |
| 43 | Schema v7: `PhotoDateRecord.regionCode` + scan pipeline region resolution | 16 | Flutter + Dart |
| 44 | `RegionVisit` domain model + `region_visits` Drift table + `RegionRepository` | 16 | Flutter + shared_models |
| 45 | Scan pipeline + bootstrap: produce `RegionVisit` records | 16 | Flutter |
| 46 | Region count + region list in country detail sheet | 16 | Flutter (UI) |

---

### Task 42 — Build `packages/region_lookup`

**Deliverable:** A standalone Dart package at `packages/region_lookup/` that resolves (lat, lng) coordinates to ISO 3166-2 admin1 region codes offline using a bundled binary dataset. API mirrors `country_lookup`.

**Acceptance criteria:**
- `packages/region_lookup/` exists with `pubspec.yaml`, `lib/`, `test/`, `assets/`
- Public API: `initRegionLookup(Uint8List bytes)` + `resolveRegion(double lat, double lng) → String?`
- Returns null for coordinates with no matching region (coastal, small countries with no admin1 divisions, open water)
- Binary data file generated from Natural Earth admin1 1:10m boundaries; file ≤ 5 MB; same compact binary format as `ne_countries.bin` (or documented new format)
- Zero external dependencies (pure Dart)
- `dart analyze` reports zero issues
- ≥ 20 unit tests: known capitals resolve to correct region codes; null returns for open water; ISO 3166-2 format verified (e.g. `"FR-IDF"`, `"US-CA"`, `"GB-ENG"`)
- Package registered in root `pubspec.yaml` workspace

**Dependencies:** None (standalone package).

---

### Task 43 — Schema v7: PhotoDateRecord.regionCode + scan pipeline region resolution

**Deliverable:** `PhotoDateRecord` gains a nullable `regionCode` column. The background isolate that resolves country codes also resolves region codes in the same pass. Schema migrated to v7.

**Acceptance criteria:**
- `RoavvyDatabase.schemaVersion` → 7
- `PhotoDateRecords` table: new column `TextColumn get regionCode => text().nullable()();`
- v7 migration: `await m.addColumn(photoDateRecords, photoDateRecords.regionCode);`
- Background isolate: after `resolveCountry(lat, lng)`, also calls `resolveRegion(lat, lng)` from `region_lookup`; sets `regionCode` on the row
- `initRegionLookup` called once at app startup in `main.dart` (after loading binary asset, before isolate spawned)
- `resolveRegion` not called if `resolveCountry` returns null (no point resolving region of unknown country)
- `dart analyze` reports zero issues
- Unit tests: PhotoDateRecord rows with regionCode populated after scan; null preserved when no region match; existing rows with no regionCode column are unaffected by migration

**Dependencies:** Task 42 complete (region_lookup package must exist).

---

### Task 44 — `RegionVisit` domain model + `region_visits` Drift table + `RegionRepository`

**Deliverable:** `RegionVisit` type in shared_models; `region_visits` Drift table in schema v7; `RegionRepository` with upsert + load + clear operations.

**Acceptance criteria:**
- `shared_models` exports `RegionVisit(tripId: String, countryCode: String, regionCode: String, firstSeen: DateTime, lastSeen: DateTime, photoCount: int)`
- `region_visits` Drift table (already added to schema in Task 43 migration or in same migration): columns `tripId TEXT NOT NULL`, `regionCode TEXT NOT NULL`, `countryCode TEXT NOT NULL`, `firstSeen TEXT NOT NULL`, `lastSeen TEXT NOT NULL`, `photoCount INTEGER NOT NULL DEFAULT 0`, `isDirty INTEGER NOT NULL DEFAULT 1`, `syncedAt TEXT NULL`; composite PK `(tripId, regionCode)`
- `RegionRepository(RoavvyDatabase db)` in `lib/data/region_repository.dart`:
  - `upsertAll(List<RegionVisit> visits)` — insertOrReplace for each
  - `loadByCountry(String countryCode) → Future<List<RegionVisit>>`
  - `loadByTrip(String tripId) → Future<List<RegionVisit>>`
  - `clearAll()` — deletes all rows
- `dart run build_runner build` run; `.g.dart` file committed
- `dart analyze` reports zero issues
- Unit tests: upsert + load by country; load by trip; clearAll; duplicate upsert replaces existing row

**Dependencies:** Task 43 (schema v7 migration must already include region_visits table, or this task adds it; clarify with Architect).

**Note for Architect:** Task 43 adds the regionCode column to photo_date_records (schema v7). Task 44 adds region_visits to the same schema version. Architect must confirm whether this is one v7 migration block (preferred — atomicity) or two separate version bumps (v7 and v8). Recommend one atomic v7 migration covering both changes.

---

### Task 45 — Scan pipeline + bootstrap: produce RegionVisit records

**Deliverable:** After trip inference runs (post-scan and on bootstrap), the scan pipeline groups PhotoDateRecords by (tripId × regionCode) and upserts RegionVisit records.

**Acceptance criteria:**
- New pure function in `shared_models`: `List<RegionVisit> inferRegionVisits(List<PhotoDateRecord> records, List<TripRecord> trips)` — groups records by matching tripId (using same time-clustering as trip inference: record falls within trip's startedOn..endedOn window) and regionCode; null regionCode records are excluded
- `ScanScreen` / scan pipeline: after `tripRepo.upsertAll(inferredTrips)`, calls `inferRegionVisits` and `regionRepo.upsertAll(inferredRegions)`
- `BootstrapService.bootstrapExistingUser` extended: after bootstrapping trips, also infers and upserts region visits from existing PhotoDateRecords
- `VisitRepository.clearAll()` extended: also calls `RegionRepository.clearAll()` (delete history must wipe region data)
- `dart analyze` reports zero issues
- Unit tests: known photo records with region codes produce correct RegionVisit aggregates; photos with null regionCode excluded; PhotoDateRecords spanning multiple trips assigned to correct trips

**Dependencies:** Task 44 complete.

---

### Task 46 — Region count + region list in country detail sheet

**Deliverable:** `CountryDetailSheet` shows how many regions the user has visited in a country. Expanding the count reveals a list of region names.

**Acceptance criteria:**
- `regionRepositoryProvider` added to `lib/core/providers.dart` (follows same pattern as tripRepositoryProvider)
- `CountryDetailSheet` (ConsumerWidget) reads `regionRepositoryProvider`; calls `loadByCountry(countryCode)` on open; displays "X regions visited" row (hidden when 0 regions)
- A static `kRegionNames` map (`lib/core/region_names.dart`): `Map<String, String>` of ISO 3166-2 code → English name; generated from Natural Earth admin1 dataset at build time; fallback to the code if not in map
- Tapping the region row (or a trailing expand icon) shows an inline list of region names, alphabetically sorted
- Loading state handled (FutureProvider or manual setState)
- Graceful empty state: if no regions (e.g. country detected before Task 45 ran), the region row is hidden
- `dart analyze` reports zero issues
- Widget tests: region count row visible with correct count; row hidden when 0 regions; region list shown on tap; kRegionNames fallback to code works

**Dependencies:** Task 45 complete.

---

**Dependencies summary:**
- Task 42 → no dependencies
- Task 43 → requires Task 42
- Task 44 → requires Task 43 (same schema version)
- Task 45 → requires Task 44
- Task 46 → requires Task 45

**Risks and open questions:**

1. **Binary asset size**: Natural Earth admin1 1:10m has ~3,800 polygons vs 1,580 for country_lookup. Estimated binary 3–5 MB. Check this does not push the app bundle over Apple's cellular download limit (200 MB OTA). Mitigation: use 1:50m admin1 data for a smaller binary (~2 MB, lower precision) if needed.

2. **Countries with no admin1 regions**: Monaco, Vatican, Singapore, and similar micro-states have no ISO 3166-2 admin1 subdivisions. `resolveRegion` must return null for coordinates in these countries; this is correct behaviour and must be tested.

3. **Coastal and border false-nulls**: Points on coastlines, in harbours, or at land borders may fall outside all admin1 polygons. These will get null regionCode and be silently excluded from RegionVisits. This is acceptable; document in code comments.

4. **Schema atomicity**: Tasks 43 and 44 both add to schema v7. Architect must confirm that both `photoDateRecords.regionCode` and `region_visits` table are created in a single `if (from < 7)` migration block. If split across v7 and v8, the builder must document this clearly.

5. **kRegionNames size**: ISO 3166-2 has ~4,400 codes. A static Dart map is ~350 KB of source. This is acceptable. If app size is a concern post-Task 46, consider lazy loading from a binary asset.

6. **Cascade delete for region_visits**: Task 40 (manual trip delete) calls `TripRepository.delete(tripId)`. It does NOT currently call `RegionRepository` (it didn't exist). After M16, `TripRepository.delete(tripId)` must also call `regionRepo.deleteByTrip(tripId)`. The Architect must flag this coupling. Recommendation: pass `RegionRepository?` to `TripRepository.delete()` (optional, for backwards compatibility) or add a `deleteByTrip` call in the scan screen's delete handler.

7. **Trip assignment for region photos**: `inferRegionVisits` assigns photos to trips using the trip's `startedOn`/`endedOn` window. Photos with `capturedAt` outside any trip window are excluded. This is consistent with how trip inference works.

---

## Architect sign-off — Milestone 16 (Tasks 42–46)

**Plan validated with the following corrections. All corrections are mandatory before the Builder starts.**

---

### Correction 1 — Region resolution must use the same bucketed coordinates as country resolution (ADR-051)

The Planner's Task 43 describes the background isolate calling `resolveRegion(lat, lng)` but does not specify whether these are raw or bucketed coordinates. **This must be bucketed (0.5° grid) — the same coordinate that `resolveCountry` uses.**

Reason: if country resolution uses a bucketed point and region resolution uses a raw point, a photo near a border could produce `countryCode = "FR"` but `regionCode = "ES-CT"` — silently wrong data. Consistency requires the same input coordinate.

**Builder must:** In the background isolate, bucket the raw coordinate first (round lat/lng to nearest 0.5°), then call both `resolveCountry` and `resolveRegion` on the bucketed value. This is already how `resolveCountry` works — region resolution is added to the same step with the same input.

Known limitation (documented in ADR-051): photos within 55 km of a region border may be attributed to the wrong region.

---

### Correction 2 — Schema v7 is a single atomic migration block spanning Tasks 43 and 44 (ADR-051)

The Planner left the migration atomicity as an "open question for the Architect." **Decision: one `if (from < 7)` block.**

**Builder must (in Task 43):**
```dart
if (from < 7) {
  await m.addColumn(photoDateRecords, photoDateRecords.regionCode);
  await m.createTable(regionVisits);
}
schemaVersion = 7;
```

Task 44 creates only Dart types and repository code — no additional `schemaVersion` bump.

---

### Correction 3 — RegionRepository must expose `deleteByTrip(String tripId)` (Task 44)

The Planner flagged the cascade-delete gap. **Decision: caller coordinates, repositories stay decoupled.**

**Builder must (in Task 44):** Add `deleteByTrip(String tripId) → Future<void>` to `RegionRepository`. It deletes all `region_visits` rows where `tripId = tripId`.

**Builder must (in Task 45 or 46):** Wherever the trip-delete action lives in the UI layer (currently in `CountryDetailSheet` — Task 39/40 of M15), add a call to `regionRepo.deleteByTrip(id)` after `tripRepo.delete(id)`. Do not modify `TripRepository` — the coupling stays in the app layer, not the repository layer.

---

### Correction 4 — `VisitRepository.clearAll()` must also call `RegionRepository.clearAll()` (Task 45)

The Planner says `clearAll()` wipes region data. **Confirmed — both `photo_date_records` (which now has `regionCode`) and `region_visits` must be cleared when the user deletes travel history.**

`VisitRepository.clearAll()` already calls `TripRepository.clearAll()` (added in M15). It must also call `RegionRepository.clearAll()`.

**Builder must (in Task 45):** Wire `regionRepo.clearAll()` into `VisitRepository.clearAll()`. Since `VisitRepository` and `RegionRepository` are both app-layer classes, pass `regionRepo` as a parameter (following the same pattern used for `tripRepo` in M15), or wire it in the `VisitRepositoryProvider`'s `clearAll` call-site.

**Preferred:** Keep repositories independent. The `clearAll` call-site in `MapScreen` (the "Delete travel history" flow) calls both explicitly:
```dart
await visitRepo.clearAll();
await tripRepo.clearAll();
await regionRepo.clearAll(); // new in M16
```

---

### Confirmed unchanged

- `packages/region_lookup` as a standalone pure Dart package, structurally identical to `country_lookup`. No dependency on `country_lookup`. ✓
- `RegionVisit` as a plain data class in `shared_models`; no Flutter or Drift dependencies in the model. ✓
- `inferRegionVisits(List<PhotoDateRecord> records, List<TripRecord> trips) → List<RegionVisit>` as a pure function in `shared_models`. ✓
- `kRegionNames` static map in `apps/mobile_flutter/lib/core/region_names.dart`, following ADR-019 pattern. ✓
- Privacy: `regionCode` is derived metadata; GPS coordinates discarded after resolution. ADR-002 satisfied. ADR-050 documents the scope extension. ✓
- `FirestoreSyncService` is NOT extended in M16; `region_visits.isDirty` column exists but is never flushed until a future milestone. ✓
- Package DAG remains acyclic: `apps/mobile_flutter → packages/region_lookup`; no package-to-package dependency. ✓

**Build order:** Task 42 → Task 43 → Task 44 → Task 45 → Task 46. Strictly sequential.

**ADRs written:** ADR-049 (region_lookup package), ADR-050 (regionCode as derived metadata), ADR-051 (bucketed coordinates; atomic schema v7 migration).

---

## Milestone 17 — Phase 7: Navigation Redesign

**Goal:** Extend the app from a 2-tab shell (Map · Scan) to a 4-tab shell (Map · Journal · Stats · Scan). The new Journal tab lets users browse trip history chronologically; the new Stats tab gives achievements and aggregate statistics a dedicated home.

**Scope — included:**
- 4-tab `NavigationBar` shell: Map · Journal · Stats · Scan (tabs in this order)
- Journal screen: all trips from `TripRepository`, grouped by year (most recent first); each row shows country name, date range, duration; tapping opens existing `CountryDetailSheet`
- Stats & Achievements screen: stats panel (countries visited, regions visited, year span) + full achievement gallery (all `kAchievements`, locked/unlocked state, unlock date for unlocked ones)

**Scope — excluded:**
- Country Detail promoted to full-screen page (deferred to M18)
- Trip Detail full-screen (M18)
- Journal filtering and search (deferred)
- Map frequency colouring and continent labels (deferred)
- Continent breakdown in Stats (deferred)
- Timeline / year-by-year chart (deferred)
- Sharing from Journal or Stats (deferred)
- Photos tab in Country Detail (deferred)

**Note:** All three tasks have user-facing components — invoke UX Designer before Architect.

**Tasks:**

| Task | Name | Milestone | Component |
|------|------|-----------|-----------|
| 47 | 4-tab navigation shell | 17 | Flutter |
| 48 | Journal screen | 17 | Flutter |
| 49 | Stats & Achievements screen | 17 | Flutter |

---

### Task 47 — 4-tab navigation shell

**Milestone:** 17

**Why:** The current shell exposes only Map and Scan. Journal and Stats need dedicated tab slots before their screens can be built. This task wires the navigation shell and adds placeholder screens so the app is always in a working state.

**Deliverable:**
- `NavigationShell` extended from 2 destinations to 4: Map (globe icon), Journal (list icon), Stats (bar chart icon), Scan (camera icon)
- `JournalScreen` stub: `lib/features/journal/journal_screen.dart` — renders a placeholder message
- `StatsScreen` stub: `lib/features/stats/stats_screen.dart` — renders a placeholder message
- `IndexedStack` extended to 4 children; Journal at index 1, Stats at index 2, Scan at index 3
- Existing Map (index 0) and Scan (now index 3) tabs unaffected; all existing tests still pass

**Acceptance criteria:**
- [ ] 4 tabs visible in `NavigationBar`: Map, Journal, Stats, Scan (in that order)
- [ ] Tapping each tab switches to the correct screen without error
- [ ] Map and Scan tabs function identically to current behaviour
- [ ] `JournalScreen` and `StatsScreen` stubs render without errors
- [ ] `dart analyze` reports zero issues
- [ ] Widget test: all 4 tab labels present in the navigation bar; switching to each tab renders the correct widget

**Files to change:**
- `apps/mobile_flutter/lib/features/shell/navigation_shell.dart` — extend to 4 tabs
- `apps/mobile_flutter/lib/features/journal/journal_screen.dart` (new — stub)
- `apps/mobile_flutter/lib/features/stats/stats_screen.dart` (new — stub)
- `apps/mobile_flutter/test/features/shell/navigation_shell_test.dart` (new or extend)

**Dependencies:** None (M16 complete).

---

### Task 48 — Journal screen

**Milestone:** 17

**Why:** Gives users a chronological view of their entire trip history without having to locate individual countries on the map. The trip data already exists in `TripRepository` (M15); this task surfaces it in a dedicated screen.

**Deliverable:**
- `JournalScreen` fully implemented (replaces stub from Task 47)
- Reads all trips via `tripRepositoryProvider`; groups by `startedOn.year`; most recent year first
- Each year section has a sticky header ("2023")
- Each trip row shows: country name (from `kCountryNames`), date range, duration, photo count
- Tapping a trip opens `CountryDetailSheet` for that country via `showModalBottomSheet`; reads `effectiveVisitsProvider` to obtain the `EffectiveVisitedCountry?` value for the sheet constructor
- Empty state: "No trips yet — scan your photos to discover your journeys"
- Loading state: `CircularProgressIndicator` while `FutureBuilder` resolves

**Acceptance criteria:**
- [ ] Trips grouped by year, most recent year first
- [ ] Trips within a year sorted by `startedOn` descending
- [ ] Each trip row shows country name, date range, duration, and photo count
- [ ] Tapping a trip row opens `CountryDetailSheet` for that country
- [ ] Empty state shown when `loadAll()` returns `[]`
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: year grouping correct; trip row renders expected fields; empty state shown; tapping a row triggers sheet

**Files to change:**
- `apps/mobile_flutter/lib/features/journal/journal_screen.dart` — replace stub with full implementation
- `apps/mobile_flutter/test/features/journal/journal_screen_test.dart` (new)

**Dependencies:** Task 47 complete.

---

### Task 49 — Stats & Achievements screen

**Milestone:** 17

**Why:** Achievement data has been stored since M9 but is only surfaced as a SnackBar on unlock and a count in the stats strip. This screen gives achievements a permanent home and exposes region count as a top-level stat.

**Deliverable:**
- `StatsScreen` fully implemented (replaces stub from Task 47)
- Stats panel: "N countries visited", "N regions visited", "Since [year]" (or "—" if no dates)
  - Countries: `effectiveVisitsProvider` length
  - Regions: unique region codes via new `RegionRepository.countUnique() → Future<int>` (SQL: `SELECT COUNT(DISTINCT regionCode) FROM region_visits`)
  - Since year: earliest `firstSeen` from `travelSummaryProvider`
- Achievement gallery: scrollable grid of all `kAchievements`; unlocked achievements visually distinct (filled icon / colour); locked achievements greyed out; unlocked ones show unlock date
- Reads `achievementRepositoryProvider` to get the set of unlocked achievement IDs

**Acceptance criteria:**
- [ ] Stats panel shows correct country count, region count, and earliest year from live data (no hardcoded values)
- [ ] `RegionRepository` gains `countUnique() → Future<int>`
- [ ] Achievement gallery shows all `kAchievements` entries
- [ ] Unlocked achievements are visually distinct from locked ones
- [ ] Unlocked achievements display the unlock date
- [ ] `dart analyze` reports zero issues
- [ ] Widget tests: stats panel displays expected values; unlocked achievement card distinct from locked; locked achievement shown greyed out

**Files to change:**
- `apps/mobile_flutter/lib/features/stats/stats_screen.dart` — replace stub with full implementation
- `apps/mobile_flutter/lib/data/region_repository.dart` — add `countUnique()` method
- `apps/mobile_flutter/test/features/stats/stats_screen_test.dart` (new)
- `apps/mobile_flutter/test/data/region_repository_test.dart` — extend with `countUnique` test

**Dependencies:** Task 47 complete. (Tasks 48 and 49 can be built in parallel after Task 47.)

---

## Planner sign-off — Milestone 17 (Tasks 47–49)

**Plan complete: 2026-03-19**

**Task sequence:**

| Task | Name | Milestone | Component |
|------|------|-----------|-----------|
| 47 | 4-tab navigation shell | 17 | Flutter |
| 48 | Journal screen | 17 | Flutter |
| 49 | Stats & Achievements screen | 17 | Flutter |

**Key risks and open questions:**

1. **UX: tab icons and labels** — The UX Designer must confirm the icon set (globe, list, bar-chart, camera) and whether "Journal" and "Stats" are the right tab labels before Builder implements.

2. **Opening CountryDetailSheet from Journal** — The sheet constructor requires `EffectiveVisitedCountry? visit`. The Journal screen has a `TripRecord` (country code only). To get the matching `EffectiveVisitedCountry`, the screen reads `effectiveVisitsProvider` and looks up the country code in the resulting list. The Architect must confirm this is the correct approach (or propose an alternative if `effectiveVisitsProvider` is expensive to watch here).

3. **Achievement gallery UX** — There are 8+ achievements and potentially many locked ones. The UX Designer must decide: grid vs. list, ordering (unlocked first?), whether to show locked achievements with a hint or hide them entirely. Planner defers this decision to the UX Designer.

4. **Scan tab index shift** — Moving Scan from index 1 to index 3 changes the `IndexedStack` child order. Any widget test that references the Scan tab by index (not by label) will break. Builder must audit and fix all such references.

5. **`achievementRepositoryProvider`** — The Stats screen needs the achievement repository. Confirm this provider already exists in `lib/core/providers.dart` (added in M9) before Task 49 begins.

**Next step: UX Designer must review before Architect.** Invoke UX Designer next.

---

## Architect sign-off — Milestone 17 (Tasks 47–49)

**Review complete: 2026-03-19**

**ADR written:** ADR-052 (4-tab shell index contract; Journal data access; achievement unlock dates).

### Provider audit

All providers referenced by M17 are confirmed to exist in `lib/core/providers.dart`:

| Provider | Type | Used by |
|----------|------|---------|
| `tripRepositoryProvider` | `Provider<TripRepository>` | Task 48 (Journal) |
| `effectiveVisitsProvider` | `FutureProvider<List<EffectiveVisitedCountry>>` | Task 48 (Journal → CountryDetailSheet lookup) |
| `regionRepositoryProvider` | `Provider<RegionRepository>` | Task 49 (Stats — region count) |
| `travelSummaryProvider` | `FutureProvider<TravelSummary>` | Task 49 (Stats — since year) |
| `achievementRepositoryProvider` | `Provider<AchievementRepository>` | Task 49 (Stats — achievement gallery) |

### Corrections to Planner task specs

**Task 47 — file naming correction:**
The Planner names the shell file `lib/features/shell/navigation_shell.dart`. The existing file is `lib/features/shell/main_shell.dart`. The Builder must edit the existing file, not create a new one. Test file: `test/features/shell/main_shell_test.dart` (match existing naming).

**Task 48 — no loading spinner (Design Principle 3):**
The Planner's acceptance criteria includes "Loading state: `CircularProgressIndicator` while `FutureBuilder` resolves". Remove this. `TripRepository.loadAll()` reads from local SQLite — it resolves in well under one frame. Per Design Principle 3 and the UX Designer's spec, no spinner is shown. If data has not arrived within a single frame, render nothing (blank) rather than a spinner.

**Task 48 — empty state copy:**
The Planner's empty state copy is "No trips yet — scan your photos to discover your journeys". Replace with the UX Designer's canonical copy:
- Heading: "Your journal is empty"
- Body: "Scan your photos to build your travel history."
- CTA: "Scan Photos" (`FilledButton`, navigates to Scan tab index 3)

**Task 48 — `effectiveVisitsProvider` watch vs. read:**
`JournalScreen` must `watch` `effectiveVisitsProvider`, not `read` it. This keeps the country list current if a manual visit add/remove occurs while the Journal tab is visible (ADR-052, Decision 2).

**Task 49 — `AchievementRepository.loadAllRows()` is a required file change:**
`AchievementRepository.loadAll()` returns `List<String>` (IDs only). Displaying unlock dates requires the full row. Add `loadAllRows() → Future<List<UnlockedAchievementRow>>` to `AchievementRepository`. Update the files list:

- `apps/mobile_flutter/lib/data/achievement_repository.dart` — add `loadAllRows()`
- `apps/mobile_flutter/test/data/achievement_repository_test.dart` — add test for `loadAllRows()`

**Task 49 — Stats screen has no loading spinner:**
Same Design Principle 3 applies. No `CircularProgressIndicator` for any of the three stats values or the achievement gallery.

**Task 49 — Stats screen watches multiple async providers:**
`StatsScreen` must handle `AsyncValue` from three async sources: `effectiveVisitsProvider`, `travelSummaryProvider`, and a `FutureProvider` wrapping `regionRepositoryProvider.countUnique()`. Use `ref.watch` on all three. The simplest pattern: show the stat tile with "—" as a fallback while any value is still loading; do not block the entire screen on a single spinner.

A thin `regionCountProvider` (`FutureProvider<int>`) should be defined in `lib/core/providers.dart` to wrap `regionRepositoryProvider.countUnique()`, consistent with how `travelSummaryProvider` wraps repository reads (ADR-018).

### Confirmed structural decisions (ADR-052)

1. **Tab indices locked:** Map=0, Journal=1, Stats=2, Scan=3. No file outside `MainShell` uses a numeric literal for a tab index.
2. **Journal → CountryDetailSheet:** `ref.watch(effectiveVisitsProvider)` → `firstWhereOrNull((v) => v.countryCode == trip.countryCode)` → passed as `visit:` parameter. Sound — sheet already handles nullable visit.
3. **`kAchievements`** confirmed in `packages/shared_models/lib/src/achievement.dart` — 8 achievements; `StatsScreen` iterates this list to build the gallery.
4. **Scan callback:** `ScanScreen(onScanComplete: _goToMap)` — `_goToMap` already navigates to index 0. No change needed to `ScanScreen` itself.

### Build order

Task 47 → (Task 48 ∥ Task 49). Tasks 48 and 49 are independent of each other and may be built in parallel after Task 47 lands.

---

## Milestone 19A — Quality & Depth

**Goal:** Fix incorrect trip and region detection; restore missing confetti celebration; make every country, achievement, and trip tap-through to a detail screen; and let users view the photos from any trip or country in an on-device gallery.

**Scope — included:**
- Task 59: Trip inference — geographic sequence model (replace 30-day gap)
- Task 60: Region detection — diagnose and fix coverage gaps
- Task 61: Confetti — fix celebration flow so new-country scans reliably show confetti
- Task 62: Interactive navigation — Stats screen country list + tappable achievements
- Task 63: Privacy model update + store PHAsset IDs in local DB (prerequisite for gallery)
- Task 64: Photo gallery — per-country and per-trip photo grid on device

**Scope — excluded:**
- City detection
- Map animations or country-reveal animation
- Android support
- Firestore sync for region visits (deferred from M16)

**Risks / open questions:**
1. **Trip re-inference is user-impacting.** Changing the algorithm will alter existing stored trip records after bootstrap re-runs. Users who have manually edited trips will not be affected (manual trips are never re-inferred), but automatically inferred trips will change. This is intentional and correct — the old algorithm was wrong — but should be noted in the ADR.
2. **Region gaps may be data coverage, not code bugs.** Natural Earth admin1 does not define sub-national regions for every country (e.g., small island nations, city-states). If the gap is data, the fix is to document known limitations and ensure no silent failure.
3. **Privacy model change for asset IDs.** Storing `PHAsset.localIdentifier` in local SQLite is a deliberate change to the privacy model — currently the doc says identifiers are never written to DB. Asset IDs are on-device UUIDs with no intrinsic PII and never go to Firestore; the Architect must write an ADR and update `docs/architecture/privacy_principles.md`.
4. **Photo gallery channel vs. `photo_manager` package.** Two implementation options: (a) extend the custom Swift `EventChannel` with a new method to batch-fetch thumbnails, or (b) add the `photo_manager` pub.dev package which handles PHAsset access cross-platform. Architect to decide.

---

## Task 59 — Fix trip inference: geographic sequence model (ADR-058)

**Milestone:** 19A
**Phase:** Quality fix

**Why:** The current algorithm clusters photos within a single country by a 30-day time gap. This produces wrong results: a user who visits Japan three times in a year with fewer than 30 days between visits gets one trip instead of three. See ADR-058 for full options analysis.

**Algorithm (ADR-058):**
Sort all `PhotoDateRecord`s globally by `capturedAt`. Walk chronologically; when `countryCode` changes, close the current run and open a new one. Each run = one `TripRecord`. Remove the `gap` parameter entirely.

**Deliverable:** Updated `inferTrips()` in `packages/shared_models/lib/src/trip_inference.dart`. `inferRegionVisits()` is unchanged — it matches photos to trips by timestamp window and works correctly with the new trip boundaries.

**Acceptance criteria:**
- [ ] `inferTrips()` signature: `List<TripRecord> inferTrips(List<PhotoDateRecord> records)` — no `gap` parameter
- [ ] Sort all records by `capturedAt` ascending before walking; no grouping by country
- [ ] A sequence `[JP, JP, US, JP, JP]` produces `TripRecord(JP), TripRecord(US), TripRecord(JP)` — three trips, not one JP + one US
- [ ] `startedOn` = first record's `capturedAt` in the run; `endedOn` = last record's `capturedAt` in the run; `photoCount` = run length
- [ ] Empty input → empty output
- [ ] Single-record input → single trip
- [ ] All existing `shared_models` tests updated and passing
- [ ] New tests: alternating countries, non-adjacent same country, single-photo runs
- [ ] `dart analyze` reports zero issues

**Files to change:**
- `packages/shared_models/lib/src/trip_inference.dart`
- `packages/shared_models/test/trip_inference_test.dart`

**Dependencies:** None. Independent.

---

## Task 60 — Fix region detection coverage gaps

**Milestone:** 19A
**Phase:** Quality fix

**Why:** The user sees regions for Japan (JP) and a few other countries but not for all countries where photos exist. Region detection must either work for every country with GPS photos, or fail explicitly so the user understands why regions are absent.

**Deliverable:** Diagnosed root cause; code fix or documented known limitation; no silent failures.

**Acceptance criteria:**
- [ ] Investigate whether the gap is: (a) missing geodata in `ne_admin1.bin` for certain countries, (b) point-in-polygon edge cases (antimeridian, coastal photos just outside polygon boundaries), or (c) a bug in `RegionRepository.upsertAll()` or bootstrap
- [ ] If (a): add a comment/doc entry listing countries known to have no admin1 coverage in Natural Earth data; no code change needed
- [ ] If (b): fix the point-in-polygon boundary handling (e.g., expand coastal polygon bounds by a small epsilon, or use the nearest-polygon fallback for coastal misses)
- [ ] If (c): fix the bug; add regression test
- [ ] After fix: run a scan with photos from ≥ 5 countries including at least one previously missing; confirm region records appear in `CountryDetailSheet` for all countries where geodata exists
- [ ] `dart analyze` reports zero issues

**Files likely to change (Architect to confirm after diagnosis):**
- `packages/region_lookup/lib/src/lookup_engine.dart` — if point-in-polygon fix needed
- `packages/region_lookup/lib/src/point_in_polygon.dart` — if boundary epsilon needed
- `apps/mobile_flutter/lib/data/region_repository.dart` — if upsert bug found
- `apps/mobile_flutter/lib/data/bootstrap_service.dart` — if bootstrap ordering bug found

**Dependencies:** None. Independent.

---

## Task 61 — Fix confetti celebration flow (ADR-059)

**Milestone:** 19A
**Phase:** Quality fix

**Why:** `ScanSummaryScreen` with confetti never fires after a scan. Root cause (ADR-059): `ScanScreen._scan()` calls `widget.onScanComplete()` directly at the end, navigating to the Map tab without pushing `ScanSummaryScreen` at all. The `ReviewScreen` path that was supposed to push `ScanSummaryScreen` is only reachable via the "Review & Edit" button — and by that point `initialVisits` already contains the post-scan countries, so the `newCountries` delta is always empty.

**Deliverable:** `ScanScreen._scan()` pushes `ScanSummaryScreen` directly when new countries are found. ReviewScreen is simplified to a pure editor (no ScanSummaryScreen, no confetti). See ADR-059 for the full flow diagram.

**Acceptance criteria:**
- [ ] `ScanScreen._scan()` captures `preScanCodes` from `_repo.loadEffective()` **before** calling `clearAndSaveAllInferred()` (this is the true pre-scan baseline)
- [ ] After scan completes and new countries are found: `ScanScreen` pushes `ScanSummaryScreen(newCountries: ..., newAchievementIds: ..., onDone: widget.onScanComplete)`
- [ ] `ScanSummaryScreen.onDone` calls the provided callback — `widget.onScanComplete` — which navigates to Map tab
- [ ] `ScanScreen._openReview()` passes `onScanComplete: null` to `ReviewScreen` (review-and-edit is no longer a scan lifecycle event)
- [ ] `ReviewScreen._save()` removes the `ScanSummaryScreen` push branch; when `onScanComplete` is null or after save, it pops (no summary screen)
- [ ] `ReviewScreen._handleSummaryDone()` is deleted
- [ ] If `reduceMotion` is true: confetti does not fire (accessibility; do not change this)
- [ ] Widget test for `ScanScreen`: assert `ScanSummaryScreen` is pushed with non-empty `newCountries` when mock scan produces new countries
- [ ] Widget test for `ReviewScreen`: assert it pops on save without pushing `ScanSummaryScreen`
- [ ] `dart analyze` reports zero issues

**Files to change:**
- `apps/mobile_flutter/lib/features/scan/scan_screen.dart` — capture `preScanCodes` before clear; push `ScanSummaryScreen`; pass `onScanComplete: null` to `_openReview`
- `apps/mobile_flutter/lib/features/visits/review_screen.dart` — remove `ScanSummaryScreen` push branch; remove `_handleSummaryDone()`
- `apps/mobile_flutter/test/features/scan/scan_screen_incremental_test.dart` — update
- `apps/mobile_flutter/test/features/visits/review_screen_test.dart` — update

**Dependencies:** None. Independent.

---

## Task 62 — Interactive navigation: countries list + achievement tap-to-detail

**Milestone:** 19A
**Phase:** Quality fix

**Why:** The Stats screen shows country and achievement counts but nothing is tappable. Users cannot navigate from the stats panel to country details or from an achievement tile to the achievement detail sheet. The Journal already supports tap-through, but Stats is a dead end.

**Deliverable:** Every country and achievement visible in Stats is tappable and navigates to the appropriate detail screen.

**Acceptance criteria:**
- [ ] Stats screen "X countries" count (or a "See all countries" row below it) navigates to a scrollable countries list. Each country row shows flag emoji + name + visit dates; tapping any row opens `CountryDetailSheet` for that country
- [ ] Achievement gallery cards on Stats screen are tappable → open `AchievementUnlockSheet` (already built); this applies to both locked and unlocked cards (locked cards open sheet in locked state showing what is required to unlock)
- [ ] Navigation uses `Navigator.push` (full-screen or bottom sheet as appropriate); back button returns to Stats
- [ ] No changes to Journal screen (already tappable)
- [ ] Widget tests: tapping "X countries" navigates to countries list; tapping achievement card opens sheet
- [ ] `dart analyze` reports zero issues

**Files to change:**
- `apps/mobile_flutter/lib/features/stats/stats_screen.dart` — add tap handlers + countries list navigation
- `apps/mobile_flutter/lib/features/stats/countries_list_screen.dart` — new (or modal bottom sheet)
- `test/features/stats/stats_screen_test.dart` — extend with tap navigation tests

**Dependencies:** None. Independent.

---

## Task 63 — Privacy model update: store PHAsset IDs in local DB (ADR-060)

**Milestone:** 19A
**Phase:** Quality fix (prerequisite for Task 64)

**Why:** Photo gallery requires `PHAsset.localIdentifier` at display time. These are currently discarded after scan. ADR-060 approves persisting them in local SQLite only — never Firestore. They are opaque on-device UUIDs with no intrinsic PII.

**Deliverable:** Schema v9 with `asset_id` on `photo_date_records`; Swift channel updated to include `localIdentifier`; `PhotoRecord` and `PhotoDateRecord` gain `assetId`; privacy doc updated.

**Acceptance criteria:**
- [ ] `docs/architecture/privacy_principles.md` updated: PHAsset identifier row → "stored in local SQLite `photo_date_records`; never written to Firestore" (ADR-060 written — ✓ done)
- [ ] Drift schema v9: nullable `asset_id TEXT` column added to `PhotoDateRecords` table; migration: `ALTER TABLE photo_date_records ADD COLUMN asset_id TEXT` (existing rows get NULL)
- [ ] `roavvy_database.g.dart` regenerated via `dart run build_runner build`
- [ ] `PhotoRecord` (in `photo_scan_channel.dart`) gains `final String? assetId`; `fromMap()` reads `m['assetId']`
- [ ] `PhotoDateRecord` (in `packages/shared_models`) gains `final String? assetId`; equality and hashCode updated
- [ ] `PhotoScanPlugin.swift` includes `"assetId": asset.localIdentifier` in each photo map entry in the batch stream
- [ ] `resolveBatch()` in `scan_screen.dart` carries `assetId` from `PhotoRecord` through to `PhotoDateRecord`; the `_repo.savePhotoDates()` write persists it
- [ ] `FirestoreSyncService` unchanged — `assetId` is NOT in any Firestore payload
- [ ] Unit tests: `PhotoDateRecord` equality with `assetId`; schema migration test

**Files to change:**
- `docs/architecture/privacy_principles.md`
- `apps/mobile_flutter/lib/data/db/roavvy_database.dart` — schema v9, `asset_id` column
- `apps/mobile_flutter/lib/data/db/roavvy_database.g.dart` — regenerated
- `packages/shared_models/lib/src/photo_date_record.dart` — add `assetId` field
- `apps/mobile_flutter/lib/photo_scan_channel.dart` — `PhotoRecord.assetId` field + fromMap
- `apps/mobile_flutter/lib/features/scan/scan_screen.dart` — carry `assetId` through `resolveBatch`
- `apps/mobile_flutter/ios/Runner/PhotoScanPlugin/PhotoScanPlugin.swift` — add `"assetId"` to batch map

**Dependencies:** None. Independent of Tasks 59–62.

---

## Task 64 — Photo gallery: per-country photo grid (ADR-061)

**Milestone:** 19A
**Phase:** Quality fix

**Why:** The product vision: "A user taps a country and relives a trip through the photos from that week." Asset IDs from Task 63 make this entirely on-device. No upload required.

**Deliverable:** `photo_manager` package integration; `PhotoGalleryScreen` widget (3-column thumbnail grid); "Photos" tab in `CountryDetailSheet`.

**Acceptance criteria:**
- [ ] `photo_manager: ^3.x` added to `pubspec.yaml` (ADR-061: `photo_manager` chosen over extending Swift channel)
- [ ] `PhotoRepository` (new, or method on existing repo) exposes `loadAssetIds(countryCode) → Future<List<String>>` — queries `photo_date_records` for all non-null `asset_id` values for a given country
- [ ] `PhotoGalleryScreen` accepts `List<String> assetIds`; fetches `AssetEntity` by id via `photo_manager`; displays 3-column `GridView` of `AssetEntity.thumbnailDataWithSize(ThumbnailSize(150, 150))`
- [ ] Each thumbnail tap → full-screen `Image` with `InteractiveViewer` (pinch-to-zoom); back button returns to grid
- [ ] Empty state: "No photos with location data" message when `assetIds` is empty
- [ ] `CircularProgressIndicator` shown per cell while thumbnail loads (via `FutureBuilder`)
- [ ] `CountryDetailSheet` adds a "Photos" tab; tab body = `PhotoGalleryScreen` with asset IDs loaded for that country
- [ ] Widget tests: empty state; grid with mock assets; Photos tab present in `CountryDetailSheet`
- [ ] `dart analyze` reports zero issues
- [ ] Privacy: no network call; no Firestore write; thumbnails from local PhotoKit only

**Files to change:**
- `apps/mobile_flutter/pubspec.yaml` — add `photo_manager`
- `apps/mobile_flutter/lib/data/photo_repository.dart` — new (or `loadAssetIds` added to visit_repository)
- `apps/mobile_flutter/lib/features/map/photo_gallery_screen.dart` — new
- `apps/mobile_flutter/lib/features/map/country_detail_sheet.dart` — add Photos tab
- `apps/mobile_flutter/ios/Podfile` — updated by `pod install` automatically
- `apps/mobile_flutter/test/features/map/photo_gallery_screen_test.dart` — new

**Dependencies:** Task 63 must be complete.

---

### M19A build order

Tasks 59, 60, 61, 62, 63 are all independent and may be built in any order or in parallel.
Task 64 depends on Task 63.

**Builder may proceed.**

---

## Milestone 20A — Commerce Prerequisites

**Goal:** All external infrastructure is confirmed and documented so the builder can begin M20 implementation without hitting an unknown blocker mid-way.

**Why a separate milestone:** M20 cannot be partially built. The mockup system, Shopify checkout, and fulfilment integration are tightly coupled. If the critical question (can the fulfilment partner render a unique design per order from a country code list?) has the wrong answer, the architecture changes entirely. Every hour of M20 code written before this is confirmed is at risk.

**Scope — included:**
- Decision: which print-on-demand partner to use (Printful vs. Printify)
- Shopify store created with Storefront API access enabled
- Product catalogue configured: t-shirt variants (colour × size) + poster variants (stock × size)
- Fulfilment partner connected to Shopify store
- Critical validation: confirm the fulfilment partner can accept a per-order country list and generate a custom print file from it
- Storefront API access token documented and securely recorded (not committed to repo)

**Scope — excluded:**
- Any Flutter or Next.js code
- Mockup API integration (M20)
- Shopify checkout flow (M20)

**Who does this:** The store owner / product owner. These are external actions in Shopify and Printful/Printify admin panels, not tasks for the builder. The exception is Task 68 (API validation spike), which may require a developer to test API endpoints.

---

**Architecture amendment (2026-03-20):** The commerce architecture is now backend-mediated. See ADR-062. Key changes to M20A:
- Task 66 now requires TWO Shopify API tokens: a public Storefront API token (used by Firebase Functions to create carts) and a private Admin API token (used by Firebase Functions for order management). Neither token should be in the mobile app or web client.
- Task 68 validation question simplified: the POD provider connects to Shopify as a Shopify app and receives orders automatically. We do NOT need the POD to support dynamic country-list rendering in the PoC — the store owner manually provides the print file. Post-PoC, Firebase Functions will generate and submit a custom print file per order via the POD's API.
- New prerequisite: Firebase project must have Cloud Functions enabled (Blaze/pay-as-you-go plan required). This is a one-line Firebase Console change.
- "Option C" risk (POD cannot accept custom files) is eliminated for the PoC — the POD only needs to receive and ship a Shopify order.

---

## Task 65 — Choose print-on-demand partner

**Milestone:** 20A
**Phase:** 10 — Commerce Prerequisites
**Owner:** Product owner (decision) + developer (API research)

**Why:** Printful and Printify are the two leading print-on-demand platforms with Shopify integration. They differ on price, product range, API quality, and — critically — whether they support per-order custom artwork generation from a dynamic input (our country code list). The wrong choice creates a re-platform mid-build.

**Deliverable:** A written decision (added to `docs/architecture/decisions.md` as an ADR note) stating which platform was chosen and why.

**Acceptance criteria:**
- [ ] Both Printful and Printify API docs reviewed for: mockup generation API, per-order print file submission, line item custom property support
- [ ] Key question answered for each: "Can we pass a list of country codes per order and have the platform generate a unique print-ready file from it, or must we upload the print file ourselves?"
- [ ] T-shirt and poster product availability confirmed on chosen platform (correct colours, sizes, paper stocks)
- [ ] Pricing confirmed: base cost per t-shirt, per poster; acceptable margin at planned retail price
- [ ] Decision documented in `docs/architecture/decisions.md`

**Key question to answer:**

> Does [Platform] support per-order dynamic print file generation from a parameter set (e.g. country code list), or must the merchant upload a static print file per SKU?

If neither platform supports dynamic generation, document what the workaround is (e.g., generate and upload a print file via webhook when an order is placed — this is feasible but requires a server-side component Roavvy does not currently have).

**Dependencies:** None. Do this first.

---

## Task 66 — Create Shopify store and configure Storefront API access

**Milestone:** 20A
**Phase:** 10 — Commerce Prerequisites
**Owner:** Product owner

**Why:** The Shopify Storefront API is the interface between Roavvy (mobile app + web) and the Shopify cart/checkout. Without a store and a Storefront API access token, no integration code can be tested.

**Deliverable:** Live Shopify store; Storefront API access token generated and recorded securely.

**Acceptance criteria:**
- [ ] Shopify store created at a suitable domain (e.g. `shop.roavvy.app` or `roavvy.myshopify.com`)
- [ ] Store currency, tax settings, and shipping zones configured
- [ ] A custom app (or Headless channel) created in the Shopify admin with Storefront API access enabled
- [ ] Storefront API access token generated with at minimum these scopes: `unauthenticated_read_product_listings`, `unauthenticated_write_checkouts`, `unauthenticated_read_checkouts`
- [ ] Token recorded in a secure location (password manager / environment secrets) — **not committed to the repo**
- [ ] Token confirmed working: a simple `curl` against the Storefront API GraphQL endpoint returns a valid response

**Steps (Shopify admin):**
1. Create store → Settings → Plan → choose Starter or Basic
2. Settings → Apps and sales channels → Develop apps → Create an app
3. In the app, enable Storefront API and select the required scopes
4. Install the app → copy the Storefront API access token

**Dependencies:** None. Can be done in parallel with Task 65.

---

## Task 67 — Configure product catalogue in Shopify

**Milestone:** 20A
**Phase:** 10 — Commerce Prerequisites
**Owner:** Product owner

**Why:** The Shopify Storefront API serves products from the Shopify catalogue. The mobile and web apps query product variants (colour, size, price) at runtime. Without products configured, the design studio cannot display real options or prices.

**Deliverable:** T-shirt product and Poster product live in the Shopify catalogue with all variants configured.

**Acceptance criteria:**

**T-Shirt product:**
- [ ] Product created: "Roavvy Travel T-Shirt" (or equivalent title)
- [ ] Variants configured: 5 colours (White, Black, Navy, Forest Green, Stone Grey) × 5 sizes (S, M, L, XL, 2XL) = 25 variants
- [ ] Each variant has a SKU, price, and is linked to the corresponding fulfilment partner product (after Task 68)
- [ ] Product published to the Storefront API channel

**Poster product:**
- [ ] Product created: "Roavvy Travel Poster"
- [ ] Variants configured: 3 paper stocks (White Matte, White Gloss, Recycled Cream) × 5 sizes (A3, A2, A1, 18×24", 24×36") = 15 variants
- [ ] Each variant has a SKU, price, and is linked to the fulfilment partner product (after Task 68)
- [ ] Product published to the Storefront API channel

**Validation:**
- [ ] Querying the Storefront API `products` endpoint returns both products with all variants and prices

**Dependencies:** Task 66 (store must exist). Task 68 (fulfilment mapping) can follow after.

---

## Task 68 — Connect fulfilment partner and validate dynamic country-list rendering

**Milestone:** 20A
**Phase:** 10 — Commerce Prerequisites
**Owner:** Developer (API validation spike) + product owner (account setup)

**Why:** This is the highest-risk unknown in the entire commerce system. The Roavvy merchandise concept depends on generating a unique product design per customer based on their country visit list. If this cannot be done via the chosen print-on-demand platform's standard flow, a custom server-side file-generation step is required — which significantly changes the M20 architecture and timeline.

**Deliverable:** Written validation report (added inline to `docs/architecture/decisions.md`) answering the critical question. Fulfilment partner connected to Shopify store.

**Acceptance criteria:**

**Setup:**
- [ ] Account created on chosen platform (Printful or Printify)
- [ ] Platform app installed in Shopify store
- [ ] T-shirt and poster products in Shopify linked to corresponding SKUs on the platform
- [ ] A test order can be placed and a fulfilment job created (even if cancelled immediately)

**Critical validation — answer this question:**

> When a Shopify order arrives with a line item custom property `visitedCodes: "GB,FR,JP,US"`, can the fulfilment platform automatically generate a unique print file with those countries highlighted, or must the merchant supply a static print file?

**PoC validation question:** Can the POD Shopify app receive a Shopify order and allow the store owner to attach or select a print file for fulfillment? Yes/No. If yes, the PoC is unblocked. Custom per-order file generation is a post-PoC enhancement.

**Dependencies:** Task 65 (platform chosen), Task 67 (products created in Shopify).

---

## Task 69 — Document API contracts and store credentials

**Milestone:** 20A
**Phase:** 10 — Commerce Prerequisites
**Owner:** Developer

**Why:** Before the builder starts M20, they need a clear reference for the API surface they will code against. This task consolidates all the API details discovered in Tasks 65–68 into a single reference document. It also ensures credentials are accessible to the build process without being committed to the repo.

**Deliverable:** `docs/engineering/commerce_api_contracts.md` documenting all API endpoints, parameters, and credential management approach.

**Acceptance criteria:**
- [ ] Storefront API GraphQL endpoint and access token management documented (token lives in Firebase Functions environment; not in client)
- [ ] Admin API token management documented (Firebase Functions environment variables only; never in mobile app or web client)
- [ ] Product GIDs for t-shirt and poster variants recorded (needed for `cartCreate` mutations in Firebase Functions)
- [ ] Mockup API endpoint documented: URL, required parameters, response format, expected latency
- [ ] Line item custom property format confirmed and documented: `{ "merchConfigId": "<id>" }` — full design config in Firestore, not in Shopify cart attributes
- [ ] `POST /createMerchCart` Firebase Function request/response contract documented: request body shape, Firebase Auth header requirement, response shape `{ checkoutUrl, cartId, merchConfigId }`
- [ ] Shopify `orders/create` webhook payload format documented: payload structure, HMAC authentication header, expected response, and how the Function links `orderId` to `MerchConfig`
- [ ] Credentials checklist: Storefront access token, Admin API token, mockup API key (if separate), webhook signing secret — all stored in password manager and Firebase Functions config; none in repo

**Dependencies:** Tasks 65–68 all complete.

---

## M20A — Risks and open questions

1. **Dynamic rendering support (Task 68)** — This is the only real unknown. Options A, B, and C have significantly different implementation costs. Option A is ideal; Option B adds a Cloud Functions dependency; Option C may require re-evaluating the product concept.

2. **Mockup API rate limits** — The design studio makes a mockup API call every time the user changes design style, placement, or colour. Check rate limits before building — may need client-side debouncing or caching by parameter hash.

3. **Shopify plan selection** — The Basic Shopify plan is sufficient for Storefront API access. Confirm the chosen plan includes API access before paying.

4. **Country code list size** — A user with 100+ visited countries produces a large `visitedCodes` string as a line item property. Confirm Shopify's custom attribute character limit (currently 255 chars per value). ISO alpha-2 codes are 2 chars + comma separator; 100 countries = ~300 chars. May need to encode as a compressed format or use a Firestore lookup reference instead.

---

## M20A — Build order and handoff

All tasks are sequential due to dependencies:

```
Task 65 (choose platform)
    ↓
Task 66 (create store)  ← can start in parallel with 65
    ↓
Task 67 (configure products)
    ↓
Task 68 (connect fulfilment + validate rendering)
    ↓
Task 69 (document API contracts)
    ↓
M20 builder may begin
```

**M20 cannot start until Task 68 is complete and Option A, B, or C is confirmed.** The Architect will adjust the M20 implementation plan based on the Task 68 outcome before the builder starts.

---

---

## Milestone 20 — Phase 10: Shop & Merchandise (PoC)

**Goal:** A user can tap "Shop" in the app, select their visited countries, choose a product and variant, and complete a Shopify checkout. The order links to a Firestore `MerchConfig` document so the store owner can identify which countries to feature in the print file. Store owner manually attaches a print file per order in the Printful dashboard (PoC fulfilment model per ADR-062).

**Phase:** 10 — Commerce
**ADRs:** ADR-062 (backend-mediated architecture), ADR-063 (Printful)

**Scope boundary (PoC — what is explicitly OUT):**
- No live mockup generation — static placeholder product images only
- No Printful API calls from Firebase Functions (post-PoC)
- No design studio (style / placement / colour selection for the print) — variant selection only
- No map-to-image rendering in this milestone

**Build order:**

```
Task 70 (Functions setup)
    ↓
Task 71 (createMerchCart function)
    ↓
Task 72 (webhook handler)          ← parallel with 71 once Functions deploy works
    ↓
Task 73 (mobile: Shop entry + Country Selection)
    ↓
Task 74 (mobile: Product Browser)
    ↓
Task 75 (mobile: Variant Selection + Checkout handoff)
```

---

## Task 70 — Firebase Functions project setup

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** Firebase Functions is the only layer that calls Shopify and Printful (ADR-062). Before any commerce logic can be built, the Functions project must be initialised, buildable, and deployable. Firebase requires the Blaze (pay-as-you-go) plan for Cloud Functions.

**Deliverable:** `apps/functions/` initialised as a TypeScript Firebase Functions project (v2). A stub `helloRoavvy` HTTPS callable function deployed to Firebase and returning `{ status: "ok" }`.

**Acceptance criteria:**
- [ ] `apps/functions/src/index.ts` compiles with `tsc` and exports at least one HTTPS callable function
- [ ] `firebase deploy --only functions` succeeds against the Roavvy Firebase project
- [ ] Firebase Blaze plan active on the Firebase project (prerequisite; builder confirms before starting)
- [ ] `apps/functions/.env` loaded via `dotenv` in local dev; `apps/functions/.env.example` committed with placeholder values
- [ ] `apps/functions/.env` confirmed git-ignored
- [ ] No secrets committed to the repo

**Dependencies:** M20A complete (Tasks 65–69). Blaze plan must be enabled by the user before the builder starts.

---

## Task 71 — `createMerchCart` Firebase Function

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** This is the core commerce function. The mobile app calls it to create a Shopify cart and receive a checkout URL. The function must persist the user's design configuration to Firestore before creating the cart, so the store owner can reference it when fulfilling the order.

**Deliverable:** `POST /createMerchCart` Firebase HTTPS callable function deployed to Firebase. Firestore security rules for `users/{uid}/merch_configs` deployed.

**`MerchConfig` Firestore schema (`users/{uid}/merch_configs/{configId}`):**

```
userId: string
variantId: string            // Shopify GID e.g. "gid://shopify/ProductVariant/47577103466683"
selectedCountryCodes: string[] // ISO 3166-1 alpha-2
quantity: number             // always 1 for PoC
shopifyCartId: string | null // populated after cartCreate
shopifyOrderId: string | null // populated after orders/create webhook
createdAt: timestamp
```

**Function contract (matches `docs/engineering/commerce_api_contracts.md` §4):**

Request (mobile → function):
```json
{
  "userId": "firebase-uid",
  "variantId": "gid://shopify/ProductVariant/47577103466683",
  "selectedCountryCodes": ["GB", "FR", "JP"],
  "quantity": 1
}
```

Response (function → mobile):
```json
{
  "checkoutUrl": "https://roavvy.myshopify.com/cart/c/...",
  "cartId": "gid://shopify/Cart/...",
  "merchConfigId": "<firestore-doc-id>"
}
```

**Acceptance criteria:**
- [ ] Function callable via Firebase SDK from the mobile app (Firebase Auth ID token required; `onCall` handles verification automatically — ADR-064)
- [ ] Invalid / missing auth returns a Firebase Functions `unauthenticated` error
- [ ] Malformed body (missing variantId, empty countryCodes) returns `invalid-argument` error
- [ ] `MerchConfig` document written to Firestore with correct fields before Shopify cart is created
- [ ] `SHOPIFY_STOREFRONT_TOKEN` read from `process.env`; used directly as `X-Shopify-Storefront-Access-Token` header — no token exchange or refresh logic (ADR-064 §3)
- [ ] `cartCreate` mutation attaches `{ key: "merchConfigId", value: "<configId>" }` as a cart attribute
- [ ] Returned `checkoutUrl` is a valid `roavvy.myshopify.com` URL
- [ ] No Firestore security rule changes needed — existing `users/{userId}/{document=**}` wildcard rule already covers `merch_configs` (ADR-064 §5)

**Dependencies:** Task 70 (Functions project setup).

---

## Task 72 — `shopifyOrderCreated` webhook handler

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** When a customer completes Shopify checkout, Roavvy needs to link the Shopify order to the `MerchConfig` document so the store owner can look up which countries to print. HMAC verification is required to reject spoofed webhook calls.

**Deliverable:** `POST /shopifyOrderCreated` Firebase HTTPS function (non-callable, raw HTTP) that verifies the Shopify HMAC signature, reads `note_attributes` for `merchConfigId`, and writes `shopifyOrderId` to the Firestore `MerchConfig` document.

**Acceptance criteria:**
- [ ] Requests where `X-Shopify-Hmac-Sha256` header does not match computed HMAC are rejected with HTTP 401
- [ ] Valid webhook payload with `note_attributes: [{ name: "merchConfigId", value: "<id>" }]` updates `MerchConfig.shopifyOrderId` and sets `status: "ordered"`
- [ ] Function returns HTTP 200 within 5 seconds (Shopify retry requirement)
- [ ] Webhook registered in Shopify Admin for the `orders/create` topic pointing at the deployed function URL
- [ ] `SHOPIFY_CLIENT_SECRET` used for HMAC verification loaded from Firebase Functions environment config; not hard-coded

**Dependencies:** Task 70 (Functions setup), Task 71 (MerchConfig Firestore schema established).

---

## Task 73 — Mobile: Shop entry point + Country Selection screen

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** This is the first screen in the commerce flow. The UX spec (`docs/ux/commerce_flow.md`) states that countries should be pre-selected from the user's visit history — zero friction. The user can deselect countries they don't want on the product before proceeding.

**Deliverable:** "Shop" button on the Stats screen navigates to `MerchCountrySelectionScreen`. The screen shows all of the user's effective visited countries as toggleable rows (flag + name + checkbox). A "Next →" button navigates to the Product Browser when at least one country is selected.

**Acceptance criteria:**
- [ ] "Shop" button visible on the Stats screen (position: consistent with existing Stats layout)
- [ ] `MerchCountrySelectionScreen` lists every effective visited country (ISO alpha-2 → display name + flag)
- [ ] All countries pre-selected on first open
- [ ] "Select all" and "Clear all" controls present
- [ ] "Next →" button enabled only when ≥ 1 country is selected; disabled (greyed) otherwise
- [ ] Selected country codes are passed to the next screen
- [ ] Screen accessible via the Stats tab only (not from the tab bar directly)
- [ ] No network calls on this screen — reads from local Riverpod provider

**Dependencies:** None beyond existing app structure (effective visited countries already available via Riverpod).

---

## Task 74 — Mobile: Product Browser screen

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** The user needs to choose between the two available products (T-shirt and Poster). For the PoC, static placeholder images are sufficient — live mockup generation is post-PoC.

**Deliverable:** `MerchProductBrowserScreen` shows two product cards (Roavvy Test Tee, Roavvy Travel Poster). Each card shows a placeholder product image, product name, and price range. Tapping a card navigates to `MerchVariantScreen` for that product.

**Products (from `commerce_api_contracts.md`):**
- Roavvy Test Tee — from £29.99 — Product GID `gid://shopify/Product/8357194694843`
- Roavvy Travel Poster — from £24.99 — Product GID `gid://shopify/Product/8357218353339`

**Acceptance criteria:**
- [ ] Both product cards shown with placeholder image asset, name, and "from £XX.XX" price
- [ ] Tapping a card navigates to `MerchVariantScreen` passing the product type and selected country codes
- [ ] Screen scrollable; renders correctly on iPhone SE (375pt width) and iPhone Pro Max
- [ ] No network calls on this screen

**Dependencies:** Task 73 (country codes passed from previous screen).

---

## Task 75 — Mobile: Variant Selection + Checkout handoff

**Milestone:** 20
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** This is where the user commits to a specific product variant and triggers cart creation. The Firebase Function call and Shopify checkout URL handoff happen here. This is the last screen before the user leaves the app to complete payment.

**Deliverable:** `MerchVariantScreen` with pickers appropriate to the selected product, a "Buy Now" button that calls `createMerchCart`, and opens the returned `checkoutUrl` in `SFSafariViewController`.

**Variant options:**

T-shirt:
- Colour: Black / White / Navy / Heather Grey / Red
- Size: S / M / L / XL / 2XL
- 25 variant GIDs (from `commerce_api_contracts.md`)

Poster:
- Paper: Enhanced Matte / Luster / Fine Art
- Size: 12x18in / 18x24in / 24x36in / A3 / A4
- 15 variant GIDs (from `commerce_api_contracts.md`)

**Acceptance criteria:**
- [ ] Correct pickers shown for T-shirt (colour + size) vs Poster (paper + size)
- [ ] Correct variant GID resolved from picker state (all 40 GIDs present in code, sourced from `commerce_api_contracts.md`)
- [ ] "Buy Now" shows a loading indicator while the Firebase Function call is in flight
- [ ] On success: `checkoutUrl` opened in `SFSafariViewController` (iOS) — not `webview`, not external Safari
- [ ] On Firebase Function error: user-facing error message shown with a "Try again" option
- [ ] Selected country codes and quantity (1) passed correctly to the function
- [ ] Order summary row shown above "Buy Now": selected product, variant, and number of countries

**Dependencies:** Task 71 (`createMerchCart` function deployed and callable), Task 74 (product + country codes passed from previous screen).

---

## M20 — Risks and open questions

1. **Firebase Blaze plan** — Cloud Functions require the Blaze plan. Must be enabled before Task 70 starts. The user must confirm this before the builder begins.

2. **Shopify Storefront token vs client credentials token** — The `commerce_api_contracts.md` documents a Storefront API access token (`SHOPIFY_STOREFRONT_TOKEN`). The `createMerchCart` function uses this token (not the Admin token) to call the Storefront API `cartCreate` mutation. Confirm the token in `.env` has the correct public Storefront API access token (not the Admin token).

3. **Checkout URL domain** — `checkoutUrl` returned by `cartCreate` must use `roavvy.myshopify.com`. Confirm Shopify has not configured a custom domain that would change the checkout host.

4. **`SFSafariViewController` session** — The Shopify checkout runs in `SFSafariViewController`. After the user completes payment, Shopify redirects to its own confirmation page. The app has no programmatic signal that checkout succeeded — the `orders/create` webhook is the only confirmation. This is acceptable for the PoC.

5. **Firestore rules deployment** — New security rules for `users/{uid}/merch_configs` must be deployed alongside Task 71. Builder must not leave the collection open.

6. **Printful API key** — The `PRINTFUL_API_KEY` is not required for the PoC (store owner manually attaches print files). It can be left blank in `.env` for now.

---


---

# M21 — Personalised Flag Print Pipeline (Mobile + Functions)

**Milestone:** 21
**Phase:** 10 — Commerce
**Status:** Planned — 2026-03-21

## Goal

Every Roavvy merch order carries a unique auto-generated image of the buyer's visited country flags. The mobile app shows a live flag grid preview before purchase. Firebase Functions generate both a web preview and a print-quality PNG at `createMerchCart` time — before the user pays. The `shopifyOrderCreated` webhook only validates the file exists, creates the Printful order via API, and attaches the generated print file.

## Why

The M20 PoC proved the end-to-end flow but deferred the core product differentiator: a personalised flag print unique to each buyer. Without it the product is not shippable. The two-stage model (generate before checkout, validate on webhook) keeps webhook handlers fast and idempotent, and means the print file is ready the moment the order is paid.

## Architecture

See ADR-065 (decisions.md) and ADR-063 revision. Summary:
- Mobile renders a `FlagGridPreview` widget (display-only, no upload).
- `createMerchCart` generates preview PNG + print PNG, uploads to Firebase Storage, writes paths to `MerchConfig`.
- `shopifyOrderCreated` validates the print file, then creates the Printful order via direct API call with the print file attached.
- Printful Shopify app auto-import is disabled for generated-merch variants.

## Scope — included

- `FlagGridPreview` Flutter widget in `MerchVariantScreen`
- `templateId: 'flag_grid_v1'` and M21 `MerchConfig` fields end-to-end
- `imageGen.ts` — flag grid PNG generator (`flag-icons` + `@resvg/resvg-js` + `sharp`)
- `printDimensions.ts` — static Shopify variant GID → print canvas dimensions map
- `createMerchCart` updated: generates preview + print file, uploads to Firebase Storage
- `shopifyOrderCreated` updated: validates file, creates Printful order via API with file attached
- Shopify variant GID → Printful variant ID mapping table

## Scope — excluded

- Scheduled cleanup of abandoned design records (30-day manual cleanup acceptable for MVP)
- Templates other than `flag_grid_v1`
- Mockup generation for product browser
- Web shop landing page (`/shop`)
- Android support

---

## Task 76 — Mobile: `FlagGridPreview` widget

**Milestone:** 21
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** The current `MerchVariantScreen` has no visual preview of what the user is buying. A live flag grid makes the personalisation tangible before purchase.

**Deliverable:** `FlagGridPreview` — a Flutter widget that renders a responsive grid of country flag images for a `List<String> selectedCodes`. Shown in `MerchVariantScreen` between the "Designing for N countries" header and the first picker row.

**Implementation notes:**
- Evaluate `country_flags` (pub.dev) for bundled flag assets. If the package adds unacceptable size, fall back to flag emoji rendered in a `Text` widget (simple, zero-size overhead, acceptable for preview).
- Grid: 5 columns on screens ≤390pt wide, 6 columns wider. Each cell is square, flag centred with padding.
- Maximum 24 cells shown. If `selectedCodes.length > 24`, the last cell shows "+N more" instead of a flag.
- Zero height when `selectedCodes` is empty.
- No async work, no network calls.

**Acceptance criteria:**
- [ ] Renders correctly for 1, 5, 24, and 50+ codes
- [ ] "+N more" chip shown when codes > 24
- [ ] All flag assets are bundled (no network calls)
- [ ] Visible in `MerchVariantScreen` for both T-shirt and Poster products
- [ ] Renders without overflow on iPhone SE (375pt)
- [ ] `flutter analyze` zero issues

**Dependencies:** Task 75 (`MerchVariantScreen` exists and receives `selectedCodes`).

---

## Task 77 — Functions: `MerchConfig` type extension + variant mapping tables

**Milestone:** 21
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** The updated `MerchConfig` type (ADR-065) must be in place before Tasks 78–80 can write or read the new fields. The Shopify GID → Printful variant ID mapping is required for Task 80 to create Printful orders correctly.

**Deliverables:**

1. `apps/functions/src/types.ts` — `MerchConfig` extended with M21 fields:
   ```typescript
   templateId: 'flag_grid_v1';
   designStatus: 'pending' | 'files_ready' | 'generation_error' | 'print_file_submitted' | 'print_file_error';
   previewStoragePath: string | null;
   printFileStoragePath: string | null;
   printFileSignedUrl: string | null;
   printFileExpiresAt: admin.firestore.Timestamp | null;
   printfulOrderId: string | null;
   ```

2. `apps/functions/src/printDimensions.ts` — new file:
   - `PRINT_DIMENSIONS: Record<string, { widthPx: number; heightPx: number; dpi: number; backgroundColor: 'white' | 'transparent' }>` keyed by Shopify variant GID.
   - `PRINTFUL_VARIANT_IDS: Record<string, number>` keyed by Shopify variant GID → Printful numeric variant ID.
   - Source the Printful variant IDs from the Printful dashboard (product catalogue → variant IDs). Verify against `commerce_api_contracts.md`.

**Acceptance criteria:**
- [ ] `MerchConfig` TypeScript interface compiles with all M21 fields
- [ ] `PRINT_DIMENSIONS` covers all 40 Shopify variant GIDs (25 t-shirt + 15 poster)
- [ ] `PRINTFUL_VARIANT_IDS` covers all 40 GIDs with verified Printful IDs
- [ ] `npm run build` in `apps/functions/` passes with zero errors

**Dependencies:** Task 75 (existing `createMerchCart`), ADR-065.

---

## Task 78 — Functions: `imageGen.ts` — flag grid PNG generator

**Milestone:** 21
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** The core generation logic. Both `createMerchCart` (preview + print) and `shopifyOrderCreated` (optional regeneration) call this helper.

**Deliverable:** `apps/functions/src/imageGen.ts` exporting:

```typescript
export async function generateFlagGrid(input: {
  templateId: 'flag_grid_v1';
  selectedCountryCodes: string[];
  widthPx: number;
  heightPx: number;
  dpi: number;
  backgroundColor: 'white' | 'transparent';
}): Promise<Buffer>
```

Implementation:
- Load flag SVG from `node_modules/flag-icons/flags/4x3/{lowerCode}.svg`. Skip unknown codes silently.
- Compute grid: columns = `Math.ceil(Math.sqrt(N * (4/3)))` or a fixed column count tuned for print aspect ratio. Cell dimensions = `widthPx / columns`.
- If `cellWidth < 100`: reduce flag count to fit minimum cell size; append a text strip listing remaining country names at the bottom of the canvas (using `sharp`'s text overlay).
- Rasterise each flag SVG to PNG buffer using `@resvg/resvg-js` at `cellWidth × cellHeight`.
- Composite all flag buffers into a white/transparent canvas using `sharp.composite()`.
- Return the final PNG buffer.

`apps/functions/package.json` additions: `flag-icons`, `@resvg/resvg-js`, `sharp`.

**Acceptance criteria:**
- [ ] Returns a valid PNG buffer for 1 country code
- [ ] Returns a valid PNG buffer for 50 country codes
- [ ] Unknown codes are silently skipped (no crash)
- [ ] Output image dimensions match `widthPx × heightPx`
- [ ] Minimum cell size enforced; overflow countries listed in text strip
- [ ] `npm run build` succeeds
- [ ] Jest unit test covers: 1 code, 50 codes, unknown code only, empty array
- [ ] `@resvg/resvg-js` and `sharp` binaries load correctly in Cloud Run linux/amd64 environment (verify via `firebase deploy --only functions` smoke test)

**Dependencies:** Task 77 (package.json and types).

---

## Task 79 — Functions: `createMerchCart` — two-stage generation

**Milestone:** 21
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** This is where the design record is created and both PNG files are generated before the user reaches checkout. By the time the order webhook fires, the print file already exists.

**Deliverable:** Updated `createMerchCart` onCall handler in `apps/functions/src/index.ts`:

After writing the initial `MerchConfig` document (existing logic), and after calling Shopify `cartCreate` (existing logic):

1. Call `generateFlagGrid` twice:
   - **Preview:** `widthPx: 800`, `heightPx: 600`, `dpi: 96`, `backgroundColor: 'white'`. Output: JPEG (use `sharp().toFormat('jpeg', { quality: 80 })`).
   - **Print:** dimensions from `PRINT_DIMENSIONS[variantId]`.
2. Upload both buffers to Firebase Storage (Admin SDK):
   - Preview: `previews/{configId}.jpg` — public read (for display in mobile/web).
   - Print file: `print_files/{configId}.png` — private; generate a signed URL (7-day expiry).
3. Update `MerchConfig`:
   ```typescript
   designStatus: 'files_ready',
   previewStoragePath: `previews/${configId}.jpg`,
   printFileStoragePath: `print_files/${configId}.png`,
   printFileSignedUrl: <signed URL>,
   printFileExpiresAt: <now + 7 days>,
   ```
4. Return `{ checkoutUrl, cartId, configId, previewUrl: <public preview URL> }` to the mobile caller.

If generation fails at any point: set `designStatus: 'generation_error'`, throw `HttpsError('internal', 'Design generation failed. Please try again.')`. Cart is not returned to the user.

**Acceptance criteria:**
- [ ] After a successful call, Firebase Storage contains `previews/{configId}.jpg` and `print_files/{configId}.png`
- [ ] `MerchConfig.designStatus` is `'files_ready'`
- [ ] `MerchConfig.printFileSignedUrl` is a valid signed URL accessible from a browser
- [ ] `previewUrl` returned to the mobile app resolves to a valid image
- [ ] Generation failure results in `HttpsError('internal', ...)` — no cart URL returned
- [ ] `MerchConfig.designStatus` is `'generation_error'` on failure
- [ ] `flutter analyze` zero issues (mobile side unchanged beyond receiving `previewUrl`)

**Dependencies:** Task 78 (`generateFlagGrid`), Task 77 (types + dimensions).

---

## Task 80 — Functions: `shopifyOrderCreated` — validate + Printful order creation

**Milestone:** 21
**Phase:** 10 — Commerce
**Owner:** Builder

**Why:** Closes the fulfilment loop. When an order is paid, the function validates the print file and creates the Printful order via direct API call — no manual dashboard work.

**Deliverable:** Updated `shopifyOrderCreated` onRequest handler:

After updating `MerchConfig.shopifyOrderId` and `status: 'ordered'` (existing logic):

1. Check `MerchConfig.designStatus`:
   - If `'files_ready'` and `printFileExpiresAt > now + 1h`: use existing `printFileSignedUrl`.
   - If signed URL close to expiry: regenerate signed URL from `printFileStoragePath` (7-day renewal).
   - If `'generation_error'` or file missing: call `generateFlagGrid` once. On success update MerchConfig to `'files_ready'`; on failure set `'print_file_error'`, log, return 200.
2. Look up Printful variant ID: `PRINTFUL_VARIANT_IDS[MerchConfig.variantId]`.
3. Create Printful order:
   ```
   POST https://api.printful.com/v2/orders
   Authorization: Bearer {PRINTFUL_API_KEY}
   {
     "external_id": "<shopifyOrderId>",
     "recipient": { <from Shopify order payload> },
     "items": [{
       "variant_id": <printfulVariantId>,
       "quantity": 1,
       "files": [{ "url": "<printFileSignedUrl>", "type": "default" }]
     }]
   }
   ```
4. Update `MerchConfig`:
   ```typescript
   printfulOrderId: response.id,
   designStatus: 'print_file_submitted',
   ```
5. Return 200.

Error handling: any Printful API error → set `designStatus: 'print_file_error'`, log full response, return 200 (Shopify does not retry).

**Acceptance criteria:**
- [ ] End-to-end: placing a test order via the mobile app results in a Printful order visible in the Printful dashboard (sandbox)
- [ ] The Printful order's line item has the correct print file attached
- [ ] `MerchConfig.designStatus` is `'print_file_submitted'` after success
- [ ] `MerchConfig.printfulOrderId` is set
- [ ] Signed URL refresh works when `printFileExpiresAt` is within 1 hour
- [ ] Regeneration fallback works when `designStatus` is `'generation_error'`
- [ ] Printful API errors set `designStatus: 'print_file_error'` and return 200
- [ ] `PRINTFUL_API_KEY` is never logged

**Dependencies:** Task 78 (generator), Task 77 (mapping tables), Task 79 (`createMerchCart` writes files_ready state).

---

## M21 — Risks and open questions

1. **`@resvg/resvg-js` + `sharp` native binaries on Cloud Run** — Both ship prebuilt `.node` binaries. Cloud Run uses `linux/amd64`. Verify both load correctly with a `firebase deploy --only functions` smoke test in Task 78 before proceeding to Tasks 79–80. If either binary is missing, use `npm install --platform=linux --arch=x64` in the functions build step.

2. **Firebase Storage public access for preview** — The preview image (`previews/{configId}.jpg`) needs to be publicly readable so the mobile app can display it. Configure Firebase Storage rules to allow public read on `previews/*`. Print files (`print_files/*`) remain private (signed URL only).

3. **Printful sandbox** — All Tasks 79–80 acceptance tests must pass against the Printful sandbox API before any production Printful API key is used. Use a sandbox Printful API key in `.env` for development.

4. **Printful variant ID verification** — Printful variant IDs (numeric) must be verified in the Printful dashboard before Task 77. They differ from Shopify variant GIDs. A mismatch creates the wrong product at Printful.

5. **Shopify order shipping address** — `shopifyOrderCreated` must parse the shipping address from the Shopify webhook payload to populate the Printful order `recipient` field. Verify the Shopify webhook payload includes a full shipping address (it does for `orders/paid` topic; confirm the webhook topic registered in M20 is `orders/paid` not `orders/create`).

6. **Printful Shopify app auto-import** — Must be disabled for the product variants in the generated-merch pipeline (see ADR-063). Verify in the Printful dashboard after Task 80 that the test order is not duplicated (once by the app, once by the function).

