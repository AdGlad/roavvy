# M162 — Country Profile: Rich Destination Screen

## Tasks

- [ ] T1: Add `sitesForCountry()` to `WorldHeritageLookupService`
- [ ] T2: `CountryStats` value class + `narrativeText()` generator
- [ ] T3: `countryDetailProvider` FutureProvider.family in providers.dart
- [ ] T4: `CountryProfileScreen` — SliverAppBar hero + all section widgets
- [ ] T5: Routing — map tap / countries list / notification push to CountryProfileScreen
- [ ] T6: Unvisited bottom sheet WHS hint
- [ ] T7: Tests — CountryStats + countryDetailProvider

## Key decisions

- FutureProvider.family<CountryDetailState, String> keyed on isoCode
- Visited country → push CountryProfileScreen; unvisited → keep bottom sheet
- 3 call sites to update: map_screen.dart, countries_list_screen.dart, main_shell.dart
- Photo strip reuses _platformFetch pattern from photo_gallery_screen.dart
- Region thumbnail: decorative CustomPaint arc + continent colour (not polygon render)
- Count-up: TweenAnimationBuilder<double> per stat tile
- Heritage sites: visited cards gold border; unvisited dimmed; same horizontal scroll
- Stagger: AnimatedOpacity per section, 80ms offset each
