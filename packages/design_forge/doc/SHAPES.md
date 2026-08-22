# Clip Shape Registry — architecture

Clip shapes are a **data-driven, extensible** part of the `DesignRecipe`, not a
hard-coded enum. Pipeline position is unchanged and effect-independent:

```
Design Artwork → Clip Shape → Edge Treatment → Effects → Output
```

## The registry (pure `design_forge`)

`src/recipe/shape_catalog.dart` — `kClipShapeCatalog: List<ClipShapeMeta>`.

```dart
class ClipShapeMeta {
  final String id;            // 'hexagon', 'luggageTag', 'text', 'countryOutline'
  final String label;         // Lab display name
  final ShapeFamily family;   // geometric/travel/outdoor/geographic/symbolic/typographic/custom
  final ClipShapeSource source; // procedural | text | resolver | svgAsset
  final double aspectRatio;   // natural W/H
  final bool cornerRadius;    // honours Clip.cornerRadius
  final ClipShape? resolverKind; // for source==resolver
}
```

Helpers: `clipShapeMetaById(id)`, `clipShapesByFamily(family)`.

## Recipe (extended, backward compatible)

`Clip { shapeId, code, text, scale, rotationDeg, aspectRatio, cornerRadius,
feather, position }`. Old `{shape: <enum>}` recipes still decode (`shape`→
`shapeId`); `Clip.shape(ClipShape, …)` convenience kept for the enum shapes.

## One shape-agnostic stage (`design_forge_render`)

`ClipStage` never special-cases a shape id. It:
1. looks up `ClipShapeMeta` by `shapeId`;
2. computes ONE target rect from `scale × aspect`, centred at `position`;
3. resolves geometry by `source`:
   - **procedural** → `ShapeGeometry.build(id, rect, cornerRadius)` → `ui.Path`,
     rotated about centre, `clipPath` (or feathered mask);
   - **text** → `TextMask.build(...)` → glyph alpha mask, `dstIn`;
   - **resolver** → `AssetResolver.resolveClipMask(kind, code)` → alpha mask, `dstIn`
     (country/continent outlines, animal/plant/landmark silhouettes);
   - **svgAsset** → resolver by `code` (custom SVG; wiring TBD).

**Adding a shape:**
- *SVG/asset*: drop the asset + add a `ClipShapeMeta` — **no renderer code**.
- *procedural*: add a `ClipShapeMeta` + one entry in `ShapeGeometry._builders`.
- *text*: already generic (any string).

## Shapes shipped (M1)

Geometric: circle, oval, rounded rectangle, arch, diamond, triangle, hexagon,
shield. Symbolic: heart, star, lightning. Outdoor: mountain, wave, island,
sunset. Travel: map pin, compass, ticket, luggage tag, postage stamp, passport
stamp, entry/exit stamp. Typographic: text (any word/name/number, incl. the
country's own name). Geographic: country outline,
continent outline, animal/plant/landmark silhouettes, real per-country passport
entry/exit stamps (`passportStampOutline`, resolver mask — the flag fills the
stamp's ink), and a `passportPage` that overlays a country's entry + exit stamps
at opposing angles like stamps on a passport page. Custom: customSvg (stub).

Verified: all 22 procedural+text shapes render a flag through the mask
(`shapes_export_test.dart`), independent of composition (single/grid/voronoi/…),
edge treatment and effects.

## Performance

- Procedural shapes are `ui.Path` clips — effectively free, resolution-independent.
- Text + asset masks rasterise once at the target size; cache by shape+size in the
  resolver (already done for SVG/outline). Text masks can be cached by
  (text, size, rotation) if profiling shows a cost in the feed.
- `Path.combine` (ticket/luggage/stamp) is CPU but one-off per render.

## Milestones

- **M1 (done)** registry + shape-agnostic stage + geometric/symbolic/outdoor/
  travel procedural shapes + text masks + recipe params (scale/rotation/aspect/
  cornerRadius/position).
- **M2 (done)** Lab: browse by Family → Shape, live scale/rotation/corner/text.
- **M3** batch-across-shapes in the Lab + studio evaluation to cull weak shapes
  (lightning/wave/compass are candidates); custom-SVG upload; world-map shape;
  transform (scale/rotation) for asset masks; bundled display font for text.
