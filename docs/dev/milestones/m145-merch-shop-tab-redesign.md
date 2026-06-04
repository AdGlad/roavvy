# M145 — Merch Shop Tab Redesign: Personal Discovery Surface

## Goal

Redesign the Shop tab from a cart/orders container into a personalised merch discovery
surface. Every visit to the Shop tab should surface relevant design ideas based on the
user's current travel data — without requiring a Memory Pulse or Achievement trigger.

The tab becomes a destination worth opening, not a staging area for items created elsewhere.

---

## Phases & Tasks

### T1 — `MerchIdentityHeader` widget

**New file:** `apps/mobile_flutter/lib/features/merch/widgets/merch_identity_header.dart`

A compact header shown at the top of the Shop tab:

```
┌────────────────────────────────────────────┐
│  🌍  Globetrotter                          │
│  42 countries · 4 continents · since 2019  │
└────────────────────────────────────────────┘
```

Data sources:
- Travel identity: `TravelIdentityInfo.forContext()` using country and continent count
  (already exists in `travel_identity.dart`, used by `AchievementMerchOptionScreen`).
- Country count: `effectiveVisitsProvider`.
- Continent count: `continentCountProvider`.
- "Since [year]": earliest `firstSeen` from `effectiveVisitsProvider`.

Style: dark navy card (`RoavvyColours.backgroundDark`) with gold identity name,
identity emoji at 28px, subtle travel stats in `Colors.white54`.

### T2 — `MerchReadyToDesignSection` widget

**New file:** `apps/mobile_flutter/lib/features/merch/widgets/merch_ready_to_design_section.dart`

A horizontally scrollable row of 2–3 pre-generated design recommendations:

```
Ready to design
─────────────────────────────────────────────────
[card]           [card]           [card]
The Grand Tour   Europe 2024      25 Countries
All your travels This year        Achievement

[Design →]       [Design →]       [Design →]
─────────────────────────────────────────────────
```

Each card is an `_InspiredDesignCard`:
- Shows a local shirt mockup rendered from the recommendation's country set
- Title, scope label
- "Design →" button navigating to `LocalMockupPreviewScreen`

**Recommendations algorithm** (client-side, no server call):

Generate up to 3 options using `MerchTemplateRanker` and `MerchContext`:
1. Most recently unlocked merch-eligible achievement → top-ranked template for its scope.
2. This-year travel → all countries visited in current year, top-ranked template.
3. All-time collection → all countries, top-ranked template.

Deduplicate by country set — if options 1 and 2 resolve to the same country set, skip 2
and use a continent-scoped option instead.

This section loads async. Show 3 shimmer placeholders while loading.

### T3 — `MerchCollectionsSection` widget

**New file:** `apps/mobile_flutter/lib/features/merch/widgets/merch_collections_section.dart`

A vertically stacked list of collection chips:

```
Your Collections
─────────────────────────────────────────────────
[🌍  All Countries — 42]         [→]
[📅  2024 Travels — 8 countries] [→]
[🇪🇺  Europe — 18 countries]    [→]
[🏆  Continent Explorer]         [→]
─────────────────────────────────────────────────
```

Collections are generated dynamically:

| Collection | Condition | Countries used |
|---|---|---|
| All Countries | Always shown | All codes |
| [Year] Travels | If current year has travel | Year-filtered codes |
| [Continent] | If ≥3 countries in continent | Continent-filtered codes |
| [Achievement Name] | Most recent unlocked merch achievement | Achievement-scoped codes |

Tapping a collection row navigates to `PulseMerchOptionScreen` with the appropriate
country/trip set, or directly to `MerchDesignEntryScreen` (M140) pre-filtered to
that collection's codes.

Maximum 5 collections shown. No "see all" needed — keep the list compact.

### T4 — Restructure `MerchShopScreen`

**File:** `apps/mobile_flutter/lib/features/merch/merch_shop_screen.dart`

Replace the current two-tab structure (Cart + My Collection) with a single-scroll
`CustomScrollView` containing:

```
SliverToBoxAdapter: MerchIdentityHeader
SliverToBoxAdapter: _DesignEntryBanner (from M140 — "Design a shirt")
SliverToBoxAdapter: MerchReadyToDesignSection ("Ready to design")
SliverToBoxAdapter: MerchCollectionsSection ("Your Collections")
SliverToBoxAdapter: section header "Saved Designs"
SliverList: cart items (MerchCartItemCard from M141)
SliverToBoxAdapter: section header "My Collection"
SliverList: order history (compact, max 5 shown with "See all" link)
```

Remove the `DefaultTabController` / `TabBar` / `TabBarView` structure.

The Cart and Orders content moves inline into the scroll. Both sections remain fully
functional — the tab structure simply becomes a scrollable page.

The "My Collection" section in the scroll shows the 5 most recent orders. A "See all"
link at the bottom navigates to the full `MerchOrdersScreen`.

### T5 — Tests

- Widget test: `MerchIdentityHeader` renders identity name and stats from mock providers.
- Widget test: `MerchReadyToDesignSection` shows 3 shimmer cards while loading.
- Widget test: `MerchCollectionsSection` shows the correct number of dynamic collections.
- Widget test: `MerchShopScreen` renders all sections in scroll order.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_shop_screen.dart                              EDIT — single scroll layout
  widgets/
    merch_identity_header.dart                        NEW
    merch_ready_to_design_section.dart                NEW
    merch_collections_section.dart                    NEW

apps/mobile_flutter/test/features/merch/
  merch_shop_screen_redesign_test.dart                NEW  — 4 widget tests
```

---

## ADR-177

**Shop tab redesigned as single-scroll discovery surface (M145)**

Decision: Remove the Tab-based Cart/Orders structure from `MerchShopScreen` and
replace with a single `CustomScrollView` that stacks identity, recommendations,
collections, saved designs, and recent orders. The Cart and Orders content is
preserved inline — not removed. The motivation is that the tab structure encouraged
treating the Shop as two separate utility screens rather than a unified personal
gallery. The new layout makes discovery content dominant while keeping transactional
content (cart, history) accessible below it.

Status: Accepted

---

## Definition of Done

- [ ] `MerchShopScreen` renders as a single scroll with all sections in order.
- [ ] `MerchIdentityHeader` shows live travel identity, country count, continent count.
- [ ] `MerchReadyToDesignSection` generates 2–3 personalised recommendations using
      `MerchTemplateRanker`.
- [ ] `MerchCollectionsSection` generates 2–5 dynamic collections.
- [ ] Saved designs (cart items) appear inline in the scroll.
- [ ] Recent orders (up to 5) appear inline with a "See all" link.
- [ ] All navigation paths from the old tab structure (cart items, orders) are preserved.
- [ ] 4 widget tests pass.
- [ ] `flutter analyze` — no new warnings.

**Phase:** 27 — Merch UX
**Depends on:** M141, M142, M143, M144
