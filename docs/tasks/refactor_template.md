# Refactor Task Template

Copy this file and rename it `NNN-short-description.md` (e.g. `015-extract-sync-service.md`).

Refactors must not change observable behaviour. If behaviour changes are required, they belong in a feature or bugfix task.

---

## [Refactor Title]

**Status:** `backlog` | `in progress` | `in review` | `done`
**Persona(s):** Builder / Architect
**Created:** YYYY-MM-DD

---

## Motivation

Why is this refactor needed now? What problem does the current code cause?

Good motivations: test coverage is impossible, the code violates package boundaries, performance is measurably bad, duplication is causing bugs.

Not a good motivation: "I don't like how it looks."

---

## Current State

Describe the specific code or structure being changed. Link to files or line numbers.

---

## Target State

Describe what the code will look like after the refactor. If helpful, include a before/after sketch.

---

## Behaviour Contract

Explicitly state what must not change:

- [ ] [Specific behaviour that must be preserved]
- [ ] All existing tests pass without modification (or describe what minimal test changes are acceptable)
- [ ] No change to public API surface (or explicitly state what API changes are allowed and why)

---

## Privacy / Architecture Check

- [ ] Refactor does not introduce any new data flow that could carry GPS coordinates or photo data.
- [ ] Package boundaries are maintained or improved (not loosened).
- [ ] If `shared_models` is touched: both Dart and TypeScript updated.

---

## Risks

What could go wrong? What behaviour is hardest to verify is unchanged?

---

## Definition of Done

See [definition_of_done.md](../engineering/definition_of_done.md). All items must be checked before this task is marked `done`.

Additionally:
- [ ] Observable behaviour is unchanged (verified by passing existing tests and manual smoke test).
- [ ] No new tech debt introduced in the process of removing old tech debt.
