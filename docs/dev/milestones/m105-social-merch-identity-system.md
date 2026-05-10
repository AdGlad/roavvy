# M105 — Social Merch & Travel Identity System

**Branch:** `milestone/m105-social-merch-identity-system`
**Status:** Complete
**Created:** 2026-05-09

---

Act as Roavvy product architect, senior Flutter engineer, growth product designer, social engagement strategist, and QA reviewer.

Milestone 5 of the achievement-driven merchandise system.

M99–M104 built the shared context layer, achievement-aware generation, continent/region/passport scope, two new template types, and intelligent density-ranked recommendations. M105 transforms the system from "generate a shirt and buy it" into a social, emotional, and viral engagement system. The user should feel: **"I unlocked something special."**

Do not redesign the purchase workflow.
Do not break Memory Pulse.
Do not rewrite Printful integration or checkout.
Extend existing systems rather than replacing them.

---

## Goal

Merchandise should feel like:
- a collectible tied to a travel identity
- an achievement unlock moment
- something worth sharing on social media

Three pillars:
1. **Travel Identity** — users associate with an identity (Passport Collector, Europe Explorer, World Traveller) that influences merch titles, presentation, and emotional framing
2. **Merch Reveal** — the gallery feels like a curated drop with staggered cinematic entry animations and a featured lead card
3. **Social Export** — users can export a polished share card (story or square format) from any merch option for Instagram, WhatsApp, etc.

---

## Scope

**In:**
- `apps/mobile_flutter/lib/features/merch/travel_identity.dart` (new) — `TravelIdentity` model
- `apps/mobile_flutter/lib/features/merch/merch_drop.dart` (new) — `MerchDrop` model + `kCurrentMerchDrops`
- `apps/mobile_flutter/lib/features/merch/merch_share_exporter.dart` (new) — social export pipeline
- `apps/mobile_flutter/lib/features/merch/merch_share_card.dart` (new) — social share card widget
- `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart` — staggered reveal animations; featured card; improved section labels
- `apps/mobile_flutter/lib/features/merch/achievement_merch_option_screen.dart` — celebration header with TravelIdentity label + animated entrance
- `apps/mobile_flutter/lib/features/merch/local_mockup_preview_screen.dart` — "Share This Design" action in toolbar
- `apps/mobile_flutter/lib/features/merch/merch_context.dart` — pass `TravelIdentity` to `MerchStory`; surface featured item; surface active drops
- `apps/mobile_flutter/lib/features/merch/merch_story.dart` — identity-aware copy variants
- `docs/architecture/decisions/_index.md` — ADR-155

**Out:**
- New `CardTemplateType` values
- New product types (hoodies, posters, mugs)
- Checkout, Printful, Shopify changes
- Friend gifting / collaborative merch
- Animated video exports (Travel Wrapped)
- Social feed / public profile
- Web, Android

---

## New Components

### TravelIdentity (enum + model)

```dart
enum TravelIdentity {
  passportCollector,     // ≥10 stamps / stamp milestones
  europeExplorer,        // continent-explorer: Europe
  asiaExplorer,          // continent-explorer: Asia
  africaExplorer,        // continent-explorer: Africa
  americasExplorer,      // continent-explorer: North or South America
  oceaniaExplorer,       // continent-explorer: Oceania
  mediterraneanExplorer, // region: Mediterranean
  islandExplorer,        // region: Southeast Asia (island-heavy)
  hemisphereHopper,      // countries across both N+S hemispheres
  worldTraveller,        // 50+ countries
  globalExplorer,        // continent-breadth achievement (≥4 continents)
  frequentFlyer,         // ≥10 trips
  adventurer,            // generic fallback
}
```

```dart
class TravelIdentityInfo {
  const TravelIdentityInfo({
    required this.identity,
    required this.displayName,
    required this.tagline,
    required this.emoji,
  });
  final TravelIdentity identity;
  final String displayName;  // "Europe Explorer"
  final String tagline;      // "Collecting stamps across the continent"
  final String emoji;        // "🌍"

  static TravelIdentityInfo forContext({
    required Achievement? achievement,
    required List<String> codes,
    required int tripCount,
    required int stampCount,
  });
}
```

