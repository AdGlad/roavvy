# Current Task

**Milestone:** T5 — Integration Tests
**Status:** Complete — 2026-06-03

Delivered:
- integration_test/app_test.dart: 8 journey test groups (T5.1–T5.8)
- integration_test/fixtures/scan_fixture.dart: 30-country photo fixture (EventChannel format)
- integration_test/helpers/app_runner.dart: pumpTestApp + loadGeodataBytes + freshDb
- integration_test/helpers/channel_stubs.dart: photo scan EventChannel + MethodChannel stubs
- .github/workflows/flutter_ci.yml: integration job enabled (macos-latest, iOS simulator)
- All files compile cleanly (flutter analyze exits 0)

Run: flutter test integration_test/app_test.dart (requires iOS simulator)

## Next milestone: T8 (device-level tests)
