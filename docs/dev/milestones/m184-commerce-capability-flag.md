# M184 — Commerce capability flag (one switch)

**Phase:** Free Launch (M184–M189)
**Depends on:** —
**Status:** Done
**Primary target:** `apps/mobile_flutter/lib/core` · ADR-180

Plan and sequencing: `next_tasks.md` (top section, "PLAN — Free Launch").

---

## 1. Why this exists

The first App Store release ships **without** any T-shirt generation or purchasing. Today
there are four unrelated flags, and none of them hides anything:

| Flag | Where | Default | What it actually gates |
|---|---|---|---|
| `purchasing_enabled` | Remote Config | **true** (fail-open) | final checkout leg only |
| `purchasing_enabled_<template>` ×9 | Remote Config | **true** | final checkout leg per template |
| `studio_v2_fulfilment_enabled` | Remote Config | false | Studio V2 `createMerchCart` only |
| `kStudioV2Enabled` (`STUDIO_V2`) | dart-define | false | boots the dev-only Studio shell |

All entry points (Shop tab, Print buttons, "Design your merch" CTAs) stay visible whatever the
flags say. We need **one** switch that everything else follows.

## 2. Decision (ADR-180)

```
commerceEnabled = kCommerceBuild            // compile time: --dart-define=ROAVVY_COMMERCE=true
               && remote 'commerce_enabled' // Remote Config kill switch, default true
```

- **`kCommerceBuild` defaults to `false`.** A release build without the define has no commerce.
- **Remote Config can only turn commerce OFF, never ON**. Commerce reaches users through a
  reviewed build, not a server flip. (App Review guideline 2.3.1: no hidden or dormant
  features turned on after review.)
- Every existing commerce flag is derived from it:
  `purchasingEnabledProvider`, `purchasingEnabledForTemplateProvider`,
  `studioV2FulfilmentEnabledProvider` all short-circuit to `false` when it is off.
- Dev and T-shirt work continues with `--dart-define=ROAVVY_COMMERCE=true`.

## 3. Tasks

- **T1** `lib/core/commerce/commerce_flag.dart`:
  - `const bool kCommerceBuild = bool.fromEnvironment('ROAVVY_COMMERCE')`.
  - `commerceEnabledProvider` (Riverpod `Provider<bool>`), which reads Remote Config through a
    try/catch. If Remote Config is missing it falls back to `kCommerceBuild`, which is never
    more permissive.
- **T2** Add `'commerce_enabled': true` to the `RemoteConfigService` defaults. Invalidate the
  provider on Remote Config update, alongside the existing `purchasingEnabled*` invalidations
  in `main_shell.dart`.
- **T3** Rewire `purchasingEnabledProvider`, `purchasingEnabledForTemplateProvider` and
  `studioV2FulfilmentEnabledProvider` (`core/providers.dart:509-546`) to `&&` with
  `commerceEnabledProvider`.
- **T4** Unit tests, using the `ProviderContainer` override pattern:
  - off by default;
  - build-on + remote-off → off;
  - build-on + remote-on → on;
  - every derived provider is false when commerce is off.
- **T5** Write ADR-180 in `adr-recent.md` and add it to `_index.md`.

## 4. Acceptance

- [ ] `flutter test` passes. `flutter analyze` reports 0 errors.
- [ ] With no dart-define, every commerce provider reads `false` (test-proven).
- [ ] No UI change yet. This milestone is the switch only, so it is safe to merge alone.

## 5. Out of scope

Hiding UI (M185/M186), backend (M187), copy (M188).
