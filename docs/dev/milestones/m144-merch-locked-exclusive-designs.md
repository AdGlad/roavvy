# M144 — Merch Locked & Unlocked Exclusive Designs

## Goal

Show users designs that are "almost unlocked" — exclusive shirt designs tied to
achievement milestones that become available once the user reaches the next target.

A user at 40 countries sees the "Half the World" design with a lock overlay:
"10 more countries to unlock this design." This creates goal-directed travel and
positions Roavvy as a platform where real-world achievements unlock real rewards.

---

## Phases & Tasks

### T1 — `MerchExclusiveDesign` data model

**New file:** `apps/mobile_flutter/lib/features/merch/merch_exclusive_design.dart`

```dart
/// A design that is locked behind an achievement milestone.
class MerchExclusiveDesign {
  const MerchExclusiveDesign({
    required this.id,
    required this.label,           // e.g. "Half the World"
    required this.description,     // e.g. "Visit 50 countries"
    required this.unlockCondition, // e.g. MerchUnlockCondition.countries(50)
    required this.template,
    required this.emoji,           // displayed on lock screen
  });

  final String id;
  final String label;
  final String description;
  final MerchUnlockCondition unlockCondition;
  final CardTemplateType template;
  final String emoji;

  bool isUnlocked(MerchUnlockContext ctx) => unlockCondition.isSatisfied(ctx);

  /// Countries still needed to unlock, or 0 if already unlocked.
  int remaining(MerchUnlockContext ctx) => unlockCondition.remaining(ctx);
}

/// What a user needs to reach to unlock the design.
sealed class MerchUnlockCondition {
  const MerchUnlockCondition();
  bool isSatisfied(MerchUnlockContext ctx);
  int remaining(MerchUnlockContext ctx);
}

class CountryCountCondition extends MerchUnlockCondition {
  const CountryCountCondition(this.target);
  final int target;
  @override bool isSatisfied(MerchUnlockContext ctx) => ctx.countryCount >= target;
  @override int remaining(MerchUnlockContext ctx) => (target - ctx.countryCount).clamp(0, target);
}

class ContinentCountCondition extends MerchUnlockCondition {
  const ContinentCountCondition(this.target);
  final int target;
  @override bool isSatisfied(MerchUnlockContext ctx) => ctx.continentCount >= target;
  @override int remaining(MerchUnlockContext ctx) => (target - ctx.continentCount).clamp(0, target);
}

class MerchUnlockContext {
  const MerchUnlockContext({
    required this.countryCount,
    required this.continentCount,
  });
  final int countryCount;
  final int continentCount;
}
```

Define the catalogue of exclusive designs in a const list:

```dart
const kMerchExclusiveDesigns = [
  MerchExclusiveDesign(
    id: 'half_the_world',
    label: 'Half the World',
    description: 'Visit 50 countries',
    unlockCondition: CountryCountCondition(50),
    template: CardTemplateType.passport,
    emoji: '🌍',
  ),
  MerchExclusiveDesign(
    id: 'global_citizen',
    label: 'Global Citizen',
    description: 'Visit all 6 continents',
    unlockCondition: ContinentCountCondition(6),
    template: CardTemplateType.badge,
    emoji: '🌐',
  ),
  MerchExclusiveDesign(
    id: 'century_club',
    label: 'The Century Club',
    description: 'Visit 100 countries',
    unlockCondition: CountryCountCondition(100),
    template: CardTemplateType.grid,
    emoji: '💯',
  ),
  MerchExclusiveDesign(
    id: 'world_explorer',
    label: 'World Explorer',
    description: 'Visit 25 countries',
    unlockCondition: CountryCountCondition(25),
    template: CardTemplateType.timeline,
    emoji: '🧭',
  ),
];
```

### T2 — `MerchLockedDesignCard` widget

