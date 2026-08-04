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
    this.halftone = 0,
    this.halftoneScale = 0.02,
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

  /// Halftone dot-treatment intensity. `0..1`.
  final double halftone;

  /// Halftone dot cell size in artwork-normalised units (fraction of the
  /// artwork's shorter side). Resolution-independent.
  final double halftoneScale;

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

  PrintStyleParams copyWith({
    PrintStyleId? id,
    double? distress,
    double? grain,
    double? fade,
    double? roughEdges,
    double? halftone,
    double? halftoneScale,
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
      halftone: halftone ?? this.halftone,
      halftoneScale: halftoneScale ?? this.halftoneScale,
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
      other.halftone == halftone &&
      other.halftoneScale == halftoneScale &&
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
  PrintStyleId.vintage: PrintStyleParams(
    id: PrintStyleId.vintage,
    distress: 0.30,
    grain: 0.35,
    fade: 0.45,
    roughEdges: 0.20,
    colorTreatment: ColorTreatment.vintageWarm,
  ),
  PrintStyleId.retro: PrintStyleParams(
    id: PrintStyleId.retro,
    distress: 0.15,
    grain: 0.30,
    fade: 0.35,
    halftone: 0.25,
    halftoneScale: 0.025,
    colorTreatment: ColorTreatment.muted,
  ),
  PrintStyleId.halftone: PrintStyleParams(
    id: PrintStyleId.halftone,
    grain: 0.10,
    halftone: 0.85,
    halftoneScale: 0.018,
    colorTreatment: ColorTreatment.none,
  ),
  PrintStyleId.stamp: PrintStyleParams(
    id: PrintStyleId.stamp,
    distress: 0.45,
    grain: 0.25,
    roughEdges: 0.75,
    colorTreatment: ColorTreatment.monoInk,
  ),
  PrintStyleId.grunge: PrintStyleParams(
    id: PrintStyleId.grunge,
    distress: 0.65,
    grain: 0.45,
    fade: 0.20,
    roughEdges: 0.55,
    colorTreatment: ColorTreatment.muted,
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
