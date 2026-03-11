# Roavvy — Root CLAUDE.md

## Project Overview

Roavvy is a travel discovery app that scans a user's photo library to detect which countries they have visited. It presents a world travel map, awards achievements, generates shareable travel cards, and connects to a merchandise store.

---

## Session Initialization

At the start of every new Claude session:

1. Read the core project context:

   - docs/architecture/decisions.md
   - docs/dev/current_state.md
   - docs/dev/project_index.md
   - docs/dev/next_tasks.md

2. Read all persona definitions:

   - docs/personas/*

3. Use these files as the authoritative source of truth for the Roavvy project.

Claude must rely on repository documentation rather than conversation history whenever possible.

---

## Repo Structure

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

All development follows a four-stage workflow. Each stage has a dedicated persona. Do not skip stages or collapse them without explicit instruction.

```
Planner → (UX Designer) → Architect → Builder → Reviewer
```

| Stage | Persona | File | Does |
|---|---|---|---|
| 1 | Planner | `docs/personas/planner.md` | Scopes work; writes task list with acceptance criteria |
| 2 | Architect | `docs/personas/architect.md` | Validates plan; identifies structural risks; writes ADRs |
| 3 | Builder | `docs/personas/builder.md` | Implements the scoped task with tests |
| 4 | Reviewer | `docs/personas/reviewer.md` | Reviews for correctness, privacy, and boundaries |

**UX Designer** (`docs/personas/ux_designer.md`) — invoked between Planner and Architect for any task with a user-facing component. Designs flows, component states, and copy before implementation begins.

### How to invoke a persona

Say "Act as the [persona name]" at the start of a request. The persona file defines what that role does, what it does not do, and what it must read before acting.

### Workflow rules

- The Planner produces a task list before the Architect or Builder touch anything.
- The Architect reads `docs/architecture/decisions.md` before proposing any design.
- The Builder reads the relevant `CLAUDE.md` before writing code in any directory.
- The Reviewer's `[BLOCKER]` findings must be resolved before the task is considered done.
- Any persona can flag "this needs the Architect" or "this needs a Planner task first" — do not proceed past a structural concern without explicit sign-off.

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

### Incremental development

Implement features in the smallest possible working slice. Prefer small commits and minimal vertical slices. Do not implement multiple subsystems at once or expand scope beyond the current milestone.

### File modification discipline

Identify the minimal set of files that must change. Avoid modifying unrelated directories. Packages must respect boundaries defined in `docs/engineering/package_boundaries.md`.

### Geographic data

All country detection and geographic rendering must use ISO 3166-1 alpha-2 codes. All geographic logic must remain compatible with `packages/country_lookup/`. Country detection must work offline and never depend on network APIs.

---

## Key Docs

- [Architecture Decisions](docs/architecture/decisions.md)
- [Current Development State](docs/dev/current_state.md)
- [Project Index](docs/dev/project_index.md)
- [Next Tasks](docs/dev/next_tasks.md)
- [Personas](docs/personas/)
- [System Overview](docs/architecture/system_overview.md)
- [Data Model](docs/architecture/data_model.md)
- [Offline Strategy](docs/architecture/offline_strategy.md)
- [Privacy Principles](docs/architecture/privacy_principles.md)
- [Mobile Scan Flow](docs/architecture/mobile_scan_flow.md)
- [Package Boundaries](docs/engineering/package_boundaries.md)

## Session Compaction Protocol

When the user runs `/compact`, Claude must perform the following steps before compacting the session.

### Step 1 — Persist project state to the repository

Update the following files so they reflect the true current state of the Roavvy project:

docs/dev/current_state.md  
docs/dev/next_tasks.md  

Include:

- tasks completed in this session
- components that now exist
- what currently works
- the next task to implement
- any risks or TODOs

If architecture decisions were made in the session, also update:

docs/architecture/decisions.md

### Step 2 — Produce a session summary

Before compacting, output a concise summary including:

- completed tasks
- current milestone
- next task
- important architectural decisions
- anything still unresolved

### Step 3 — Compact the session

After the repository documentation has been updated and the summary produced, Claude may execute the `/compact` command.

### Step 4 — Verify context after compaction

After compaction, confirm:

- current Roavvy milestone
- last completed task
- next command the user should run