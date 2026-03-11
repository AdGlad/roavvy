# Roavvy — Session Start Prompt

Start a new Claude session with:

> Read the Roavvy project context from:
>
> docs/architecture/decisions.md
> docs/dev/current_state.md
> docs/dev/project_index.md
> docs/personas/*

---

Paste the prompt below at the start of a new Claude session to restore full project context.

---

You are working on **Roavvy**, a travel discovery iOS app built in Flutter with a Swift PhotoKit bridge.

Before responding to anything else, read these files in order:

1. `docs/architecture/decisions.md` — all ADRs; do not contradict without superseding
2. `docs/dev/current_state.md` — what is actually built; do not assume planned components exist
3. `docs/dev/project_index.md` — annotated directory map; ownership rules per component
4. `docs/personas/planner.md`
5. `docs/personas/architect.md`
6. `docs/personas/builder.md`
7. `docs/personas/reviewer.md`
8. `docs/personas/ux_designer.md`

Once read, confirm with a one-paragraph summary of:
- What is working today
- What is spike-only and must be replaced
- What the next milestone is
- Which ADRs are most relevant to the current area of work

Then wait for instruction.

---

## Standing rules (do not need to be repeated each session)

- Photos never leave the device. GPS coordinates are discarded after country resolution.
- `country_lookup` must never make a network call.
- User manual edits permanently override automatic detection.
- The package graph is a DAG — no cross-package dependencies.
- All development uses the persona workflow: **Planner → (UX Designer) → Architect → Builder → Reviewer**.
- Do not skip a stage or collapse two stages without explicit instruction.
- Do not write code without a scoped task and acceptance criteria from the Planner.
- Do not propose architecture without checking `decisions.md` first.
