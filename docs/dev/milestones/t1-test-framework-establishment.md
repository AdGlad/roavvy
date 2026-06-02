# T1 — Test Framework Establishment

**Testing milestone. Prefix T = testing; does not conflict with feature milestone numbering.**

## Goal

Create a clean, runnable testing foundation. Ensure every existing test passes. Add missing dependencies. Record the coverage baseline. Do not write new tests in this milestone.

---

## Why First

Approximately 90 test files exist but no CI is configured, `mocktail` is missing from `dev_dependencies`, and coverage has never been measured. Before adding a single new test, the team needs to know what state the existing suite is in. An unknown baseline is not a baseline.

This milestone has zero user-visible changes. Its output is a stable, reproducible test environment.

---

## Tasks

### T1.1 — Add missing dev_dependencies

**Edit:** `apps/mobile_flutter/pubspec.yaml`

Add to `dev_dependencies`:

```yaml
dev_dependencies:
  mocktail: ^0.3.0
  integration_test:
    sdk: flutter
```

Run:

```bash
cd apps/mobile_flutter
flutter pub get
```

Verify: `flutter pub get` exits with code 0 and no version conflicts.

---

### T1.2 — Run the full existing test suite

```bash
cd apps/mobile_flutter
flutter test 2>/tmp/t1_test_run.txt
tail -50 /tmp/t1_test_run.txt
```

Capture the output. Classify every failure as one of:
- **A** — genuine application defect (production code is wrong)
- **B** — incorrect test expectation (test asserts wrong value)
- **C** — missing fixture or mock (test setup incomplete)
- **D** — environment or configuration issue (import path, dep version)
- **E** — flaky or timing-related test

For each failure, apply the smallest safe fix required by its class. Rerun the failing test, then rerun the full suite. Commit only when `flutter test` exits with zero failures.

---

### T1.3 — Add coverage script

**Edit:** `apps/mobile_flutter/Makefile` (create if it does not exist)

```makefile
.PHONY: check test coverage

check: ## Run analysis and all tests
	flutter analyze 2>/tmp/analyze.txt && tail /tmp/analyze.txt
	flutter test

test: ## Run tests only
	flutter test

coverage: ## Generate HTML coverage report
	flutter test --coverage
	lcov --remove coverage/lcov.info \
	  '*/lib/**.g.dart' \
	  '*/lib/firebase_options.dart' \
	  '*/lib/**/*.freezed.dart' \
	  --output-file coverage/lcov_clean.info
	genhtml coverage/lcov_clean.info --output-directory coverage/html
	@echo "Coverage report: coverage/html/index.html"
```

Run `make coverage`. Confirm `coverage/html/index.html` is generated.

Add to `apps/mobile_flutter/.gitignore`:

```
coverage/
```

---

### T1.4 — Record the coverage baseline

**New file:** `docs/testing/coverage_baseline.md`

```markdown
# Coverage Baseline — T1

**Date recorded:** <today's date>
**Flutter version:** <output of flutter --version>
**Test count:** <number of tests that passed>

## Overall coverage: <X>%

| Layer | Coverage |
|---|---|
| Business logic | X% |
| Service / repository | X% |
| Widget / UI | X% |

## Notes

<Any areas of anomalously high or low coverage worth noting.>
<Any tests that were fixed to reach a clean run — describe the fix.>
```

Populate from the `make coverage` output before committing.

---

### T1.5 — Create the fixture directory structure

**New directories and placeholder files:**

```
apps/mobile_flutter/test/fixtures/
  visits/
    single_country_gb.json          ← { "countryCode": "GB", ... }
    multi_continent_30_countries.json
    duplicate_asset_ids.json
  challenges/
    todays_challenge.json
    completed_streak_7.json
  merch/
    cart_two_items.json
    printful_order_expected.json
```

Each JSON file should be a minimal valid example of the data it represents. Use fabricated values — no real user data, no real GPS coordinates.

---

### T1.6 — flutter analyze clean pass

```bash
flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt
```

The output must end with `No issues found!` or a count of zero errors. Warnings that existed before this milestone are documented in `coverage_baseline.md` but are not required to be fixed here.

---

## File Map

```
apps/mobile_flutter/
  pubspec.yaml                            EDIT — add mocktail, integration_test
  Makefile                                NEW — check, test, coverage targets
  .gitignore                              EDIT — add coverage/

docs/testing/
  coverage_baseline.md                    NEW — baseline metrics

test/fixtures/
  visits/
    single_country_gb.json               NEW
    multi_continent_30_countries.json    NEW
    duplicate_asset_ids.json             NEW
  challenges/
    todays_challenge.json                NEW
    completed_streak_7.json              NEW
  merch/
    cart_two_items.json                  NEW
    printful_order_expected.json         NEW
```

---

## Definition of Done

- [ ] `flutter pub get` exits cleanly with `mocktail` and `integration_test` resolved.
- [ ] `flutter test` exits with zero failures.
- [ ] `make coverage` generates `coverage/html/index.html` successfully.
- [ ] `docs/testing/coverage_baseline.md` populated with real numbers.
- [ ] All 7 fixture files created with valid JSON content.
- [ ] `flutter analyze` reports no new errors introduced in this milestone.
- [ ] No production Firebase, real payment flow, or live Printful endpoint was used.
