# Roavvy — Root CLAUDE.md

## Project Overview

Roavvy is a travel discovery app that scans a user's photo library to detect which countries they have visited. It presents a world travel map, awards achievements, generates shareable travel cards, and connects to a merchandise store.

## Repo Structure

```
apps/mobile_flutter/     Flutter app (iOS-first, Swift PhotoKit bridge)
apps/web_nextjs/         Next.js web app (travel map, sharing, merch)
packages/country_lookup/ Offline coordinate→country resolution
packages/shared_models/  Platform-agnostic data models and types
docs/                    Architecture, engineering, product, UX, prompts, tasks
```

## Core Constraints

1. **Photos are never uploaded.** Only derived metadata (GPS coordinates, timestamps, country codes) leaves the device — and only with explicit user consent.
2. **Offline-first.** Country detection must work without a network connection. The `country_lookup` package must never make network calls.
3. **User edits override detection.** Any country or visit that a user manually adds, edits, or removes takes permanent precedence over automatically detected data.
4. **Minimal cloud footprint.** Firebase stores only: user ID, country visit records (country code + first/last seen dates), achievement state, and sharing tokens.

## Personas

Each persona has a prompt file under `docs/prompts/`. Invoke them by describing your role at the start of a session, or reference the file directly.

| Persona | File | Responsibilities |
|---|---|---|
| Planner | `docs/prompts/planner.md` | Scope, prioritisation, task breakdown |
| Engineering Architect | `docs/prompts/architect.md` | System design, package boundaries, ADRs |
| Builder | `docs/prompts/builder.md` | Feature implementation, code quality |
| Reviewer | `docs/prompts/reviewer.md` | Code review, security, correctness |
| UX Designer | `docs/prompts/ux_designer.md` | Flows, components, accessibility |

## Cross-Cutting Conventions

- All monetary values in minor units (cents / pence).
- Country codes: ISO 3166-1 alpha-2 (e.g. `GB`, `US`, `JP`).
- Dates: ISO 8601 strings in Firestore; `DateTime` (UTC) in Dart; `Date` objects in TypeScript.
- Error handling: surface user-facing errors in the UI layer only; packages throw typed exceptions.
- No analytics SDKs in packages — only in app layers.

## Key Docs

- [System Overview](docs/architecture/system_overview.md)
- [Data Model](docs/architecture/data_model.md)
- [Offline Strategy](docs/architecture/offline_strategy.md)
- [Privacy Principles](docs/architecture/privacy_principles.md)
- [Mobile Scan Flow](docs/architecture/mobile_scan_flow.md)
- [Package Boundaries](docs/engineering/package_boundaries.md)
