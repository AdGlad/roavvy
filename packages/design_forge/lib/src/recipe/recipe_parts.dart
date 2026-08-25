/// Optional, append-only recipe dimension groups. Each is nullable on
/// [DesignRecipe]; when present it contributes to the content hash. `toJson`
/// omits fields at their default so recipes stay compact and two logically-equal
/// recipes hash identically.

// ---------------------------------------------------------------------------
// Placement
// ---------------------------------------------------------------------------

enum LayoutMode {
  packedRow,
  normalizedGrid,
  treemap,
  montage;

  static LayoutMode fromId(String? id) {
    for (final v in LayoutMode.values) {
      if (v.name == id) return v;
    }
    return LayoutMode.packedRow;
  }
}

enum Density {
  sparse,
  balanced,
  dense;

  static Density fromId(String? id) {
    for (final v in Density.values) {
      if (v.name == id) return v;
    }
    return Density.balanced;
  }
}

/// How multiple flag instances are packed into the frame (the "fitting
/// algorithm"). Each partitions the frame into N regions, one per flag, filling
/// the available space. Append-only.
enum FillAlgorithm {
  grid, // uniform rows × columns
  treemap, // squarified nested rectangles
  diagonalStripe, // parallel diagonal bands
  voronoi, // nearest-seed cells
  tornRegion, // noise-perturbed cells with ragged boundaries
  noiseBlend, // organic blobs from a noise field
  radial, // pie sectors from the centre
  mosaic; // mixed-size quilt (some 2×2 blocks)

  static FillAlgorithm fromId(String? id) {
    for (final v in FillAlgorithm.values) {
      if (v.name == id) return v;
    }
    return FillAlgorithm.grid;
  }
}

/// Where the primary artwork sits within the frame.
class Placement {
  const Placement({
    this.anchorX = 0.5,
    this.anchorY = 0.5,
    this.scale = 1.0,
  });

  final double anchorX;
  final double anchorY;
  final double scale;

  Map<String, Object?> toJson() => {
        if (anchorX != 0.5) 'anchorX': anchorX,
        if (anchorY != 0.5) 'anchorY': anchorY,
        if (scale != 1.0) 'scale': scale,
      };

  factory Placement.fromJson(Map<String, Object?> j) => Placement(
        anchorX: (j['anchorX'] as num?)?.toDouble() ?? 0.5,
        anchorY: (j['anchorY'] as num?)?.toDouble() ?? 0.5,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
      );
}

// ---------------------------------------------------------------------------
// Flag combination
// ---------------------------------------------------------------------------

enum FlagCombineMode {
  mix,
  diagonalSplit,
  vertical,
  horizontal,
  wave,
  stripes,
  checker,
  radial,
  torn;

  static FlagCombineMode fromId(String? id) {
    for (final v in FlagCombineMode.values) {
      if (v.name == id) return v;
    }
    return FlagCombineMode.mix;
  }
}

/// How 2+ flags merge into one artwork (maps to `flag_blend.frag` modes).
class FlagCombination {
  const FlagCombination({
    this.mode = FlagCombineMode.mix,
    this.weightA = 0.5,
    this.seam = 0.0,
  });

  final FlagCombineMode mode;
  final double weightA;
  final double seam;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        if (weightA != 0.5) 'weightA': weightA,
        if (seam != 0.0) 'seam': seam,
      };

  factory FlagCombination.fromJson(Map<String, Object?> j) => FlagCombination(
        mode: FlagCombineMode.fromId(j['mode'] as String?),
        weightA: (j['weightA'] as num?)?.toDouble() ?? 0.5,
        seam: (j['seam'] as num?)?.toDouble() ?? 0.0,
      );
}

// ---------------------------------------------------------------------------
// Clip / shape
// ---------------------------------------------------------------------------

