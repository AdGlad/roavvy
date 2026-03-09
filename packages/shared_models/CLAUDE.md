# packages/shared_models — CLAUDE.md

## Purpose

Platform-agnostic data models and types shared between the mobile app (Dart) and the web app (TypeScript). This package is the single source of truth for the Roavvy data schema.

When a model changes here, both apps must be updated before the change is merged.

## Constraints

1. **No side effects.** This package contains only data classes, enums, and pure transformation functions (e.g. serialisation). No network calls, no file I/O, no platform APIs.
2. **No business logic.** Validation rules and domain logic live in the consuming apps, not here.
3. **Dual-language.** Models are defined in both Dart (`lib/`) and TypeScript (`ts/`). They must stay in sync. If you add a field in one, add it in the other.
4. **Backwards-compatible changes only.** New optional fields are fine. Removing or renaming fields requires a migration plan.

## Models

| Model | Description |
|---|---|
| `CountryVisit` | A user's record of visiting a country (country code, first seen, last seen, source) |
| `TravelProfile` | Aggregated stats: total countries, continents, visits |
| `Achievement` | A single unlocked achievement (id, unlocked at) |
| `SharingCard` | Snapshot for public sharing (token, country list, generated at) |
| `VisitSource` | Enum: `auto` (detected from photos) or `manual` (user added) |

## Serialisation

- Dart: `fromJson` / `toJson` on each model class. Use `freezed` + `json_serializable`.
- TypeScript: Zod schemas for runtime validation; plain interfaces for type-only use.

## Versioning

Include a `schemaVersion` integer on `TravelProfile`. Increment when breaking changes are unavoidable. Both apps check this field on read.

## Related Docs

- [Data Model](../../docs/architecture/data_model.md)
- [Package Boundaries](../../docs/engineering/package_boundaries.md)
