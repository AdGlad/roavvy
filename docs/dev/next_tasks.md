# M171 — Country & Continent Outline Clip
Branch: milestone/m171-country-outline-clip

## Goal
Add `countryOutline` and `continentOutline` clip shapes to the flag grid. Flags fill the geographic silhouette of the selected country or continent. The defining premium shapes for the platform.

## Tasks

### T1 — Pipeline environment ✅
- fiona, shapely, pyproj installed
- scripts/requirements.txt written

### T2 — Offline path pipeline
- `scripts/build_country_paths.py`: polygon selection, simplification, normalisation, serialization
- `scripts/country_overrides.json`: per-country ε/resolution overrides
- Output: assets/country_paths/{iso2}.json × 195, assets/continent_paths/{key}.json × 6, _meta.json
- pubspec.yaml asset declarations updated

### T3 — CountryPathService
- lib/features/cards/country_path_service.dart
- rootBundle load → JSON → ui.Path (moveTo/lineTo per polygon, no Path.combine)
- Scale to targetSize (fit-inside, centred)
- LRU cache max 40, keyed by code+size
- preload(codes, size) helper
- Unit tests

### T4 — GridFlagsCard outline path loading
- clipCode: String? param to GridFlagsCard + _GridPainter
- initState/didUpdateWidget: CountryPathService.pathFor when clipShape is outline type
- ui.Path? in state → passed to painter → _clipPathFor()

### T5 — Conditional carousel pages in FlagShapeCustomiseScreen
- Page list: always [none, heart, circle], + [countryOutline] if codes.length==1, + [continentOutline] if continentKey!=null
- Labels: country name / continent display name
- _ClipVariantCard: spinner until outline path loads

### T6 — Pre-navigation preload
- CountryPathService.preload before Navigator.push in merch_option_list_widgets.dart
- 800ms max timeout, proceed regardless

### T7 — Continent context propagation
- continentKey: String? on PulseMerchOption
- ShopCollectionOptionScreen derives continent key from collection label
- Thread to LocalMockupPreviewScreen → FlagShapeCustomiseScreen

### T8 — Analyze + tests
- flutter analyze: 0 new warnings
- CountryPathService unit tests
