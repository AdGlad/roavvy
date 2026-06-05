# Current Task

**Milestone:** M146 — Annual Travel Story with Merch CTA
**Task:** T1 — TravelStoryData data class + build() factory
**Status:** In Progress

## Goal
Create `apps/mobile_flutter/lib/features/merch/travel_story_data.dart`:
- `TravelStoryData` immutable class with fields: year, countryCodes, continentCount,
  tripCount, topAchievement?, identity, merchOption, heroCountryCode
- `build()` factory: filters to year, resolves identity, selects top achievement,
  builds PulseMerchOption from MerchTemplateRanker
