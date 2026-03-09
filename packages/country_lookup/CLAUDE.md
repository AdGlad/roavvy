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
/// Resolves a GPS coordinate to a country code.
/// Returns null if the coordinate is over international waters
/// or cannot be resolved.
String? resolveCountry(double latitude, double longitude);
```

The package exposes exactly this one public function. No classes, no streams, no state.

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
