# M139 — Merch Option Screen: Lead with One Design

## Goal

Restructure `PulseMerchOptionScreen` and `AchievementMerchOptionScreen` to lead with
a single full-screen featured design recommendation and collapse the remaining options
behind a disclosure. Reduces choice paralysis — the primary conversion gap at the
option selection stage.

**Before:** ~15–20 options with equal visual weight, grouped by template type in a
long scrollable list. The "Best Match" card exists at the top but the full list below
it undermines the recommendation.

**After:** One large featured design dominates the screen. A horizontal strip of
3–4 alternative thumbnail options sits below it. A "See all styles" disclosure reveals
the full list for users who want to browse further.

---

## Phases & Tasks

### T1 — Add `MerchOptionAlternativesStrip` widget

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

New widget: `MerchOptionAlternativesStrip`

A horizontally scrollable row of compact option thumbnails (back-shirt mockup only),
shown below the featured card. Each thumbnail:
- Width: 80px, Height: 100px
- Renders the back-shirt local mockup (same `LocalMockupPainter` as `MerchOptionCard`)
- Shows the template label below the thumbnail in `Colors.white38` at 10px
- Tapping navigates to `LocalMockupPreviewScreen` for that option (same as `MerchOptionCard`)
- Loading state: shimmer placeholder (same dimensions)
- Max 4 alternatives shown (the next 4 ranked options after the featured one)

```dart
class MerchOptionAlternativesStrip extends StatelessWidget {
  const MerchOptionAlternativesStrip({
    super.key,
    required this.options,   // up to 4 PulseMerchOption items
    required this.allCodes,
  });
  ...
}
```

Add a "See all styles" `TextButton` below the strip that expands the full list.

### T2 — Restructure `PulseMerchOptionScreen`

**File:** `apps/mobile_flutter/lib/features/merch/pulse_merch_option_screen.dart`

Change `_buildItems()` to return a structured result rather than a flat list:

```dart
({
  PulseMerchOption featured,
  List<PulseMerchOption> alternatives,  // next 4 after featured
  List<MerchOptionListItem> allItems,   // existing full list
}) _buildOptions(...);
```

Replace the `ListView.builder` with a `CustomScrollView` using `SliverList`:

```
SliverToBoxAdapter: subtitle ("Inspired by France · 2024")
SliverToBoxAdapter: MerchOptionFeaturedCard (featured option)
SliverToBoxAdapter: MerchOptionAlternativesStrip (next 4 options)
SliverToBoxAdapter: "See all styles" TextButton (collapsed by default)
SliverList (shown only when expanded): remaining full option list
```

State: `bool _showAll = false`. Tapping "See all styles" sets `_showAll = true` and
re-renders.

The `MerchOptionFeaturedCard` already exists and renders correctly — no changes needed
to it. The ranked first item from `MerchTemplateRanker` is always the featured option.

### T3 — Restructure `AchievementMerchOptionScreen`

**File:** `apps/mobile_flutter/lib/features/merch/achievement_merch_option_screen.dart`

Apply the same restructuring as T2. The `_CelebrationHeader` (identity emoji, gold
display name, tagline) moves above the `MerchOptionFeaturedCard`:

```
_CelebrationHeader
MerchOptionFeaturedCard (best match for this achievement)
MerchOptionAlternativesStrip (4 alternatives)
"See all styles" TextButton
[full list — collapsed by default]
```

`MerchContext.buildItems()` already produces a list with `MerchOptionFeaturedEntry`
as the first item when a ranked recommendation exists. Extract the featured item and
the next 4 `MerchOptionEntry` items to pass to `MerchOptionAlternativesStrip`.

### T4 — Tests

**File:** `apps/mobile_flutter/test/features/merch/`

- Widget test: `PulseMerchOptionScreen` shows featured card and alternatives strip
  when items list contains a `MerchOptionFeaturedEntry`.
- Widget test: "See all styles" button reveals the full list when tapped.
- Widget test: `MerchOptionAlternativesStrip` renders up to 4 thumbnails.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_option_list_widgets.dart          EDIT — add MerchOptionAlternativesStrip
  pulse_merch_option_screen.dart          EDIT — restructure layout
  achievement_merch_option_screen.dart    EDIT — restructure layout

apps/mobile_flutter/test/features/merch/
  pulse_merch_option_screen_test.dart     NEW  — 3 widget tests
```

---

## ADR-173

**Single featured design entry point for merch option screens (M139)**

Decision: Lead the merch option screens with a single ranked recommendation
(`MerchOptionFeaturedCard`) and expose alternatives via a horizontal strip and
a "See all styles" disclosure. The full existing list remains accessible but is
not shown by default. `MerchTemplateRanker` continues to determine ranking —
no change to ranking logic.

Status: Accepted

---

## Definition of Done

- [ ] Both `PulseMerchOptionScreen` and `AchievementMerchOptionScreen` lead with the
      featured card followed by the alternatives strip.
- [ ] "See all styles" correctly reveals the full options list.
- [ ] Alternatives strip shows up to 4 thumbnails with correct mockup rendering.
- [ ] The `_CelebrationHeader` remains above the featured card in the achievement flow.
- [ ] 3 widget tests pass.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to `MerchTemplateRanker`, `MerchContext`, or checkout navigation.

**Phase:** 27 — Merch UX
**Depends on:** M138