**Resolution rules (first match wins):**

| Condition | Identity |
|---|---|
| achievement.continentScope == 'Europe' | europeExplorer |
| achievement.continentScope == 'Asia' | asiaExplorer |
| achievement.continentScope == 'Africa' | africaExplorer |
| achievement.continentScope in {'North America','South America'} | americasExplorer |
| achievement.continentScope == 'Oceania' | oceaniaExplorer |
| achievement.regionScope == 'Mediterranean' | mediterraneanExplorer |
| achievement.regionScope == 'SoutheastAsia' | islandExplorer |
| achievement.merch == MerchTriggerType.passportStamp | passportCollector |
| codes.length >= 50 | worldTraveller |
| achievement.category == continents && progressTarget >= 4 | globalExplorer |
| tripCount >= 10 | frequentFlyer |
| stampCount >= 10 | passportCollector |
| _else_ | adventurer |

**Display names + taglines + emojis:**

| Identity | displayName | tagline | emoji |
|---|---|---|---|
| passportCollector | "Passport Collector" | "Every stamp tells a story" | "📖" |
| europeExplorer | "Europe Explorer" | "Collecting stamps across the continent" | "🇪🇺" |
| asiaExplorer | "Asia Explorer" | "Discovering the ancient and the new" | "🌏" |
| africaExplorer | "Africa Explorer" | "Adventures across the continent" | "🌍" |
| americasExplorer | "Americas Explorer" | "From north to south" | "🌎" |
| oceaniaExplorer | "Oceania Explorer" | "Islands, reefs, and open skies" | "🏝️" |
| mediterraneanExplorer | "Mediterranean Explorer" | "Sun, sea, and stamps" | "☀️" |
| islandExplorer | "Island Explorer" | "Hopping between paradise" | "🏝️" |
| hemisphereHopper | "Hemisphere Hopper" | "Both sides of the world" | "🌐" |
| worldTraveller | "World Traveller" | "Half the world explored" | "✈️" |
| globalExplorer | "Global Explorer" | "Every continent, every story" | "🗺️" |
| frequentFlyer | "Frequent Flyer" | "Always on the move" | "✈️" |
| adventurer | "Adventurer" | "Always somewhere new" | "🧭" |

`MerchContext.fromAchievement` resolves `TravelIdentityInfo` and stores it. `MerchStory.forOption` accepts an optional `TravelIdentityInfo` and may use `displayName`/`tagline` in subtitle copy where appropriate.

---

### MerchDrop (seasonal / special edition concept)

```dart
class MerchDrop {
  const MerchDrop({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,       // e.g. "✨ Featured"
    required this.templates,   // subset of CardTemplateType values
    this.isActive = true,
  });
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final List<CardTemplateType> templates;
  final bool isActive;
}

const List<MerchDrop> kCurrentMerchDrops = [
  MerchDrop(
    id: 'explorer_badge_collection',
    title: 'Explorer Badge Collection',
    subtitle: 'Circular badge designs for every explorer',
    badge: '✦ Collection',
    templates: [CardTemplateType.badge],
  ),
  MerchDrop(
    id: 'passport_series',
    title: 'Passport Series',
    subtitle: 'Classic stamp designs, reimagined',
    badge: '📖 Classic',
    templates: [CardTemplateType.passport],
  ),
];
```

`MerchContext` checks `kCurrentMerchDrops` — if any active drop's templates overlap with the ranked results, those options receive a `dropBadge` label surfaced in the gallery.

---

### MerchShareCard (social export widget)

