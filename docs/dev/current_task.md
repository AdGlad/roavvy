# Current Task — Task 58: iPhone-only declaration + bundle identity fix

**Milestone:** 19
**Phase:** 9 — App Store Readiness

## Why

The Flutter scaffold targets both iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). Without an adaptive iPad layout, shipping with iPad support risks App Store Review rejection. Declaring iPhone-only is the correct choice for M19 (ADR-057). The bundle display name `"Mobile Flutter"` is also a placeholder that must be corrected before any App Store submission.

## Acceptance criteria

- [ ] `TARGETED_DEVICE_FAMILY` set to `"1"` in **all three** build configuration blocks in `project.pbxproj` (Debug, Release, Profile)
- [ ] `UISupportedInterfaceOrientations~ipad` section removed from `Info.plist`
- [ ] `CFBundleDisplayName` updated to `"Roavvy"` in `Info.plist`
- [ ] `CFBundleName` updated to `"Roavvy"` in `Info.plist`
- [ ] `flutter build ios --no-codesign` completes without errors
- [ ] App runs correctly on iPhone Simulator after changes

## Status: AWAITING BUILDER

## ADR

ADR-057

## Files to change

- `apps/mobile_flutter/ios/Runner.xcodeproj/project.pbxproj` — set `TARGETED_DEVICE_FAMILY = "1"` in all three build configs
- `apps/mobile_flutter/ios/Runner/Info.plist` — remove `UISupportedInterfaceOrientations~ipad`; update `CFBundleDisplayName` and `CFBundleName`

## Dependencies

None. No external deliverables required.
