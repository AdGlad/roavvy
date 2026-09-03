import 'dart:ui' show Color;

import 'artwork_detail_analyzer.dart';

/// The set of selectable print styles (filters) that transform finished merch
/// artwork into a professional-apparel look. Everything is generated locally
/// and deterministically (see [PrintStyleParams.seed]).
///
/// [clean] is a verified pass-through — applying it returns the source artwork
/// byte-for-byte, so the default experience is unchanged.
///
/// New styles (Cracked Ink, Duotone, Stencil, Ink Bleed, Travel Patch, …) are
/// added by appending one enum value here and one entry in [kPrintStylePresets]
/// — no pipeline or call-site signature changes.
enum PrintStyleId {
  clean,
  vintage,
  retro,
  halftone,
  stamp,
  grunge,
  riso,
  newsprint,
  sunFaded,
  photocopy,
  edgeTear,
  acidWash,
  rippedFlag,
}

/// Colour grading applied before texture effects.
enum ColorTreatment {
  /// Leave colours untouched.
  none,

  /// Slightly desaturated, lower-contrast — modern-retro tees.
  muted,

  /// Warm, faded, aged-paper cast — vintage travel shirts.
  vintageWarm,

  /// Collapse to a single ink colour (used by [PrintStyleId.stamp]).
  monoInk,

  /// Two-tone mapping between [PrintStyleParams.duotoneA]/[duotoneB].
  duotone,
}

/// How aggressively detailed artwork auto-reduces distress. `0` disables the
/// auto-protection; `1` fully removes distress from maximally detailed art.
///
/// Kept intentionally < 1 so even busy grids receive a hint of texture.
const double kDetailGuard = 0.85;

/// Fully-resolved, deterministic parameters for a single styled render.
///
/// Intensities are in `0..1`. Coordinates for procedural textures (e.g.
/// [halftoneScale]) are expressed in **artwork-normalised** space so a low-res
/// preview and the high-res print render look identical.
///
/// Users pick a [PrintStyleId]; [kPrintStylePresets] supplies the base values;
/// [resolvedFor] then folds in the per-artwork [detailFactor] and injects the
/// analysis-derived protection mask.
class PrintStyleParams {
  const PrintStyleParams({
    required this.id,
    this.distress = 0,
    this.grain = 0,
    this.fade = 0,
    this.roughEdges = 0,
    this.cracks = 0,
    this.distressHardness = 0.5,
    this.acidWash = 0,
    this.halftone = 0,
    this.halftoneScale = 0.02,
    this.halftoneAngle = 0.7853981633974483, // 45°, the classic AM screen angle
    this.colorTreatment = ColorTreatment.none,
    this.duotoneA,
    this.duotoneB,
    this.seed = 0,
    this.detailFactor = 1.0,
    this.detail,
  });

  /// Which preset this instance derives from.
  final PrintStyleId id;

  /// Ink loss — distressed pixels become **transparent** so the garment shows
  /// through (never painted with the garment colour). `0..1`.
  final double distress;

  /// Film-grain intensity. `0..1`.
  final double grain;

  /// Desaturation + tonal lift toward a faded look. `0..1`.
  final double fade;

  /// Edge erosion / irregularity (rough screen-print / stamp edges). `0..1`.
  final double roughEdges;

  /// Branching crack network cut through the ink (cracked-paint / grunge).
  /// `0..1`.
  final double cracks;

  /// How sharply distress/rough-edge ink loss transitions. `0` = soft, cloudy
  /// fade (many washes); `1` = hard-edged worn chunks (heavy grunge / stamp).
  final double distressHardness;

  /// Cloudy acid-wash bleach: lightens the ink in soft low-frequency patches
  /// (masked to the artwork so the garment stays clean). `0..1`.
  final double acidWash;

  /// Halftone dot-treatment intensity. `0..1`.
  final double halftone;

  /// Halftone dot cell size in artwork-normalised units (fraction of the
  /// artwork's shorter side). Resolution-independent.
  final double halftoneScale;

