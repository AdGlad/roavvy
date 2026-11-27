/// Lines of text placed above and below the artwork (`DesignRecipe.captions`),
/// e.g. "I" over a flag heart and the country's name beneath it.
///
/// Drawn after every other stage and after any outline, so captions are never
/// outlined or clipped by the artwork's shape. Strings may use pack tokens
/// (`{{countryName}}`, `{{country3}}` …). Like the other new groups, [toJson]
/// writes every field.
class Captions {
  const Captions({
    this.top,
    this.bottom,
    this.font = 'brush',
    this.colour = flagColour,
    this.topSize = 0.13,
    this.bottomSize = 0.13,
    this.upperCase = true,
    this.grit = 0.3,
  });

  /// [colour] value: the flag's strongest colour (Greece → its blue).
  static const String flagColour = 'flag';

  final String? top;
  final String? bottom;

  /// 'brush' (embedded Permanent Marker), 'varsity' (embedded Graduate) or
  /// null (platform bold sans).
  final String? font;

  /// [flagColour], 'auto' (legible on the garment) or `#RRGGBB`.
  final String colour;

  /// Height of each text band as a fraction of the canvas height.
  final double topSize;
  final double bottomSize;

  final bool upperCase;

  /// Worn, dry-brush specks knocked out of the letters (0 = clean).
  final double grit;

  Map<String, Object?> toJson() => {
        if (top != null) 'top': top,
        if (bottom != null) 'bottom': bottom,
        if (font != null) 'font': font,
        'colour': colour,
        'topSize': topSize,
        'bottomSize': bottomSize,
        'upperCase': upperCase,
        'grit': grit,
      };

  factory Captions.fromJson(Map<String, Object?> j) {
    const d = Captions();
    final colour = j['colour'] as String? ?? d.colour;
    if (colour != flagColour &&
        colour != 'auto' &&
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colour)) {
      throw FormatException('captions.colour must be flag, auto or #RRGGBB, not $colour');
    }
    return Captions(
      top: j['top'] as String?,
      bottom: j['bottom'] as String?,
      font: j.containsKey('font') ? j['font'] as String? : null,
      colour: colour,
      topSize: (j['topSize'] as num?)?.toDouble() ?? d.topSize,
      bottomSize: (j['bottomSize'] as num?)?.toDouble() ?? d.bottomSize,
      upperCase: (j['upperCase'] as bool?) ?? d.upperCase,
      grit: (j['grit'] as num?)?.toDouble() ?? d.grit,
    );
  }
}
