# M70 — Passport Stamp UX Cleanup + Title Generation Improvements

**Branch:** `milestone/m70-stamp-ux-title`

---

## Goal

Three targeted improvements to the Passport Stamp card experience:

1. **Remove the orientation toggle** for the passport template — lock it to portrait.
2. **Add a Shuffle button** so users can explore different stamp arrangements without
   changing their countries or title.
3. **Improve title generation** — remove years, expand region awareness, make AI and
   fallback titles feel playful and human.

---

## Context (from code review)

### What exists today

| Area | Location | Notes |
|---|---|---|
| Orientation toggle | `card_editor_screen.dart:96,128,239–242,708–724` | `_portrait` bool → `_aspectRatio 2:3 / 3:2`; `IconButton.outlined` in `_ControlStrip` |
| Stamp seed | `passport_layout_engine.dart:169` | `effectiveSeed = seed ?? countryCodes.join().hashCode` — deterministic; `PassportStampsCard` does **not** expose a `seed` param |
| Shuffle (Heart/Grid) | `card_editor_screen.dart:750–776` | 4 sort-mode chips (Shuffle / By Date / A→Z / By Region) — **passport has none** |
| AI title prompt | `AiTitlePlugin.swift:62–73` | Sends year range; says "max 5 words"; no constraint against ":" or years |
| Fallback generator | `rule_based_title_generator.dart` | Appends year suffix; 4 sub-regions; 6 continent labels |
| Title call site | `card_editor_screen.dart:321–373` | Passes `startYear` / `endYear` to request |

### Problems mapped to code

| Problem | Root cause |
|---|---|
| Orientation toggle exists for passport | `_portrait` + orientation button shown for all template types |
| No stamp shuffle | `PassportStampsCard` has no `seed` param; no shuffle button for passport |
| Year in AI title | Prompt sends year range; AI uses it; no post-process strip |
| Year in fallback title | `_yearSuffix()` appended in `_compute()` |
| Generic fallback titles | Only 4 sub-regions; continent labels are flat ("Asian Adventure") |
| Prompt allows ":" | Not constrained; no post-process strip |

---

## Scope

**Included:**
- Hide orientation toggle when template is `passport`; default portrait on template switch
- Add `seed` param to `PassportStampsCard` + `PassportLayoutEngine` call site
- Add Shuffle `IconButton` in toolbar for passport template only
- Remove year from AI prompt and from fallback title output
- Expand fallback sub-region map (10→ clusters covering Indian Ocean, Pacific, Balkans, etc.)
- Improve AI system prompt: tighter constraints, playful framing, 2–4 word target
- Post-process AI output: strip ":", strip leading/trailing quotes, collapse whitespace
- ADR + tests

**Excluded:**
- Removing orientation for Grid / Heart / Timeline (they benefit from landscape)
- Changes to stamp rendering, stamp styles, or stamp imagery
- Sound or haptics changes
- Paste-stamp-as-image export changes

---

## Tasks

---

### Task 1 — Lock passport template to portrait [ ]

**Files:**
- `apps/mobile_flutter/lib/features/cards/card_editor_screen.dart`

**Deliverable:**

1. In `_CardEditorScreenState._buildControlStrip()` (or equivalent toolbar builder),
   wrap the orientation `IconButton` in a conditional so it is **omitted** when
   `widget.templateType == CardTemplateType.passport`.

2. In the `initState` / template-switch path, add:
   ```dart
   if (widget.templateType == CardTemplateType.passport) {
     _portrait = true;
   }
   ```
   so that navigating to a passport card from a landscape session resets to portrait.

3. In `_buildTemplate`, the `PassportStampsCard` call already uses `_aspectRatio`.
   No change needed there — the toggle being hidden ensures `_portrait` stays `true`.

**Acceptance Criteria:**
- No orientation button rendered when on passport template
- `_portrait` is always `true` for passport (inspect via `_aspectRatio == 2/3`)
- Orientation toggle still works for Grid, Heart, Timeline, FrontRibbon
- `flutter analyze` zero issues

