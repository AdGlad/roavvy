/// A flag wrapped onto a ball (`DesignRecipe.globe`): the flag is projected
/// onto the front of a sphere so its stripes curve, lit from one side with a
/// soft highlight and darker edges, scattered with faint sparkle stars, and
/// ringed by a sticker-style rim.
///
/// Used with a `circle` clip: the sphere's radius is the clip's. Works for any
/// flag. Like the other new groups, [toJson] writes every field.
class Globe {
  const Globe({
    this.bulge = 0.85,
    this.zoom = 0.95,
    this.lightX = -0.45,
    this.lightY = -0.5,
    this.shading = 0.6,
    this.specular = 0.35,
    this.sparkles = 0.5,
    this.rim = 0.035,
    this.rimColour = '#FFFFFF',
  });

  /// How strongly the flag curves round the ball (0 = flat disc, 1 = a true
  /// sphere projection).
  final double bulge;

  /// How much of the flag shows across the ball (1 = the full width the
  /// frame holds; smaller = closer in).
  final double zoom;

  /// Light direction across the ball (-1..1; negative x = from the left,
  /// negative y = from above).
  final double lightX;
  final double lightY;

  /// Strength of the 3D shading (0 = flat colour).
  final double shading;

  /// Strength of the glossy highlight.
  final double specular;

  /// Faint scattered stars over the ball (0 = none).
  final double sparkles;

  /// Width of the sticker rim, as a fraction of the radius (0 = none).
  final double rim;

  /// Rim colour, `#RRGGBB`.
  final String rimColour;

  Map<String, Object?> toJson() => {
        'bulge': bulge,
        'zoom': zoom,
        'lightX': lightX,
        'lightY': lightY,
        'shading': shading,
        'specular': specular,
        'sparkles': sparkles,
        'rim': rim,
        'rimColour': rimColour,
      };

  factory Globe.fromJson(Map<String, Object?> j) {
    const d = Globe();
    double n(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    final rimColour = j['rimColour'] as String? ?? d.rimColour;
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(rimColour)) {
      throw FormatException('globe.rimColour must be #RRGGBB, not $rimColour');
    }
    return Globe(
      bulge: n('bulge', d.bulge),
      zoom: n('zoom', d.zoom),
      lightX: n('lightX', d.lightX),
      lightY: n('lightY', d.lightY),
      shading: n('shading', d.shading),
      specular: n('specular', d.specular),
      sparkles: n('sparkles', d.sparkles),
      rim: n('rim', d.rim),
      rimColour: rimColour,
    );
  }
}
