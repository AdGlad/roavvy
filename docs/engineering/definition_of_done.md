# Definition of Done

A task is done when every item on this list is true. "Mostly done" is not done.

---

## Code

- [ ] Acceptance criteria from the task are met.
- [ ] No new lint warnings (`dart analyze`, `eslint`).
- [ ] Code formatted (`dart format`, `prettier`).
- [ ] No commented-out code, no TODO comments.
- [ ] No hardcoded strings where a constant or type should be used.

## Tests

- [ ] Tests written for all new behaviour.
- [ ] All existing tests pass.
- [ ] Privacy-critical test cases pass (see [Testing Strategy](testing_strategy.md)).

## Privacy & Security

- [ ] GPS coordinates are not persisted to local DB or Firestore.
- [ ] Asset identifiers are not persisted to local DB or Firestore.
- [ ] Shopify credentials are not exposed in client bundles.
- [ ] Firestore security rules updated if data model changed.
- [ ] No new third-party SDKs added to `country_lookup` or `shared_models`.

## Architecture

- [ ] Package boundaries respected — no new dependencies that cross the boundary rules.
- [ ] If `shared_models` changed: both Dart and TypeScript versions updated.
- [ ] User edit override logic handled correctly if the change touches scan or sync.

## Docs

- [ ] Relevant architecture docs updated if behaviour changed (data model, scan flow, sync model, etc.).
- [ ] CLAUDE.md for the affected directory updated if conventions changed.

## Review

- [ ] PR reviewed and approved.
- [ ] Review comments resolved or explicitly deferred with a filed task.

---

## Applies To

These criteria apply to all task types. The [feature template](../tasks/feature_template.md), [bugfix template](../tasks/bugfix_template.md), and [refactor template](../tasks/refactor_template.md) each include this checklist by reference.
