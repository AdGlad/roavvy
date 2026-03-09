# Navigation

## Mobile App Structure

```
Tab bar (persistent)
├── Map          — world map; primary destination
├── Countries    — list view of all visited countries (accessible alternative to map)
├── Achievements — achievement grid and progress
└── Profile      — settings, privacy, account
```

The tab bar is always visible. No nested tab bars.

---

## Screen Hierarchy

```
Map (tab root)
├── Country detail sheet (modal, bottom sheet)
│     ├── Edit visit (push)
│     └── Delete (confirm dialog → dismiss sheet)
├── Add country (modal, full screen)
└── Scan in progress (modal, full screen, non-dismissable during scan)
      └── Scan complete summary (replaces scan screen)

Countries (tab root)
└── Country detail sheet (same as above)

Achievements (tab root)
└── Achievement detail sheet (modal, bottom sheet)
      └── Share achievement (iOS share sheet)

Profile (tab root)
├── Privacy settings (push)
│     ├── Delete travel history (confirm dialog)
│     └── Delete account (confirm dialog × 2)
├── Sharing cards (push)
│     └── Sharing card detail (push)
│           └── Revoke card (confirm dialog)
└── About / legal (push)
```

---

## Navigation Principles

**Bottom sheet for contextual detail.** Country and achievement detail sheets are bottom sheets — they keep the map visible behind them. Full-screen modals are reserved for flows that require full attention (scan progress, add country).

**Push for linear settings flows.** Settings screens use standard navigation push, not modals, so the user always has a back button.

**No deep linking into authenticated routes.** The only publicly deep-linkable route is `/share/[token]` on web. App deep links (for share → app install → map) are a Phase 5 concern.

**Tab state is preserved.** Navigating away from Map and returning restores the previous position. The map does not reset to a default view.

---

## Web App Structure

```
/                    Landing / marketing (unauthenticated)
/(app)/map           Authenticated travel map
/(app)/achievements  Achievements (authenticated)
/share/[token]       Public sharing card (no auth required, SSR)
/shop                Merchandise (no auth required)
/shop/[product]      Product detail
```

Web navigation is standard top-nav for authenticated views. Sharing and shop pages are standalone with minimal chrome — optimised for sharing, not for app navigation.

---

## Gestures (Mobile)

| Gesture | Behaviour |
|---|---|
| Tap country on map | Opens country detail sheet |
| Long press country on map | No action (keep it simple) |
| Pinch / pan on map | Standard map zoom and pan |
| Swipe down on sheet | Dismisses bottom sheet |
| Swipe back | Standard iOS swipe-back navigation on push screens |
