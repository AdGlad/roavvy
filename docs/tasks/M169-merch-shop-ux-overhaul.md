# M169 — Merch Shop UX Overhaul

**Status:** `complete`
**Created:** 2026-06-27
**Completed:** 2026-06-28

---

## Overview

Three interconnected UX problems in the merch purchase flow:

1. The "Design a shirt" country-select screen bypasses the new design carousel
2. The design carousel is too small to evaluate artwork quality
3. The Shop tab is confusing — its purpose and structure are unclear

---

## Tasks

### 1. Fix country-select entry point to use carousel

**File:** `merch_design_entry_screen.dart`

When the user taps "Design with N countries →" in `MerchDesignEntryScreen`, it
navigates directly to `LocalMockupPreviewScreen`, bypassing the
`ShopCollectionOptionScreen` carousel introduced in M168.

**Change:** Replace the `LocalMockupPreviewScreen` push with a
`ShopCollectionOptionScreen` push, passing the selected codes, all codes, trips,
and the top-ranked template as `featuredTemplate`.

Remove the async title generation call that no longer serves a purpose in this path
(title is generated later inside `LocalMockupPreviewScreen` when artwork is rendered).

```
Before: Country select → LocalMockupPreviewScreen
After:  Country select → ShopCollectionOptionScreen (carousel) → LocalMockupPreviewScreen
```

---

### 2. Full-screen design carousel

**Files:** `shop_collection_option_screen.dart`, `merch_option_list_widgets.dart`,
`achievement_merch_option_screen.dart`, `pulse_merch_option_screen.dart`

The current `MerchOptionAlternativesStrip` shows thumbnails at 80×100 px in a
132 px strip. Artwork is too small to evaluate design quality at this stage.

**Change:** Replace the horizontal thumbnail strip with a full-width paged
`PageView` carousel.

- Each page shows one design option at ~70% screen width, full artwork preview
- Featured option (index 0) shown first, gold border retained
- Left/right edges of adjacent cards visible to signal swipeability
- Label + description below each card
- Existing `_AlternativeThumb` generation logic (artwork bytes, mockup painter)
  reused; only the layout shell changes
- Page indicator dots below the carousel
- Tapping a card navigates to `LocalMockupPreviewScreen` (same as today)

Apply the new layout in `ShopCollectionOptionScreen`,
`AchievementMerchOptionScreen`, and `PulseMerchOptionScreen` — all three share
the same carousel entry point.

---

### 3. Shop screen redesign — collections grid

**Files:** `merch_shop_screen.dart`, `widgets/merch_collections_section.dart`,
`widgets/merch_ready_to_design_section.dart`, `widgets/merch_identity_header.dart`

**Current problem:** The screen has four sections (identity header, design banner,
"Ready to design" horizontal cards, "Your Collections" vertical list) that
overlap in purpose. Users don't understand what to do or why the screen exists.

**The screen's actual job:** Give users a single place to start a design from any
country scope they care about.

**Change:** Replace the multi-section layout with a single unified collections
grid.

- Remove `MerchReadyToDesignSection` and `MerchIdentityHeader` — their content
  is absorbed into the grid
- Keep `_DesignEntryBanner` as the header CTA ("Design a shirt from scratch")
- Replace `MerchCollectionsSection` with a 2-column grid of collection cards
- Each card: large emoji, bold label, country count subtitle, subtle "→" indicator
- Collections generated from the same logic as today (all countries, this year,
  continents ≥3 countries, most recent achievement) — no change to data layer
- Tapping a card → `ShopCollectionOptionScreen` with that collection's
  `featuredTemplate` (same as today, just from a grid card instead of a list row)
- Remove `MerchOrdersScreen` icon from AppBar if orders are surfaced elsewhere;
  keep Cart icon

**Grid card design:**
```
┌─────────────────┐
│                 │
│       🌍        │
│                 │
│  All Countries  │
│  47 countries   │
│                 │
└─────────────────┘
```

---

## Definition of Done

- [ ] Country select "Design with N countries →" navigates to carousel, not
      directly to mockup preview
- [ ] Design carousel uses full-width `PageView` on all three entry screens
      (achievement, pulse, shop collection)
- [ ] Shop tab shows a single 2-column collection grid; "Ready to design" and
      identity header sections removed
- [ ] `flutter analyze` reports no new issues
- [ ] Manual test: Shop → collection card → carousel → design option → mockup
      preview
- [ ] Manual test: Achievement unlock → carousel → design option → mockup
      preview
