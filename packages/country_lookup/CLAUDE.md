# packages/country_lookup — CLAUDE.md

## Purpose

Resolves GPS coordinates to ISO 3166-1 alpha-2 country codes, entirely offline. Used by the mobile app during photo scanning. Must never make network calls.

## Constraints — Non-Negotiable

1. **No network calls.** This package must function with zero internet access. Any change that introduces an HTTP dependency will be rejected in review.
2. **No platform dependencies.** Pure Dart. No Flutter, no iOS/Android plugins.
3. **No file I/O at runtime.** Geodata is bundled at build time (compiled into the binary or loaded from a bundled asset). The package does not read from arbitrary file paths.
4. **Deterministic output.** Given the same coordinate, the package always returns the same result. No randomness, no external state.

## API Contract

```dart
/// Must be called once before any other function.
/// [geodataBytes] is the raw content of assets/geodata/ne_countries.bin.
void initCountryLookup(Uint8List geodataBytes);

/// Resolves a GPS coordinate to an ISO 3166-1 alpha-2 country code.
/// Returns null if the coordinate is over international waters or unresolvable.
String? resolveCountry(double latitude, double longitude);

/// Returns all country polygons from the loaded binary.
/// Multiple entries may share the same [CountryPolygon.isoCode] for
/// multi-ring countries (e.g. US, RU, archipelagos).
/// Used by the map rendering layer; see ADR-017.
List<CountryPolygon> loadPolygons();
```

`CountryPolygon` is an exported type: `isoCode` (ISO 3166-1 alpha-2) and `vertices` (list of `(lat, lng)` pairs in decimal degrees).

All three functions assert if called before `initCountryLookup()`.

## Data Source

Bundled polygon data derived from Natural Earth (public domain). The build process for updating geodata is documented in `packages/country_lookup/GEODATA.md` (to be created when data pipeline is set up).

Accuracy target: capital city coordinates resolve correctly; small island nations resolve correctly; coordinates within 1 km of a border may resolve to either country (acceptable).

## Performance Target

`resolveCountry` must complete in < 5 ms on a mid-range device (iPhone XR equivalent). Benchmark test required.

## Testing

- 100% coverage of the public API.
- Tests for: major countries, island nations, poles, null island (0,0), international waters, border cases.

## Related Docs

- [Offline Strategy](../../docs/architecture/offline_strategy.md)
- [Package Boundaries](../../docs/engineering/package_boundaries.md)
