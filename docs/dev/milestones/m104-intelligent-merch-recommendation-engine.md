# M104 — Intelligent Merch Recommendation Engine

**Branch:** `milestone/m104-intelligent-merch-recommendation-engine`  
**Status:** ✅ Complete (2026-05-09)
**Created:** 2026-05-09

---

Act as Roavvy product architect, senior Flutter engineer, and QA reviewer.

Milestone 4 of the achievement-driven merchandise system.

M99–M103 built the shared context layer, achievement-aware option generation, continent/region/passport scope, and two new template types (typography, badge). M104 transforms the system from "generate all templates in fixed order" into an intelligent, ranked, emotionally engaging recommendation engine.

Do not redesign the purchase workflow.  
Do not break Memory Pulse.  
Preserve artwork consistency from selection through checkout.

## Goal

The merch gallery should feel curated, not exhaustive. A user with 1 country should see 4–5 highly relevant, visually distinct options — not 14 generic shirt ideas. A user with 50 countries should see a different set, weighted toward global/mosaic styles. Every option should have a story-driven title that feels personal.

## Scope

**In:**
- `apps/mobile_flutter/lib/features/merch/merch_template_ranker.dart` (new) — `MerchTemplateRank` record; `MerchTemplateRanker.rankFor()` pure function; density class enum
- `apps/mobile_flutter/lib/features/merch/merch_story.dart` (new) — `MerchStory` data class; `MerchStory.forAchievement()` and `MerchStory.forTemplate()` generators
- `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart` — extend `merchAutoTuneCodes` / `merchAutoTuneStamps` with 5-tier density model; extend `merchSuggestShirtColor` to accept density class; add `contextLabel` field to `MerchOptionEntry`; show context label in `MerchOptionCard`
- `apps/mobile_flutter/lib/features/merch/pulse_merch_option.dart` — add `contextLabel` field
- `apps/mobile_flutter/lib/features/merch/merch_context.dart` — replace per-builder hardcoded template lists with `MerchTemplateRanker.rankFor()`; use `MerchStory` for titles/descriptions; pass `contextLabel` on entries
- `docs/architecture/decisions/_index.md` — ADR-154

**Out:**
- New `CardTemplateType` values (route/vintage/scrapbook — deferred)
- New product types (hoodies, posters, mugs — separate milestone)
- AI runtime calls / external APIs
- Checkout, Printful, Shopify changes
- Web, Android
- `pulse_merch_option_screen.dart` Memory Pulse list (untouched)

## New Components

### MerchDensityClass (enum)
```
solo      // 1 country / 1–2 stamps
small     // 2–5 countries / 3–8 stamps
medium    // 6–15 countries / 9–24 stamps
large     // 16–50 countries / 25–74 stamps
massive   // 51+ countries / 75+ stamps
```

### MerchTemplateRank (record)
```
{
  CardTemplateType template,
  String label,        // section header label
  int priority,        // lower = shown first; same priority = original order
  bool exclude,        // true = omit from gallery entirely
}
```

### MerchTemplateRanker.rankFor()
```dart
static List<MerchTemplateRank> rankFor({
  Achievement? achievement,
  required int codeCount,
  int tripCount = 0,
  int stampCount = 0,
})
```

Returns templates ranked by suitability for the given context. Filters (`exclude: true`) templates that do not suit the data size or achievement type.

**Ranking rules (priority 1 = highest):**

| Context | Highest priority | Excluded |
|---|---|---|
| `solo` (1 country) | passport, badge, typography | — |
| `solo` | grid, heart, timeline | _(deprioritised, shown last)_ |
| `small` (2–5) | passport, grid, badge | — |
| `medium` (6–15) | grid, passport, heart, timeline | — |
| `large` (16–50) | grid, heart, timeline, typography | badge (excluded — too cluttered) |
| `massive` (51+) | grid, heart, typography | badge, passport excluded |
| continent-explorer | badge (if ≤15), grid, typography | — |
| region-explorer | passport, badge (if ≤15), typography | — |
| passport-milestone | passport, timeline | badge, typography excluded |
| year achievement | timeline, typography, grid | badge excluded |

