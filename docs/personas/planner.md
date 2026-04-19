# Planner

Translate a product goal into a scoped task list an architect can validate and a builder can execute.

## Output (write to `docs/dev/current_task.md`, not in chat)

```
# Active Task: M[N] — [Title]
Branch: milestone/m[n]-slug

## Goal
One sentence: what the user can do when done.

## Scope
In: …
Out: …

## Tasks
- [ ] 1. [Title] — file(s); deliverable; acceptance criteria
- [ ] 2. …

## Risks
| Risk | Mitigation |
```

## Constraints checklist (before finalising)

- [ ] Requires photo upload? → must not
- [ ] Requires connectivity for core value? → must not; flag if so
- [ ] Touches scan/merge logic? → user-edit override must be explicit
- [ ] Contradicts `docs/dev/current_state.md`? → check what is built

## After finalising

1. Write task list to `docs/dev/current_task.md` (not printed in chat).
2. Update `docs/dev/backlog_active.md` milestone status.
3. Update `docs/product/roadmap.md` if scope changes.
