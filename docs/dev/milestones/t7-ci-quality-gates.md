# T7 — CI Quality Gates

**Depends on:** T1–T6 complete (all tests passing, emulator tests running)

## Goal

Enforce automated quality gates on every pull request via GitHub Actions. No code merges to `main` without passing CI. Coverage may not decrease from the established baseline.

---

## Why CI Is Phase 7, Not Phase 1

CI that gates on a failing test suite provides no value — engineers learn to ignore or bypass it. By establishing a clean, passing baseline first (T1–T4), then adding integration and emulator tests (T5–T6), the suite is reliable before enforcement begins. A CI system that only ever fails when something is genuinely broken is a CI system that engineers trust.

---

## Tasks

### T7.1 — Create the GitHub Actions workflow

**New file:** `.github/workflows/flutter_ci.yml`

```yaml
name: Flutter CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    name: Analyse and Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        working-directory: apps/mobile_flutter
        run: flutter pub get

      - name: Check formatting
        working-directory: apps/mobile_flutter
        run: dart format --output=none --set-exit-if-changed .

      - name: Run static analysis
        working-directory: apps/mobile_flutter
        run: flutter analyze --no-fatal-infos 2>/tmp/analyze.txt; tail /tmp/analyze.txt

      - name: Run tests with coverage
        working-directory: apps/mobile_flutter
        run: flutter test --coverage

      - name: Filter coverage (exclude generated files)
        working-directory: apps/mobile_flutter
        run: |
          sudo apt-get install -y lcov
          lcov --remove coverage/lcov.info \
            '*/lib/**.g.dart' \
            '*/lib/firebase_options.dart' \
            '*/lib/**/*.freezed.dart' \
            --output-file coverage/lcov_clean.info

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: apps/mobile_flutter/coverage/lcov_clean.info

  integration:
    name: Integration Tests
    runs-on: macos-latest
    needs: test

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Boot iOS simulator
        run: |
          xcrun simctl boot "iPhone 15" || true
          xcrun simctl list devices | grep Booted

      - name: Install dependencies
        working-directory: apps/mobile_flutter
        run: flutter pub get

      - name: Run integration tests
        working-directory: apps/mobile_flutter
        run: flutter test integration_test/app_test.dart

  emulator:
    name: Emulator Tests
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install Node and Firebase CLI
        run: npm install -g firebase-tools

      - name: Install dependencies
        working-directory: apps/mobile_flutter
        run: flutter pub get

      - name: Start Firebase emulators
        run: firebase emulators:start --only auth,firestore,functions &

      - name: Wait for emulators
        run: sleep 15

      - name: Run emulator tests
        working-directory: apps/mobile_flutter
        run: flutter test test/emulator/
        env:
          FIREBASE_AUTH_EMULATOR_HOST: localhost:9099
          FIRESTORE_EMULATOR_HOST: localhost:8080
```

---

### T7.2 — Enable branch protection on `main`

In GitHub repository settings → Branches → Branch protection rules for `main`:

- [x] Require status checks to pass before merging
  - Required checks: `Analyse and Test`, `Integration Tests`, `Emulator Tests`
- [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings

Document in `docs/engineering/ci_setup.md` how to configure branch protection (for onboarding future contributors).

---

### T7.3 — Coverage threshold enforcement

**Edit:** `.github/workflows/flutter_ci.yml` — add a coverage threshold step after filtering:

```yaml
- name: Check coverage threshold
  working-directory: apps/mobile_flutter
  run: |
    COVERAGE=$(lcov --summary coverage/lcov_clean.info 2>&1 | grep 'lines' | grep -o '[0-9.]*%' | head -1 | tr -d '%')
    THRESHOLD=50
    echo "Coverage: ${COVERAGE}%"
    if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
      echo "Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
      exit 1
    fi
```

The threshold is set to the baseline recorded in `docs/testing/coverage_baseline.md` at the end of T4. It must not decrease.

---

### T7.4 — Optional: PR coverage comment

**New file:** `.github/workflows/coverage_comment.yml`

```yaml
name: Coverage Comment

on:
  pull_request:

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
        working-directory: apps/mobile_flutter
      - run: flutter test --coverage
        working-directory: apps/mobile_flutter
      - run: |
          sudo apt-get install -y lcov
          lcov --remove coverage/lcov.info \
            '*/lib/**.g.dart' \
            '*/lib/firebase_options.dart' \
            --output-file coverage/lcov_clean.info
          COVERAGE=$(lcov --summary coverage/lcov_clean.info 2>&1 | grep 'lines' | grep -o '[0-9.]*%' | head -1)
          echo "COVERAGE=${COVERAGE}" >> $GITHUB_ENV
        working-directory: apps/mobile_flutter
      - uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `Coverage: **${process.env.COVERAGE}**`
            })
```

---

### T7.5 — Create `docs/engineering/ci_setup.md`

Document:
- How to run CI locally: `make check`
- How to configure branch protection in GitHub
- What each CI job does and why
- How to update the coverage threshold
- How to add a new CI step

---

### T7.6 — Verify CI passes end-to-end on `main`

Before enforcing branch protection:
1. Push `.github/workflows/flutter_ci.yml` to `main`.
2. Confirm all three jobs pass on the push to `main`.
3. Create a test branch, make a trivial change, open a PR.
4. Confirm the CI checks appear and pass.
5. Enable branch protection.

---

## File Map

```
.github/
  workflows/
    flutter_ci.yml                    NEW — main CI workflow
    coverage_comment.yml              NEW — optional PR comment

docs/engineering/
  ci_setup.md                         NEW — CI documentation
```

---

## Definition of Done

- [ ] `.github/workflows/flutter_ci.yml` passes on a push to `main`.
- [ ] All three jobs (test, integration, emulator) pass.
- [ ] Branch protection is enabled on `main`; no merge is possible without passing CI.
- [ ] Coverage threshold check fails the build if coverage drops below baseline.
- [ ] Coverage report is uploaded as a CI artefact on every run.
- [ ] `docs/engineering/ci_setup.md` documents how to configure and maintain the pipeline.
- [ ] All existing tests continue to pass under the CI environment (ubuntu-latest / macos-latest).
