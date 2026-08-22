import '../recipe/shape_catalog.dart';

/// Coarse shape families for preference gathering.
///
/// These map onto the finer [ClipShape] / [ShapeFamily] values in the recipe
/// system. Users pick 1–3 of these; the system inflates them into concrete
/// shape IDs when building the pool.
enum ShapePreference {
  noClip('No Clip', 'Full-bleed flag artwork'),
  countryOutline('Country Outline', 'Cut to the visited country shape'),
  silhouette('Animal / Nature', 'Animal, plant, or landmark silhouette'),
  geometric('Geometric', 'Circle, hexagon, diamond, shield …'),
  travelIcon('Travel Icon', 'Compass, ticket, luggage tag, map pin …'),
  textMask('Text Mask', 'Artwork clipped inside bold lettering');

  const ShapePreference(this.label, this.description);
  final String label;
  final String description;
}

/// Maps a [ShapePreference] to the clip-shape IDs it covers.
///
/// Returns a list of shape IDs from [kClipShapeCatalog] that belong to
/// this preference bucket. Used by the sampler to inflate preferences
/// into concrete clip choices.
List<String> shapeIdsForPreference(ShapePreference pref) {
  switch (pref) {
    case ShapePreference.noClip:
      return ['none'];
    case ShapePreference.countryOutline:
      return ['countryOutline', 'continentOutline'];
    case ShapePreference.silhouette:
      return [
        'animalSilhouette',
        'plantSilhouette',
        'landmarkSilhouette',
      ];
    case ShapePreference.geometric:
      return [
        'circle',
        'oval',
        'arch',
        'roundedRect',
        'diamond',
        'triangle',
        'hexagon',
        'shield',
        'heart',
        'star',
        'lightning',
      ];
    case ShapePreference.travelIcon:
      return [
        'compass',
        'badge',
        'mapPin',
        'ticket',
        'luggageTag',
        'postageStamp',
        'passportStamp',
        'entryStamp',
        'passportStampReal',
        'passportPage',
        'mountain',
        'island',
        'sunset',
        'wave',
      ];
    case ShapePreference.textMask:
      return ['text'];
  }
}

/// Infers the [ShapePreference] bucket that a clip shape ID belongs to.
///
/// Returns `null` for unrecognised IDs.
ShapePreference? shapePreferenceFor(String shapeId) {
  for (final pref in ShapePreference.values) {
    if (shapeIdsForPreference(pref).contains(shapeId)) return pref;
  }
  return null;
}
