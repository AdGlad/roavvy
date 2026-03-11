# Roavvy — Project Index

A map of every major directory in the repository: what it contains, what it owns, and what it does not own.

---

## Repository Root

```
roavvy/
├── CLAUDE.md               AI session instructions and project conventions
├── apps/
│   ├── mobile_flutter/     Flutter + Swift iOS app
│   └── web_nextjs/         Next.js web app (not yet built)
├── packages/
│   ├── shared_models/      Domain model — Dart (TypeScript side pending)
│   └── country_lookup/     Offline GPS → country code resolver (not yet built)
└── docs/
    ├── architecture/       ADRs, system design, data model, scan flow
    ├── dev/                Living development state (current_state, this file)
    ├── engineering/        Coding standards, testing strategy, DoD
    ├── product/            Vision, roadmap, user flows
    ├── prompts/            AI persona prompts (architect, builder, etc.)
    ├── tasks/              Task templates (feature, bugfix, refactor)
    └── ux/                 Design principles, navigation, onboarding
```

Dependency rule: apps depend on packages; packages depend on nothing except each other (and that is currently forbidden — packages are isolated). Docs reference code but never the reverse.

---

## apps/mobile_flutter

**Status:** Active — runs on a real iPhone. Spike-phase code; some components will be replaced.

**Technology:** Flutter 3.29.3 (Dart), Swift (iOS PhotoKit bridge).

**Owns:**
- The Swift PhotoKit bridge that reads GPS + date metadata from the photo library
- The Dart `MethodChannel` wrapper that communicates with the bridge
- Scan orchestration, permission handling, and result merging
- Local persistence (currently `shared_preferences`; will be Drift SQLite)
- All UI screens

**Does not own:**
- Domain model types — those live in `packages/shared_models`
- Country code resolution — that will live in `packages/country_lookup`
- Firebase access — not yet built

### Directory layout

```
apps/mobile_flutter/
├── ios/Runner/
│   └── AppDelegate.swift          Swift PhotoKit + CLGeocoder bridge (spike)
│                                  Reads CLLocation + creationDate per PHAsset.
│                                  Returns aggregate scan result over MethodChannel.
│
├── lib/
│   ├── main.dart                  App entry point; MaterialApp + RoavvySpike widget
│   ├── photo_scan_channel.dart    MethodChannel wrapper; Dart types for channel
│   │                              payloads: ScanStats, ScanResult, DetectedCountry,
│   │                              PhotoPermissionStatus. Spike-only types — will be
│   │                              replaced by ScanSummary from shared_models.
│   ├── scan_screen.dart           Main screen: permission request, scan trigger,
│   │                              stats card, country visit list, Review & Edit button
│   └── features/
│       ├── scan/
│       │   └── scan_mapper.dart   Converts DetectedCountry → CountryVisit (auto source)
│       └── visits/
│           ├── visit_store.dart   SharedPreferences persistence: load/save/clear
│           │                      List<CountryVisit> as JSON at key roavvy.visits.v1
│           └── review_screen.dart Full-screen review flow: remove detected countries,
│                                  add countries manually, save corrected list
│
└── test/
    ├── widget_test.dart                ScanScreen widget tests + ScanStats unit tests
    └── features/
        ├── scan/
        │   └── scan_mapper_test.dart   Unit tests for DetectedCountry → CountryVisit
        └── visits/
            ├── visit_store_test.dart   Unit tests for load/save/clear + tombstone behaviour
            └── review_screen_test.dart Widget tests for remove, undo, add, save flows
```

### Key interfaces

**Channel contract** (`MethodChannel('roavvy/photo_scan')`):

| Method | Args | Returns |
|---|---|---|
| `requestPermission` | — | `int` (PhotoPermissionStatus raw value) |
| `scanPhotos` | `{limit: int, sinceDate?: String}` | `{inspected, withLocation, geocodeSuccesses, countries: [...]}` |

This is the spike contract. The production contract will stream per-photo records instead of returning an aggregate.

---

## apps/web_nextjs

**Status:** Not yet built. Directory exists with a `CLAUDE.md` defining conventions.

**Technology (planned):** Next.js 14+ App Router, TypeScript, Firebase client SDK, Shopify Storefront API.

**Will own:**
- Authenticated travel map view (reads from Firestore)
- Public sharing pages at `/share/[token]` (SSR, no auth required)
- Merchandise store (Shopify Storefront API, server components only)
- Firebase Auth integration (anonymous + persistent sign-in)

**Does not own:**
- Scanning — that is mobile-only
- Domain model types — those live in `packages/shared_models/ts/`

---

## packages/shared_models

**Status:** Active. Dart side implemented; TypeScript side not yet built.

**Technology:** Pure Dart. Zero dependencies (only `test` in dev dependencies). No Flutter SDK, no platform plugins.

**Owns:**
- The canonical domain model types for both apps
- Serialisation (`toJson` / `fromJson` on each type)
- The `effectiveVisitedCountries()` merge function

**Does not own:**
- Business logic or validation (those live in apps)
- Network calls, file I/O, or platform APIs
- State management

**Dual-language rule:** every change to a Dart type must be reflected in `ts/` in the same PR. The `ts/` directory does not yet exist — it must be created before any `apps/web_nextjs` usage.

### Directory layout

