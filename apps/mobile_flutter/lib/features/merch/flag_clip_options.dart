import 'dart:math' as math;

import '../../core/country_names.dart';
import '../cards/flag_grid_layout_engine.dart';
import 'animal_silhouette_service.dart';

// ── Smart defaults ─────────────────────────────────────────────────────────────

/// Row count for a single-country grid design's densest packing — the
/// slider's max. Shared with the Shop's "Best Match" preview thumbnail
/// ([MerchDesignCarousel]) so the two stay visually consistent.
const int kSoloGridRowCount = 10;

/// Returns the recommended repeat count for [codeCount] unique countries
/// and [shape]. Heart/circle clip shapes lose ~35% effective area, so the
/// count is bumped by 1 to keep the shirt looking full.
int merchDefaultRepeatCount(int codeCount, GridClipShape shape) {
  final base = switch (codeCount) {
    1 => 9,
    2 => 6,
    <= 4 => 4,
    <= 8 => 2,
    _ => 1,
  };
  final clipBoost =
      (shape != GridClipShape.none &&
              shape != GridClipShape.countryOutline &&
              shape != GridClipShape.continentOutline)
          ? 1
          : 0;
  return math.min(50, base + clipBoost);
}

// ── FlagClipOption ─────────────────────────────────────────────────────────────

/// A single selectable clip-shape option for the flag-grid configurator.
///
/// [shape] is the [GridClipShape] to apply, [label] is the user-facing name
/// (country / animal / plant / landmark name, or "Grid"/"Heart"/"Circle"), and
/// [clipCode] is the ISO code / continent key / encoded silhouette slug used to
/// resolve the outline path (null for none/heart/circle).
class FlagClipOption {
  const FlagClipOption({
    required this.shape,
    required this.label,
    this.clipCode,
  });

  final GridClipShape shape;
  final String label;
  final String? clipCode;

  /// Stable identity for selection comparison + widget keys.
  String get id => '${shape.name}:${clipCode ?? ''}';
}

/// Continent display names from continent key.
const _kContinentDisplayNames = {
  'africa': 'Africa',
  'asia': 'Asia',
  'europe': 'Europe',
  'north_america': 'North America',
  'oceania': 'Oceania',
  'south_america': 'South America',
};

/// Builds the synchronous base set of clip options (Grid / Heart / Circle,
/// plus country / continent outlines) and appends any provided silhouette
/// options. Mirrors the old `FlagShapeCustomiseScreen._buildPages` logic so the
/// merged configurator (M187) offers exactly the same choices.
List<FlagClipOption> buildFlagClipOptions({
  required List<String> codes,
  String? continentKey,
  List<SilhouetteOption> animalOptions = const [],
  List<SilhouetteOption> plantOptions = const [],
  List<SilhouetteOption> landmarkOptions = const [],
}) {
  final options = <FlagClipOption>[
    const FlagClipOption(shape: GridClipShape.none, label: 'Grid'),
    const FlagClipOption(shape: GridClipShape.heart, label: 'Heart'),
    const FlagClipOption(shape: GridClipShape.circle, label: 'Circle'),
  ];
  // Country outline + silhouettes — only for single-country designs.
  if (codes.length == 1) {
    final code = codes.first.toUpperCase();
    final countryName = kCountryNames[code] ?? code;
    options.add(
      FlagClipOption(
        shape: GridClipShape.countryOutline,
        label: countryName,
        clipCode: codes.first.toLowerCase(),
      ),
    );
    for (final o in animalOptions) {
      options.add(
        FlagClipOption(
          shape: GridClipShape.animalSilhouette,
          label: o.name,
          clipCode: AnimalSilhouetteService.encodeClipCode(code, o.slug),
        ),
      );
    }
    for (final o in plantOptions) {
      options.add(
        FlagClipOption(
          shape: GridClipShape.plantSilhouette,
          label: o.name,
          clipCode: AnimalSilhouetteService.encodeClipCode(code, o.slug),
        ),
      );
    }
    for (final o in landmarkOptions) {
      options.add(
        FlagClipOption(
          shape: GridClipShape.landmarkSilhouette,
          label: o.name,
          clipCode: AnimalSilhouetteService.encodeClipCode(code, o.slug),
        ),
      );
    }
  }
  // Continent outline — only when a continent key is provided.
  if (continentKey != null) {
    final displayName = _kContinentDisplayNames[continentKey] ?? continentKey;
    options.add(
      FlagClipOption(
        shape: GridClipShape.continentOutline,
        label: displayName,
        clipCode: continentKey,
      ),
    );
  }
  return options;
}

/// Loads the full clip-option list, fetching single-country animal / plant /
/// landmark silhouette options from Firebase Storage. Returns the base set
/// (Grid/Heart/Circle + outlines) immediately for multi-country sets.
Future<List<FlagClipOption>> loadFlagClipOptions({
  required List<String> codes,
  String? continentKey,
}) async {
  if (codes.length != 1) {
    return buildFlagClipOptions(codes: codes, continentKey: continentKey);
  }
  final cc = codes.first.toUpperCase();
  final results = await Future.wait([
    AnimalSilhouetteService.optionsFor(cc, 'animal'),
    AnimalSilhouetteService.optionsFor(cc, 'plant'),
    AnimalSilhouetteService.optionsFor(cc, 'landmark'),
  ]);
  return buildFlagClipOptions(
    codes: codes,
    continentKey: continentKey,
    animalOptions: results[0],
    plantOptions: results[1],
    landmarkOptions: results[2],
  );
}
