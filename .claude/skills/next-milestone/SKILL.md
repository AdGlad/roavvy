---
name: next-milestone
description: Runs the full Planner → Architect → Builder → Reviewer workflow for the next unstarted milestone, autonomously without confirmation prompts.
---

# Skill: next-milestone

Runs the full four-stage development workflow (Planner → Architect → Builder → Reviewer) for the next milestone without pausing for confirmation. Execute every step below in order, autonomously.

---

## Step 0 — Compact and branch

1. Run `/compact` to clear context before starting.
2. Read `docs/dev/backlog.md` to identify the next milestone (the first milestone listed that has no ✅ status).
3. Derive a branch name from the milestone number and short title, e.g. `milestone/m22-gamified-map`.
4. Run `git checkout -b <branch-name>` to create and switch to the branch. Do not ask for confirmation.

---

## Step 1 — Planner

Act as the Planner persona defined in `docs/personas/planner.md`.

Before scoping, read:
- `docs/dev/current_state.md`
- `docs/dev/backlog.md`
- `docs/product/roadmap.md`
- `docs/product/vision.md`

Produce the full task list for the milestone. Apply the Planner's output format exactly (Goal, Scope, Tasks with Deliverable + Acceptance Criteria, Dependencies, Risks).

After finalising:
- Write the complete task list to `docs/dev/next_tasks.md` (overwrite).
- Write the first task to `docs/dev/current_task.md` with status "In Progress".
- Update `docs/product/roadmap.md` milestone status to "In Progress" if needed.

Then run `/compact`.

---

## Step 2 — Architect

Act as the Engineering Architect persona defined in `docs/personas/architect.md`.

Before proposing anything, read:
- `docs/architecture/decisions.md`
- `docs/dev/current_state.md`
- `docs/dev/next_tasks.md`

Review the Planner's task list for structural risks. For every significant technical decision, append an ADR to `docs/architecture/decisions.md` using the standard ADR format (ADR-NNN, Status: Accepted, Context, Decision, Consequences).

If any task has a blocker-level structural risk, rewrite that task in `docs/dev/next_tasks.md` to resolve it before building begins.

Then run `/compact`.

---

## Step 3 — Builder

Act as the Builder persona defined in `docs/personas/builder.md`.

Read `docs/dev/next_tasks.md` and implement every task in the listed order. For each task:

1. Read the CLAUDE.md for each directory you will touch.
2. Read `docs/architecture/decisions.md` for constraints on the area.
3. Implement the minimum code that satisfies the acceptance criteria.
4. Write tests alongside implementation. **Do NOT run tests** — test execution is temporarily suspended to avoid token exhaustion.
5. Update `docs/dev/current_task.md` — mark the task ✅ Done and set the next task to "In Progress".

Do not ask for permission before creating files, running commands, or editing code. Proceed autonomously through all tasks.

When all tasks are complete, update `docs/dev/current_task.md` status to "✅ Complete" with today's date.

Then run `/compact`.

---

## Step 4 — Reviewer

Act as the Reviewer persona defined in `docs/personas/reviewer.md`.

Review all changes made during Step 3 using `git diff main`. Apply the full review checklist from `docs/personas/reviewer.md` (Privacy, Package boundaries, Correctness, Security).

Output each finding as `[BLOCKER]` or `[SUGGESTION]` with a reason.

If there are any BLOCKERs:
- Fix them immediately (act as Builder to apply the fix).
- Re-run the relevant review checklist items.

Finish with a final verdict: **Approved**, **Approved with suggestions**, or **Changes required**.

Then update `docs/dev/current_state.md` to reflect what was built in this milestone.

---

## Completion

When the review passes, output a concise summary:
- Milestone completed
- Branch name
- List of tasks implemented
- Any open suggestions (non-blocking)
- Reminder of any production prerequisites noted during the build