---

### Task 2 — Stamp shuffle button [ ]

**Files:**
- `apps/mobile_flutter/lib/features/cards/card_templates.dart` — add `seed` param to `PassportStampsCard`
- `apps/mobile_flutter/lib/features/cards/passport_layout_engine.dart` — verify call-site passes seed (already supported)
- `apps/mobile_flutter/lib/features/cards/card_editor_screen.dart` — state + button

**Deliverable:**

**2a. `PassportStampsCard` seed parameter**

Add `final int? seed;` to `PassportStampsCard`. The constructor is currently `const` —
keep it `const` (`int?` with a default of `null` is a compile-time constant).

Pass `seed` through to wherever `PassportLayoutEngine.layout()` is called inside the
widget's `build`/`paint` chain.

**2b. `CardEditorScreen` shuffle state**

Add state variable:
```dart
int? _stampLayoutSeed; // null = use deterministic hash default
```

Add shuffle handler:
```dart
void _shuffleStampLayout() {
  setState(() => _stampLayoutSeed = math.Random().nextInt(0x7FFFFFFF));
}
```

Pass seed to `PassportStampsCard`:
```dart
case CardTemplateType.passport:
  return PassportStampsCard(
    ...existing params...
    seed: _stampLayoutSeed,
  );
```

**2c. Shuffle button in toolbar**

In the `_ControlStrip` (or equivalent toolbar), add a Shuffle `IconButton` that is
**only visible** when `templateType == CardTemplateType.passport`:

```dart
if (templateType == CardTemplateType.passport)
  IconButton(
    onPressed: onShuffleStamps,
    icon: const Icon(Icons.shuffle_rounded, size: 20),
    tooltip: 'Shuffle stamp layout',
    padding: const EdgeInsets.all(6),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  ),
```

**Acceptance Criteria:**
- Shuffle button visible in passport template toolbar; absent for all other templates
- Each press produces a visibly different stamp arrangement (positions, rotations)
- Countries, title, date label, and stamp count are unaffected by shuffle
- Navigating away and back does NOT reset the seed (it is session-persistent in state)
- `flutter analyze` zero issues

---

### Task 3 — Improve fallback title generator [ ]

**File:**
- `apps/mobile_flutter/lib/features/cards/title_generation/rule_based_title_generator.dart`

**Deliverable:**

**3a. Remove year suffix entirely.**

Delete `_yearSuffix()` and all call sites in `_compute()`.
Titles must never include a year — the card's date label already shows the year range.

**3b. Expand `_kSubRegions`.**

Replace the current 4-entry map with at minimum the following 16 clusters.
The rule: *all codes in the user's set must be a subset of the cluster* (existing logic is correct).

```dart
const _kSubRegions = <String, Set<String>>{
  // Northern Europe
  'Nordic Wander':       {'NO', 'SE', 'FI', 'IS', 'DK'},
  'Baltic Loop':         {'EE', 'LV', 'LT'},
  'British Isles':       {'GB', 'IE'},
  // Western / Southern Europe
  'Southern Europe':     {'IT', 'ES', 'PT', 'FR', 'MT'},
  'Mediterranean Escape':{'GR', 'CY', 'MT'},
  'Iberian Road':        {'ES', 'PT'},
  'Balkan Trail':        {'HR', 'BA', 'ME', 'RS', 'MK', 'AL', 'SI'},
  'Alpine Escape':       {'CH', 'AT', 'LI'},
  'Benelux':             {'BE', 'NL', 'LU'},
  // Asia
  'East Asia':           {'JP', 'KR', 'CN', 'TW'},
  'Southeast Asia':      {'TH', 'VN', 'KH', 'LA', 'MM', 'SG', 'MY', 'ID', 'PH'},
  'Indian Subcontinent': {'IN', 'LK', 'NP', 'BD', 'BT'},
  // Oceans
  'Indian Ocean':        {'MV', 'SC', 'MU', 'RE', 'YT'},
  'Pacific Islands':     {'FJ', 'WS', 'TO', 'VU', 'PG', 'SB', 'CK', 'NU'},
  // Americas
  'Central America':     {'MX', 'GT', 'BZ', 'HN', 'SV', 'NI', 'CR', 'PA'},
  'Caribbean Hop':       {'CU', 'JM', 'HT', 'DO', 'TT', 'BB', 'LC', 'VC', 'GD', 'AG', 'DM', 'KN'},
};
```

