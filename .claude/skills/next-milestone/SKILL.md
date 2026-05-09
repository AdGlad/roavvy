---
name: next-milestone
description: Runs the full Planner → Architect → Builder → Reviewer workflow for the next unstarted milestone autonomously with crash recovery, compact context loading, and selective retrieval.
---

# Skill: next-milestone

Runs the full four-stage development workflow (Planner → Architect → Builder → Reviewer) for the next milestone without pausing for confirmation.

The workflow is optimised for:
- reduced token usage
- crash recovery
- compact context loading
- selective Firebase + markdown retrieval
- autonomous milestone execution

---

# Global Rules

## Firebase Retrieval (mandatory)

Before running any retrieval, verify GCP auth:

```bash
gcloud auth application-default print-access-token >/dev/null
```

If this command fails, **STOP immediately** and report:
> `GCP auth failed. Run: gcloud auth application-default login`

Then run retrieval:

```bash
python3 scripts/retrieve_context.py "<current milestone summary>"
```

If retrieval returns **no output**, **STOP immediately** and report:
> `Firebase retrieval returned no chunks. Fix GCP auth or retrieval data before running next-milestone.`

Do NOT fall back to local markdown files.
Do NOT continue with the workflow if retrieval returns empty output.

Use the retrieved Firebase chunks as the **primary** project memory/context source for:
- architecture decisions (ADRs)
- roadmap context
- feature history
- known issues
- implementation notes

Only directly read local files for small files directly related to implementation:
- `CLAUDE.md`
- `docs/dev/current_task.md`
- the current milestone file
- small source files being modified

Do NOT bulk-read large markdown docs (`current_state.md`, `backlog_active.md`, `decisions/_index.md`) — retrieve from Firebase instead.

---

## Crash Recovery

Before starting any work:

1. Inspect git status.
2. Inspect current branch.
3. Inspect uncommitted changes.
4. Inspect git diff against main.
5. Recover safely from interrupted or crashed executions.
6. Never duplicate already completed work.
7. Continue from current repository state.

---

## Context Loading Rules

1. Never bulk-read large markdown documents.
2. Prefer Firebase chunk retrieval over local markdown reads.
3. Read only the minimum context required for the current task.
4. Large markdown files should be treated as indexed reference material, not always-on context.
5. If a markdown file exceeds ~150 lines, retrieve only relevant sections.
6. CLAUDE.md files must remain concise and focused on constraints/rules.

---

## Working Style

1. Work autonomously.
2. Do not ask for confirmation.
3. Implement in small coherent slices.
4. Keep changes minimal and targeted.
5. Avoid unnecessary refactors.
6. Preserve existing architecture patterns unless required.

---

## Validation Rules

1. Run lightweight validation where useful.
2. Prefer `flutter analyze 2>/tmp/analyze.txt; tail /tmp/analyze.txt` over full test runs.
3. Avoid large token-expensive outputs.
4. Summarise validation failures concisely.

---

## Step 0 — Compact and Branch

1. Run `/compact`.
2. Inspect git status and recover safely from interrupted work.
3. Verify GCP auth and run Firebase retrieval for the next milestone:
   ```bash
   gcloud auth application-default print-access-token >/dev/null
   python3 scripts/retrieve_context.py "next milestone backlog"
   ```
   If auth fails or retrieval returns no output, **STOP** — report the error and do not continue.
4. From the retrieved context, identify the first incomplete milestone.
5. Derive branch name: `milestone/mXX-short-name`
6. Create or switch to the branch automatically.
7. Read ONLY:
   - root `CLAUDE.md`
   - `docs/dev/current_task.md`
   - current milestone file

Do NOT bulk-read documentation.

---

# Step 1 — Planner

Act as the Planner persona defined in `docs/personas/planner.md`.

Before planning, verify GCP auth and run Firebase retrieval:

```bash
gcloud auth application-default print-access-token >/dev/null
python3 scripts/retrieve_context.py "<milestone title> current state roadmap"
```

If auth fails or retrieval returns no output, **STOP** — report the error and do not continue.

Use retrieved chunks for:
- `current_state.md` context
- `roadmap.md` context
- `vision.md` context

Produce:
- Goal
- Scope
- Tasks
- Acceptance Criteria
- Dependencies
- Risks

After finalising:

1. Write task list to `docs/dev/next_tasks.md`
2. Write first task to `docs/dev/current_task.md`
3. Mark milestone as "In Progress" if required.

Then run `/compact`.

---

# Step 2 — Architect

Act as the Engineering Architect persona defined in `docs/personas/architect.md`.

Before proposing architecture, verify GCP auth and run Firebase retrieval:

```bash
gcloud auth application-default print-access-token >/dev/null
python3 scripts/retrieve_context.py "<milestone title> architecture decisions ADR"
```

If auth fails or retrieval returns no output, **STOP** — report the error and do not continue.

Use retrieved chunks for:
- ADR context
- structural patterns
- integration risks

Read `docs/dev/next_tasks.md` locally.

Review for:
- structural risks
- integration risks
- scalability concerns
- security concerns

Append only necessary ADRs.

If any blocker-level issue exists, rewrite affected tasks before build begins.

Then run `/compact`.

---

# Step 3 — Builder

Act as the Builder persona defined in `docs/personas/builder.md`.

Read `docs/dev/next_tasks.md` locally.

For each task:

1. Verify GCP auth and run Firebase retrieval for the specific task:
   ```bash
   gcloud auth application-default print-access-token >/dev/null
   python3 scripts/retrieve_context.py "<task description> implementation"
   ```
   If auth fails or retrieval returns no output, **STOP** — report the error and do not continue.
2. Read only relevant CLAUDE.md sections for directories being modified.
3. Implement the minimum code required.
4. Add or update tests where appropriate.
5. Avoid unnecessary rewrites.
6. Update `docs/dev/current_task.md`.

Implementation rules:
- work in small slices
- prefer incremental commits
- preserve existing patterns
- minimise token-heavy outputs

After significant slices:
- inspect diff
- ensure consistency
- commit checkpoint if appropriate

When complete:
- mark current task complete
- update milestone status

Then run `/compact`.

---

# Step 4 — Reviewer

Act as the Reviewer persona defined in `docs/personas/reviewer.md`.

Review all changes using:

```bash
git diff main
```

Verify GCP auth and run Firebase retrieval to validate against known patterns:

```bash
gcloud auth application-default print-access-token >/dev/null
python3 scripts/retrieve_context.py "<milestone title> review acceptance criteria"
```

If auth fails or retrieval returns no output, **STOP** — report the error and do not continue.

Check:
- all acceptance criteria met
- no new `flutter analyze` warnings
- docs updated (`current_state.md`, `backlog_active.md`, ADR index, milestone status)
- commit clean and descriptive

Then run `/compact`.
