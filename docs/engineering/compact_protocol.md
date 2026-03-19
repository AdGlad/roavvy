# Session Compaction Protocol

When the user runs `/compact`, perform these steps before compacting.

## Step 1 — Persist project state

Update these files to reflect the true current state:

- `docs/dev/current_task.md` — mark completed items; update status and files-changed list
- `docs/dev/backlog.md` — move completed tasks out; update next task in queue
- `docs/dev/current_state.md` — what is built, what currently works, any risks

If architecture decisions were made, also update `docs/architecture/decisions.md`.

## Step 2 — Produce a session summary

Output a concise summary:

- completed tasks
- current milestone
- next task
- important architectural decisions
- anything still unresolved

## Step 3 — Compact

Execute the `/compact` command.

## Step 4 — Verify context after compaction

Confirm:

- current Roavvy milestone
- last completed task
- next command the user should run