**3c. Improve continent titles.**

Replace flat labels with more evocative alternatives:

```dart
const _kContinentTitles = <String, String>{
  'Europe':        'Euro Wander',
  'Asia':          'Asian Escape',
  'North America': 'American Road',
  'South America': 'South American Journey',
  'Africa':        'African Adventure',
  'Oceania':       'Pacific Escape',
};
```

**3d. Improve single-country titles.**

For a single-country request, use the country name as-is (no year suffix, no added suffix).
Do NOT add "Escape" or other suffixes — keep it clean and unambiguous.

**Acceptance Criteria:**
- No year appears in any generated title
- `_kSubRegions` contains at least 14 entries
- `{MV, SC}` → `'Indian Ocean'`
- `{FJ, WS}` → `'Pacific Islands'`
- `{NO, SE}` → `'Nordic Wander'`
- `{FR, IT, ES}` → `'Euro Wander'` (continent fallback, since set ⊄ 'Southern Europe')
- `{JP}` → `'Japan'`
- `flutter analyze` zero issues

---

### Task 4 — Improve AI title prompt and post-processing [ ]

**Files:**
- `apps/mobile_flutter/ios/Runner/AiTitlePlugin.swift`
- `apps/mobile_flutter/lib/features/cards/card_editor_screen.dart`

**Deliverable:**

**4a. Swift prompt rewrite**

Replace the `generateTitle` method's prompt construction with:

```swift
// Build concise region hint (e.g. "Europe, Asia").
let regionHint = (args["regionNames"] as? [String] ?? [])
    .prefix(3)
    .joined(separator: ", ")

var prompt = "Write a short, playful, human-sounding travel title."
if !countries.isEmpty {
    let listed = countries.prefix(8).joined(separator: ", ")
    prompt += " Countries visited: \(listed)."
}
if !regionHint.isEmpty {
    prompt += " Region: \(regionHint)."
}
prompt += " Rules: 2 to 4 words only. No year. No colon. No phrases like 'My Travel' or 'Trip Summary'. Sound like a human wrote it, not an AI."
```

Replace the system instructions with:

```swift
instructions: "You generate short, witty travel card titles. Output ONLY the title — 2 to 4 words. Never include a year, a colon, or quotation marks. Never use clichés like 'My Travels'. Sound playful and human."
```

**4b. Post-process output** — after receiving the model response, before returning:

```swift
var title = response.content
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .replacingOccurrences(of: "\"", with: "")
    .replacingOccurrences(of: "'", with: "")
    .replacingOccurrences(of: ":", with: "")
    // Collapse any double spaces introduced by stripping
    .components(separatedBy: .whitespaces)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
```

**4c. Remove year from Dart call site**

In `card_editor_screen.dart` `_generateTitle()` (lines 321–373), remove `startYear`
and `endYear` from the `TitleGenerationRequest` construction:

```dart
final request = TitleGenerationRequest(
  countryCodes: codes,
  countryNames: codes.map((c) => kCountryNames[c] ?? c).toList(),
  regionNames: codes
      .map((c) => kCountryContinent[c])
      .whereType<String>()
      .toSet()
      .toList(),
  // startYear and endYear intentionally omitted — year must not appear in title
  cardType: widget.templateType,
);
```

