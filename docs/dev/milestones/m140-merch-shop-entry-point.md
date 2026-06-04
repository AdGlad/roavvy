# M140 — Merch Shop Entry Point: Design a Shirt from the Shop Tab

## Goal

Add an intent-driven entry point to the merch design flow directly from the Shop tab.
Currently, the only ways to reach merch are passive (Memory Pulse notification,
Achievement unlock, Stats screen Merch Moments). A user who opens the app with purchase
intent has nowhere to start.

This milestone makes "Design a shirt" actionable at any time from the Shop tab.

---

## Phases & Tasks

### T1 — "Design a Shirt" CTA in the Cart tab

**File:** `apps/mobile_flutter/lib/features/merch/merch_shop_screen.dart`

Add a persistent design CTA to the top of the `_CartTabBody`:

```dart
// Above the cart list (or empty state)
_DesignEntryBanner()
```

`_DesignEntryBanner` is a new private widget in `merch_shop_screen.dart`:

```
┌──────────────────────────────────────────────┐
│  42 countries · 4 continents                  │
│  Ready to design your next shirt?             │
│                          [Design a shirt →]   │
└──────────────────────────────────────────────┘
```

- Read country count and continent count from `effectiveVisitsProvider` and
  `continentCountProvider`.
- Show a loading shimmer while providers are loading; do not block the cart list.
- "Design a shirt →" button calls `_navigateToDesignEntry(context, ref)`.
- The banner always shows — both when the cart is empty and when it has items.
  When the cart is empty it replaces the current empty-state text entirely.
  When the cart has items it appears above the list as a compact header.
- Style: rounded card with a subtle gradient using `RoavvyColours` (coral/gold accent).

### T2 — `MerchDesignEntryScreen` — Country Selection

**New file:** `apps/mobile_flutter/lib/features/merch/merch_design_entry_screen.dart`

A new screen that lets the user choose which countries to design for, then proceeds
to `LocalMockupPreviewScreen`.

Layout:

```
AppBar: "Design a shirt"

[Hero stat: "42 countries · 4 continents"]

Chips (horizontally scrollable):
  [All countries]  [This year]  [Europe]  [Asia]  [Americas]  [Custom]

[Country list with checkboxes — pre-selected per chip]

Bottom bar:
  [Design with X countries →]
```

Implementation:
- Load `effectiveVisitsProvider` for all country codes.
- Load `tripListProvider` for trip data.
- Default selection: "All countries" chip pre-selects all codes.
- "This year" chip filters to current calendar year (same logic as `thisYearCountryCountProvider`).
- Continent chips filter by `kCountryContinent` lookup.
- "Custom" chip: user manually selects/deselects individual countries.
- "Design with X countries →" button navigates to `LocalMockupPreviewScreen` with:
  - `selectedCodes`: the filtered selection
  - `allCodes`: all country codes
  - `trips`: all trips (not filtered — `LocalMockupPreviewScreen` uses them internally)
  - No `artworkImageBytes` / `initialPreset` — screen auto-generates from preset
    using the new country set.

### T3 — Navigation wiring

**File:** `apps/mobile_flutter/lib/features/merch/merch_shop_screen.dart`

```dart
void _navigateToDesignEntry(BuildContext context, WidgetRef ref) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const MerchDesignEntryScreen(),
    ),
  );
}
```

No router changes needed — push via Navigator directly.

### T4 — Tests

- Widget test: `_DesignEntryBanner` renders with country count from mock provider.
- Widget test: "Design a shirt" button navigates to `MerchDesignEntryScreen`.
- Widget test: `MerchDesignEntryScreen` chip selection updates country count in the CTA.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_shop_screen.dart            EDIT — add _DesignEntryBanner, navigation
  merch_design_entry_screen.dart    NEW  — country selection + chip filter UI

apps/mobile_flutter/test/features/merch/
  merch_shop_entry_test.dart        NEW  — 3 widget tests
```

---

## ADR-174

**Merch design entry point in Shop tab (M140)**

Decision: Add a `_DesignEntryBanner` permanently to the Cart tab (not gated behind an
empty cart state) and a new `MerchDesignEntryScreen` for country selection. The existing
`MerchCountrySelectionScreen` was not reused because it is designed for post-card-editor
flows with a different pre-selection model; a new screen avoids coupling.

Status: Accepted

---

## Definition of Done

- [ ] `_DesignEntryBanner` shows in the Cart tab with live country and continent count.
- [ ] Tapping "Design a shirt →" opens `MerchDesignEntryScreen`.
- [ ] `MerchDesignEntryScreen` shows chip filters (All / This year / continents / Custom).
- [ ] Each chip updates the selected country list and the CTA button count.
- [ ] "Design with X countries →" navigates to `LocalMockupPreviewScreen` with correct codes.
- [ ] 3 widget tests pass.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to existing Memory Pulse or Achievement merch entry paths.

**Phase:** 27 — Merch UX
**Depends on:** M139
