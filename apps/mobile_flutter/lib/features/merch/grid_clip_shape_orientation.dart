import 'dart:ui' as ui;

import '../cards/country_path_service.dart';
import '../cards/flag_grid_layout_engine.dart';
import 'animal_silhouette_service.dart';

/// Card aspect ratios the rest of the merch rendering pipeline understands —
/// [LocalMockupPreviewScreen]'s manual portrait/landscape toggle only ever
/// switches between these two, so shape-driven defaults snap to whichever is
/// closer rather than using a continuous ratio.
const double kPortraitCardAspectRatio = 2.0 / 3.0;
const double kLandscapeCardAspectRatio = 3.0 / 2.0;

/// Whether [shape]'s own image reads best portrait or landscape, based on its
/// bounding-box proportions — so a single-country flag-grid design fills as
/// much of the shirt's print area as possible instead of being squeezed into
/// a fixed default orientation.
///
/// For example the kangaroo (Australia's animal silhouette) is naturally
/// tall and narrow: forcing it into a landscape canvas leaves most of the
/// canvas as wasted side margins. The Sydney Opera House (a landmark
/// silhouette) is naturally wide, so the reverse holds.
///
/// Returns `null` for shapes with no country-specific image ([none],
/// [heart], [circle]) or when the shape's asset hasn't loaded — callers
/// should fall back to their usual template default in that case.
Future<bool?> isPortraitForClipShape(
  GridClipShape shape,
  String? clipCode,
) async {
  if (clipCode == null) return null;

  ui.Rect? bounds;
  switch (shape) {
    case GridClipShape.animalSilhouette:
      bounds = (await AnimalSilhouetteService.pathFor(clipCode))?.getBounds();
    case GridClipShape.plantSilhouette:
      bounds =
          (await AnimalSilhouetteService.plantPathFor(clipCode))?.getBounds();
    case GridClipShape.landmarkSilhouette:
      bounds =
          (await AnimalSilhouetteService.landmarkPathFor(
            clipCode,
          ))?.getBounds();
    case GridClipShape.countryOutline:
    case GridClipShape.continentOutline:
      bounds =
          (await CountryPathService.pathFor(
            clipCode.toLowerCase(),
            const ui.Size(800, 533),
          ))?.getBounds();
    case GridClipShape.none:
    case GridClipShape.heart:
    case GridClipShape.circle:
      return null;
  }

  if (bounds == null ||
      bounds.isEmpty ||
      bounds.width <= 0 ||
      bounds.height <= 0) {
    return null;
  }
  return bounds.height > bounds.width;
}
