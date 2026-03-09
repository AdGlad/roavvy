# Testing Strategy

## Philosophy

Test behaviour, not implementation. A test that breaks when you rename a private method is not useful. A test that breaks when a user's manual edit gets overwritten by a re-scan is.

Tests are written alongside implementation, not after. A PR without tests for new behaviour is incomplete.

---

## Test Layers

### Unit Tests

**What:** Pure functions, models, repositories (with mocked DB/network), `country_lookup` resolution logic.

**Where:**
- Dart: `test/` alongside each package or feature directory.
- TypeScript: `*.test.ts` co-located with the module under test.

**Mandatory for:**
- All public functions in `packages/country_lookup` and `packages/shared_models`.
- All repository methods in `apps/mobile_flutter`.
- Conflict resolution and merge logic in the sync service.
- All Route Handlers in `apps/web_nextjs`.

**Coverage target:** 100% for packages. No enforced numeric target for apps, but all meaningful branches must be covered.

### Widget / Component Tests

**What:** UI components in non-trivial states (loading, error, empty, populated). Not layout pixel-perfection.

**Where:**
- Dart: Flutter widget tests using `flutter_test`.
- TypeScript: React Testing Library.

**Mandatory for:**
- Scan progress and result states.
- Permission request flow.
- Country visit edit and delete interactions.
- Sharing card generation and revoke.

**Not required for:** trivial display-only components with no conditional logic.

### Integration Tests

**What:** Feature flows stitched end-to-end with real (or near-real) dependencies, faking only the platform boundary.

**Where:**
- Flutter: `integration_test/` using `flutter_test` integration framework. Platform channel mocked via `TestDefaultBinaryMessengerBinding`.
- Next.js: Playwright for critical user journeys.

**Mandatory for:**
- Full scan flow (mock platform channel → local DB write → UI update).
- Firestore sync (mock Firestore client, assert dirty records flushed).
- Sharing page SSR (Playwright: navigate to `/share/[token]`, assert rendered without JS).
- Checkout flow (Playwright: add to cart → proceed to Shopify checkout).

### What We Do Not Write

- **Golden / snapshot tests** — unless explicitly requested for a specific visual regression.
- **Tests for framework behaviour** — don't test that Riverpod notifies listeners; test that your code calls the right methods.
- **Trivial boilerplate tests** — no tests that just assert a model serialises the field you just added.

---

## Test Data

- Use factory helpers or fixtures, not magic strings scattered across test files.
- `CountryVisit` and other models: provide a `CountryVisit.fixture({...overrides})` helper in each test suite.
- Never use production UIDs, real coordinates, or real asset identifiers in tests.

---

## CI Requirements

- All unit and widget tests run on every PR.
- Integration tests run on merge to `main`.
- Zero failing tests to merge. Flaky tests are treated as bugs and fixed before the next release.

---

## Privacy-Specific Test Cases

These cases must exist somewhere in the test suite and must not regress:

| Scenario | Asserted behaviour |
|---|---|
| Scan completes | No GPS coordinates in local DB |
| Scan completes | No asset identifiers in local DB |
| Sync runs | Firestore write payload contains only country codes and dates |
| User edits a visit (source → manual) | Re-scan does not overwrite it |
| Account deleted | All Firestore documents under `users/{uid}` removed |