  /// Angle (radians) of the AM halftone dot screen. Defaults to 45° — the angle
  /// the eye reads least as a grid; riso/newsprint can offset it.
  final double halftoneAngle;

  final ColorTreatment colorTreatment;

  /// Duotone endpoints (only used when [colorTreatment] is
  /// [ColorTreatment.duotone]).
  final Color? duotoneA;
  final Color? duotoneB;

  /// Deterministic seed driving every procedural texture. The same
  /// `(id, params, seed)` always produces identical artwork; persist this with
  /// the design to reproduce a print exactly.
  final int seed;

  /// Multiplier (`0..1`) applied to [distress], [roughEdges], [halftone] and
  /// scratch intensity to protect detailed artwork. `1.0` = full effect.
  /// Populated by [resolvedFor] from an [ArtworkDetail]; default `1.0`.
  final double detailFactor;

  /// The per-artwork analysis (global protection score + local edge mask).
  /// Null until [resolvedFor] is applied. The pipeline uses [ArtworkDetail]'s
  /// edge map to keep emblems/text inked even at high global distress.
  final ArtworkDetail? detail;

  /// True when this style leaves the artwork unchanged (fast pass-through).
  bool get isClean => id == PrintStyleId.clean;

  /// Effective distress after per-artwork detail protection.
  double get effectiveDistress => distress * detailFactor;

  /// Effective rough-edge amount after per-artwork detail protection.
  double get effectiveRoughEdges => roughEdges * detailFactor;

  /// Effective halftone intensity after per-artwork detail protection.
  double get effectiveHalftone => halftone * detailFactor;

  /// Effective crack intensity after per-artwork detail protection.
  double get effectiveCracks => cracks * detailFactor;

  PrintStyleParams copyWith({
    PrintStyleId? id,
    double? distress,
    double? grain,
    double? fade,
    double? roughEdges,
    double? cracks,
    double? distressHardness,
    double? acidWash,
    double? halftone,
    double? halftoneScale,
    double? halftoneAngle,
    ColorTreatment? colorTreatment,
    Color? duotoneA,
    Color? duotoneB,
    int? seed,
    double? detailFactor,
    ArtworkDetail? detail,
  }) {
    return PrintStyleParams(
      id: id ?? this.id,
      distress: distress ?? this.distress,
      grain: grain ?? this.grain,
      fade: fade ?? this.fade,
      roughEdges: roughEdges ?? this.roughEdges,
      cracks: cracks ?? this.cracks,
      distressHardness: distressHardness ?? this.distressHardness,
      acidWash: acidWash ?? this.acidWash,
      halftone: halftone ?? this.halftone,
      halftoneScale: halftoneScale ?? this.halftoneScale,
      halftoneAngle: halftoneAngle ?? this.halftoneAngle,
      colorTreatment: colorTreatment ?? this.colorTreatment,
      duotoneA: duotoneA ?? this.duotoneA,
      duotoneB: duotoneB ?? this.duotoneB,
      seed: seed ?? this.seed,
      detailFactor: detailFactor ?? this.detailFactor,
      detail: detail ?? this.detail,
    );
  }

  /// Folds a per-artwork [ArtworkDetail] into these params: computes
  /// [detailFactor] from the analysis and attaches the [detail] (for the local
  /// protection mask). Pure — the same inputs always produce the same result.
  ///
  /// `detailFactor = 1 - protection * kDetailGuard`, clamped to `0..1`, so more
  /// detailed artwork (higher `protection`) receives proportionally less
  /// distress/rough-edge/halftone.
  PrintStyleParams resolvedFor(ArtworkDetail detail) {
    final factor = (1.0 - detail.protection * kDetailGuard).clamp(0.0, 1.0);
    return copyWith(detailFactor: factor, detail: detail);
  }

