# M92 — Label-Powered Auto Titles

**Branch:** `milestone/m92-label-powered-titles`
**Phase:** 19 — Personalisation & Memory
**Status:** Complete (2026-04-30)

## Goal

Enrich the existing rule-based title generator with scene and mood labels from hero images so card titles are more vivid and specific than geography alone allows.

## Scope

**In:**
- `lib/features/cards/title_generation/title_generation_models.dart`
- `lib/features/cards/title_generation/rule_based_title_generator.dart`
- `lib/features/cards/card_editor_screen.dart`

**Out:** AI title plugin, web title generation, Memory Pulse copy.

## Tasks

- [x] T1 — Extend `TitleRequest` + `HeroLabelAggregator`
  - File: `lib/features/cards/title_generation/title_generation_models.dart`
  - Deliverable: `heroLabels: List<HeroLabels>?` added to `TitleGenerationRequest`. `AggregatedLabels` class. `HeroLabelAggregator.aggregate()` with confidence-weighted frequency.
  - Tests: uniform labels, mixed labels (most-frequent wins), empty list returns null.

- [x] T2 — Label title tables + selection logic
  - File: `lib/features/cards/title_generation/rule_based_title_generator.dart`
  - Deliverable: `_kSceneMoodTitles`, `_kSceneActivityTitles`, `_kSceneTitles`, `_kMoodTitles` constants. `_labelTitle(AggregatedLabels) → String?` method. Label lookup runs as priority 1 in `_compute()`.
  - Tests: combo tables, label fires before sub-region + single-country, fallback when no match.

- [x] T3 — Card editor integration
  - File: `lib/features/cards/card_editor_screen.dart`
  - Deliverable: `_fetchHeroLabelsForTrips()` reads `heroForTripProvider` cache. Result passed as `heroLabels` to `TitleGenerationRequest`.
  - Tests: graceful when heroLabels null; richer title when labels present.
