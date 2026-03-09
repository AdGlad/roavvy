# Bug Fix Task Template

Copy this file and rename it `NNN-short-description.md` (e.g. `012-manual-edit-overwritten-on-rescan.md`).

---

## [Bug Title]

**Status:** `backlog` | `in progress` | `in review` | `done`
**Severity:** `critical` | `high` | `medium` | `low`
**Persona(s):** Builder / Reviewer
**Created:** YYYY-MM-DD
**Reported by:** (user report / internal / test failure)

---

## Description

What is the observed incorrect behaviour? Be specific: what did the user do, what happened, what was expected?

---

## Steps to Reproduce

1. Step one
2. Step two
3. Observed: [what happens]
4. Expected: [what should happen]

---

## Root Cause (once investigated)

Fill in after investigation. Leave blank until the cause is confirmed — don't speculate here.

---

## Fix

Describe the fix once decided. Prefer a small, targeted change. If the fix requires a larger refactor, file a separate refactor task and reference it.

---

## Regression Test

What test must be added (or updated) to ensure this bug cannot regress?

- [ ] Test case: [description of the specific scenario covered]

---

## Privacy / Safety Check

- [ ] Does this bug or fix touch GPS coordinate handling? If so, confirm coordinates are not persisted after fix.
- [ ] Does this bug involve the user edit override logic? If so, confirm manual edits still win after fix.
- [ ] Does this fix change any Firestore write? If so, confirm the payload is still derived metadata only.

---

## Definition of Done

See [definition_of_done.md](../engineering/definition_of_done.md). All items must be checked before this task is marked `done`.
