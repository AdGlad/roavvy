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

**Public API:** one function.
```dart
String? resolveCountry(double latitude, double longitude);
```

**In scope:**
- The function above
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
- Data classes and enums (`CountryVisit`, `TravelProfile`, `Achievement`, `SharingCard`, `VisitSource`)
- Serialisation: `fromJson`/`toJson` in Dart; Zod schemas + plain interfaces in TypeScript
- Pure derived computations (e.g. mapping country codes to continents)

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
