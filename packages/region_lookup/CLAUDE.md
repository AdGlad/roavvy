# packages/region_lookup — CLAUDE.md

## Purpose

Resolves GPS coordinates to ISO 3166-2 region codes (e.g. "US-CA", "GB-ENG", "FR-IDF"),
entirely offline. Used by the mobile app during photo scanning. Must never make network calls.

## Constraints — Non-Negotiable

1. **No network calls.** This package must function with zero internet access.
2. **No platform dependencies.** Pure Dart. No Flutter, no iOS/Android plugins.
3. **No file I/O at runtime.** Geodata is loaded from a bundled asset by the caller.
4. **Deterministic output.** Same coordinate always returns the same result.

## API Contract

```dart
/// Must be called once before any other function.
/// [geodataBytes] is the raw content of assets/geodata/ne_admin1.bin.
void initRegionLookup(Uint8List geodataBytes);

/// Resolves a GPS coordinate to an ISO 3166-2 region code.
/// Returns null for open water, micro-states without admin1 divisions, or
/// coordinates that do not match any admin1 polygon.
String? resolveRegion(double latitude, double longitude);
```

## Coordinate Contract (ADR-051)

`resolveRegion` must be called with the **same 0.5° bucketed coordinates** used
by `resolveCountry` in `packages/country_lookup`. Callers must NOT pass raw GPS
coordinates — bucketing is the caller's responsibility.

## Data Source

Natural Earth 1:10m admin1/states-provinces (public domain). Build script:
`tool/build_geodata.py`. See `GEODATA.md` for instructions.

## Related Docs

- [ADR-049](../../docs/architecture/decisions.md) — region_lookup package design
- [ADR-051](../../docs/architecture/decisions.md) — bucketed coordinate contract
- [Package Boundaries](../../docs/engineering/package_boundaries.md)
