import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';

import 'render_stage.dart';

/// Colour grading of the artwork: vintage warm-fade, monochrome and duotone,
/// via `ColorFilter.matrix` (GPU, resolution-independent). Runs after geometry
/// and texture so the grade covers the whole treated artwork.
class ColourStage extends RenderStage {
  const ColourStage();

  @override
  String get id => 'colour';

  @override
  Future<void> apply(DesignRecipe recipe, RenderContext ctx) async {
    final palette = recipe.palette;
    if (palette == null || ctx.artwork == null) return;

    final filters = <List<double>>[];

    if (palette.strategy == ColourStrategy.monochrome) {
      filters.add(_saturation(0.0));
    } else if (palette.strategy == ColourStrategy.duotone &&
        palette.accents.length >= 2) {
      // Duotone: luminance → gradient between two accents.
      filters.add(_saturation(0.0));
      filters.add(_duotone(_hex(palette.accents[0]), _hex(palette.accents[1])));
    } else if (palette.strategy == ColourStrategy.garmentAware &&
        _isAdaptiveInk(recipe, palette)) {
      // Garment-aware: re-ink ADAPTIVE designs (text/typographic, solid stamp
      // ink, opted-in line-art) toward a legible contrast tone for the garment.
      // Flag fills and intentionally-coloured artwork are NOT adaptive, so this
      // branch never fires for them → they keep their semantic colours.
      filters.add(_recolour(_contrastInk(palette, ctx.target.background)));
    }

    if (palette.vintageGrade > 0) {
      filters.add(_vintage(palette.vintageGrade.clamp(0.0, 1.0)));
    }

    if (filters.isEmpty) return;

    final matrix = filters.reduce(_mul);
    await ctx.transformArtwork((canvas, src) {
      canvas.drawImage(
        src,
        ui.Offset.zero,
        ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix),
      );
    });
  }

  // ---- garment-aware adaptive ink ----

  /// True when the recipe's ink is ADAPTIVE (re-inkable for contrast) rather than
  /// a flag fill. Classified from the recipe (ColourStage only sees flattened
  /// pixels): typographic family or a `text` clip (letterforms), solid
  /// passport-stamp ink (`clip.ink` is `black`/`white`, not `flag`), or an
  /// explicit [Palette.contrastInk] opt-in for line-art/outline/silhouette
  /// designs whose ink is not flag-derived. Flag-filled shapes stay semantic.
  bool _isAdaptiveInk(DesignRecipe recipe, Palette palette) {
    if (palette.contrastInk) return true;
    if (recipe.composition.family == DesignFamily.typographic) return true;
    final clip = recipe.clip;
    if (clip != null) {
      if (clip.shapeId == 'text') return true;
      final ink = clip.ink;
      // null/'flag' = filled with the flag (semantic); anything else is solid ink.
      if (ink != null && ink != 'flag') return true;
    }
    return false;
  }

  /// The contrast ink colour for the garment: an explicit [Palette.adaptiveInk]
  /// if given, else near-white on dark garments / near-black on light ones. The
  /// garment tone is read from [Palette.garmentColour] (hex) when parseable, else
  /// the render target background, else a neutral light grey.
  ui.Color _contrastInk(Palette palette, ui.Color? background) {
    final explicit = _tryHex(palette.adaptiveInk);
    if (explicit != null) return explicit;
    final garment =
        _tryHex(palette.garmentColour) ?? background ?? const ui.Color(0xFFF2F2F2);
    final lum = 0.2126 * garment.r + 0.7152 * garment.g + 0.0722 * garment.b;
    return lum < 0.5 ? const ui.Color(0xFFF5F5F5) : const ui.Color(0xFF1A1A1A);
  }

  /// A flat recolour matrix: force RGB to [c], preserve alpha. Anti-aliased edges
  /// (partial alpha) stay soft, so text/stamp ink reads cleanly as one tone.
  List<double> _recolour(ui.Color c) => <double>[
        0, 0, 0, 0, c.r * 255,
        0, 0, 0, 0, c.g * 255,
        0, 0, 0, 0, c.b * 255,
        0, 0, 0, 1, 0,
      ];

  ui.Color? _tryHex(String? s) {
    if (s == null) return null;
    var h = s.replaceAll('#', '').trim();
    if (h.length == 6) h = 'ff$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : ui.Color(v);
  }

  // ---- colour matrices (4x5, row-major) ----

  List<double> _saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    return <double>[
      sr + s, sg, sb, 0, 0,
      sr, sg + s, sb, 0, 0,
      sr, sg, sb + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Warm, slightly desaturated, lifted-black vintage grade, mixed by [amount].
  List<double> _vintage(double a) {
    final desat = _saturation(1 - a * 0.5);
    final warm = <double>[
      1 + a * 0.12, 0, 0, 0, a * 8,
      0, 1 + a * 0.04, 0, 0, a * 4,
      0, 0, 1 - a * 0.10, 0, -a * 2,
      0, 0, 0, 1, 0,
    ];
    // Lift blacks a touch (fade).
    final lift = <double>[
      1 - a * 0.08, 0, 0, 0, a * 18,
      0, 1 - a * 0.08, 0, 0, a * 16,
      0, 0, 1 - a * 0.08, 0, a * 12,
      0, 0, 0, 1, 0,
    ];
    return _mul(_mul(desat, warm), lift);
  }

  /// Map luminance to a gradient between [dark] and [light] (assumes prior desat).
  List<double> _duotone(ui.Color dark, ui.Color light) {
    final dr = dark.r, dg = dark.g, db = dark.b; // 0..1 doubles
    final lr = light.r, lg = light.g, lb = light.b;
    // out = dark + luminance*(light-dark); use green channel as luminance proxy
    // (input already desaturated so R=G=B=luminance).
    return <double>[
      0, lr - dr, 0, 0, dr * 255,
      0, lg - dg, 0, 0, dg * 255,
      0, lb - db, 0, 0, db * 255,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _mul(List<double> a, List<double> b) {
    // Compose two 4x5 colour matrices (apply `a` then `b`): result = b * a.
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += b[row * 5 + k] * a[k * 5 + col];
        }
        if (col == 4) sum += b[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  ui.Color _hex(String s) {
    var h = s.replaceAll('#', '');
    if (h.length == 6) h = 'ff$h';
    return ui.Color(int.parse(h, radix: 16));
  }
}
