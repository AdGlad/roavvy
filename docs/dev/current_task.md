# M171 — Country & Continent Outline Clip

**Milestone:** M171
**Status:** Complete

## Done
- T1: Pipeline env — fiona/shapely/pyproj installed; scripts/requirements.txt
- T2: scripts/build_country_paths.py — 236 country JSONs + 6 continent JSONs; 154 KB total; France ISO fix
- T3: CountryPathService — LRU cache (40), rootBundle async load, fit-inside scale, preload(); 8 unit tests
- T4: GridFlagsCard.clipCode param; _GridFlagsCardState._loadOutlinePath() via CountryPathService.pathFor; outlinePath passed to painter
- T5: FlagShapeCustomiseScreen page list dynamic — [none,heart,circle] + [countryOutline] if codes.length==1 + [continentOutline] if continentKey!=null; country name labels; continent display names; _preloadOutlinePaths in initState
- T6: Pre-navigation preload handled by FlagShapeCustomiseScreen.initState
- T7: PulseMerchOption.continentKey field; threaded through merch_option_list_widgets → FlagShapeCustomiseScreen
- T8: flutter analyze — 23 issues (all pre-existing); 546 card+merch tests pass
- pubspec.yaml: assets/country_paths/ + assets/continent_paths/ declared