Also remove the `startYear`/`endYear` computation block above it (the `effectiveRange`
→ `startYear`/`endYear` logic) since it is now unused.

**Acceptance Criteria:**
- AI prompt does not mention any year
- AI prompt includes region context
- System instructions constrain to 2–4 words, no colon, no year
- Post-processing strips `"`, `'`, `:` from output
- Dart call site no longer computes or passes year fields
- `TitleGenerationRequest.startYear` / `.endYear` fields can remain on the model
  (used by fallback year-removal is covered in Task 3); just don't populate them here
- `flutter analyze` zero issues

---

### Task 5 — Update tests [ ]

**Files:**
- `apps/mobile_flutter/test/features/cards/title_generation/rule_based_title_generator_test.dart`
- `apps/mobile_flutter/test/features/cards/title_generation/ios_title_channel_test.dart`

**Deliverable:**

**`rule_based_title_generator_test.dart`** — update or add:

- `{MV, SC}` → `'Indian Ocean'`
- `{FJ, WS}` → `'Pacific Islands'`
- `{NO, SE, DK}` → `'Nordic Wander'`
- `{IT, ES}` → `'Euro Wander'` (continent fallback)
- `{JP}` → `'Japan'`
- `{}` (empty) → `'My Travels'`
- Remove any test that asserts a year appears in output
- Assert that no title from any test case contains a digit (year guard)

**`ios_title_channel_test.dart`** — update mock channel invocations:

- Assert `startYear` is **not** present in the method channel args map
- Assert `endYear` is **not** present in the method channel args map
- Assert `regionNames` **is** present

**Acceptance Criteria:**
- All tests pass
- No golden tests
- `flutter analyze` zero issues

---

### Task 6 — ADR [ ]

**File:** `docs/architecture/decisions.md`

Append **ADR-125** documenting:

- **Context:** Passport stamp card had a landscape/portrait toggle that added
  complexity with little value; no stamp shuffle existed; title generation produced
  year-heavy, robotic output.
- **Decision:**
  1. Orientation toggle hidden for `CardTemplateType.passport`; card fixed to portrait (`2:3`).
  2. `PassportStampsCard` gains nullable `seed` param; `CardEditorScreen` holds
     `_stampLayoutSeed` state; Shuffle button fires `Random().nextInt(0x7FFFFFFF)`.
  3. Year removed from `TitleGenerationRequest` call site and from
     `RuleBasedTitleGenerator` output; AI prompt rewritten to 2–4 words, no colon,
     region-aware; post-processing strips punctuation artefacts.
  4. `_kSubRegions` expanded from 4 to 16 thematic clusters.
- **Consequences:** Portrait-only passport reduces test surface; shuffle is
  session-persistent (resets on screen push); titles never include years.

---

## Implementation Order

1. Task 1 (orientation) — isolated UI change, no logic risk
2. Task 2 (shuffle) — adds state + param; straightforward
3. Task 3 (fallback titles) — pure Dart, easily testable
4. Task 4 (AI prompt) — Swift + Dart; depends on Task 3 model understanding
5. Task 5 (tests) — depends on Tasks 3 + 4
6. Task 6 (ADR) — last, documents final decisions

---

## Risks

| Risk | Mitigation |
|---|---|
| Removing year from `TitleGenerationRequest` breaks other callers | Only `card_editor_screen.dart` constructs `TitleGenerationRequest`; grep confirms single call site |
| AI output still includes year despite prompt constraint | Post-processing in Swift strips digits is NOT applied (too aggressive — "Area 51" etc.); rely on prompt + system instruction instead |
| Shuffle seed collisions produce identical layouts | `nextInt(0x7FFFFFFF)` space is large enough; cosmetically acceptable even if collision occurs |
| Sub-region cluster "Nordic Wander" triggers for `{NO}` (single code) | Single-code path returns early before sub-region check — no conflict |
| `const` removal from `PassportStampsCard` constructor | `seed` is `int?` with default `null` — constructor remains `const` |
