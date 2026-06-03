# CI Setup

GitHub Actions pipeline defined in `.github/workflows/flutter_ci.yml`.

Triggers on push/PR to `main`.

## Jobs

### `flutter_test`

| Step | Detail |
|---|---|
| Flutter | 3.32.x stable via `subosito/flutter-action` |
| Format | `dart format --output=none --set-exit-if-changed lib/ test/` — fails if files are not formatted |
| Analyse | `flutter analyze --no-fatal-infos --no-fatal-warnings` — fails only on errors |
| Tests | `flutter test --coverage` |
| Coverage | lcov filters generated files (`.g.dart`, `.freezed.dart`); threshold: **40 %** line coverage |

> Pre-existing warnings exist in the codebase (41 issues as of T7). `--no-fatal-warnings` lets CI
> pass while the backlog is cleaned up. Ratchet to `--fatal-warnings` when warnings reach zero.

### `functions_test`

Node 22, `npm ci && npm test` in `apps/functions/`. Runs Jest unit tests for Cloud Functions TypeScript.

### `firestore_rules`

Node 22, Firebase CLI. Starts a Firestore emulator via `firebase emulators:exec --only firestore`
and runs the Jest rules test suite in `test/firestore-rules/`.

Uses demo project `demo-roavvy` (no real Firebase access required in CI).

### `integration` (disabled)

Commented out pending T5 (integration test scaffold). Will run on `macos-latest` using
`flutter test integration_test/` once the test directory exists.

## Secrets / env vars

No secrets are required for the current jobs. The emulator uses `--project demo-roavvy` which
requires no authentication.

## Baseline coverage

Coverage threshold starts at 40 %. Raise incrementally as new tests are added.

## Format baseline

`dart format` was run across all 313 Dart files in T7 to establish the format baseline before
enabling `--set-exit-if-changed` enforcement.
