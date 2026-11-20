# M185 — App shell without a Shop

**Phase:** Free Launch (M184–M189)
**Depends on:** M184
**Status:** Done
**Primary target:** `features/shell/main_shell.dart` · `core/notification_service.dart`

---

## 1. Why this exists

The Shop is tab index 3 of 5 (Map · Journey · Stats · Shop · Play). A cart badge sits on it,
and notifications jump to tabs by **raw integer** (`payload: 'tab:3'`). If we remove the tab,
Play moves to index 3, so every integer-based jump breaks without any error. Tabs need names
before one of them can go.

## 2. Tasks

- **T1** Add an `AppTab` enum (`map, journey, stats, shop, play`).
  - `visibleTabs` is computed from `commerceEnabledProvider`.
  - The `IndexedStack`, `NavigationBar`/`NavigationRail` and the selected index all come from
    `visibleTabs`.
  - Remove the int-to-screen `switch` (`main_shell.dart:316`).
- **T2** Notification payloads become names (`tab:stats`, `tab:shop`).
  - `getLaunchTab()`/`pendingTabIndex` resolve a name to a *visible* tab.
  - A hidden tab falls back to Map.
  - Update `_kShopTab`/`_kStatsTab`/`_kScanTab` and the ADR-052 tab contract doc comment.
- **T3** When commerce is off, `notifyExclusiveDesignUnlocked` is a no-op. The scan-time
  exclusive-design unlock (`scan_screen.dart:~1608`, `kMerchExclusiveDesigns`) is skipped:
  nothing is recorded or announced.
- **T4** Don't watch `merchCartCountProvider` when commerce is off, so no cart reads happen at
  startup.
- **T5** Tests:
  - commerce off → 4 tabs, no Shop or cart badge, `tab:shop` opens Map, `tab:stats` opens
    Stats;
  - commerce on → today's 5 tabs, unchanged.

## 3. Acceptance

- [x] Commerce off: 4 tabs on phone and tablet (rail) layouts, and no cart badge.
- [x] Every notification lands on the right tab in both modes.
- [x] Commerce on: no change from today (existing shell tests still pass).
