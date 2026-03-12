# Package Boundaries

## Dependency Graph

```
apps/mobile_flutter  ──►  packages/country_lookup
apps/mobile_flutter  ──►  packages/shared_models  (Dart)
apps/web_nextjs      ──►  packages/shared_models  (TypeScript)

packages/country_lookup  ──►  (none)
packages/shared_models   ──►  (none)
```

**Rules:**
- Apps depend on packages. Packages do not depend on apps. Packages do not depend on each other.
- This graph must remain a DAG. Any design that requires a cycle is a signal to redesign.

---

## `packages/country_lookup`

**Language:** Dart (pure — no Flutter, no platform plugins)

**Public API:**
```dart
// Initialise once at startup (caller loads the asset bytes):
void initCountryLookup(Uint8List geodataBytes);

// Resolve a coordinate to a country code (returns null for open water / poles):
String? resolveCountry(double latitude, double longitude);

// Return all country polygons from the loaded binary (for map rendering).
// Multiple entries may share the same isoCode (multi-ring countries).
List<CountryPolygon> loadPolygons();

// Exported type:
class CountryPolygon { final String isoCode; final List<(double, double)> vertices; }
```

See ADR-017 for the rationale for expanding beyond a single public function.

**In scope:**
- The three functions and one type above
- Bundled geodata loading at startup

**Never add:**
- Network calls of any kind
- Runtime file I/O
- Flutter or platform dependencies
- Analytics or logging (the caller logs if needed)

**Why the strict boundary:** the package is the privacy guarantee. If it can make network calls, the guarantee weakens. Reviews block any change that introduces an external dependency.

---

## `packages/shared_models`

**Languages:** Dart (`lib/`) and TypeScript (`ts/`) — both must stay in sync.

**In scope:**
- Data classes and pure transformation functions (see `packages/shared_models/CLAUDE.md` for the current model list)
- Serialisation: hand-written Dart constructors; TypeScript interfaces planned
- Pure derived computations (e.g. `effectiveVisitedCountries()`, `TravelSummary.fromVisits()`)

**Never add:**
- Business rules or validation (these live in the consuming app)
- Network calls, file I/O, or platform APIs
- State management

**Dual-language discipline:** when a field is added, renamed, or removed in Dart, the TypeScript counterpart must be updated in the same PR, and vice versa. CI should enforce this via a schema diff check (to be added).

---

## Rules for All Packages

1. **Minimal public surface.** Export only what consumers actually need. Everything else is package-private.
2. **Breaking changes update all consumers in the same PR.** No staged rollouts across separate PRs.
3. **Platform channel code stays in apps.** The Swift/Dart bridge lives in `apps/mobile_flutter`, not in a package.
4. **No analytics SDKs in packages.** Apps instrument; packages compute.

---

## What Belongs in Apps, Not Packages

If you are considering extracting something into a package, check this list first:

| Concern | Stays in app |
|---|---|
| Firebase / Firestore access | Yes |
| State management (Riverpod, etc.) | Yes |
| UI components | Yes |
| Platform channel implementations | Yes |
| Analytics and error monitoring | Yes |
| Feature flags | Yes |
| Repository layer / local DB | Yes |

A package is justified only when: (a) two or more apps need the same logic, **and** (b) it can be tested in complete isolation, **and** (c) it has no side effects. If all three are true, create the package under `packages/` and add a `CLAUDE.md` defining its boundary rules.
