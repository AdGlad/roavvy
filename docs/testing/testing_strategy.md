# Roavvy Automated Testing Strategy

**Version:** 1.0
**Date:** June 2026
**Status:** Authoritative — all future testing work must align with this document
**Scope:** `apps/mobile_flutter` Flutter iOS application

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Goals](#2-goals)
3. [Testing Principles](#3-testing-principles)
4. [Current State Assessment](#4-current-state-assessment)
5. [Testing Architecture](#5-testing-architecture)
6. [Technology Stack](#6-technology-stack)
7. [File and Naming Conventions](#7-file-and-naming-conventions)
8. [Coverage Objectives](#8-coverage-objectives)
9. [Continuous Integration Strategy](#9-continuous-integration-strategy)
10. [Test Data Strategy](#10-test-data-strategy)
11. [Risk Map — Priority Areas](#11-risk-map--priority-areas)
12. [Incremental Rollout Plan](#12-incremental-rollout-plan)
13. [Defect Resolution and Incremental Fixing Approach](#13-defect-resolution-and-incremental-fixing-approach)

---

## 1. Executive Summary

Roavvy is an iOS-first Flutter application backed by Firebase, a Swift platform channel for on-device photo scanning, and a Drift (SQLite) local database. It delivers on-device country detection, travel achievements, daily UNESCO challenges, a travel card and passport system, and a merchandise workflow involving Printful fulfilment.

The application has a meaningful foundation of test coverage — approximately 90 unit and widget test files already exist across the data, feature, and core layers. However, no continuous integration pipeline is configured, no integration tests exist, and there are no formal quality gates on pull requests. The test suite therefore provides value in isolation but does not yet provide the release confidence the product requires.

This document defines the authoritative automated testing strategy for Roavvy. It establishes:

- The required test layers and what each must cover
- The technology stack to be standardised on
- Realistic coverage targets with a clear path to achieve them
- A CI pipeline that enforces quality gates on every pull request
- An incremental rollout plan across eight phases
- A defect resolution discipline that keeps the codebase continuously stable

The first priority is not writing more tests. The first priority is establishing the framework, validating that the existing tests run cleanly, reporting coverage, and building the CI infrastructure. New tests are added incrementally on top of a known-good baseline.

---

## 2. Goals

### 2.1 Product Stability

- Prevent regressions in existing functionality across every release
- Detect defects before they reach production
- Reduce production incidents caused by untested code paths
- Ensure consistent behaviour across iOS versions and device sizes

### 2.2 Development Velocity

- Allow features to be delivered faster because engineers have confidence the existing system still works
- Reduce time spent on manual verification of functionality already covered by tests
- Provide rapid feedback during development — test runs should complete in seconds for unit tests, minutes for the full suite
- Support continuous delivery practices by making every commit releasable in principle

### 2.3 User Experience Protection

- Ensure critical user journeys continue to function correctly after every change
- Protect: onboarding, photo scanning, map interaction, challenge participation, achievement unlocking, merchandise creation, cart management, and checkout handoff
- Detect UI and behavioural regressions early through widget tests

### 2.4 Revenue Protection

- Prevent defects that corrupt merchandise configuration or flag selection
- Prevent checkout data errors before handoff to Printful
- Ensure cart calculations and item management remain correct
- Protect the mockup approval, order placement, and order tracking workflows
- Verify that Printful placement mapping produces correct output

### 2.5 Data Integrity

- Ensure user visit data, country detection results, and scan history remain accurate
- Validate XP calculations, achievement qualification logic, and level-up thresholds
- Prevent corruption of the Drift SQLite database through migration testing
- Verify that Firestore sync writes only the permitted fields (`countryCode`, `firstSeen`, `lastSeen`, achievement state, share tokens)

### 2.6 Release Confidence

- Establish clear, automated quality gates that must pass before any merge
- Provide measurable, reproducible coverage reports
- Reduce reliance on manual testing for regression verification
- Give the team confidence that a passing CI run represents a shippable build

---

## 3. Testing Principles

The following principles govern all testing decisions at Roavvy. When in doubt, apply these principles rather than asking for a rule.

| Principle | Meaning in Practice |
|---|---|
| **Automate whenever practical** | If a behaviour can be verified mechanically, it must not rely on manual checking |
| **Test business logic before UI** | A unit test for a calculation is more valuable than a widget test for the screen that displays it |
| **Focus on high-risk areas first** | Merchandise creation, checkout, scan processing, and achievement qualification take priority over low-value screens |
| **Prefer deterministic tests** | Tests must produce the same result every run. Time-dependent, random, or platform-dependent logic must be injected and controlled |
| **Keep tests fast** | Unit tests must run in milliseconds. No test should make a real network call, read from the file system arbitrarily, or sleep without good reason |
| **Run tests continuously** | Tests are not a pre-release activity. They run on every pull request and locally before every push |
| **Avoid brittle tests** | Do not test implementation details. Test observable behaviour. Tests that break on harmless refactors destroy confidence in the suite |
| **Prevent production dependencies** | No test may touch real Firebase, a real Printful endpoint, a real payment flow, or any live third-party service |
| **Make failures easy to diagnose** | A failing test must identify what broke and why. Opaque assertion failures waste engineering time |
| **Increase coverage incrementally** | Add tests as features are built or bugs are fixed. Do not attempt to reach coverage targets in a single sprint |

---

## 4. Current State Assessment

### 4.1 What Exists

The `apps/mobile_flutter/test/` directory contains approximately 90 test files organised as follows:

```
test/
  core/
    notification_service_test.dart
    providers_test.dart
    year_filter_providers_test.dart
  data/
    achievement_evaluation_test.dart
    achievement_repository_test.dart
    bootstrap_service_test.dart
    daily_challenge_repository_test.dart
    firestore_sync_service_test.dart
    hero_image_repository_anniversary_test.dart
    level_up_repository_test.dart
    milestone_repository_test.dart
    region_repository_test.dart
    trip_repository_test.dart
    visit_repository_test.dart
  features/
    account/   cards/   challenge/   globe_replay/
    journal/   map/     memory/      merch/
    onboarding/ scan/   settings/    sharing/
    shell/      stats/  visits/      xp/
  widget_test.dart
```

Coverage exists across the data layer, challenge logic, card rendering engines, scan processing, map components, and merchandise screens.

### 4.2 What Is Missing

| Gap | Impact | Phase to Address |
|---|---|---|
| No CI pipeline (`.github/workflows/`) | Tests run only when an engineer remembers to run them locally | Phase 7 |
| No integration tests (`integration_test/`) | No end-to-end journey validation | Phase 5 |
| No Firebase Emulator test suite | Backend security rules and Cloud Functions untested | Phase 6 |
| `mocktail` not in `dev_dependencies` | Mocking approach is inconsistent | Phase 1 |
| No coverage reporting | Coverage is unknown; targets cannot be measured | Phase 1 |
| Merch cart and checkout not covered | Highest-revenue workflow has no test protection | Phase 3–4 |
| XP repository and notifier partially covered | Level-up logic is partially unverified | Phase 2–3 |
| Firestore security rules untested | Access control regressions are undetectable | Phase 6 |
| No device-level tests | Permission flows and photo scanning are untested programmatically | Phase 8 |

### 4.3 Known Risk Areas

The following areas represent the highest risk of regression and must receive priority testing investment:

1. **Scan pipeline** — `photo_scan_channel.dart` → visit deduplication → country detection → achievement qualification
2. **Merchandise creation** — flag selection → Printful placement mapping → mockup generation → cart → checkout handoff
3. **Achievement qualification** — `achievement_repository.dart` evaluation logic and XP / level-up thresholds
4. **Firestore sync** — write permission rules; only permitted fields must ever be written
5. **Daily challenge scoring** — guess normalisation, hot/cold feedback, streak calculation
6. **Cart calculations** — item count, price totals, variant selection

---

## 5. Testing Architecture

Roavvy uses a six-layer testing architecture. Each layer has a distinct purpose, a defined scope, and its own execution frequency.

```
┌─────────────────────────────────────────────────────┐
│              Device-Level Tests (Phase 8)            │  ← Real device / Firebase Test Lab
├─────────────────────────────────────────────────────┤
│          Backend Emulator Tests (Phase 6)            │  ← Firebase Emulator Suite
├─────────────────────────────────────────────────────┤
│           Integration Tests (Phase 5)                │  ← integration_test package
├─────────────────────────────────────────────────────┤
│            Widget Tests (Phase 4)                    │  ← flutter_test / WidgetTester
├─────────────────────────────────────────────────────┤
│            Service Tests (Phase 3)                   │  ← Mocked/emulated dependencies
├─────────────────────────────────────────────────────┤
│             Unit Tests (Phase 2)                     │  ← Pure Dart, no Flutter
└─────────────────────────────────────────────────────┘
```

The lower layers execute on every commit. Upper layers execute on pull requests and release candidates.

---

### 5.1 Unit Tests

**Purpose:** Validate pure business logic with no external dependencies.

**Characteristics:**
- No Flutter framework (`testWidgets` not used)
- No Firebase, no Drift database, no platform channels
- All dependencies injected via constructor; none created inside the function under test
- Deterministic: fixed inputs, fixed expected outputs
- Execution time: under 5ms per test, entire unit suite under 30 seconds

**Location:** `test/` mirroring `lib/` structure, `_test.dart` suffix

**Concrete examples from Roavvy's codebase:**

| Source File | What to Test |
|---|---|
| `features/challenge/guess_normalizer.dart` | Normalisation of Unicode, whitespace, accents, partial matches |
| `features/challenge/hot_cold_feedback.dart` | Distance thresholds → feedback label correctness |
| `features/challenge/daily_challenge_stats.dart` | Streak increment/reset logic, win-rate calculation |
| `features/cards/grid_math_engine.dart` | Grid dimension calculations for all country counts |
| `features/cards/stamp_noise_generator.dart` | Noise repeatability given a fixed seed |
| `features/cards/title_generation/rule_based_title_generator.dart` | Title rules: single country, multi-country, continent groups |
| `features/merch/merch_template_ranker.dart` | Template ranking given a specific set of visited countries |
| `features/merch/merch_variant_lookup.dart` | Variant selection for a given size/colour combination |
| `features/merch/printful_placement_mapper.dart` | Placement coordinate correctness for each product type |
| `features/merch/travel_identity.dart` | Identity construction from visited country set |
| `features/scan/hero_candidate_selector.dart` | Hero selection priority rules |
| `features/map/globe_projection.dart` | Lat/lng → screen coordinate calculations |
| `features/map/country_visual_state.dart` | Visual state transitions: unvisited → visited → highlighted |
| `data/xp_repository.dart` | XP award amounts, level threshold boundaries |
| `data/achievement_repository.dart` | Each achievement qualification condition in isolation |

**Target:** 85%+ coverage of all pure business logic. This is the largest and most important layer.

---

### 5.2 Service Tests

**Purpose:** Validate application services, repositories, and data persistence with mocked or emulated dependencies.

**Characteristics:**
- May use Flutter test infrastructure but not `testWidgets`
- Firebase replaced with `fake_cloud_firestore` and `firebase_auth_mocks`
- Drift database uses an in-memory configuration: `NativeDatabase.memory()`
- External HTTP calls (Printful, any third-party API) mocked with `mocktail`
- Platform channels stubbed using `TestDefaultBinaryMessengerBinding`

**Location:** `test/data/` and `test/features/*/` for service-level files

**Concrete examples from Roavvy's codebase:**

| Source File | What to Test |
|---|---|
| `data/visit_repository.dart` | Insert, deduplicate by `assetId`, query by country, delete all |
| `data/trip_repository.dart` | Trip creation from visits, date grouping, country assignment |
| `data/achievement_repository.dart` | Achievement unlock write, already-unlocked guard, Firestore sync |
| `data/daily_challenge_repository.dart` | Challenge fetch, answer recording, streak persistence |
| `data/firestore_sync_service.dart` | Only permitted fields are written; no photo data; offline queuing |
| `data/level_up_repository.dart` | Level threshold crossings, notification trigger conditions |
| `data/milestone_repository.dart` | Milestone record creation, read-back accuracy |
| `data/region_repository.dart` | Region assignment from country codes, continent rollup |
| `data/bootstrap_service.dart` | First-run initialisation sequence, idempotency on re-run |
| `data/heritage_repository.dart` | UNESCO site lookup by ID and proximity |
| `features/merch/merch_cart_repository.dart` | Add item, update quantity, remove item, clear cart, total calculation |
| `features/merch/mockup_approval_service.dart` | Approval state transitions, rejection with reason |
| `features/challenge/daily_challenge_service.dart` | Correct challenge selection for today's date, no repetition within cycle |
| `features/sharing/share_token_service.dart` | Token generation uniqueness, expiry validation |
| `features/memory/memory_pulse_service.dart` | Anniversary detection, pulse eligibility rules |
| `features/scan/hero_image_repository.dart` | Hero image persistence, cache invalidation, anniversary selection |
| `features/account/account_deletion_service.dart` | Deletion cascade: local Drift data, Firestore data, auth account |
| `core/providers.dart` | Provider dependency wiring, initial state correctness |

**Key constraint:** No service test may write to production Firestore or call a real Printful endpoint. Any service that communicates externally must have its HTTP client injected and mocked.

**Target:** 70%+ coverage of the service and repository layer.

---

### 5.3 Widget Tests

**Purpose:** Validate the behaviour of individual UI components and screens in isolation.

**Characteristics:**
- Use `testWidgets` and `WidgetTester`
- Providers are overridden with `ProviderScope(overrides: [...])` using controlled test data
- No real navigation; `GoRouter` stubbed or replaced with `MaterialApp` wrapper as appropriate
- Platform channel calls stubbed
- Focus on interactions and state changes, not pixel-perfect layout

**Location:** `test/features/*/` mirroring widget file paths

**Concrete examples from Roavvy's codebase:**

| Screen / Widget | What to Test |
|---|---|
| `features/onboarding/onboarding_flow.dart` | Step progression, "Scan my photos" CTA visible on final step |
| `features/scan/scan_screen.dart` | Scan button triggers channel call, progress indicator appears, completion state |
| `features/scan/scan_summary_screen.dart` | Country count display, new countries highlighted, CTA buttons present |
| `features/scan/achievement_unlock_sheet.dart` | Achievement name rendered, confetti triggered, dismiss action |
| `features/scan/level_up_sheet.dart` | New level displayed, XP bar rendered correctly |
| `features/challenge/daily_challenge_screen.dart` | Clue reveal progression, guess input accepted, result state shown |
| `features/challenge/challenge_stats_screen.dart` | Streak count, win rate, history list rendered |
| `features/merch/merch_country_selection_screen.dart` | Country list renders, selection toggles correctly, count badge updates |
| `features/merch/merch_customisation_sheet.dart` | Colour picker, layout toggle, preview updates |
| `features/merch/merch_variant_screen.dart` | Size selection, colour selection, Add to Cart enabled/disabled state |
| `features/merch/merch_cart_screen.dart` | Item list, quantity adjustment, remove item, total displayed, Checkout button |
| `features/merch/merch_order_confirmation_screen.dart` | Order reference displayed, tracking link present |
| `features/merch/merch_orders_screen.dart` | Order history list, status badges, empty state |
| `features/stats/achievements_screen.dart` | Locked vs unlocked badges, progress bars, correct counts |
| `features/stats/stats_screen.dart` | Country count, continent count, XP level, top countries |
| `features/map/map_screen.dart` | Map renders with visited countries, country tap opens detail sheet |
| `features/map/country_detail_sheet.dart` | Country name, flag, visit date, UNESCO sites nearby |
| `features/cards/passport_book_screen.dart` | Stamp grid renders, page turn animation triggers |
| `features/auth/sign_in_screen.dart` | Apple Sign-In button present, anonymous skip available |
| `features/shell/main_shell.dart` | Bottom navigation renders, tab switching works |
| `features/visits/review_screen.dart` | Detected countries listed, manual add/remove controls |

**Target:** 40%+ coverage of UI components, prioritising screens in critical revenue and onboarding workflows.

---

### 5.4 Integration Tests

**Purpose:** Validate complete end-to-end user journeys through the live Flutter application running against mocked backends.

**Characteristics:**
- Use the `integration_test` package, which runs on a simulator or real device
- Firebase replaced with emulator or in-memory fakes injected at app startup via test entry point
- Platform channel (photo scanning) stubbed to return controlled fixture data
- Tests drive the application through multiple screens via `find` and `tap`
- Slower than unit/widget tests; run on pull request, not on every local save

**Location:** `integration_test/` at the root of `apps/mobile_flutter/`

**Test entry point:** `integration_test/app_test.dart` which boots the app with test configuration injected

**Critical journeys to cover (in priority order):**

| Journey | Screens Traversed |
|---|---|
| **New user onboarding → first scan** | Onboarding → Scan → Scan Summary → Map |
| **Challenge participation → result** | Daily Challenge → Clue reveals → Guess → Result → Stats |
| **Achievement unlock post-scan** | Scan → Achievement Unlock Sheet → Stats Screen |
| **Merchandise creation → cart** | Merch Shop → Country Selection → Customisation → Variant → Cart |
| **Cart → checkout handoff** | Cart → Checkout → Order Confirmation (Printful call mocked) |
| **Manual visit edit** | Map → Country Detail → Visit Edit Sheet → Saved |
| **Travel card share** | Stats → Card Selection → Share Sheet trigger |
| **Account deletion** | Settings → Delete Account → Confirmation → Auth signed out |

**Target:** One robust integration test per critical journey. Eight journeys minimum. Quality over quantity.

---

### 5.5 Backend Emulator Tests

**Purpose:** Validate Firebase backend behaviour — security rules, Firestore read/write access, Cloud Functions, and authentication flows — in a fully isolated environment.

**Characteristics:**
- Use Firebase Emulator Suite (Firestore, Auth, Functions emulators)
- No test may touch production Firebase under any circumstances
- Rules tested by attempting reads/writes as different auth states (anonymous, authenticated, unauthenticated)
- Cloud Functions tested by invoking them directly against the emulator

**Location:** `test/emulator/` within `apps/mobile_flutter/`
**Emulator configuration:** `firebase.json` emulator settings in project root

**What to test:**

| Area | Tests |
|---|---|
| **Firestore security rules** | Authenticated user can write their own profile; cannot write another user's data; anonymous user read-only on public data; unauthenticated user rejected on all writes |
| **Visit sync** | Only `countryCode`, `firstSeen`, `lastSeen` are accepted; writes containing photo data or GPS coordinates are rejected |
| **Achievement state** | Authenticated user can update their own achievement state; cannot modify another user's achievements |
| **Share tokens** | Token creation succeeds for authenticated user; token read succeeds without authentication (public share); token write by non-owner rejected |
| **Authentication flows** | Anonymous sign-in succeeds; Apple Sign-In upgrade preserves data; account deletion removes all Firestore documents |
| **Cloud Functions** | Order placement function produces correct Printful API payload structure (mocked HTTP); error handling on fulfilment failure |

**Target:** All Firestore security rules tested. All Cloud Functions that touch external services tested with mocked HTTP clients.

---

### 5.6 Device-Level Tests

**Purpose:** Validate behaviour that can only be confirmed on a real device — iOS permission dialogs, photo library access, camera roll scanning, native rendering, and performance.

**Characteristics:**
- Run via Firebase Test Lab or locally on physical iOS devices
- Not required on every commit; required before every TestFlight or App Store submission
- Use the `integration_test` package with real device configuration
- Scanning tests use a controlled photo library populated with fixture images containing known GPS coordinates

**Location:** `integration_test/device/` subdirectory with device-specific test entry points

**What to test:**

| Area | Tests |
|---|---|
| **Photo library permission** | Permission prompt appears; denial is handled gracefully; full access enables scan |
| **Scan pipeline end-to-end** | Known GPS-tagged photos produce correct country codes; deduplication works across re-scans |
| **Platform channel reliability** | Channel delivers results without timeout; large batch (2,000 photos) completes within acceptable time |
| **Rendering performance** | Globe painter renders at 60fps on a supported device; no jank on country tap |
| **Notification permissions** | Notification permission request appears at correct moment; daily challenge notification delivered |

**Target:** Mandatory pass before every release candidate submission. Not gated on individual pull requests.

---

## 6. Technology Stack

All testing at Roavvy standardises on the following packages. No alternatives should be introduced without updating this document.

### 6.1 Core Testing

| Package | Purpose | Source |
|---|---|---|
| `flutter_test` | Unit and widget testing framework | Flutter SDK |
| `test` | Pure Dart test utilities | pub.dev |

### 6.2 Mocking

| Package | Purpose | Version |
|---|---|---|
| `mocktail` | Mock generation without code generation | `^0.3.0` or latest stable |

Add to `dev_dependencies` in `pubspec.yaml`:
```yaml
dev_dependencies:
  mocktail: ^0.3.0
```

`mocktail` is preferred over `mockito` because it does not require build_runner code generation, which slows the development loop.

### 6.3 Firebase Testing

| Package | Purpose |
|---|---|
| `fake_cloud_firestore` | In-memory Firestore for unit and service tests |
| `firebase_auth_mocks` | Firebase Auth mock for sign-in/sign-out flows |
| Firebase Emulator Suite | Full backend validation in an isolated environment |

Both `fake_cloud_firestore` and `firebase_auth_mocks` are already present in `dev_dependencies`.

### 6.4 Integration Testing

| Package | Purpose |
|---|---|
| `integration_test` | End-to-end test runner; part of Flutter SDK |

Add to `dev_dependencies`:
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

### 6.5 Coverage

| Tool | Purpose |
|---|---|
| `flutter test --coverage` | Generates `coverage/lcov.info` |
| `lcov` | Filters and processes coverage data |
| `genhtml` | Generates HTML coverage report |

Coverage report generation command:
```bash
flutter test --coverage
lcov --remove coverage/lcov.info \
  '*/lib/**.g.dart' \
  '*/lib/firebase_options.dart' \
  '*/lib/**/**.freezed.dart' \
  --output-file coverage/lcov_clean.info
genhtml coverage/lcov_clean.info --output-directory coverage/html
```

Generated files (`*.g.dart`, `firebase_options.dart`) must be excluded from coverage measurement as they contain no testable logic.

### 6.6 Continuous Integration

| Tool | Purpose |
|---|---|
| GitHub Actions | CI pipeline execution on every pull request and main branch push |

### 6.7 Device Testing (Future Phase)

| Tool | Purpose |
|---|---|
| Firebase Test Lab | Cloud-hosted real device test execution |

---

## 7. File and Naming Conventions

### 7.1 Test File Location

Test files mirror the `lib/` directory structure exactly:

```
lib/features/merch/merch_cart_repository.dart
→
test/features/merch/merch_cart_repository_test.dart
```

```
lib/data/achievement_repository.dart
→
test/data/achievement_repository_test.dart
```

### 7.2 Naming Rules

- All test files end with `_test.dart`
- Top-level `group()` name matches the class or function under test
- `test()` and `testWidgets()` descriptions are written as complete sentences describing the expected outcome:
  - ✓ `'returns zero when no countries have been visited'`
  - ✗ `'test achievement count'`
  - ✗ `'achievement'`

### 7.3 Test Structure Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Declare mocks at file level
class MockVisitRepository extends Mock implements VisitRepository {}

void main() {
  group('AchievementRepository', () {
    late MockVisitRepository mockVisits;
    late AchievementRepository repository;

    setUp(() {
      mockVisits = MockVisitRepository();
      repository = AchievementRepository(visits: mockVisits);
    });

    group('qualifiesForWorldTraveller', () {
      test('returns true when 25 or more distinct countries are visited', () {
        // arrange
        when(() => mockVisits.countDistinctCountries())
            .thenReturn(25);
        // act
        final result = repository.qualifiesForWorldTraveller();
        // assert
        expect(result, isTrue);
      });

      test('returns false when fewer than 25 countries are visited', () {
        when(() => mockVisits.countDistinctCountries())
            .thenReturn(24);
        expect(repository.qualifiesForWorldTraveller(), isFalse);
      });
    });
  });
}
```

### 7.4 Fixture Data

Test fixtures live in `test/fixtures/` and are referenced by relative path from the test file. Fixtures must be deterministic, self-describing, and small.

```
test/
  fixtures/
    visits/
      single_country_gb.json
      multi_continent_30_countries.json
      duplicate_asset_ids.json
    challenges/
      todays_challenge.json
      completed_streak_7.json
    merch/
      cart_two_items.json
      printful_order_expected.json
```

---

## 8. Coverage Objectives

### 8.1 Philosophy

Coverage percentage is not the primary goal. Confidence and defect prevention are the primary goals.

A codebase with 90% coverage but tests that only verify `widget.render()` produces no assertion failures provides false confidence. A codebase with 60% coverage where every test validates a specific business rule at a known boundary condition is far more valuable.

High-risk functionality must always receive priority over low-value coverage inflation.

### 8.2 Initial Targets (End of Phase 4)

| Layer | Target |
|---|---|
| Business logic (pure functions and calculations) | 85%+ |
| Critical revenue workflows (merch, cart, checkout) | 80%+ |
| Service and repository layer | 70%+ |
| UI components and screens | 40%+ |
| **Overall application** | **50–65%** |

### 8.3 Long-Term Targets (End of Phase 7)

| Layer | Target |
|---|---|
| Business logic | 90%+ |
| Critical revenue workflows | 90%+ |
| Service and repository layer | 80%+ |
| UI components and screens | 55%+ |
| **Overall application** | **70%+** |

### 8.4 Excluded From Coverage

The following must be excluded from coverage measurement:

- `*.g.dart` — Drift and build_runner generated files
- `firebase_options.dart` — Platform configuration
- `*.freezed.dart` — Generated data classes (if introduced)
- `lib/main.dart` — Entry point with no testable logic
- Files containing only constants, enums, or type aliases with no branching logic

### 8.5 Coverage Enforcement

Once Phase 7 (CI quality gates) is complete, the CI pipeline will fail if overall coverage drops below the current baseline. Coverage may not decrease on any pull request. Individual exemptions require explicit documentation in the PR description.

---

## 9. Continuous Integration Strategy

### 9.1 Pipeline Overview

The CI pipeline runs automatically on every pull request targeting `main` and on every push to `main`.

```
┌──────────────────────────────────────────────────────────┐
│                    Pull Request CI                        │
├───────────────┬──────────────────┬───────────────────────┤
│  Stage 1      │  Stage 2         │  Stage 3              │
│  Validation   │  Analysis        │  Tests                │
│               │                  │                       │
│ flutter pub   │ flutter analyze  │ flutter test          │
│ get           │                  │   --coverage          │
│               │ dart format      │                       │
│               │   --output=none  │ Coverage report       │
│               │   --set-exit-if- │   upload              │
│               │   changed .      │                       │
└───────────────┴──────────────────┴───────────────────────┘
```

All stages must pass. A failure in any stage blocks the merge.

### 9.2 GitHub Actions Workflow

The workflow file lives at `.github/workflows/flutter_ci.yml`.

**Trigger events:**
- `pull_request` targeting `main`
- `push` to `main`

**Runner:** `ubuntu-latest` with Flutter stable channel

**Steps (in order):**
1. Checkout repository
2. Set up Flutter (pinned to project's stable version)
3. Cache pub packages (`~/.pub-cache`)
4. `flutter pub get`
5. `dart format --output=none --set-exit-if-changed .`
6. `flutter analyze --no-fatal-infos` (fatal on warnings and errors)
7. `flutter test --coverage`
8. Filter coverage: exclude generated files
9. Upload coverage report to CI artefacts
10. (Future) Post coverage summary as PR comment

**Failure behaviour:**
- Any step failure marks the CI run as failed
- Merge to `main` is blocked while CI is failing
- Branch protection rules enforce this; no bypasses are permitted

### 9.3 Local Pre-Push Checks

Engineers must run the following locally before pushing:

```bash
# From apps/mobile_flutter/
flutter analyze
flutter test
```

A `Makefile` target (or shell alias) should be provided to make this a single command:

```makefile
check:
	flutter analyze && flutter test --coverage
```

### 9.4 Future CI Phases

| Phase | Addition |
|---|---|
| Phase 5 | Integration tests run on simulator in CI (macOS runner) |
| Phase 6 | Firebase Emulator tests run in CI |
| Phase 7 | Coverage threshold enforcement; build fails if coverage drops |
| Phase 8 | Firebase Test Lab device matrix on release candidate tag |

---

## 10. Test Data Strategy

### 10.1 Principles

- All test data is deterministic. No test generates random data without a fixed seed.
- All test data is self-contained within the test file or a fixture file. No test reads from the device file system at runtime.
- All external services are replaced with fakes, mocks, or emulators. No test touches production systems.
- Test configurations are separate from production configurations. The app must boot in a "test mode" that injects in-memory dependencies.

### 10.2 Database Strategy

Drift (SQLite) tests use an in-memory database created fresh in `setUp()`:

```dart
setUp(() async {
  db = RoavvyDatabase(NativeDatabase.memory());
});

tearDown(() async {
  await db.close();
});
```

Each test starts with an empty database and inserts exactly the data it needs. No test depends on data left by a previous test.

### 10.3 Firebase Strategy

**Unit and service tests:** `fake_cloud_firestore` and `firebase_auth_mocks` replace all Firebase dependencies.

**Integration tests:** Firebase Emulator Suite running locally or in CI.

**Emulator configuration:**
```dart
// In test entry point (integration_test/app_test.dart)
await Firebase.initializeApp();
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
```

**Environment variable:** `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099` must be set for auth emulator to activate.

### 10.4 Platform Channel Strategy

The photo scan Swift platform channel (`roavvy/photo_scan`) cannot be invoked in unit or widget tests. It must be stubbed using `TestDefaultBinaryMessengerBinding`:

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('roavvy/photo_scan'),
  (MethodCall call) async {
    if (call.method == 'startScan') {
      return kFixtureScanResults; // controlled JSON
    }
    return null;
  },
);
```

Integration tests that need real scanning behaviour run on physical devices only (Phase 8).

### 10.5 Third-Party API Strategy

Printful, payment processors, and any other third-party HTTP APIs must be intercepted via a mockable HTTP client. The production implementation injects an `http.Client`; tests inject a `MockClient` that returns fixture responses without making network calls.

```dart
// Production
class PrintfulService {
  PrintfulService({required http.Client client}) : _client = client;
}

// Test
final mockClient = MockClient((request) async {
  return http.Response(kFixturePrintfulOrderResponse, 200);
});
final service = PrintfulService(client: mockClient);
```

### 10.6 Fixture Management

Fixture JSON files are stored in `test/fixtures/` and loaded via:

```dart
String fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();
```

All fixture files are committed to the repository. No fixture file may contain real user data, real GPS coordinates from an actual user, or any personally identifiable information.

---

## 11. Risk Map — Priority Areas

The following table maps application areas to their risk level and testing priority. High-risk areas must achieve their coverage target before lower-risk areas receive additional investment.

| Area | Risk Level | Reason | Priority |
|---|---|---|---|
| Merch cart → checkout | Critical | Direct revenue impact | 1 |
| Printful placement mapper | Critical | Incorrect mapping produces wrong products | 1 |
| Scan deduplication | Critical | Duplicate visits corrupt the travel record | 1 |
| Achievement qualification | High | Incorrect awards undermine user trust | 2 |
| XP / level-up thresholds | High | Regression breaks the gamification loop | 2 |
| Firestore security rules | High | Data exposure risk | 2 |
| Daily challenge scoring | High | Incorrect streaks frustrate users | 2 |
| Country detection logic | High | Core product promise | 2 |
| Firestore sync field guard | High | Privacy constraint; must never leak photo data | 2 |
| Card and passport layout engines | Medium | Visual corruption is user-facing | 3 |
| Mockup approval service | Medium | Revenue workflow dependency | 3 |
| Share token service | Medium | Broken sharing degrades virality | 3 |
| Memory pulse service | Low | Nice-to-have engagement feature | 4 |
| Globe painter rendering | Low | Visual; caught by device testing | 4 |
| Onboarding flow | Medium | Affects new user conversion | 3 |

---

## 12. Incremental Rollout Plan

Testing capability is built incrementally across eight phases. Each phase has a defined objective, a deliverable, and a completion criterion. No phase is skipped.

---

### Phase 1 — Framework Establishment

**Objective:** Create a clean, runnable testing foundation with coverage reporting.

**Work:**
- Add `mocktail` to `dev_dependencies`
- Add `integration_test` to `dev_dependencies`
- Run the existing test suite: `flutter test`
- Classify any failures as genuine defects, incorrect expectations, or configuration issues
- Resolve all failures before proceeding
- Add coverage script: `flutter test --coverage` with `lcov` filtering
- Measure and record current coverage baseline
- Create `test/fixtures/` directory with initial fixture files for visits, countries, and challenges
- Create `Makefile` with `check`, `test`, and `coverage` targets
- Document the baseline in `docs/testing/coverage_baseline.md`

**Completion criterion:** `flutter test` passes with zero failures. Coverage baseline is recorded.

---

### Phase 2 — Business Logic Tests

**Objective:** Achieve 85%+ coverage of all pure business logic.

**Focus areas (in priority order):**
1. `features/merch/printful_placement_mapper.dart`
2. `features/merch/merch_template_ranker.dart`
3. `features/merch/merch_variant_lookup.dart`
4. `features/merch/travel_identity.dart`
5. `features/challenge/guess_normalizer.dart` (extend existing)
6. `features/challenge/hot_cold_feedback.dart` (extend existing)
7. `features/challenge/daily_challenge_stats.dart`
8. `data/xp_repository.dart` — level threshold boundaries
9. `data/achievement_repository.dart` — each qualification condition
10. `features/cards/grid_math_engine.dart` (extend existing)
11. `features/cards/title_generation/rule_based_title_generator.dart` (extend)
12. `features/map/globe_projection.dart` (extend existing)
13. `features/map/country_visual_state.dart`

**Completion criterion:** Business logic coverage ≥ 85%. All new and existing tests pass.

---

### Phase 3 — Service Tests

**Objective:** Achieve 70%+ coverage of the service and repository layer using mocked dependencies.

**Focus areas (in priority order):**
1. `features/merch/merch_cart_repository.dart` — add/remove/update/total/clear
2. `features/merch/mockup_approval_service.dart` (extend existing)
3. `data/firestore_sync_service.dart` — field guard validation (extend existing)
4. `data/visit_repository.dart` — deduplication by `assetId` (extend existing)
5. `data/achievement_repository.dart` — Firestore write integration (extend)
6. `data/daily_challenge_repository.dart` — streak persistence (extend existing)
7. `features/sharing/share_token_service.dart` (extend existing)
8. `features/challenge/daily_challenge_service.dart` — date-based selection
9. `features/account/account_deletion_service.dart` (extend existing)
10. `data/bootstrap_service.dart` — idempotency (extend existing)
11. `data/region_repository.dart` — continent rollup (extend existing)
12. `data/heritage_repository.dart` — UNESCO proximity lookup

**Completion criterion:** Service layer coverage ≥ 70%. All new and existing tests pass.

---

### Phase 4 — Widget Tests

**Objective:** Achieve 40%+ coverage of UI components, prioritising critical user workflows.

**Focus areas (in priority order):**
1. `features/merch/merch_cart_screen.dart` — full cart management interactions
2. `features/merch/merch_customisation_sheet.dart` — configuration UI
3. `features/merch/merch_country_selection_screen.dart` — selection toggles
4. `features/merch/merch_variant_screen.dart` — size/colour/add-to-cart
5. `features/scan/scan_screen.dart` — scan trigger, progress, completion
6. `features/scan/scan_summary_screen.dart` — results display
7. `features/challenge/daily_challenge_screen.dart` — clue/guess/result flow
8. `features/stats/achievements_screen.dart` — locked/unlocked states
9. `features/onboarding/onboarding_flow.dart` (extend existing)
10. `features/auth/sign_in_screen.dart` (extend existing)
11. `features/shell/main_shell.dart` — tab switching
12. `features/map/map_screen.dart` — country tap, detail sheet

**Completion criterion:** UI coverage ≥ 40%. All new and existing tests pass. Overall coverage ≥ 50%.

---

### Phase 5 — Integration Tests

**Objective:** Validate critical end-to-end user journeys running against mocked backends.

**Setup:**
- Create `integration_test/` directory
- Create `integration_test/app_test.dart` as test entry point with injected test configuration
- Stub photo scan channel to return fixture data

**Journeys to implement (in priority order):**
1. New user onboarding → first scan → map shows countries
2. Daily challenge → guess → result
3. Scan → achievement unlock sheet → stats screen
4. Merch country selection → customisation → variant → cart → checkout handoff
5. Manual visit edit → saved and reflected on map
6. Travel card share → share sheet triggered
7. Challenge streak continuation on second consecutive day
8. Account deletion → signed out → app returns to onboarding

**Completion criterion:** All eight journeys pass on iOS simulator. CI macOS runner executes integration tests on PR.

---

### Phase 6 — Backend Emulator Tests

**Objective:** Validate Firestore security rules, Cloud Functions, and authentication flows against the Firebase Emulator Suite.

**Setup:**
- Install and configure Firebase Emulator Suite (Firestore + Auth + Functions)
- Add emulator configuration to `firebase.json`
- Create `test/emulator/` directory with emulator test files
- Configure CI to start emulators before running emulator tests

**Tests to implement:**
1. Security rules: authenticated user writes permitted fields only
2. Security rules: unauthenticated user cannot write any Firestore document
3. Security rules: authenticated user cannot write another user's data
4. Security rules: GPS coordinates and photo data are rejected
5. Share token read without authentication succeeds
6. Share token write by non-owner rejected
7. Authentication: anonymous sign-in succeeds
8. Authentication: Apple Sign-In upgrade preserves existing documents
9. Account deletion: all user documents removed from Firestore
10. Cloud Function: order placement produces correct Printful payload structure

**Completion criterion:** All emulator tests pass. CI runs emulator tests on pull request.

---

### Phase 7 — CI Quality Gates

**Objective:** Enforce quality gates on every pull request via GitHub Actions.

**Deliverables:**
- `.github/workflows/flutter_ci.yml` — complete CI workflow
- Branch protection rules on `main` requiring CI to pass before merge
- Coverage threshold: build fails if overall coverage drops below current baseline
- Coverage report uploaded as CI artefact on every run
- (Optional) Coverage summary posted as PR comment

**Quality gates (all must pass for a PR to merge):**
1. `flutter pub get` — dependencies resolve
2. `dart format --set-exit-if-changed .` — code is formatted
3. `flutter analyze` — no warnings or errors
4. `flutter test --coverage` — all tests pass
5. Coverage does not decrease from baseline

**Completion criterion:** All PRs are automatically blocked on CI failure. `main` is always in a passing state.

---

### Phase 8 — Device-Level Testing

**Objective:** Validate real-device behaviour for permission flows, scanning, and rendering performance before release.

**Setup:**
- Create `integration_test/device/` with device-specific test suite
- Configure Firebase Test Lab project and service account in CI
- Prepare test photo library fixture with GPS-tagged images

**Tests to implement:**
1. Photo library permission prompt and denial handling
2. Full scan pipeline with fixture photos → correct country codes
3. Re-scan deduplication: scanning same photos twice produces no duplicates
4. Large scan performance: 2,000 photos complete within 60 seconds
5. Globe rendering: 60fps maintained on a supported device under load

**Trigger:** Runs automatically when a release candidate tag (`v*.*.*-rc.*`) is pushed. Not required on every PR.

**Completion criterion:** All device tests pass on at least one supported iPhone model before each App Store submission.

---

## 13. Defect Resolution and Incremental Fixing Approach

Automated testing will be used to detect defects as early as possible and prevent unstable code from progressing through the release process. Defects should be resolved as they are discovered, not batched up for correction at the end of a large testing milestone.

Each testing milestone must follow an incremental test-and-fix cycle:

1. Select a small, clearly defined area of functionality.
2. Add or update a focused set of tests for that area.
3. Run the relevant tests immediately.
4. Investigate any failures before moving to the next area.
5. Classify each failure as one of the following:
   - genuine application defect
   - incorrect or incomplete test expectation
   - missing test fixture or mock
   - environment or configuration issue
   - flaky or timing-related test
6. Apply the smallest safe fix required.
7. Rerun the failing test.
8. Rerun related tests to ensure no regression has been introduced.
9. Commit the change only when the current test area is passing.

The objective is to maintain a continuously improving and continuously stable codebase. Large batches of failing tests should be avoided because they make diagnosis harder, increase rework, and reduce confidence in the test suite.

Claude Code may be used to diagnose failures, propose fixes, apply small code changes, and rerun tests. However, tests must not be weakened or removed simply to make the suite pass. Any production code changes made to satisfy tests must be minimal, justified, and aligned with the intended product behaviour.

No milestone should be considered complete unless:

- all tests added in that milestone pass;
- existing related tests still pass;
- any defects found have been resolved or explicitly documented;
- no production Firebase, real payment flow, or live third-party fulfilment service has been used during testing.

This approach ensures that automated testing becomes part of the development workflow rather than a clean-up activity performed after implementation is complete.

---

*This document is the authoritative testing strategy for Roavvy. All future testing decisions, tooling choices, and coverage investments must align with the principles and architecture defined here. Updates to this document require a pull request and must be reviewed before merging.*
