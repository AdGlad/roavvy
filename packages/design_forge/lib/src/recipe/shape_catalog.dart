import 'recipe_parts.dart' show ClipShape;

/// The clip-shape family a shape belongs to (for browsing/grouping).
enum ShapeFamily {
  geometric,
  travel,
  outdoor,
  geographic,
  symbolic,
  typographic,
  custom;

  static ShapeFamily fromId(String? id) {
    for (final v in ShapeFamily.values) {
      if (v.name == id) return v;
    }
    return ShapeFamily.geometric;
  }
}

/// How a shape's geometry is produced. The [ClipStage] uses this to decide
/// whether to build a path or an alpha mask — it never special-cases a shape id.
enum ClipShapeSource {
  /// Procedural `ui.Path` from a registered builder (no asset).
  procedural,

  /// Text rendered to an alpha mask (uses [Clip.text]).
  text,

  /// Alpha mask via `AssetResolver.resolveClipMask` (country/continent/silhouette).
  resolver,

  /// Alpha mask rasterised from a bundled/custom SVG asset (uses [Clip.code]).
  svgAsset,
}

/// Metadata describing one clip shape. This is the **registry**: adding a shape
/// is (1) add an asset or a procedural builder, (2) add a [ClipShapeMeta] entry,
/// (3) optional default params — with **no renderer changes**.
class ClipShapeMeta {
  const ClipShapeMeta({
    required this.id,
    required this.label,
    required this.family,
    required this.source,
    this.aspectRatio = 1.0,
    this.cornerRadius = false,
    this.resolverKind,
  });

  /// Stable id used in `Clip.shapeId` and the render registry.
  final String id;

  /// Human-readable name for the Lab browser.
  final String label;

  final ShapeFamily family;
  final ClipShapeSource source;

  /// Natural width/height. Used when the recipe doesn't override aspectRatio.
  final double aspectRatio;

  /// Whether the shape honours [Clip.cornerRadius].
  final bool cornerRadius;

  /// For [ClipShapeSource.resolver], which mask kind to request.
  final ClipShape? resolverKind;
}