```dart
class MerchShareCard extends StatelessWidget {
  const MerchShareCard({
    super.key,
    required this.option,
    required this.artworkBytes,
    required this.identity,
    required this.format,
  });

  final PulseMerchOption option;
  final Uint8List artworkBytes;
  final TravelIdentityInfo identity;
  final MerchShareFormat format; // story (9:16) or square (1:1)
}

enum MerchShareFormat { story, square }
```

Renders a polished share card:
- Dark navy background (`#0D1B2A`)
- Artwork centred with subtle shadow
- Identity emoji + displayName in gold at bottom
- `option.title` + `option.description` below artwork
- Roavvy wordmark at bottom-right (small, white/40%)
- Story format: 1080×1920 logical; square: 1080×1080 logical

```dart
class MerchShareExporter {
  static Future<Uint8List> exportToPng(
    BuildContext context,
    PulseMerchOption option,
    Uint8List artworkBytes,
    TravelIdentityInfo identity, {
    MerchShareFormat format = MerchShareFormat.story,
  });
}
```

Uses `CardImageRenderer`'s off-screen OverlayEntry pattern (do not introduce new render infrastructure).

---

### Staggered Gallery Reveal

`MerchOptionCard` gains an `index` constructor parameter. On first build, a `SlideTransition` + `FadeTransition` play with a stagger delay of `index * 80ms`. After the animation completes the card is fully static.

```dart
class MerchOptionCard extends StatefulWidget {
  const MerchOptionCard({
    super.key,
    required this.option,
    required this.allCodes,
    this.index = 0,
  });
  final int index;
}
```

Both `PulseMerchOptionScreen` and `AchievementMerchOptionScreen` pass the item index when building `MerchOptionCard`.

---

### Featured Card

The first non-excluded merch option in a `buildItems()` result is marked as featured via a new `MerchOptionFeaturedEntry` list item type:

```dart
class MerchOptionFeaturedEntry extends MerchOptionListItem {
  MerchOptionFeaturedEntry(this.option);
  final PulseMerchOption option;
}
```

`MerchOptionFeaturedCard` renders a larger card (full width, taller thumbnail pair, bolder typography). The option is still tappable and navigates to `LocalMockupPreviewScreen`.

The list builders in both merch screens check for `MerchOptionFeaturedEntry` and render `MerchOptionFeaturedCard` instead of `MerchOptionCard`.

---

### Achievement Merch Screen — Celebration Header

`AchievementMerchOptionScreen` header gains:
- `TravelIdentityInfo` resolved from the context
- Animated entrance: `ScaleTransition` on the achievement icon (400ms, curve: `easeOutBack`)
- Identity `emoji + displayName` shown in gold below the achievement title
- Identity `tagline` in white/60 below displayName
- A subtle animated shimmer background on the header (gold → transparent, 2s loop, subtle)

---

### Section Label Improvements

Replace `MerchOptionHeaderItem` copy in `_buildFromRankedTemplates` with identity-aware labels:

| Context | Section label (was) | Section label (now) |
|---|---|---|
| First featured option | "Passport" | "✦ Featured For You" |
| Continent-explorer with TravelIdentity | "Flags" | "Your [Identity] Collection" |
| Passport milestone | "Passport" | "Your Stamp Collection" |
| Active MerchDrop template | (template name) | "[drop.badge] [drop.title]" |
| All others | (unchanged) | (unchanged) |

---

### "Share This Design" in LocalMockupPreviewScreen

`LocalMockupPreviewScreen` toolbar gains a share icon button (top-right). Tapping it:
1. Shows a bottom sheet with two options: "Story (9:16)" and "Square (1:1)"
2. Calls `MerchShareExporter.exportToPng(...)` with the current artwork
3. Invokes the system share sheet with the PNG bytes

The artwork bytes are already available in the screen (`_artworkImageBytes`). No regeneration needed.

---

## Tasks