**File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`

New widget `MerchLockedDesignCard`:

```
┌──────────────────────────────────────────┐
│  [blurred/dimmed shirt silhouette]       │  ← placeholder, not a real render
│  🔒  [emoji] [label]                    │
│  [description]                           │
│  ▓▓▓▓▓▓▓▓░░░░░░ 40/50 countries        │  ← LinearProgressIndicator
│  10 more countries to unlock            │
└──────────────────────────────────────────┘
```

If the design IS unlocked (condition satisfied), render with a gold border and
"✦ Unlocked for you" badge instead of the lock. Tapping an unlocked design navigates
to `LocalMockupPreviewScreen` with the appropriate country set.

For locked designs: tapping shows a `SnackBar`:
"Visit [n] more countries to unlock this design."

### T3 — Surface in option screens

**File:** `apps/mobile_flutter/lib/features/merch/pulse_merch_option_screen.dart`
**File:** `apps/mobile_flutter/lib/features/merch/achievement_merch_option_screen.dart`

When "See all styles" is expanded (M139 added this disclosure), append a section
below the full list:

```
──────────────────────
EXCLUSIVE DESIGNS
──────────────────────
[MerchLockedDesignCard] ← show 1–2 near-miss designs
```

"Near-miss" = designs where `remaining(ctx) > 0 && remaining(ctx) <= 15`. This
means a user who has visited 42 countries sees the 50-country "Half the World"
design (8 away) but not the 100-country "Century Club" (58 away — too far).

Also surface any already-unlocked exclusive designs (regardless of "near-miss"
threshold) so users can design them if they have not yet done so.

Provide `MerchUnlockContext` from existing providers:
- `countryCount`: `effectiveVisitsProvider.length`
- `continentCount`: `continentCountProvider`

### T4 — Notification when a new exclusive design unlocks

**File:** `apps/mobile_flutter/lib/core/` — notification service

When the user scans new photos and their country count crosses a milestone that unlocks
an exclusive design, trigger a local notification:

```
"You unlocked the 'Half the World' design. Design your shirt."
```

Tap routes to `AchievementMerchOptionScreen` or `LocalMockupPreviewScreen` with the
milestone country set.

Check for unlocked exclusive designs in the scan completion handler, after achievement
evaluation. Only notify once per design (persist notified IDs in `SharedPreferences`).

### T5 — Tests

- Unit test: `CountryCountCondition(50).isSatisfied()` returns correct values.
- Unit test: `remaining()` returns correct countdown.
- Widget test: `MerchLockedDesignCard` shows progress indicator and lock for unsatisfied condition.
- Widget test: `MerchLockedDesignCard` shows "Unlocked" badge for satisfied condition.

---

## File Map

```
apps/mobile_flutter/lib/features/merch/
  merch_exclusive_design.dart             NEW  — data model + kMerchExclusiveDesigns
  merch_option_list_widgets.dart          EDIT — MerchLockedDesignCard widget
  pulse_merch_option_screen.dart          EDIT — exclusive designs section
  achievement_merch_option_screen.dart    EDIT — exclusive designs section

apps/mobile_flutter/lib/core/
  [notification service]                  EDIT — exclusive design unlock notification

apps/mobile_flutter/test/features/merch/
  merch_exclusive_design_test.dart        NEW  — 2 unit + 2 widget tests
```

---

## ADR-176

**Exclusive designs gated by client-side condition evaluation (M144)**

Decision: Exclusive design lock/unlock status is evaluated entirely on the client using
`MerchUnlockContext` derived from existing Riverpod providers. No server-side access
control is applied — a sufficiently motivated user could theoretically bypass the
lock. This is acceptable because: (1) the designs are aspirational motivators, not
paid gated content; (2) the country count data comes from the user's own scan history,
making gaming non-trivial; (3) adding server-side enforcement would require a new
Firebase Function and Firestore read, which is disproportionate complexity for a UX
feature.

Status: Accepted

---

## Definition of Done

- [ ] `kMerchExclusiveDesigns` defines 4 milestone designs.
- [ ] `MerchLockedDesignCard` renders correctly for locked and unlocked states.
- [ ] Near-miss designs (≤15 countries away) appear in the option screens under
      "Exclusive Designs".
- [ ] Unlocked exclusive designs are tappable and navigate to `LocalMockupPreviewScreen`.
- [ ] Unlock notification fires once per design after a qualifying scan.
- [ ] 4 tests pass.
- [ ] `flutter analyze` — no new warnings.

**Phase:** 27 — Merch UX
**Depends on:** M139
