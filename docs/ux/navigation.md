# Navigation

## Mobile App Structure

```
Tab bar (persistent)
├── Map          — world map; primary destination
├── Journal      — chronological trip history (list alternative to map)
├── Stats        — aggregate stats + achievement gallery
└── Scan         — photo scanner
```

The tab bar is always visible. No nested tab bars.

Tab order is intentional:
- **Map** anchors the left — it is the hero experience.
- **Journal** and **Stats** are the data exploration tabs — they live in the middle.
- **Scan** sits on the right — it is an action, not a destination. Right-side placement follows iOS conventions for primary actions.

---

## Screen Hierarchy

```
Map (tab root)
├── Country detail sheet (modal, bottom sheet)
│     ├── Trip edit sheet (modal, bottom sheet)
│     └── Delete trip (confirm dialog)
└── Scan in progress (modal, full screen, non-dismissable during scan)
      └── Scan complete summary (replaces scan screen)

Journal (tab root)
└── Country detail sheet (same as Map — reuses existing sheet)

Stats (tab root)
└── [no sub-screens in M17; achievement detail deferred]

Scan (tab root)
└── [self-contained; returns to Map tab on completion]
```

M18 will promote Country Detail to a full-screen page and add Trip Detail. The sheet-based approach is preserved for M17.

---

## Navigation Principles

**Bottom sheet for contextual detail.** Country detail sheets are bottom sheets — they keep the previous screen visible behind them.

**Push for linear settings flows.** Settings screens use standard navigation push, not modals.

**Tab state is preserved.** Navigating away from any tab and returning restores its previous scroll position. The map does not reset to a default view.

**Scan returns to Map.** When a scan completes, the app navigates back to the Map tab automatically. This preserves the "discover what you've done" moment.

---

## Web App Structure

```
/                    Landing / marketing (unauthenticated)
/(app)/map           Authenticated travel map
/share/[token]       Public sharing card (no auth required, SSR)
```

---

## Gestures (Mobile)

| Gesture | Behaviour |
|---|---|
| Tap country on map | Opens country detail sheet |
| Long press country on map | No action (keep it simple) |
| Pinch / pan on map | Standard map zoom and pan |
| Swipe down on sheet | Dismisses bottom sheet |
| Swipe back | Standard iOS swipe-back navigation on push screens |