- [ ] 1. Add `TravelIdentity` model
  - **File:** `apps/mobile_flutter/lib/features/merch/travel_identity.dart` (new)
  - **Deliverable:** `TravelIdentity` enum (13 values); `TravelIdentityInfo` data class with `displayName`, `tagline`, `emoji`; `TravelIdentityInfo.forContext({achievement, codes, tripCount, stampCount})` factory matching the resolution rules above; `kTravelIdentityInfo` const map from `TravelIdentity` to `TravelIdentityInfo`
  - **Acceptance:** `forContext(achievement: europeExplorer, ...)` returns `europeExplorer`; `forContext(codes: 50+ countries)` returns `worldTraveller`; `forContext()` with no specific context returns `adventurer`

- [ ] 2. Add `MerchDrop` model and `kCurrentMerchDrops`
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_drop.dart` (new)
  - **Deliverable:** `MerchDrop` data class; `kCurrentMerchDrops` const list with 2 entries (Explorer Badge Collection, Passport Series); `MerchDrop.forTemplate(CardTemplateType t)` helper returning the first active drop whose `templates` contains `t`, or `null`
  - **Acceptance:** `MerchDrop.forTemplate(CardTemplateType.badge)` returns the explorer badge drop; `MerchDrop.forTemplate(CardTemplateType.grid)` returns `null`

- [ ] 3. Integrate `TravelIdentity` into `MerchContext` and `MerchStory`
  - **Files:** `merch_context.dart`; `merch_story.dart`
  - **Deliverable:** `MerchContext` gains `TravelIdentityInfo? identity` field; `fromAchievement` resolves identity via `TravelIdentityInfo.forContext`; `_buildFromRankedTemplates` passes identity to `MerchStory.forOption`; `MerchStory.forOption` gains optional `TravelIdentityInfo? identity` param and uses `identity.tagline` as subtitle override for first-option generic cases where it adds emotional value (e.g. continent-explorer badge subtitle becomes the identity tagline); `PulseMerchOption` unchanged
  - **Acceptance:** `MerchContext.fromAchievement(achievement: europeExplorer, ...).identity.displayName` == `"Europe Explorer"`; badge option for Europe Explorer gets subtitle matching identity tagline

- [ ] 4. Add `MerchOptionFeaturedEntry` and `MerchOptionFeaturedCard`; update `_buildFromRankedTemplates` and section labels
  - **Files:** `merch_option_list_widgets.dart`; `merch_context.dart`
  - **Deliverable:** `MerchOptionFeaturedEntry` list item type; `MerchOptionFeaturedCard` widget (larger card: `kMerchFeaturedThumbW = 88`, `kMerchFeaturedThumbH = 112`, bolder title `fontSize: 15`, description `fontSize: 12`, gold border `Color(0x33E8C84A)`); `_buildFromRankedTemplates` emits `MerchOptionFeaturedEntry` for the first non-excluded option; drop badge prefix applied to section header label when `MerchDrop.forTemplate(template) != null`; identity-aware section label for continent-explorer first section ("Your [displayName] Collection")
  - **Acceptance:** First item in `buildItems()` result (after header) is a `MerchOptionFeaturedEntry`; subsequent items are `MerchOptionEntry`; featured card renders visually distinct from standard card

- [ ] 5. Staggered reveal animations in `MerchOptionCard`
  - **File:** `merch_option_list_widgets.dart`
  - **Deliverable:** `MerchOptionCard` gains `index` param (default 0); `_MerchOptionCardState` sets up a `SingleTickerProviderStateMixin` `AnimationController` (duration 350ms); `CurvedAnimation` with `Curves.easeOutCubic`; `SlideTransition` (begin: `Offset(0, 0.12)`, end: `Offset.zero`) wrapping a `FadeTransition` on the card; starts after `Duration(milliseconds: index * 80)`; both `PulseMerchOptionScreen` and `AchievementMerchOptionScreen` pass item index
  - **Acceptance:** Cards animate in sequentially (not all at once); animation is subtle (12% vertical slide); no animation regression on Memory Pulse screen

- [ ] 6. Enhance `AchievementMerchOptionScreen` celebration header
  - **File:** `apps/mobile_flutter/lib/features/merch/achievement_merch_option_screen.dart`
  - **Deliverable:** Header gains `TravelIdentityInfo` from `MerchContext.identity`; achievement icon gets `ScaleTransition` entrance (400ms, `easeOutBack`, starts at scale 0.6); identity `emoji + displayName` shown in `Color(0xFFE8C84A)` below title; tagline in `Colors.white60` below displayName; subtle animated gold shimmer on header background (gradient opacity oscillates 0.04→0.10 over 2s, loops)
  - **Acceptance:** Achievement screen header shows identity label; scale animation plays on first render; shimmer is subtle and non-distracting; Memory Pulse screen unchanged

- [ ] 7. Social export: `MerchShareCard`, `MerchShareExporter`, and "Share This Design" in `LocalMockupPreviewScreen`
  - **Files:** `merch_share_card.dart` (new); `merch_share_exporter.dart` (new); `local_mockup_preview_screen.dart`
  - **Deliverable:** `MerchShareFormat` enum (story/square); `MerchShareCard` CustomPaint widget rendering dark navy background + centred artwork + identity line + title + Roavvy wordmark; `MerchShareExporter.exportToPng(context, option, artworkBytes, identity, {format})` using off-screen OverlayEntry render (same pattern as `CardImageRenderer`); `LocalMockupPreviewScreen` toolbar gains share `IconButton` (Icons.ios_share); bottom sheet with format options → calls exporter → `Share.shareXFiles([XFile.fromData(bytes)])` via `share_plus` package
  - **Acceptance:** Tapping share shows bottom sheet; selecting "Story" exports a 1080×1920 PNG; selecting "Square" exports a 1080×1080 PNG; exported image contains artwork, identity label, and title; share sheet opens with the PNG

- [ ] 8. ADR-155 + `flutter analyze` — 0 new warnings
  - **Deliverable:** ADR-155 row added to `docs/architecture/decisions/_index.md`; `flutter analyze 2>/tmp/m105_analyze.txt && tail -5 /tmp/m105_analyze.txt` shows no new issues beyond pre-existing baseline

---

## Dependencies

- M104 complete (MerchTemplateRanker, MerchStory, MerchDensityClass, contextLabel) ✅
- `kCountryNames`, `kCountryContinent`, `subRegionDisplayName` available ✅
- `share_plus` package — check if already in `pubspec.yaml`; add if missing
- No new card template types required

---

## Risks

| Risk | Mitigation |
|---|---|
| `AnimationController` in `MerchOptionCard` increases memory with many cards | Dispose in `dispose()`; use `AutomaticKeepAliveClientMixin` only if needed |
| Off-screen render for share card may be slow on older devices | Show loading indicator during export; handle timeout gracefully |
| `share_plus` not in pubspec | Check first; add with `flutter pub add share_plus` if needed |
| Shimmer animation in achievement header causes jank | Use `RepaintBoundary`; keep opacity range small (0.04–0.10) |
| Identity tagline overrides important subtitle copy | Only override where subtitle would otherwise be generic; preserve specific copy (e.g. "Japan Entry Stamp") |
| `MerchOptionFeaturedEntry` breaks existing list builders in both screens | Both screens already have a `switch` on list item type — add the new case |

---

## QA Checklist

- [ ] Memory Pulse merch flow unchanged
- [ ] Achievement merch flow works end-to-end
- [ ] Identity label appears correctly on achievement header
- [ ] Scale animation plays on achievement header icon
- [ ] Cards animate in sequentially (staggered)
- [ ] First option renders as featured card (larger, gold border)
- [ ] Drop badge appears on Passport / Badge template sections
- [ ] Share icon visible in LocalMockupPreviewScreen toolbar
- [ ] Story export produces correct 9:16 PNG
- [ ] Square export produces correct 1:1 PNG
- [ ] Exported image contains artwork, identity line, title
- [ ] System share sheet opens with PNG
- [ ] `flutter analyze` clean (0 new warnings)
