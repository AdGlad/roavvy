/// A grid of small brushed hearts, one flag each (`DesignRecipe.heartWall`):
/// the many-country Heart Wall signature (M214). Every country the recipe's
/// `content.flags` lists gets a heart of the same size, in list order, in
/// rows of at most [maxColumns]; the last row is centred.
///
/// Each heart is painted like the Twin Hearts (hatched dry-brush strokes,
/// `BrushEdge.paintHatch`), only lighter. Sizes are fractions of a heart, so
/// preview and print match; everything is seeded from the recipe seed.
///
/// Like the other new groups, [toJson] writes every field.
class HeartWall {
  const HeartWall({
    this.maxColumns = 6,
    this.fill = 0.94,
    this.spacing = 0.08,
    this.tiltJitter = 3,
    this.squeeze = 0.5,
    this.hatchAngle = 0,
    this.hatchWidth = 0.09,
    this.spill = 0.3,
    this.tails = 0.4,
    this.streaks = 0.25,
    this.scratches = 0.15,
    this.frayed = true,
  });

  /// Most hearts in a row (the grid picks the column count that makes the
  /// hearts biggest, up to this).
  final int maxColumns;

  /// How much of the canvas the whole grid may use (each side).
  final double fill;

  /// Space between hearts, as a fraction of a heart's width.
  final double spacing;

  /// Each heart turns by up to this many degrees either way (seeded per
  /// heart), so the wall looks hand-placed; 0 = all upright.
  final double tiltJitter;

  /// Flag fit inside each heart: 0 = cover (crop), 1 = stretch the whole
  /// flag in (see `HeartPair.squeeze`).
  final double squeeze;

  /// Brush strokes, as in `HeartPair`: direction (degrees), thickness
  /// (fraction of a heart), spill past the outline, bristle tails, dry
  /// streaks, scratched grain, frayed (square-cut) ends.
  final double hatchAngle;
  final double hatchWidth;
  final double spill;
  final double tails;
  final double streaks;
  final double scratches;
  final bool frayed;

  Map<String, Object?> toJson() => {
        'maxColumns': maxColumns,
        'fill': fill,
        'spacing': spacing,
        'tiltJitter': tiltJitter,
        'squeeze': squeeze,
        'hatchAngle': hatchAngle,
        'hatchWidth': hatchWidth,
        'spill': spill,
        'tails': tails,
        'streaks': streaks,
        'scratches': scratches,
        'frayed': frayed,
      };

  factory HeartWall.fromJson(Map<String, Object?> j) {
    const d = HeartWall();
    double n(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    final w = HeartWall(
      maxColumns: (j['maxColumns'] as num?)?.toInt() ?? d.maxColumns,
      fill: n('fill', d.fill),
      spacing: n('spacing', d.spacing),
      tiltJitter: n('tiltJitter', d.tiltJitter),
      squeeze: n('squeeze', d.squeeze),
      hatchAngle: n('hatchAngle', d.hatchAngle),
      hatchWidth: n('hatchWidth', d.hatchWidth),
      spill: n('spill', d.spill),
      tails: n('tails', d.tails),
      streaks: n('streaks', d.streaks),
      scratches: n('scratches', d.scratches),
      frayed: j['frayed'] as bool? ?? d.frayed,
    );
    if (w.maxColumns < 1 || w.maxColumns > 12) {
      throw FormatException(
          'heartWall.maxColumns must be 1..12, not ${w.maxColumns}');
    }
    if (w.fill <= 0.2 || w.fill > 1) {
      throw FormatException(
          'heartWall.fill must be in (0.2, 1], not ${w.fill}');
    }
    if (w.hatchWidth <= 0.01 || w.hatchWidth > 0.3) {
      throw FormatException(
          'heartWall.hatchWidth must be in (0.01, 0.3], not ${w.hatchWidth}');
    }
    return w;
  }

  HeartWall copyWith({
    int? maxColumns,
    double? fill,
    double? spacing,
    double? tiltJitter,
    double? squeeze,
    double? hatchAngle,
    double? hatchWidth,
    double? spill,
    double? tails,
    double? streaks,
    double? scratches,
    bool? frayed,
  }) =>
      HeartWall(
        maxColumns: maxColumns ?? this.maxColumns,
        fill: fill ?? this.fill,
        spacing: spacing ?? this.spacing,
        tiltJitter: tiltJitter ?? this.tiltJitter,
        squeeze: squeeze ?? this.squeeze,
        hatchAngle: hatchAngle ?? this.hatchAngle,
        hatchWidth: hatchWidth ?? this.hatchWidth,
        spill: spill ?? this.spill,
        tails: tails ?? this.tails,
        streaks: streaks ?? this.streaks,
        scratches: scratches ?? this.scratches,
        frayed: frayed ?? this.frayed,
      );
}
