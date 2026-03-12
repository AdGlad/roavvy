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

The domain model uses three write-side records and one computed read model. `CountryVisit` and `VisitSource` were retired in Task 5 (ADR-008).

| Model | Kind | Description |
|---|---|---|
| `InferredCountryVisit` | Write-side | Country detected from photo GPS metadata by the scan pipeline. One record per country code per scan run. |
| `UserAddedCountry` | Write-side | Country manually added by the user. Always appears in the effective set unless suppressed by a `UserRemovedCountry`. |
| `UserRemovedCountry` | Write-side | Tombstone that permanently suppresses a country from the effective set until the user re-adds it. |
| `EffectiveVisitedCountry` | Read model | Computed on demand by `effectiveVisitedCountries()`. Never stored. One entry per country in the effective set. |
| `TravelSummary` | Read model | Point-in-time snapshot of aggregate stats (country count, date range). Built from `List<EffectiveVisitedCountry>`. |
| `ScanSummary` | Value object | Aggregate counters from a completed scan (inspected, with location, countries found). |

## Key functions

| Function | Location | Description |
|---|---|---|
| `effectiveVisitedCountries()` | `effective_visit_merge.dart` | Merges the three write-side collections into the effective set. Removals take absolute precedence. |
| `TravelSummary.fromVisits()` | `travel_summary.dart` | Builds aggregate stats from an already-merged `List<EffectiveVisitedCountry>`. |

## Serialisation

- Dart: plain immutable classes with hand-written constructors. No code generation (`freezed` and `json_serializable` are not used).
- TypeScript: not yet implemented. Planned for the next milestone.

## Related Docs

- [Data Model](../../docs/architecture/data_model.md)
- [Package Boundaries](../../docs/engineering/package_boundaries.md)
- [ADR-008: Typed domain model](../../docs/architecture/decisions.md)
