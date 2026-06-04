# M143 — Achievement Merch CTA Upgrade & Merch Moments Reframe

## Goal

Make the achievement unlock the highest-converting moment in the app. Currently the
path from "achievement unlocked" to "design a shirt" requires navigating to the Stats
screen and finding the Merch Moments section. This milestone puts a direct one-tap CTA
on the achievement itself and upgrades the `MerchMomentsSection` with emotional
language and better visual design.

---

## Phases & Tasks

### T1 — Direct merch CTA on achievement detail view

**File:** `apps/mobile_flutter/lib/features/achievements/` (identify the achievement
detail widget — likely `achievement_detail_sheet.dart` or the achievement card in the
achievements tab)

For any `Achievement` where `a.merch != null`, add a prominent CTA button:

```
┌─────────────────────────────────────────┐
│  [achievement icon] Continent Explorer  │
│  Visited 5 countries in Europe          │
│  ✦ Unlocked                             │
│                                         │
│  [Design your Continent Explorer shirt] │ ← ADD THIS
└─────────────────────────────────────────┘
```

Button style: `FilledButton` using `RoavvyColours.roavvyCoral` as background.

On tap, navigate to `AchievementMerchOptionScreen(achievement: achievement)` — the
same screen already used by the Merch Moments section.

Show this button only when the achievement is unlocked (`unlockedById.containsKey(a.id)`).

### T2 — Merch CTA on achievement unlock celebration

**File:** `apps/mobile_flutter/lib/features/achievements/` (celebration overlay or
sheet shown immediately after unlocking an achievement — likely `DiscoveryOverlay` or
a dedicated achievement celebration widget)

When an achievement with `merch != null` is unlocked, add a secondary action below
the primary "Back to map" / "Celebrate" button:

```
[Back to my map]
[Design your achievement shirt →]   ← secondary, outlined button
```

This is the highest-intent moment — the user has just unlocked. Do not make this CTA
the primary action (it should not interrupt the celebration), but make it discoverable.

### T3 — Upgrade `MerchMomentsSection` visual and copy

**File:** `apps/mobile_flutter/lib/features/stats/widgets/merch_moments_section.dart`

**Current:**
- Section header: "Merch Moments" in `titleSmall`
- Each tile: trophy icon + "You unlocked X" + "Create a Flag Grid Tee" + "Create" button

**Target:**
- Section header: "Design from your achievements" (clearer intent)
- Each tile redesigned with more visual impact:

```
┌──────────────────────────────────────────┐
│  🌍  Continent Explorer                  │
│      Visited 5 countries in Europe       │
│                                          │
│  [Design your explorer shirt →]          │
└──────────────────────────────────────────┘
```

Replace `_productLabel()` with `_merchCta()`:

```dart
String _merchCta(MerchTriggerType type) => switch (type) {
  MerchTriggerType.flagGrid     => 'Design your flag collection shirt',
  MerchTriggerType.passportStamp => 'Design your passport collection shirt',
  MerchTriggerType.timeline     => 'Design your journey timeline shirt',
  MerchTriggerType.country      => 'Design your country shirt',
  MerchTriggerType.milestone    => 'Design your milestone shirt',
};
```

Replace the trophy `Icon` with the achievement's emoji when available, or a
coloured icon using `RoavvyColours.roavvyGold`.

Replace the small `FilledButton.tonal` with a full-width `OutlinedButton` style CTA
that reads as the action, not a "Create" label.

Show up to 5 achievements (currently 3) to increase surface area.

### T4 — Tests

- Widget test: achievement detail shows merch CTA when `achievement.merch != null`
  and achievement is unlocked.
- Widget test: merch CTA not shown when achievement is locked.
- Widget test: `MerchMomentsSection` shows updated CTA labels.

---

## File Map

```
apps/mobile_flutter/lib/features/achievements/
  [achievement_detail_sheet.dart or equivalent]  EDIT — add merch CTA button
  [achievement_unlock_overlay or similar]         EDIT — add secondary merch action

apps/mobile_flutter/lib/features/stats/widgets/
  merch_moments_section.dart                      EDIT — copy + visual upgrade

apps/mobile_flutter/test/features/achievements/
  achievement_merch_cta_test.dart                 NEW  — 2 widget tests
apps/mobile_flutter/test/features/stats/
  merch_moments_section_test.dart                 NEW  — 1 widget test
```

> Note: Identify the exact file paths for achievement detail and unlock overlay before
> starting T1/T2. The achievement feature area is not listed in the main merch files
> reviewed — a short code exploration is needed first.

---

## Definition of Done

- [ ] Achievement detail view shows "Design your [X] shirt" CTA for unlocked
      achievements with `merch != null`.
- [ ] Achievement unlock celebration shows secondary merch CTA.
- [ ] `MerchMomentsSection` shows up to 5 achievements with emotional CTA language.
- [ ] `_productLabel` generic names replaced with action-oriented copy.
- [ ] 3 widget tests pass.
- [ ] `flutter analyze` — no new warnings.
- [ ] No change to `AchievementMerchOptionScreen` or the merch option flow.

**Phase:** 27 — Merch UX
**Depends on:** M139