Maximum templates shown per density class:
- `solo`: 4
- `small`: 5
- `medium`: 6
- `large`: 5
- `massive`: 4

`MerchContext` builders call `MerchTemplateRanker.rankFor()`, take the top N (based on density class max), skip `exclude: true` entries, then call `_addGroup` in ranked order with story-driven titles from `MerchStory`.

### MerchStory
```dart
class MerchStory {
  const MerchStory({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  static MerchStory forOption({
    required CardTemplateType template,
    required Achievement? achievement,
    required List<String> codes,
    required MerchDensityClass density,
    required int year,
  });
}
```

Generates emotionally engaging, specific titles and subtitles for each option.

**Examples by context:**

| Context | Template | Title | Subtitle |
|---|---|---|---|
| First country = Japan | passport | "Japan Entry Stamp" | "Your first stamp, forever" |
| First country = Japan | badge | "Japan" | "Where your travels began" |
| 5 countries | grid | "The First Five" | "Your opening chapter" |
| 10 countries | timeline | "10 Countries World Tour" | "A decade of destinations" |
| Europe Explorer (8 countries) | grid | "Europe Explorer" | "8 countries across the continent" |
| Mediterranean (6 countries) | passport | "Mediterranean Stamps" | "Sun, sea, and stamps" |
| 2026, 7 countries | timeline | "2026 World Tour" | "Your year of travel" |
| passport milestone (26 stamps) | passport | "26 Stamps" | "Every entry, every exit" |
| 50 countries | typography | "50 Countries" | "Half the world explored" |

`MerchContext` replaces its inline `scopedTitle`/`scopedDesc` strings with calls to `MerchStory.forOption(...)`.

### Extended `MerchAutoTune`

Replace 4-tier with 5-tier model matching `MerchDensityClass`:

**`merchAutoTuneCodes(int codeCount)`:**
| Density | jitter | size |
|---|---|---|
| solo (1) | 0.00 | 1.20 |
| small (2–5) | 0.15 | 1.00 |
| medium (6–15) | 0.28 | 0.85 |
| large (16–50) | 0.38 | 0.72 |
| massive (51+) | 0.42 | 0.58 |

**`merchAutoTuneStamps(int stampCount)`:**
| Range | jitter | size |
|---|---|---|
| 1–2 | 0.00 | 0.55 |
| 3–6 | 0.12 | 0.70 |
| 7–14 | 0.22 | 0.82 |
| 15–30 | 0.33 | 0.88 |
| 31+ | 0.40 | 0.72 |

### Extended `merchSuggestShirtColor`

Signature extended:
```dart
String merchSuggestShirtColor(
  CardTemplateType template, {
  MerchDensityClass density = MerchDensityClass.medium,
})
```

| Template | solo/small | medium | large/massive |
|---|---|---|---|
| passport | 'White' | 'Black' | 'Black' |
| grid | 'Black' | 'Black' | 'Navy' |
| heart | 'Black' | 'Black' | 'Black' |
| timeline | 'Black' | 'Black' | 'Black' |
| badge | 'Navy' | 'Navy' | 'Navy' |
| typography | 'Black' | 'Black' | 'Black' |

### Context Label on `MerchOptionEntry` / `MerchOptionCard`

`PulseMerchOption` gains an optional `contextLabel` field (`String?`).
`MerchOptionCard` shows a small `contextLabel` line below `description` in white/40% if set.
`MerchContext._addGroup` gains a `contextLabel` parameter; builders pass it for achievement-entry options.

Example labels:
- "Based on your Europe Explorer achievement"
- "Built from your first 10 countries"
- "Generated from your 2026 travels"
- "Celebrating 26 passport stamps"

## Tasks