```
packages/shared_models/
├── lib/
│   ├── shared_models.dart             Barrel export — imports this in consuming code
│   └── src/
│       │
│       │  ── Write-side input records (stored in DB) ──────────────────────
│       ├── inferred_country_visit.dart  Country detected by scan pipeline.
│       │                               Carries: countryCode, inferredAt,
│       │                               photoCount, firstSeen?, lastSeen?
│       ├── user_added_country.dart      Country explicitly added by user.
│       │                               Carries: countryCode, addedAt
│       ├── user_removed_country.dart    Permanent tombstone (user removed country).
│       │                               Carries: countryCode, removedAt
│       │
│       │  ── Read-side projection (computed; never stored) ─────────────────
│       ├── effective_visited_country.dart  One per code in the effective set.
│       │                               Carries: countryCode, hasPhotoEvidence,
│       │                               firstSeen?, lastSeen?, photoCount
│       │
│       │  ── Scan pipeline output ────────────────────────────────────────
│       ├── scan_summary.dart           Per-run stats + list of InferredCountryVisit.
│       │                               Carries: scannedAt, assetsInspected,
│       │                               assetsWithLocation, geocodeAttempts,
│       │                               geocodeSuccesses, countries
│       │
│       │  ── Merge function ─────────────────────────────────────────────
│       ├── effective_visit_merge.dart  effectiveVisitedCountries({inferred, added,
│       │                               removed}) → List<EffectiveVisitedCountry>
│       │
│       │  ── Legacy types (spike storage format; to be retired) ──────────
│       ├── country_visit.dart          Flat model encoding all three input kinds
│       │                               via source + isDeleted flags. Used as the
│       │                               shared_preferences JSON format today.
│       ├── visit_source.dart           enum VisitSource { auto, manual }
│       ├── visit_merge.dart            effectiveVisits(List<CountryVisit>) — legacy
│       │                               merge used with CountryVisit storage format
│       └── travel_summary.dart         TravelSummary: point-in-time snapshot of
│                                       countryCount, earliestVisit, latestVisit
│
└── test/
    ├── country_visit_test.dart           CountryVisit construction, copyWith, equality,
    │                                     JSON round-trip (13 tests)
    ├── visit_merge_test.dart             effectiveVisits() rules: manual beats auto,
    │                                     tombstone suppression, same-source conflict (12 tests)
    ├── travel_summary_test.dart          TravelSummary.fromVisits date range, counts (8 tests)
    └── effective_visit_merge_test.dart   effectiveVisitedCountries(): removals, additions,
                                          multi-scan merge, mixed scenarios (22 tests)
```

---

## packages/country_lookup

**Status:** Not yet built. Directory exists with a `CLAUDE.md` defining its boundary rules.

**Technology (planned):** Pure Dart. Zero dependencies. No network calls — ever.

**Will own:**
- Bundled Natural Earth polygon geodata (Flutter asset)
- `String? resolveCountry(double latitude, double longitude)` — the only public function
- Coordinate-to-polygon lookup (point-in-polygon over the bundled dataset)

**Will not own:**
- Network calls of any kind (this is a hard constraint — it is the privacy perimeter)
- Runtime file I/O
- Flutter or platform SDK dependencies
- Name→ISO code mapping (coordinates resolve directly to ISO codes; no names involved)

**Replaces:** CLGeocoder in `AppDelegate.swift`. When implemented, all CLGeocoder code is deleted.

---

## docs/architecture

Reference documentation for how the system is designed to work. Updated when a design decision changes.

| File | Contents |
|---|---|
| `decisions.md` | 13 ADRs — the definitive record of every key design choice, its rationale, and its consequences. **Read before making any architectural change.** |
| `system_overview.md` | System diagram, data flow narrative, component table, high-level design decisions |
| `data_model.md` | Field-level schema for all models; Firestore structure; what is never stored |
| `offline_strategy.md` | Local DB as source of truth; sync model; dirty flag; conflict resolution; reconnection |
| `privacy_principles.md` | Structural privacy guarantee; what happens to each data type; permissions; user control |
| `mobile_scan_flow.md` | Step-by-step scan pipeline; platform channel contract; incremental scan; error handling; performance targets |

---

## docs/dev

Living documents about actual development state. Updated as the codebase evolves.

| File | Contents |
|---|---|
| `current_state.md` | What is built and working today; domain model; key files; all architecture decisions summarised; test counts; next milestones; spike limitations. **Read before assuming any component exists.** |
| `project_index.md` | This file — directory map and purpose of each major location in the repo |

---

## docs/engineering

How we write and review code. Stable conventions that change only when the team agrees.

| File | Contents |
|---|---|
| `coding_standards.md` | Dart/Flutter style, state management (Riverpod), error handling pattern, TypeScript conventions, git commit format |
| `testing_strategy.md` | Test layer definitions (unit / widget / integration); mandatory test cases; privacy-specific regression tests |
| `package_boundaries.md` | Dependency graph; what belongs in packages vs. apps; rules for adding new packages |
| `definition_of_done.md` | Checklist every task must satisfy before merge |

---

## docs/product, docs/ux, docs/prompts, docs/tasks

| Directory | Contents |
|---|---|
| `product/` | Vision, roadmap, user flows — product intent and priorities |
| `ux/` | Design principles, navigation structure, onboarding flow |
| `prompts/` | AI persona prompts: architect, builder, planner, reviewer, ux_designer. Load the relevant one at the start of a session. |
| `tasks/` | Task templates for features, bugfixes, and refactors |
