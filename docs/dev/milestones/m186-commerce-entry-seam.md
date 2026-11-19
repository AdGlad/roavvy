# M186 — One seam for every commerce entry point

**Phase:** Free Launch (M184–M189)
**Depends on:** M184
**Status:** Todo
**Primary target:** `features/commerce_entry/` (new) and the ~15 call sites below

---

## 1. Why this exists

Commerce screens are reached from 13 files outside `features/merch/`, each with its own
`Navigator.push`. Wrapping 13 call sites in `if (flag)` hides them today, but the next CTA
someone adds will skip the check. The aim is a single seam that every route goes through, plus
a test that fails the build if a route bypasses it.

## 2. Design

- **`CommerceEntry`** (`lib/features/commerce_entry/commerce_entry.dart`) is the **only** library
  outside `features/merch/` and `features/studio_v2*/` allowed to import their screens. It
  exposes:
  - `bool isAvailable(WidgetRef)`;
  - typed openers (`openStudio`, `openAchievementMerch`, `openPulseMerch`, `openCountryMerch`,
    `openCardPrint`, `openOrders`, …), which `assert`/no-op when commerce is off.
- **`CommerceGate` widget** builds its child only when commerce is on, otherwise
  `SizedBox.shrink()`. Use it for buttons, banners, cards and labels.
- **Hide, never disable.** No greyed-out buttons and no "Coming soon" tiles in the app.
  (App Review 2.1 rejects placeholder or incomplete features.) Sections that end up empty
  collapse.

## 3. Call-site sweep (commerce off → hidden)

| File | Entry point |
|---|---|
| `cards/card_generator_screen.dart` | "Print your card" → `LocalMockupPreviewScreen`. Card *sharing* stays. |
| `cards/card_editor_screen.dart` | push to `LocalMockupPreviewScreen` |
| `memory/memory_reveal_sheet.dart` | "Print on a t-shirt" |
| `scan/achievement_unlock_sheet.dart` | "Design your merch" |
| `scan/scan_summary_screen.dart` | "Get a poster with your new discoveries →". Travel Story stays. |
| `stats/widgets/achievement_gallery.dart` | achievement → merch option screen |
| `stats/widgets/merch_moments_section.dart` | whole section |
| `stats/widgets/travel_progress_hero.dart` | merch CTA |
| `stats/widgets/next_achievements_carousel.dart` | "Unlocks Flag Grid Tee" labels |
| `travel_timeline/trip_detail_sheet.dart` | two `MerchCountrySelectionScreen` pushes |
| `globe_replay/replay_summary_screen.dart` | "Create T-Shirt" |
| `merch/travel_story_screen.dart` | merch CTA at the end of the story. The story itself is free and stays (reached from scan summary and Year in Review). |
| `settings/privacy_account_screen.dart` | "Orders" row |
| `merch/merch_shop_screen.dart` | "Designed for you" Studio V2 card (unreachable once the tab is gone; gate it anyway) |

Any `CardTemplateType` that exists **only** for merch (e.g. `frontRibbon`) is removed from the
card picker when commerce is off. Check each one: the shareable card templates stay.

## 4. Guard tests

- **Architecture test** (`test/architecture/commerce_boundary_test.dart`): scans `lib/` and fails
  if any file outside `features/merch/`, `features/studio_v2*/` and `features/commerce_entry/`
  imports a `*_screen.dart` or `*_sheet.dart` from merch/studio_v2. Dev entrypoints
  (`main_studio_v2.dart`, `main_mockup_lab.dart`) are allow-listed.
- **Widget sweep test**, with commerce off, for each host screen above: pump it with fixture data
  and assert that none of the strings `t-shirt|tee|merch|poster|print your|shop|order` and none
  of the known CTA keys are found.

## 5. Acceptance

- [ ] With commerce off, a full manual walk of the app (scan → summary → story → map → trip
      sheet → stats → achievements → memory reveal → cards → replay → year in review →
      settings) shows no route to generating or buying a garment.
- [ ] Architecture and sweep tests are green and run in CI.
- [ ] With commerce on, behaviour is identical to today.
