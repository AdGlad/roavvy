# Roavvy

Travel discovery app: scans photo library → detects visited countries → world map, achievements, shareable cards, merch store.

```
apps/mobile_flutter/     Flutter app (iOS-first, Swift PhotoKit bridge)
apps/web_nextjs/         Next.js web app
packages/country_lookup/ Offline GPS→country (never network)
packages/shared_models/  Shared data models (Dart + TypeScript)
```

## Hard constraints

1. Photos never leave the device. Only `{countryCode, firstSeen, lastSeen}` syncs.
2. Country detection must work offline. `country_lookup` makes zero network calls.
3. User edits permanently override auto-detection. Tombstones suppress future inference.
4. Firestore stores: uid, visit records, achievement state, share tokens — nothing else.

## Conventions

- Money: minor units (pence/cents).
- Country codes: ISO 3166-1 alpha-2.
- Dates: ISO 8601 in Firestore; `DateTime` UTC in Dart; `Date` in TypeScript.
- Errors: typed exceptions from packages; caught and surfaced at app layer only.
- No analytics SDKs in packages.

## Persona workflow

`Planner → (UX Designer) → Architect → Builder → Reviewer`

| Persona | File | Role |
|---|---|---|
| Planner | `docs/personas/planner.md` | Scope + task list + acceptance criteria |
| UX Designer | `docs/personas/ux_designer.md` | UI flows (user-facing tasks only) |
| Architect | `docs/personas/architect.md` | Structural decisions + ADRs |
| Builder | `docs/personas/builder.md` | Implementation + tests |
| Reviewer | `docs/personas/reviewer.md` | Correctness, privacy, boundaries |

## Dev rules

- Smallest working slice. No scope expansion beyond the active milestone.
- Minimal file changes. Package boundaries are hard (`docs/engineering/package_boundaries.md`).
- Geographic logic: ISO 3166-1 alpha-2 only; offline-compatible with `country_lookup`.

## Finding context — start here

`docs/_index.md` — grep by keyword → get ADR numbers + source files for any coding topic.

## Load on demand — not upfront

| When | File |
|---|---|
| Implementing | `docs/dev/current_task.md` |
| Checking what exists | `docs/dev/current_state.md` |
| Planning next milestone | `docs/dev/backlog_active.md` |
| New pattern / ADR check | `docs/architecture/decisions/_index.md` → specific ADR |
| Full recent ADRs | `docs/architecture/decisions/adr-recent.md` |
| Pre-ADR-100 history | `docs/architecture/decisions/adr-archive.md` |
| File ownership | `docs/dev/project_index.md` |
| Product scope | `docs/product/roadmap.md`, `docs/product/vision.md` |

See `docs/engineering/compact_protocol.md` for session compaction.