/// The built-in shape registry. New shapes are appended here; the render layer
/// supplies geometry keyed by [id] (a procedural builder, a text renderer, an
/// SVG asset, or the resolver kind).
const List<ClipShapeMeta> kClipShapeCatalog = [
  // ── GEOMETRIC ────────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'circle', label: 'Circle', family: ShapeFamily.geometric, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'oval', label: 'Oval', family: ShapeFamily.geometric, source: ClipShapeSource.procedural, aspectRatio: 0.72),
  ClipShapeMeta(id: 'roundedRect', label: 'Rounded rectangle', family: ShapeFamily.geometric, source: ClipShapeSource.procedural, cornerRadius: true),
  ClipShapeMeta(id: 'arch', label: 'Arch', family: ShapeFamily.geometric, source: ClipShapeSource.procedural, aspectRatio: 0.72),
  ClipShapeMeta(id: 'diamond', label: 'Diamond', family: ShapeFamily.geometric, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'triangle', label: 'Triangle', family: ShapeFamily.geometric, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'hexagon', label: 'Hexagon', family: ShapeFamily.geometric, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'shield', label: 'Shield', family: ShapeFamily.geometric, source: ClipShapeSource.procedural, aspectRatio: 0.86),

  // ── SYMBOLIC ─────────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'heart', label: 'Heart', family: ShapeFamily.symbolic, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'star', label: 'Star', family: ShapeFamily.symbolic, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'lightning', label: 'Lightning', family: ShapeFamily.symbolic, source: ClipShapeSource.procedural, aspectRatio: 0.62),

  // ── OUTDOOR ──────────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'mountain', label: 'Mountain', family: ShapeFamily.outdoor, source: ClipShapeSource.procedural, aspectRatio: 1.3),
  ClipShapeMeta(id: 'wave', label: 'Wave', family: ShapeFamily.outdoor, source: ClipShapeSource.procedural, aspectRatio: 1.5),
  ClipShapeMeta(id: 'island', label: 'Island', family: ShapeFamily.outdoor, source: ClipShapeSource.procedural, aspectRatio: 1.4),
  ClipShapeMeta(id: 'sunset', label: 'Sunset', family: ShapeFamily.outdoor, source: ClipShapeSource.procedural, aspectRatio: 1.2),

  // ── TRAVEL ───────────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'mapPin', label: 'Map pin', family: ShapeFamily.travel, source: ClipShapeSource.procedural, aspectRatio: 0.68),
  ClipShapeMeta(id: 'compass', label: 'Compass', family: ShapeFamily.travel, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'ticket', label: 'Ticket', family: ShapeFamily.travel, source: ClipShapeSource.procedural, aspectRatio: 1.9, cornerRadius: true),
  ClipShapeMeta(id: 'luggageTag', label: 'Luggage tag', family: ShapeFamily.travel, source: ClipShapeSource.procedural, aspectRatio: 0.66, cornerRadius: true),
  ClipShapeMeta(id: 'postageStamp', label: 'Postage stamp', family: ShapeFamily.travel, source: ClipShapeSource.procedural, aspectRatio: 0.86),
  ClipShapeMeta(id: 'passportStamp', label: 'Passport stamp', family: ShapeFamily.travel, source: ClipShapeSource.procedural),
  ClipShapeMeta(id: 'entryStamp', label: 'Entry/exit stamp', family: ShapeFamily.travel, source: ClipShapeSource.procedural, aspectRatio: 1.5),

  // ── TYPOGRAPHIC ──────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'text', label: 'Text', family: ShapeFamily.typographic, source: ClipShapeSource.text, aspectRatio: 2.4),

  // ── GEOGRAPHIC (asset-backed via AssetResolver) ──────────────────────────
  ClipShapeMeta(id: 'countryOutline', label: 'Country boundary', family: ShapeFamily.geographic, source: ClipShapeSource.resolver, resolverKind: ClipShape.countryOutline),
  ClipShapeMeta(id: 'continentOutline', label: 'Region (continent)', family: ShapeFamily.geographic, source: ClipShapeSource.resolver, resolverKind: ClipShape.continentOutline),
  ClipShapeMeta(id: 'passportStampOutline', label: 'Passport stamp (real)', family: ShapeFamily.travel, source: ClipShapeSource.resolver, resolverKind: ClipShape.passportStampOutline),
  ClipShapeMeta(id: 'passportPage', label: 'Passport page (entry + exit)', family: ShapeFamily.travel, source: ClipShapeSource.resolver, resolverKind: ClipShape.passportPage, aspectRatio: 1.1),
  ClipShapeMeta(id: 'animalSilhouette', label: 'Animal silhouette', family: ShapeFamily.geographic, source: ClipShapeSource.resolver, resolverKind: ClipShape.animalSilhouette),
  ClipShapeMeta(id: 'plantSilhouette', label: 'Plant silhouette', family: ShapeFamily.geographic, source: ClipShapeSource.resolver, resolverKind: ClipShape.plantSilhouette),
  ClipShapeMeta(id: 'landmarkSilhouette', label: 'Landmark silhouette', family: ShapeFamily.geographic, source: ClipShapeSource.resolver, resolverKind: ClipShape.landmarkSilhouette),

  // ── CUSTOM ───────────────────────────────────────────────────────────────
  ClipShapeMeta(id: 'customSvg', label: 'Custom SVG', family: ShapeFamily.custom, source: ClipShapeSource.svgAsset),
];

final Map<String, ClipShapeMeta> _byId = {
  for (final m in kClipShapeCatalog) m.id: m,
};

/// Look up shape metadata by id (null if unknown).
ClipShapeMeta? clipShapeMetaById(String id) => _byId[id];

/// All shapes in a family, in catalog order.
List<ClipShapeMeta> clipShapesByFamily(ShapeFamily family) =>
    [for (final m in kClipShapeCatalog) if (m.family == family) m];