/// The asset-backed clip kinds the renderer resolves via `AssetResolver`. These
/// are a subset of the full shape catalog (see shape_catalog.dart); procedural,
/// text and custom-SVG shapes are identified by string id instead.
enum ClipShape {
  none,
  heart,
  circle,
  countryOutline,
  continentOutline,
  animalSilhouette,
  plantSilhouette,
  landmarkSilhouette,
  passportStampOutline,
  passportPage; // both entry + exit stamps overlaid at angles (code = country cc)

  /// Stable id, used as [Clip.shapeId].
  String get id => name;

  static ClipShape fromId(String? id) {
    for (final v in ClipShape.values) {
      if (v.name == id) return v;
    }
    return ClipShape.none;
  }

  /// Outline/silhouette shapes are single-country and need a resolvable [code].
  bool get needsCode =>
      this == ClipShape.countryOutline ||
      this == ClipShape.continentOutline ||
      this == ClipShape.animalSilhouette ||
      this == ClipShape.plantSilhouette ||
      this == ClipShape.landmarkSilhouette ||
      this == ClipShape.passportStampOutline ||
      this == ClipShape.passportPage;
}

/// A clip shape applied to the artwork. Identified by a string [shapeId] from
/// the shape catalog (geometric/travel/outdoor/geographic/symbolic/typographic/
/// custom), with reusable placement/geometry parameters that are independent of
/// any surface effect. Backward-compatible with the old `{shape}` form.
class Clip {
  const Clip({
    required this.shapeId,
    this.code,
    this.text,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    this.aspectRatio = 0.0, // 0 = use the shape's natural aspect
    this.cornerRadius = 0.0,
    this.feather = 0.0,
    this.position,
    this.scatter = 0.5,
    this.ink,
  });

  /// Convenience for the built-in [ClipShape] enum shapes.
  Clip.shape(
    ClipShape shape, {
    this.code,
    this.text,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    this.aspectRatio = 0.0,
    this.cornerRadius = 0.0,
    this.feather = 0.0,
    this.position,
    this.scatter = 0.5,
    this.ink,
  }) : shapeId = shape.id;

  /// Catalog id, e.g. 'circle', 'hexagon', 'luggageTag', 'text', 'countryOutline'.
  final String shapeId;

  /// Asset code for asset-backed shapes (ISO country/continent, silhouette slug,
  /// or a custom SVG key).
  final String? code;

  /// The string to render for typographic shapes.
  final String? text;

  /// Size as a fraction of the frame's limiting dimension (1.0 = fill).
  final double scale;

  /// Rotation in degrees, about the shape centre.
  final double rotationDeg;

  /// Width/height override (0 = the shape's natural aspect from the catalog).
  final double aspectRatio;

  /// Corner rounding 0..1 for shapes that support it (rounded rect, ticket…).
  final double cornerRadius;

  /// Soft-edge amount 0..1.
  final double feather;

  /// Where the shape sits in the frame (centre by default).
  final Placement? position;

  /// Passport collage: how far stamps scatter/spread apart within the page
  /// (0 = tight grid, 1 = maximum jitter). Ignored by other shapes.
  final double scatter;

  /// Passport collage ink mode: null/'flag' = each stamp filled with its own
  /// flag; 'black' / 'white' = plain solid ink on transparent (a real stamp).
  final String? ink;

  /// The [ClipShape] enum for asset-backed shapes, or null for procedural/text.
  ClipShape get resolverShape => ClipShape.fromId(shapeId);

  /// Legacy alias.
  ClipShape get shape => resolverShape;

  Map<String, Object?> toJson() => {
        'shapeId': shapeId,
        if (code != null) 'code': code,
        if (text != null) 'text': text,
        if (scale != 1.0) 'scale': scale,
        if (rotationDeg != 0.0) 'rotationDeg': rotationDeg,
        if (aspectRatio != 0.0) 'aspectRatio': aspectRatio,
        if (cornerRadius != 0.0) 'cornerRadius': cornerRadius,
        if (feather != 0.0) 'feather': feather,
        if (position != null) 'position': position!.toJson(),
        if (scatter != 0.5) 'scatter': scatter,
        if (ink != null) 'ink': ink,
      };

