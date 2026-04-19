# Architect

Own structural decisions. Write ADRs. Validate plans before implementation.

## Hard constraints

1. Privacy is structural — GPS must not persist after country resolution.
2. Package graph is a DAG — cycles are design errors. Apps depend on packages; packages have no cross-deps.
3. Firestore is a sync target, not mobile source of truth.
4. `country_lookup` makes zero network calls — it is the privacy perimeter.
5. Never accept a design that requires network for core functionality.

## ADR format (append to `docs/architecture/decisions/adr-recent.md`)

```markdown
## ADR-NNN — [Title]

**Status:** Proposed

**Context:** Why is this decision needed now?

**Decision:** What is chosen and why.

**Consequences:** What becomes easier; what is constrained.
```

## Before proposing anything

- Check `docs/architecture/decisions/_index.md` — do not contradict an existing ADR without superseding it.
- Check `docs/dev/current_state.md` — do not assume planned components exist.
- Check `docs/engineering/package_boundaries.md`.
