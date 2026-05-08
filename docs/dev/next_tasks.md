# Active Tasks: M98 — Achievement-Driven Merch Workflow

Branch: milestone/m98-achievement-merch-workflow

## Goal

Users tapping "Make a Tee" or "Create" from any achievement unlock are taken into the same
modern t-shirt selection experience currently used by Memory Pulse, with shirt options
pre-scoped to the achievement's relevant countries and trips.

## Scope

In:
- `lib/features/merch/merch_option_list_widgets.dart` (new — shared rendering widgets)
- `lib/features/merch/pulse_merch_option_screen.dart` (modified — import shared widgets)
- `lib/features/merch/achievement_merch_option_screen.dart` (new — achievement merch screen)
- `lib/features/stats/widgets/achievement_gallery.dart` (modified — reroute _MerchChip)
- `lib/features/stats/widgets/merch_moments_section.dart` (modified — reroute _MerchMomentTile)

Out:
- LocalMockupPreviewScreen, MerchOrderConfirmationScreen, Shopify/Printful
- pulse_merch_option.dart, shared_models
- Web, new achievement categories, new kAchievements entries

## Tasks

- [ ] 1. Extract shared merch option widgets — `lib/features/merch/merch_option_list_widgets.dart`
  Deliverable: New file with public versions of the sealed list-item types, auto-tune helpers,
  backCardAspectRatio(), templateLabel(), MerchOptionSectionHeader, MerchOptionCard,
  MerchOptionCustomCard.
  AC: All types/functions that will be shared between pulse and achievement screens are exported
  from this file. File compiles standalone (dart analyze clean).

- [ ] 2. Refactor pulse_merch_option_screen.dart to use shared widgets — `lib/features/merch/pulse_merch_option_screen.dart`
  Deliverable: All private types replaced with imports from merch_option_list_widgets.dart.
  AC: File compiles. Public API of PulseMerchOptionScreen is unchanged. Memory Pulse
  "Print on a t-shirt" flow navigates to PulseMerchOptionScreen as before.

- [ ] 3. Create AchievementMerchOptionScreen — `lib/features/merch/achievement_merch_option_screen.dart`
  Deliverable: ConsumerWidget taking `Achievement achievement`. Reads effectiveVisitsProvider
  + tripListProvider. Resolves codes/trips per achievement category and progressTarget.
  Generates grouped PulseMerchOption list. Renders via shared widgets. Navigates to
  LocalMockupPreviewScreen on tap.
  AC:
  - countries_1 → resolvedCodes = [firstCountry], options scoped to that country + world collection
  - countries_N (N≤25) → resolvedCodes = first N by firstSeen
  - countries_N (N>25) → resolvedCodes = all countries
  - continents_N → resolvedCodes = all countries
  - trips_N → resolvedTrips = first N trips, resolvedCodes = unique codes from those trips
  - year_N → resolvedCodes = countries with firstSeen.year == currentYear, resolvedTrips = this year's trips
  - Loading state shows CircularProgressIndicator; error state shows retry

- [ ] 4. Reroute _MerchChip in achievement_gallery.dart — `lib/features/stats/widgets/achievement_gallery.dart`
  Deliverable: _MerchChip.onPressed navigates to AchievementMerchOptionScreen(achievement: achievement).
  Import of MerchCountrySelectionScreen removed.
  AC: Tapping "Make tee" on an unlocked achievement pushes AchievementMerchOptionScreen.

- [ ] 5. Reroute _MerchMomentTile in merch_moments_section.dart — `lib/features/stats/widgets/merch_moments_section.dart`
  Deliverable: "Create" button navigates to AchievementMerchOptionScreen(achievement: achievement).
  Import of MerchCountrySelectionScreen removed.
  AC: Tapping "Create" in Merch Moments pushes AchievementMerchOptionScreen.

- [ ] 6. flutter analyze — pass with no new warnings

## Dependencies

- M96 (MerchPresetConfig, LocalMockupPreviewScreen, PulseMerchOption pipeline) ✅
- M97 (Achievement model, kAchievements, AchievementGallery, MerchMomentsSection) ✅

## Risks

| Risk | Mitigation |
|---|---|
| Extracting private types from pulse screen breaks Memory Pulse | Task 2 is a pure mechanical rename; zero behavior change; analyze catches any break |
| AchievementMerchOptionScreen generates wrong codes for edge cases (0 visits, 0 trips) | Guard every resolved list: if empty, fall back gracefully (empty list = no artwork, no crash) |
| _CustomOptionCard param removal (hero, allTrips, allCodes were unused) | Verified by code read that onTap only ever used `template` — removal is safe |
