# Lane A2 — On-device rendered capture (runbook)

Renders procedural designs through the **real** `CardImageRenderer` on a booted iOS
simulator (fonts, SVG flag/outline assets, and GPU shaders all work — unlike the
flaky headless Lane A1), and writes the PNGs + contact sheet into the studio so the
Design Critic can judge render-dependent families on true pixels.

## One-time
A booted simulator. List + boot one:
```
xcrun simctl list devices available | grep iPhone
xcrun simctl boot "iPhone 15 Pro"      # or an ID; then:
open -a Simulator
```

## Run (from apps/mobile_flutter)
```
cd apps/mobile_flutter
flutter drive \
  --driver=test_driver/design_render_capture_driver.dart \
  --target=integration_test/device/design_render_capture_test.dart \
  -d "iPhone 15 Pro"
```
This renders on the sim and the host driver writes
`design_studio/generated_batches/rendered_device/report.json`.

## Decode → PNGs + contact sheet
```
design_studio/tools/decode_device_capture.sh
```
→ `design_studio/generated_batches/rendered_device/{img/*.png, manifest.json, index.html}`

## Then
Open `index.html` (or have the `design-critic` / `reference-analyst` review it).
These are the pixel-truth renders that let the studio finally judge the deferred
items — `negativeSpaceCutout` hero scale, `duoBlend` shader, `statementCount` text
(now with real fonts, not tofu) — and confirm/repair them (vs the Lane A1 triage
rule: only recipe-confirmable defects are fixed headless).

## Notes
- The set is inlined in the test (4 contexts × 3 designs) — edit the `contexts`
  map / `perContext` there to widen coverage.
- `-d` accepts a simulator name or the UDID from `xcrun simctl list`.
- If `flutter drive` can't find the device, ensure the sim is **Booted** and shows
  in `flutter devices`.
