/// Watercolour painting of the clipped artwork (`DesignRecipe.watercolour`):
/// the flag looks hand-painted with a wet brush on paper — wobbly edges,
/// colours bleeding softly into each other, uneven pigment with lighter
/// blooms, darker rims where the paint dried, fine grain, whites that read as
/// warm paper, and a few splatter dots.
///
/// Works on any clip (heart, circle, country outline …) and any flag. All
/// sizes are fractions of the canvas short side and every random choice comes
/// from the recipe seed, so a preview and the print show the same painting.
///
/// Like [TornStrips], [toJson] writes every field: the group is new, so there
/// are no legacy recipe ids to protect.
class Watercolour {
  const Watercolour({
    this.wobble = 0.7,
    this.wobbleScale = 0.5,
    this.bleed = 0.45,
    this.pigment = 0.75,
    this.blooms = 0.55,
    this.streaks = 0.45,
    this.tideLine = 0.5,
    this.granulation = 0.35,
    this.raggedEdge = 0.5,
    this.splatter = 0.3,
    this.saturation = 1.0,
    this.paper = '#FBF6EC',
  });

  /// How far colour edges (and the outline) wander off their straight lines,
  /// like a hand-held brush (0 = ruler-straight).
  final double wobble;

  /// Size of the wobbles (0 = fine ripples, 1 = long slow waves).
  final double wobbleScale;

  /// How much neighbouring colours run into each other (0 = crisp edges).
  final double bleed;

  /// Uneven pigment: darker pools and lighter washes across each colour.
  final double pigment;

  /// Pale "cauliflower" patches where water pushed the pigment away.
  final double blooms;

  /// Dry-brush streaks along the brush direction (horizontal), where the
  /// brush skipped and the paper shows through.
  final double streaks;

  /// Darker rims where paint pooled and dried at the edge of each colour and
  /// along the outline.
  final double tideLine;

  /// Fine paper-tooth grain in the pigment.
  final double granulation;

  /// How irregular and soft the outer edge of the painting is.
  final double raggedEdge;

  /// Small paint droplets around the painting.
  final double splatter;

  /// Colour saturation multiplier (1 = the flag's own colours).
  final double saturation;

  /// The paper colour whites become, `#RRGGBB`.
  final String paper;

  Map<String, Object?> toJson() => {
        'wobble': wobble,
        'wobbleScale': wobbleScale,
        'bleed': bleed,
        'pigment': pigment,
        'blooms': blooms,
        'streaks': streaks,
        'tideLine': tideLine,
        'granulation': granulation,
        'raggedEdge': raggedEdge,
        'splatter': splatter,
        'saturation': saturation,
        'paper': paper,
      };

  factory Watercolour.fromJson(Map<String, Object?> j) {
    const d = Watercolour();
    double n(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    final paper = j['paper'] as String? ?? d.paper;
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(paper)) {
      throw FormatException('watercolour.paper must be #RRGGBB, not $paper');
    }
    return Watercolour(
      wobble: n('wobble', d.wobble),
      wobbleScale: n('wobbleScale', d.wobbleScale),
      bleed: n('bleed', d.bleed),
      pigment: n('pigment', d.pigment),
      blooms: n('blooms', d.blooms),
      streaks: n('streaks', d.streaks),
      tideLine: n('tideLine', d.tideLine),
      granulation: n('granulation', d.granulation),
      raggedEdge: n('raggedEdge', d.raggedEdge),
      splatter: n('splatter', d.splatter),
      saturation: n('saturation', d.saturation),
      paper: paper,
    );
  }
}