- [ ] 1. Add `MerchDensityClass` enum and `MerchTemplateRanker`
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_template_ranker.dart` (new)
  - **Deliverable:** `MerchDensityClass` enum (5 values); `MerchTemplateRank` record; `MerchTemplateRanker.densityFor(int codeCount)` and `MerchTemplateRanker.densityForStamps(int stampCount)` pure helpers; `MerchTemplateRanker.rankFor({achievement, codeCount, tripCount, stampCount})` returning ranked, filtered template list per the rules above
  - **Acceptance:** `rankFor(codeCount: 1)` returns ≤4 items with passport first; `rankFor(codeCount: 60)` excludes badge and passport; `rankFor(codeCount: 8, achievement: europeExplorer)` has badge in top 3

- [ ] 2. Add `MerchStory` generator
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_story.dart` (new)
  - **Deliverable:** `MerchStory` data class; `MerchStory.forOption({template, achievement, codes, density, year})` factory generating contextual `title` + `subtitle` strings per the examples in the spec; uses `kCountryNames` for country display names; `subRegionDisplayName` for region names; references `kCountryContinent` for continent scope
  - **Acceptance:** `MerchStory.forOption(template: passport, achievement: firstCountry, codes: ['JP'], ...)` returns title `"Japan Entry Stamp"`, subtitle non-empty; `MerchStory.forOption(template: grid, codeCount: 5, ...)` returns title containing "Five" or "5"

- [ ] 3. Extend `MerchAutoTune` and `merchSuggestShirtColor`
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_option_list_widgets.dart`
  - **Deliverable:** `merchAutoTuneCodes` updated to 5-tier model; `merchAutoTuneStamps` updated to 5-tier model; `merchSuggestShirtColor` gains optional `density` param with per-density colour table; existing call sites (zero-arg) continue to compile with default `density: MerchDensityClass.medium`
  - **Acceptance:** `merchAutoTuneCodes(1)` returns `size: 1.20`; `merchAutoTuneCodes(75)` returns `size: 0.58`; `merchSuggestShirtColor(CardTemplateType.passport, density: MerchDensityClass.solo)` returns `'White'`

- [ ] 4. Add `contextLabel` to `PulseMerchOption` and `MerchOptionCard`
  - **Files:** `pulse_merch_option.dart`; `merch_option_list_widgets.dart`
  - **Deliverable:** `PulseMerchOption.contextLabel` optional `String?` field; `MerchOptionCard` renders a third line below description in `Colors.white38` / `fontSize: 11` when `contextLabel != null`; `MerchContext._addGroup` gains `contextLabel` optional parameter
  - **Acceptance:** An option with `contextLabel: "Based on your Europe Explorer achievement"` shows that text in the card; existing options without it are unchanged

- [ ] 5. Update `MerchContext` to use `MerchTemplateRanker`, `MerchStory`, and `contextLabel`
  - **File:** `apps/mobile_flutter/lib/features/merch/merch_context.dart`
  - **Deliverable:** All 9 builder methods replaced with a single `_buildFromRankedTemplates()` helper that: (1) calls `MerchTemplateRanker.rankFor(...)` to get the ranked template list; (2) calls `MerchStory.forOption(...)` for each template to get title/subtitle; (3) calls `_addGroup` with title, desc, and contextLabel; (4) applies the density-class max-N cap. The 9 per-type builder methods may be retained for overrides but should delegate to the shared helper.
  - **Acceptance:** `MerchContext.fromAchievement(achievement: firstCountry, ...).buildItems()` returns ≤4 template groups; `MerchContext.fromAchievement(achievement: countries50, ...).buildItems()` does not contain badge entries; option titles match `MerchStory` output

- [ ] 6. ADR-154 + `flutter analyze` — 0 new warnings
  - **Deliverable:** ADR-154 row added to `docs/architecture/decisions/_index.md`; `flutter analyze 2>/tmp/m104_analyze.txt && tail -5 /tmp/m104_analyze.txt` shows no new issues

## Dependencies

- M103 complete (typography + badge templates, suggestedShirtColor, initialColour) ✅
- `kCountryNames`, `kCountryContinent`, `subRegionDisplayName` all available ✅
- No new packages required

## Risks

| Risk | Mitigation |
|---|---|
| Ranking rules too aggressive — hides options users want | `MerchOptionCustomiseEntry` (Customise button) always present; users can still reach any template |
| `MerchStory` titles for edge cases (empty codes, unknown countries) | Guard with fallback strings; never crash |
| Changing `_addGroup` signature breaks existing calls | `contextLabel` is optional — all existing calls compile unchanged |
| Massive dataset (195 countries) — typography truncation | TypographyCard already caps at 24; `massive` density class excludes low-readability templates |
