# M158 — Purchase Killswitch via Firebase Remote Config

## Goal

Allow the store owner to enable or disable the in-app purchase flow at runtime
from the Firebase Console, without requiring an app release. Useful for:

- Pausing sales during Printful/Shopify outages
- Controlling rollout of new product lines
- Emergency stop if a pricing or fulfilment issue is found in production

---

## Architecture

### Remote Config parameter

| Key | Type | Default | Meaning |
|---|---|---|---|
| `purchasing_enabled` | Boolean | `true` | When `false`, the merch purchase flow is hidden/disabled |

**Fail-safe default = `true`** — if Remote Config cannot be fetched (network
offline, cold start before first fetch), purchasing stays on. The intent is a
manual killswitch, not an allowlist; the safe state is "open".

### Config fetch strategy

- **On app launch** — fetch + activate with a 1-hour minimum fetch interval
  (Firebase enforces this in production; 0 in debug/local)
- **On foreground resume** — re-fetch so the operator sees changes within
  ~60 seconds of toggling the Console without the user restarting
- **Riverpod provider** — expose a `purchasingEnabledProvider` (bool) that the
  UI reads. Updates trigger a rebuild wherever it is watched.

### Where the gate lives

Gate at the **merch catalog entry point**, not inside `LocalMockupPreviewScreen`.
This is the earliest point the user expresses intent to buy, and it covers all
paths (pulse cards, achievement cards, travel story, collection browse).

Concretely: the `_navigate()` method in `MerchOptionCard` and
`PulseMerchOptionCard` / `AchievementMerchOptionCard` etc. — before pushing
`LocalMockupPreviewScreen`.

Also gate the **"Design your own"** / browse entry point in
`MerchOptionListWidget`.

**Do NOT** gate the cart, order history, or tracking screens — users who already
purchased must still access those.

### UI when disabled

Show a bottom sheet / `SnackBar` with copy:
> "The store is temporarily unavailable. Check back soon."

No changes to the catalog display — items remain visible so users can browse and
plan. Only the tap-through to the purchase flow is blocked.

### Riverpod integration

```dart
// core/providers/remote_config_provider.dart
final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

final purchasingEnabledProvider = Provider<bool>((ref) {
  final rc = ref.watch(remoteConfigProvider);
  return rc.getBool('purchasing_enabled');
});
```

`RemoteConfig` is a singleton — the provider just wraps it. No stream needed;
the Riverpod cache is invalidated after each fetch+activate by calling
`ref.invalidate(purchasingEnabledProvider)`.

---

## Tasks

### T1 — Add `firebase_remote_config` dependency

**File:** `apps/mobile_flutter/pubspec.yaml`

```yaml
dependencies:
  firebase_remote_config: ^5.4.0
```

Run `flutter pub get`.

### T2 — Create `RemoteConfigService`

**New file:** `apps/mobile_flutter/lib/core/services/remote_config_service.dart`

```dart
class RemoteConfigService {
  static Future<void> initialise() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode
          ? Duration.zero
          : const Duration(hours: 1),
    ));
    await rc.setDefaults({'purchasing_enabled': true});
    // Best-effort fetch on startup; fail silently — default keeps store open.
    try {
      await rc.fetchAndActivate();
    } catch (_) {}
  }

  static Future<void> refresh() async {
    try {
      await FirebaseRemoteConfig.instance.fetchAndActivate();
    } catch (_) {}
  }
}
```

### T3 — Call `RemoteConfigService.initialise()` at app startup

**File:** `apps/mobile_flutter/lib/main.dart`

After `Firebase.initializeApp()`, before `runApp`:

```dart
await RemoteConfigService.initialise();
```

### T4 — Refresh config on foreground resume

**File:** `apps/mobile_flutter/lib/app.dart` (or wherever `WidgetsBindingObserver` is attached)

In `didChangeAppLifecycleState`:
```dart
if (state == AppLifecycleState.resumed) {
  unawaited(RemoteConfigService.refresh());
}
```

After refresh, call `ref.invalidate(purchasingEnabledProvider)` so Riverpod
widgets rebuild with the new value.

### T5 — Create Riverpod providers

**New file:** `apps/mobile_flutter/lib/core/providers/remote_config_providers.dart`

```dart
final purchasingEnabledProvider = Provider<bool>((ref) {
  return FirebaseRemoteConfig.instance.getBool('purchasing_enabled');
});
```

### T6 — Gate purchase navigation in merch catalog widgets

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

In each `_navigate()` method (called on card tap), read `purchasingEnabledProvider`
before pushing `LocalMockupPreviewScreen`:

```dart
void _navigate() {
  final enabled = ref.read(purchasingEnabledProvider);
  if (!enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The store is temporarily unavailable. Check back soon.'),
      ),
    );
    return;
  }
  // existing push logic...
}
```

Apply same guard to:
- `MerchOptionCard._navigate()`
- `PulseMerchOptionCard._navigate()` (or equivalent)
- `AchievementMerchOptionCard._navigate()`
- `TravelStoryScreen` → merch CTA
- Any "Design your own" entry point

### T7 — Set up Remote Config parameter in Firebase Console

One-time manual step (document as deployment instruction):

1. Open [Firebase Console → roavvy-prod → Remote Config](https://console.firebase.google.com/project/roavvy-prod/remoteconfig)
2. Add parameter: `purchasing_enabled`, type `Boolean`, default value `true`
3. Publish

To disable purchasing: set `purchasing_enabled = false`, publish.
To re-enable: set `purchasing_enabled = true`, publish.

Changes propagate to active users within ~60 seconds (next foreground resume fetch).

---

## File Map

```
apps/mobile_flutter/
  pubspec.yaml                                    EDIT — add firebase_remote_config
  lib/main.dart                                   EDIT — call initialise()
  lib/app.dart                                    EDIT — refresh on resume
  lib/core/services/remote_config_service.dart    NEW
  lib/core/providers/remote_config_providers.dart NEW
  lib/features/merch/merch_option_list_widgets.dart EDIT — gate _navigate()
  (and other merch entry-point widgets)
```

---

## ADR

**ADR-158: Firebase Remote Config for purchase killswitch**

- Chose Remote Config over Firestore flag because Remote Config is designed
  for exactly this use case: low-latency, cached, offline-safe feature flags.
- Default `true` (fail-open) ensures a network blip never blocks sales.
- Gate at catalog tap-through (not at the Approve button or inside the purchase
  screen) so the UX is clean and early.
- No server-side enforcement needed — this is a UX-level killswitch for managed
  outages, not a security gate.

---

## Definition of Done

- [ ] `firebase_remote_config` added to `pubspec.yaml`
- [ ] `RemoteConfigService.initialise()` called before `runApp`
- [ ] Config refreshed on foreground resume
- [ ] `purchasingEnabledProvider` accessible via Riverpod
- [ ] All merch catalog entry points check the flag before navigating
- [ ] When disabled: SnackBar shown, no navigation to purchase flow
- [ ] When enabled: no change to existing UX
- [ ] `flutter analyze` — no new warnings
- [ ] `purchasing_enabled` parameter created in Firebase Console (roavvy-prod)
- [ ] Manually tested: toggle off → store blocked; toggle on → store works
- [ ] Works correctly when app is offline (defaults to `true`)

**Phase:** Infrastructure / Ops
**Depends on:** M157 (merch pipeline must be stable before adding a killswitch)
