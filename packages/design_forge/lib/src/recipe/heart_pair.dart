/// Two flags in hearts, painted with a dry brush (`DesignRecipe.heartPair`):
/// the two-country Shared Heart (M210) and Twin Hearts (M211) signatures
/// (ADR-185).
///
/// * [layout] `shared` — ONE heart, flag A in the left lobe and flag B in the
///   right, meeting along a slightly hand-drawn vertical seam.
/// * [layout] `twin` — TWO hearts side by side, one whole flag each, tilted a
///   little toward each other.
///
/// Either way the heart is painted as hatched brush strokes ([hatchAngle],
/// [hatchWidth]) whose ends spill past the outline or stop short of it
/// ([spill]), with thin bristle tails ([tails]) and dry streaks running in
/// from the stroke ends ([streaks]), then scratched ([scratches]). Sizes are
/// fractions of the heart, so preview and print match; everything is seeded
/// from the recipe seed.
///
/// The geometry (where each flag sits, which part of it shows, where the seam
/// runs) is pure Dart in `HeartPairLayout`, shared by the renderer and pair QA.
///
/// Like the other new groups, [toJson] writes every field.
class HeartPair {
  const HeartPair({
    this.layout = shared,
    this.heartScale = 0.86,
    this.seamPosition = 0.5,
    this.seamCurve = 0.3,
    this.seamLean = 0,
    this.gap = 0.05,
    this.tilt = 8,
    this.squeeze = 0.35,
    this.hatchAngle = -55,
    this.hatchWidth = 0.05,
    this.spill = 0.5,
    this.tails = 0.5,
    this.streaks = 0.3,
    this.scratches = 0.35,
    this.frayed = false,
    this.crossHatch = 0,
  });

  static const String shared = 'shared';
  static const String twin = 'twin';

  /// [shared] (one heart, two halves) or [twin] (two hearts).
  final String layout;

  /// Heart size: the shared heart's width as a fraction of the canvas's
  /// shorter side; for twin hearts the pair's width as a fraction of the
  /// canvas width.
  final double heartScale;

  /// Shared: where the seam crosses, as a fraction of the heart's width
  /// (0.5 = middle). Kept near the middle so neither flag dominates.
  final double seamPosition;

  /// Shared: how much the seam bows (fraction of a small maximum; 0 = straight,
  /// negative bows the other way).
  final double seamCurve;

  /// Shared: how much the seam leans (positive = bottom further right).
  final double seamLean;

  /// Twin: space between the two hearts, fraction of the canvas width.
  final double gap;

  /// Twin: degrees each heart turns toward the other (mirrored).
  final double tilt;

  /// How a flag is fitted into its part of the heart: 0 = cover (crop, true
  /// proportions), 1 = stretch the whole flag in. A flag's emblem/canton
  /// box is always squeezed in when it would not otherwise fit.
  final double squeeze;

  /// Direction of the brush hatching, degrees (0 = horizontal strokes,
  /// negative = rising to the right).
  final double hatchAngle;

  /// Brush stroke thickness, fraction of the heart's size.
  final double hatchWidth;

  /// How far stroke ends spill past (or stop short of) the outline.
  final double spill;

  /// Thin bristle tails trailing from the stroke ends (0 = none).
  final double tails;

  /// Dry streaks: thin unpainted lines running in from the stroke ends
  /// (0 = none).
  final double streaks;

  /// Scratched distress across the paint (0 = none).
  final double scratches;

  /// Square-cut strokes whose ends break into a fan of bristles (true), or
  /// round, scalloped stroke ends (false).
  final bool frayed;

  /// A second, crossing pass of strokes (at [hatchAngle] + 70°) whose ends
  /// spill [crossHatch] as far, so edges parallel to the first pass are
  /// scribbled too (0 = off).
  final double crossHatch;

  bool get isTwin => layout == twin;

  Map<String, Object?> toJson() => {
        'layout': layout,
        'heartScale': heartScale,
        'seamPosition': seamPosition,
        'seamCurve': seamCurve,
        'seamLean': seamLean,
        'gap': gap,
        'tilt': tilt,
        'squeeze': squeeze,
        'hatchAngle': hatchAngle,
        'hatchWidth': hatchWidth,
        'spill': spill,
        'tails': tails,
        'streaks': streaks,
        'scratches': scratches,
        'frayed': frayed,
        'crossHatch': crossHatch,
      };

  factory HeartPair.fromJson(Map<String, Object?> j) {
    const d = HeartPair();
    double n(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    final layout = j['layout'] as String? ?? d.layout;
    if (layout != shared && layout != twin) {
      throw FormatException(
          'heartPair.layout must be "$shared" or "$twin", not "$layout"');
    }
    final h = HeartPair(
      layout: layout,
      heartScale: n('heartScale', d.heartScale),
      seamPosition: n('seamPosition', d.seamPosition),
      seamCurve: n('seamCurve', d.seamCurve),
      seamLean: n('seamLean', d.seamLean),
      gap: n('gap', d.gap),
      tilt: n('tilt', d.tilt),
      squeeze: n('squeeze', d.squeeze),
      hatchAngle: n('hatchAngle', d.hatchAngle),
      hatchWidth: n('hatchWidth', d.hatchWidth),
      spill: n('spill', d.spill),
      tails: n('tails', d.tails),
      streaks: n('streaks', d.streaks),
      scratches: n('scratches', d.scratches),
      frayed: j['frayed'] as bool? ?? d.frayed,
      crossHatch: n('crossHatch', d.crossHatch),
    );
    if (h.heartScale <= 0.1 || h.heartScale > 1) {
      throw FormatException(
          'heartPair.heartScale must be in (0.1, 1], not ${h.heartScale}');
    }
    if (h.hatchWidth <= 0.005 || h.hatchWidth > 0.2) {
      throw FormatException(
          'heartPair.hatchWidth must be in (0.005, 0.2], not ${h.hatchWidth}');
    }
    if (h.seamPosition < 0.3 || h.seamPosition > 0.7) {
      throw FormatException(
          'heartPair.seamPosition must be 0.3..0.7, not ${h.seamPosition}');
    }
    return h;
  }

  HeartPair copyWith({
    String? layout,
    double? heartScale,
    double? seamPosition,
    double? seamCurve,
    double? seamLean,
    double? gap,
    double? tilt,
    double? squeeze,
    double? hatchAngle,
    double? hatchWidth,
    double? spill,
    double? tails,
    double? streaks,
    double? scratches,
    bool? frayed,
    double? crossHatch,
  }) =>
      HeartPair(
        layout: layout ?? this.layout,
        heartScale: heartScale ?? this.heartScale,
        seamPosition: seamPosition ?? this.seamPosition,
        seamCurve: seamCurve ?? this.seamCurve,
        seamLean: seamLean ?? this.seamLean,
        gap: gap ?? this.gap,
        tilt: tilt ?? this.tilt,
        squeeze: squeeze ?? this.squeeze,
        hatchAngle: hatchAngle ?? this.hatchAngle,
        hatchWidth: hatchWidth ?? this.hatchWidth,
        spill: spill ?? this.spill,
        tails: tails ?? this.tails,
        streaks: streaks ?? this.streaks,
        scratches: scratches ?? this.scratches,
        frayed: frayed ?? this.frayed,
        crossHatch: crossHatch ?? this.crossHatch,
      );
}
