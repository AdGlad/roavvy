/// The flag painted as one broad brush stroke (`DesignRecipe.brushStroke`),
/// the Brush Flag signature (M208): a solid painted block whose top and
/// bottom edges wobble gently with a few nicks, whose trailing (right) end
/// lifts off in jagged pointed spikes, built from a few bands that start and
/// end at slightly different places, with a nearly clean leading edge. The
/// flag inside is never cut or recoloured.
///
/// The same parameters drive the reusable edge treatment (`BrushEdge` in
/// design_forge_render), which brushes the outline of ANY shape — a heart, a
/// split block. Sizes are fractions of the shape's own box, so preview and
/// print match.
///
/// Like the other new groups, [toJson] writes every field.
class BrushStroke {
  const BrushStroke({
    this.bristles = 20,
    this.dryness = 0.5,
    this.liftFray = 0.5,
    this.leadClean = 0.85,
    this.taper = 0.7,
    this.spill = 0.5,
    this.skew = 0,
    this.scale = 0.84,
    this.centerY = 0.6,
    this.minAspect = 1.3,
    this.maxAspect = 2.0,
  });

  /// How many lift-off spikes run across the trailing edge.
  final double bristles;

  /// Roughness of the edges along the stroke: wobble and small nicks
  /// (0 = smooth).
  final double dryness;

  /// Length of the lift-off spikes at the trailing end (0 = square end,
  /// 1 = spikes up to about an eighth of the stroke's length).
  final double liftFray;

  /// How clean the leading (left) edge stays compared with the rest
  /// (1 = straight, 0 = as ragged as the top and bottom).
  final double leadClean;

  /// How much the lift-off leans (the bottom reaches further; 0 = none).
  final double taper;

  /// How staggered the painted bands are: each starts and ends at a
  /// slightly different place (0 = one clean block).
  final double spill;

  /// Rotation of the whole stroke, degrees anticlockwise (small, ±3).
  final double skew;

  /// Stroke width as a fraction of the canvas width (Brush Flag stage only).
  final double scale;

  /// Vertical centre of the stroke as a fraction of the canvas height, so a
  /// caption fits above (Brush Flag stage only).
  final double centerY;

  /// The stroke takes the flag's own aspect, clamped to this range, so a
  /// square (CH) or tall (NP) flag still reads as a brush stroke and a very
  /// long one (QA) stays printable.
  final double minAspect;
  final double maxAspect;

  Map<String, Object?> toJson() => {
        'bristles': bristles,
        'dryness': dryness,
        'liftFray': liftFray,
        'leadClean': leadClean,
        'taper': taper,
        'spill': spill,
        'skew': skew,
        'scale': scale,
        'centerY': centerY,
        'minAspect': minAspect,
        'maxAspect': maxAspect,
      };

  factory BrushStroke.fromJson(Map<String, Object?> j) {
    const d = BrushStroke();
    double n(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    final b = BrushStroke(
      bristles: n('bristles', d.bristles),
      dryness: n('dryness', d.dryness),
      liftFray: n('liftFray', d.liftFray),
      leadClean: n('leadClean', d.leadClean),
      taper: n('taper', d.taper),
      spill: n('spill', d.spill),
      skew: n('skew', d.skew),
      scale: n('scale', d.scale),
      centerY: n('centerY', d.centerY),
      minAspect: n('minAspect', d.minAspect),
      maxAspect: n('maxAspect', d.maxAspect),
    );
    if (b.bristles < 3 || b.bristles > 40) {
      throw FormatException(
          'brushStroke.bristles must be 3..40, not ${b.bristles}');
    }
    if (b.minAspect <= 0 || b.maxAspect < b.minAspect) {
      throw const FormatException('brushStroke aspect range is empty');
    }
    return b;
  }

  BrushStroke copyWith({
    double? bristles,
    double? dryness,
    double? liftFray,
    double? leadClean,
    double? taper,
    double? spill,
    double? skew,
    double? scale,
    double? centerY,
    double? minAspect,
    double? maxAspect,
  }) =>
      BrushStroke(
        bristles: bristles ?? this.bristles,
        dryness: dryness ?? this.dryness,
        liftFray: liftFray ?? this.liftFray,
        leadClean: leadClean ?? this.leadClean,
        taper: taper ?? this.taper,
        spill: spill ?? this.spill,
        skew: skew ?? this.skew,
        scale: scale ?? this.scale,
        centerY: centerY ?? this.centerY,
        minAspect: minAspect ?? this.minAspect,
        maxAspect: maxAspect ?? this.maxAspect,
      );
}
