# Roavvy — Root CLAUDE.md

## Project Overview

Roavvy is a travel discovery app that scans a user's photo library to detect which countries they have visited. It presents a world travel map, awards achievements, generates shareable travel cards, and connects to a merchandise store.

---

## Repo Structure

See [docs/dev/project_index.md](docs/dev/project_index.md).

```
apps/mobile_flutter/     Flutter app (iOS-first, Swift PhotoKit bridge)
apps/web_nextjs/         Next.js web app (travel map, sharing, merch)
packages/country_lookup/ Offline coordinate→country resolution
packages/shared_models/  Platform-agnostic data models and types
docs/                    Architecture, engineering, product, UX, prompts, tasks
```

---

## Core Constraints

1. **Photos are never uploaded.** Only derived metadata (GPS coordinates, timestamps, country codes) leaves the device — and only with explicit user consent.

2. **Offline-first.** Country detection must work without a network connection. The `country_lookup` package must never make network calls.

3. **User edits override detection.** Any country or visit that a user manually adds, edits, or removes takes permanent precedence over automatically detected data.

4. **Minimal cloud footprint.** Firebase stores only: user ID, country visit records (country code + first/last seen dates), achievement state, and sharing tokens.

---

## Persona Workflow

All development follows a four-stage workflow. Do not skip stages or collapse them without explicit instruction.

```
Planner → (UX Designer) → Architect → Builder → Reviewer
```

| Stage | Persona | File | Does |
|---|---|---|---|
| 1 | Planner | `docs/personas/planner.md` | Scopes work; writes task list with acceptance criteria |
| 2 | Architect | `docs/personas/architect.md` | Validates plan; identifies structural risks; writes ADRs |
| 3 | Builder | `docs/personas/builder.md` | Implements the scoped task with tests |
| 4 | Reviewer | `docs/personas/reviewer.md` | Reviews for correctness, privacy, and boundaries |

**UX Designer** (`docs/personas/ux_designer.md`) — invoked between Planner and Architect for any task with a user-facing component.

Say "Act as the [persona name]" to invoke. Each persona file defines what it does, what it does not do, and what it must read before acting.

---

## Cross-Cutting Conventions

- All monetary values in minor units (cents / pence).
- Country codes: ISO 3166-1 alpha-2 (e.g. `GB`, `US`, `JP`).
- Dates: ISO 8601 strings in Firestore; `DateTime` (UTC) in Dart; `Date` objects in TypeScript.
- Error handling: surface user-facing errors in the UI layer only; packages throw typed exceptions.
- No analytics SDKs in packages — only in app layers.

---

## Claude Development Rules

### Before proposing architectural changes or writing new code

- **[docs/architecture/decisions.md](docs/architecture/decisions.md)** — all ADRs; check here before introducing a new pattern or overriding an existing one.
- **[docs/dev/current_state.md](docs/dev/current_state.md)** — what is actually built; check here before assuming any planned component exists.
- **[docs/dev/project_index.md](docs/dev/project_index.md)** — annotated directory map; ownership rules per component.
- **[docs/dev/current_task.md](docs/dev/current_task.md)** — the active task with acceptance criteria and status.
- **[docs/dev/backlog.md](docs/dev/backlog.md)** — upcoming tasks in priority order.
- **[docs/product/roadmap.md](docs/product/roadmap.md)** — product roadmap; read before planning new milestones.
- **[docs/product/vision.md](docs/product/vision.md)** — product vision and north-star goals; check here before changing scope or direction.

### Incremental development

Implement features in the smallest possible working slice. Prefer small commits and minimal vertical slices. Do not implement multiple subsystems at once or expand scope beyond the current milestone.

### File modification discipline

Identify the minimal set of files that must change. Avoid modifying unrelated directories. Packages must respect boundaries defined in `docs/engineering/package_boundaries.md`.

### Geographic data

All country detection and geographic rendering must use ISO 3166-1 alpha-2 codes. All geographic logic must remain compatible with `packages/country_lookup/`. Country detection must work offline and never depend on network APIs.

---

## Session Compaction

See [docs/engineering/compact_protocol.md](docs/engineering/compact_protocol.md).