  @override
  bool operator ==(Object other) =>
      other is PrintStyleParams &&
      other.id == id &&
      other.distress == distress &&
      other.grain == grain &&
      other.fade == fade &&
      other.roughEdges == roughEdges &&
      other.cracks == cracks &&
      other.distressHardness == distressHardness &&
      other.acidWash == acidWash &&
      other.halftone == halftone &&
      other.halftoneScale == halftoneScale &&
      other.halftoneAngle == halftoneAngle &&
      other.colorTreatment == colorTreatment &&
      other.duotoneA == duotoneA &&
      other.duotoneB == duotoneB &&
      other.seed == seed &&
      other.detailFactor == detailFactor;

  @override
  int get hashCode => Object.hash(
    id,
    distress,
    grain,
    fade,
    roughEdges,
    cracks,
    acidWash,
    halftone,
    halftoneScale,
    colorTreatment,
    duotoneA,
    duotoneB,
    seed,
    detailFactor,
  );
}

/// Base parameters for each selectable style. `detailFactor`/`detail` are filled
/// in per artwork via [PrintStyleParams.resolvedFor]; `seed` is overridden per
/// design so each generated shirt is unique yet reproducible.
const Map<PrintStyleId, PrintStyleParams> kPrintStylePresets = {
  PrintStyleId.clean: PrintStyleParams(id: PrintStyleId.clean),
  // "Distressed" garment-dye look: soft, cloudy many-washes fade + warm aged
  // palette. Low hardness keeps the ink loss gentle (ref: distressed.jpeg).
  PrintStyleId.vintage: PrintStyleParams(
    id: PrintStyleId.vintage,
    distress: 0.58,
    distressHardness: 0.30,
    grain: 0.42,
    fade: 0.55,
    roughEdges: 0.32,
    cracks: 0.28,
    colorTreatment: ColorTreatment.vintageWarm,
  ),
  // Screen-print retro: a visible 45° dot screen over a muted, lightly worn
  // fill.
  PrintStyleId.retro: PrintStyleParams(
    id: PrintStyleId.retro,
    distress: 0.28,
    distressHardness: 0.45,
    grain: 0.32,
    fade: 0.38,
    halftone: 0.55,
    halftoneScale: 0.030,
    colorTreatment: ColorTreatment.muted,
  ),
  // Pure comic/zine halftone: a strong 45° AM dot screen, minimal grain.
  PrintStyleId.halftone: PrintStyleParams(
    id: PrintStyleId.halftone,
    grain: 0.10,
    halftone: 1.0,
    halftoneScale: 0.034,
    colorTreatment: ColorTreatment.none,
  ),
  // Rubber-stamp: crisp single-ink, uneven coverage + hard rough edges.
  PrintStyleId.stamp: PrintStyleParams(
    id: PrintStyleId.stamp,
    distress: 0.50,
    distressHardness: 0.72,
    grain: 0.22,
    roughEdges: 0.85,
    colorTreatment: ColorTreatment.monoInk,
  ),
  // Heavy cracked-paint grunge: hard-edged chunky breakup, strong cracks, torn
  // edges (ref: grunge.jpeg).
  PrintStyleId.grunge: PrintStyleParams(
    id: PrintStyleId.grunge,
    distress: 0.72,
    distressHardness: 0.70,
    grain: 0.45,
    fade: 0.20,
    roughEdges: 0.66,
    cracks: 0.82,
    colorTreatment: ColorTreatment.muted,
  ),
  // Risograph: two flat spot inks (deep blue → fluoro pink) under an angled AM
  // dot screen with grain — the tell-tale riso zine look.
  PrintStyleId.riso: PrintStyleParams(
    id: PrintStyleId.riso,
    grain: 0.30,
    halftone: 0.60,
    halftoneScale: 0.030,
    halftoneAngle: 0.5235987755982988, // 30° — offset from the classic 45°
    colorTreatment: ColorTreatment.duotone,
    duotoneA: Color(0xFF2B2B8C), // ink shadow — riso federal blue
    duotoneB: Color(0xFFF7A9C4), // highlight — fluoro pink
  ),
  // Newsprint: grayscale single ink under a strong, coarse dot screen with paper
  // grain and a slight fade — a halftoned newspaper photo.
  PrintStyleId.newsprint: PrintStyleParams(
    id: PrintStyleId.newsprint,
    grain: 0.35,
    fade: 0.22,
    halftone: 0.85,
    halftoneScale: 0.026,
    colorTreatment: ColorTreatment.monoInk,
  ),
  // Sun-faded: heavily bleached, warm, low-saturation with the softest ink loss
  // — a shirt left in a shop window.
  PrintStyleId.sunFaded: PrintStyleParams(
    id: PrintStyleId.sunFaded,
    distress: 0.22,
    distressHardness: 0.18,
    grain: 0.20,
    fade: 0.80,
    roughEdges: 0.15,
    colorTreatment: ColorTreatment.vintageWarm,
  ),
  // Photocopy / xerox: harsh single-ink toner with heavy grain and hard-edged,
  // chipped ink loss.
  PrintStyleId.photocopy: PrintStyleParams(
    id: PrintStyleId.photocopy,
    distress: 0.34,
    distressHardness: 0.88,
    grain: 0.50,
    roughEdges: 0.32,
    colorTreatment: ColorTreatment.monoInk,
  ),
  // Edge Tear: a ripped-sticker / torn-poster boundary that frays deep into the
  // garment, over a lightly worn, clean interior.
  PrintStyleId.edgeTear: PrintStyleParams(
    id: PrintStyleId.edgeTear,
    distress: 0.16,
    distressHardness: 0.30,
    grain: 0.22,
    fade: 0.14,
    roughEdges: 0.92,
    colorTreatment: ColorTreatment.none,
  ),
  // Acid Wash: cloudy bleached patches lift the ink over a muted, faded palette
  // — the Y2K/washed streetwear look.
  PrintStyleId.acidWash: PrintStyleParams(
    id: PrintStyleId.acidWash,
    acidWash: 0.75,
    grain: 0.28,
    fade: 0.42,
    distress: 0.14,
    distressHardness: 0.20,
    colorTreatment: ColorTreatment.muted,
  ),
  // Ripped Flag: the artwork shows through a ragged vertical "gash" (the rest
  // goes transparent so the garment shows), weathered — the ripped-through-
  // fabric flag tee. The gash itself is applied by the pipeline (id-gated).
  PrintStyleId.rippedFlag: PrintStyleParams(
    id: PrintStyleId.rippedFlag,
    distress: 0.40,
    grain: 0.25,
    distressHardness: 0.45,
    colorTreatment: ColorTreatment.none,
  ),
};

/// Human-readable label for the style picker.
String printStyleLabel(PrintStyleId id) => switch (id) {
  PrintStyleId.clean => 'Clean',
  PrintStyleId.vintage => 'Vintage',
  PrintStyleId.retro => 'Retro',
  PrintStyleId.halftone => 'Halftone',
  PrintStyleId.stamp => 'Stamp',
  PrintStyleId.grunge => 'Grunge',
  PrintStyleId.riso => 'Riso',
  PrintStyleId.newsprint => 'Newsprint',
  PrintStyleId.sunFaded => 'Sun-Faded',
  PrintStyleId.photocopy => 'Photocopy',
  PrintStyleId.edgeTear => 'Edge Tear',
  PrintStyleId.acidWash => 'Acid Wash',
  PrintStyleId.rippedFlag => 'Ripped Flag',
};

/// Parses a persisted [PrintStyleId] name, tolerating unknown/missing values by
/// falling back to [PrintStyleId.clean] (backward-compatible: designs saved
/// before print styles existed render unchanged).
PrintStyleId printStyleFromName(String? name) {
  for (final id in PrintStyleId.values) {
    if (id.name == name) return id;
  }
  return PrintStyleId.clean;
}