  factory Clip.fromJson(Map<String, Object?> j) => Clip(
        // Accept the new `shapeId` or the legacy `shape` enum name.
        shapeId: (j['shapeId'] ?? j['shape']) as String? ?? 'none',
        code: j['code'] as String?,
        text: j['text'] as String?,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        rotationDeg: (j['rotationDeg'] as num?)?.toDouble() ?? 0.0,
        aspectRatio: (j['aspectRatio'] as num?)?.toDouble() ?? 0.0,
        cornerRadius: (j['cornerRadius'] as num?)?.toDouble() ?? 0.0,
        feather: (j['feather'] as num?)?.toDouble() ?? 0.0,
        position: j['position'] == null
            ? null
            : Placement.fromJson((j['position'] as Map).cast<String, Object?>()),
        scatter: (j['scatter'] as num?)?.toDouble() ?? 0.5,
        ink: j['ink'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Edge treatment (torn / ripped OUTER edges)
// ---------------------------------------------------------------------------

enum TearStyle {
  lightlyWorn,
  ragged,
  tornCorners,
  battleWorn,
  deepRips,
  frayed,
  asymmetricTear,
  heavyEdgeDamage;

  static TearStyle fromId(String? id) {
    for (final v in TearStyle.values) {
      if (v.name == id) return v;
    }
    return TearStyle.ragged;
  }
}

/// A compact, curated-family view of the torn-edge geometry (the full per-edge
/// generator params live in the render layer's torn engine; a recipe carries the
/// family + global knobs + seed, and the generator expands them deterministically).
class EdgeTreatment {
  const EdgeTreatment({
    this.style = TearStyle.ragged,
    this.edgeDamage = 0.5,
    this.maxDepth = 0.2,
    this.frayAmount = 0.5,
    this.cornerDamage = 0.3,
    this.asymmetry = 0.5,
  });

  final TearStyle style;
  final double edgeDamage;
  final double maxDepth;
  final double frayAmount;
  final double cornerDamage;
  final double asymmetry;

  Map<String, Object?> toJson() => {
        'style': style.name,
        if (edgeDamage != 0.5) 'edgeDamage': edgeDamage,
        if (maxDepth != 0.2) 'maxDepth': maxDepth,
        if (frayAmount != 0.5) 'frayAmount': frayAmount,
        if (cornerDamage != 0.3) 'cornerDamage': cornerDamage,
        if (asymmetry != 0.5) 'asymmetry': asymmetry,
      };

  factory EdgeTreatment.fromJson(Map<String, Object?> j) => EdgeTreatment(
        style: TearStyle.fromId(j['style'] as String?),
        edgeDamage: (j['edgeDamage'] as num?)?.toDouble() ?? 0.5,
        maxDepth: (j['maxDepth'] as num?)?.toDouble() ?? 0.2,
        frayAmount: (j['frayAmount'] as num?)?.toDouble() ?? 0.5,
        cornerDamage: (j['cornerDamage'] as num?)?.toDouble() ?? 0.3,
        asymmetry: (j['asymmetry'] as num?)?.toDouble() ?? 0.5,
      );
}

// ---------------------------------------------------------------------------
// Palette / colour
// ---------------------------------------------------------------------------

enum ColourStrategy {
  flagDerived,
  brand,
  garmentAware,
  duotone,
  monochrome;

  static ColourStrategy fromId(String? id) {
    for (final v in ColourStrategy.values) {
      if (v.name == id) return v;
    }
    return ColourStrategy.flagDerived;
  }
}

class Palette {
  const Palette({
    this.garmentColour,
    this.strategy = ColourStrategy.flagDerived,
    this.accents = const [],
    this.vintageGrade = 0.0,
    this.contrastInk = false,
    this.adaptiveInk,
  });

  final String? garmentColour;
  final ColourStrategy strategy;
  final List<String> accents;
  final double vintageGrade;

  /// Marks this design's ink as ADAPTIVE — re-inked for garment contrast under
  /// [ColourStrategy.garmentAware]. The renderer already treats text/typographic
  /// and solid passport-stamp ink as adaptive from the recipe structure; set this
  /// for line-art/outline/silhouette designs whose ink is not flag-derived and
  /// which the structural heuristic can't otherwise detect. Append-only.
  final bool contrastInk;

  /// Optional explicit adaptive-ink colour (hex `#rrggbb` or `#aarrggbb`). When
  /// set, [ColourStrategy.garmentAware] recolours adaptive ink to this exact
  /// colour instead of the auto-computed near-black/near-white contrast tone.
  /// Append-only.
  final String? adaptiveInk;

  Map<String, Object?> toJson() => {
        if (garmentColour != null) 'garmentColour': garmentColour,
        'strategy': strategy.name,
        if (accents.isNotEmpty) 'accents': accents,
        if (vintageGrade != 0.0) 'vintageGrade': vintageGrade,
        if (contrastInk) 'contrastInk': contrastInk,
        if (adaptiveInk != null) 'adaptiveInk': adaptiveInk,
      };

  factory Palette.fromJson(Map<String, Object?> j) => Palette(
        garmentColour: j['garmentColour'] as String?,
        strategy: ColourStrategy.fromId(j['strategy'] as String?),
        accents: [for (final a in (j['accents'] as List? ?? const [])) a as String],
        vintageGrade: (j['vintageGrade'] as num?)?.toDouble() ?? 0.0,
        contrastInk: (j['contrastInk'] as bool?) ?? false,
        adaptiveInk: j['adaptiveInk'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Effects (continuous treatments — distress/grain/fade/halftone/ripple)
// ---------------------------------------------------------------------------

class Effects {
  const Effects({
    this.distress = 0.0,
    this.distressHardness = 0.5,
    this.grain = 0.0,
    this.fade = 0.0,
    this.cracks = 0.0,
    this.halftone = 0.0,
    this.halftoneScale = 6.0,
    this.halftoneAngle = 0.0,
    this.rippleAmp = 0.0,
    this.rippleFreq = 8.0,
    this.acidWash = 0.0,
    this.tieDye = 0.0,
    this.shatter = 0.0,
    this.shatterSpikes = 0.0,
  });

  final double distress;
  final double distressHardness;
  final double grain;
  final double fade;
  final double cracks;
  final double halftone;
  final double halftoneScale;
  final double halftoneAngle;
  final double rippleAmp;
  final double rippleFreq;
  final double acidWash;

  /// Psychedelic tie-dye colour wash (0 = off, 1 = full-strength concentric
  /// rainbow bleed blended over the artwork).
  final double tieDye;

  /// Radial "shatter/explosion" warp (0 = off, 1 = full): the artwork is blown
  /// into sharp zigzag shards radiating from a centre, with a spiky torn
  /// silhouette. The signature "extreme" abstract look.
  final double shatter;

  /// Number of shatter spikes/arms as a 0..1 knob (0 → engine default ~14,
  /// 1 → dense ~40). Ignored when [shatter] is 0.
  final double shatterSpikes;

  bool get isIdentity =>
      distress == 0 &&
      grain == 0 &&
      fade == 0 &&
      cracks == 0 &&
      halftone == 0 &&
      rippleAmp == 0 &&
      acidWash == 0 &&
      tieDye == 0 &&
      shatter == 0;

  Map<String, Object?> toJson() => {
        if (distress != 0.0) 'distress': distress,
        if (distress != 0.0 && distressHardness != 0.5)
          'distressHardness': distressHardness,
        if (grain != 0.0) 'grain': grain,
        if (fade != 0.0) 'fade': fade,
        if (cracks != 0.0) 'cracks': cracks,
        if (halftone != 0.0) 'halftone': halftone,
        if (halftone != 0.0 && halftoneScale != 6.0) 'halftoneScale': halftoneScale,
        if (halftone != 0.0 && halftoneAngle != 0.0) 'halftoneAngle': halftoneAngle,
        if (rippleAmp != 0.0) 'rippleAmp': rippleAmp,
        if (rippleAmp != 0.0 && rippleFreq != 8.0) 'rippleFreq': rippleFreq,
        if (acidWash != 0.0) 'acidWash': acidWash,
        if (tieDye != 0.0) 'tieDye': tieDye,
        if (shatter != 0.0) 'shatter': shatter,
        if (shatter != 0.0 && shatterSpikes != 0.0) 'shatterSpikes': shatterSpikes,
      };

  factory Effects.fromJson(Map<String, Object?> j) => Effects(
        distress: (j['distress'] as num?)?.toDouble() ?? 0.0,
        distressHardness: (j['distressHardness'] as num?)?.toDouble() ?? 0.5,
        grain: (j['grain'] as num?)?.toDouble() ?? 0.0,
        fade: (j['fade'] as num?)?.toDouble() ?? 0.0,
        cracks: (j['cracks'] as num?)?.toDouble() ?? 0.0,
        halftone: (j['halftone'] as num?)?.toDouble() ?? 0.0,
        halftoneScale: (j['halftoneScale'] as num?)?.toDouble() ?? 6.0,
        halftoneAngle: (j['halftoneAngle'] as num?)?.toDouble() ?? 0.0,
        rippleAmp: (j['rippleAmp'] as num?)?.toDouble() ?? 0.0,
        rippleFreq: (j['rippleFreq'] as num?)?.toDouble() ?? 8.0,
        acidWash: (j['acidWash'] as num?)?.toDouble() ?? 0.0,
        tieDye: (j['tieDye'] as num?)?.toDouble() ?? 0.0,
        shatter: (j['shatter'] as num?)?.toDouble() ?? 0.0,
        shatterSpikes: (j['shatterSpikes'] as num?)?.toDouble() ?? 0.0,
      );
}

// ---------------------------------------------------------------------------
// Typography (treatment only — the printed STRING is generated downstream and
// is NOT part of the reproducible genome)
// ---------------------------------------------------------------------------

enum TextCase {
  upper,
  title,
  lower,
  asIs;

  static TextCase fromId(String? id) {
    for (final v in TextCase.values) {
      if (v.name == id) return v;
    }
    return TextCase.asIs;
  }
}

enum TextPlacement {
  top,
  bottom,
  none;

  static TextPlacement fromId(String? id) {
    for (final v in TextPlacement.values) {
      if (v.name == id) return v;
    }
    return TextPlacement.none;
  }
}

class Typography {
  const Typography({
    this.titleStyle,
    this.textCase = TextCase.asIs,
    this.placement = TextPlacement.none,
  });

  final String? titleStyle;
  final TextCase textCase;
  final TextPlacement placement;

  Map<String, Object?> toJson() => {
        if (titleStyle != null) 'titleStyle': titleStyle,
        'case': textCase.name,
        'placement': placement.name,
      };

  factory Typography.fromJson(Map<String, Object?> j) => Typography(
        titleStyle: j['titleStyle'] as String?,
        textCase: TextCase.fromId(j['case'] as String?),
        placement: TextPlacement.fromId(j['placement'] as String?),
      );
}

// ---------------------------------------------------------------------------
// Motifs (decorative silhouettes/landmarks/symbols)
// ---------------------------------------------------------------------------

enum MotifKind {
  animal,
  plant,
  landmark,
  symbol;

  static MotifKind fromId(String? id) {
    for (final v in MotifKind.values) {
      if (v.name == id) return v;
    }
    return MotifKind.symbol;
  }
}

class Motif {
  const Motif({
    required this.kind,
    required this.slug,
    this.countryCode,
  });

  final MotifKind kind;
  final String slug;
  final String? countryCode;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'slug': slug,
        if (countryCode != null) 'countryCode': countryCode,
      };

  factory Motif.fromJson(Map<String, Object?> j) => Motif(
        kind: MotifKind.fromId(j['kind'] as String?),
        slug: j['slug']! as String,
        countryCode: j['countryCode'] as String?,
      );
}
