import 'design_recipe.dart';
import 'recipe_parts.dart';
import 'versions.dart';

/// Imports the shipping engine's **flat** `ProceduralDesignRecipe.toJson()` shape
/// (studio `batch.json` designs and `design_studio/recipes/*.recipe.json`
/// anchors) into a Design Forge [DesignRecipe].
///
/// This is a pure data mapping — it takes the decoded JSON map, never the app
/// type, so `design_forge` keeps zero dependency on the mobile app. It is
/// intentionally *lossy in one direction*: the old recipe carries both a
/// `printStyle` id and continuous treatment genes; we keep the continuous genes
/// (they drive pixels) and only synthesise an [EdgeTreatment] when the print
/// style is a torn/ripped one. The original `recipeId` is preserved in
/// [RecipeProvenance.parentRecipeIds] for traceability, but the imported
/// recipe's own [DesignRecipe.recipeId] is recomputed under the new schema.
class ProceduralRecipeCodec {
  const ProceduralRecipeCodec._();

  static DesignRecipe fromFlatJson(Map<String, Object?> j) {
    double d(String k, [double fallback = 0.0]) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    String? s(String k) => j[k] as String?;

    final codes = [
      for (final c in (j['countryCodes'] as List? ?? const []))
        (c as String).toLowerCase(),
    ];
    final hero = (j['heroCode'] as String?)?.toLowerCase();

    // Hero flag (if any) gets a heavier weight so the emphasis survives.
    final flags = [
      for (final c in codes)
        FlagRef(c, weight: (hero != null && c == hero) ? 2.0 : 1.0),
    ];

    final composition = Composition(
      family: _family(s('family'), s('template')),
      orientation:
          (j['isPortrait'] as bool? ?? true) ? Orientation.portrait : Orientation.landscape,
      layoutMode: j['layoutMode'] == null ? null : LayoutMode.fromId(s('layoutMode')),
      rowCount: (j['rowCount'] as num?)?.toInt(),
      density: Density.fromId(s('density')),
      jitter: d('jitter'),
      placement: _placement(j),
    );

    final combine = _combination(s('combination'), d('weightA', 0.5));

    final mask = s('mask');
    final clip = (mask == null || mask == 'none')
        ? null
        : Clip.shape(ClipShape.fromId(mask), code: s('maskCode'));

    final effects = Effects(
      distress: d('distress'),
      grain: d('grain'),
      halftone: d('halftone'),
      fade: d('fade'),
      rippleAmp: d('rippleAmp'),
      rippleFreq: d('rippleFreq', 8.0),
    );

    final printStyle = s('printStyle');
    final edge = (printStyle == 'edgeTear' || printStyle == 'rippedFlag')
        ? const EdgeTreatment()
        : null;

    final palette = Palette(
      garmentColour: s('garmentColour'),
      strategy: _strategy(s('colourTreatment')),
    );

    final originalId = s('recipeId');

    return DesignRecipe(
      seed: (j['seed'] as num?)?.toInt() ?? 0,
      content: RecipeContent(flags: flags, source: s('source')),
      composition: composition,
      flagCombination: combine,
      clip: clip,
      edgeTreatment: edge,
      palette: palette,
      effects: effects.isIdentity ? null : effects,
      engineVersion: s('engineVersion') ?? kEngineVersion,
      grammarVersion: s('grammarVersion') ?? kGrammarVersion,
      provenance: RecipeProvenance(
        generator: s('generator') ?? 'imported',
        parentRecipeIds: originalId == null ? const [] : [originalId],
      ),
    );
  }

  static DesignFamily _family(String? family, String? template) {
    final byName = DesignFamily.fromId(family);
    if (byName != DesignFamily.unknown) return byName;
    // Fall back to the card template when the family name doesn't map.
    switch (template) {
      case 'grid':
        return DesignFamily.grid;
      case 'passport':
        return DesignFamily.passportStamp;
      case 'timeline':
        return DesignFamily.timeline;
      case 'typography':
        return DesignFamily.typographic;
      case 'badge':
        return DesignFamily.badge;
      case 'wordCloud':
        return DesignFamily.wordCloud;
      case 'landmark':
        return DesignFamily.landmark;
      case 'journeys':
        return DesignFamily.journeys;
      default:
        return DesignFamily.singleHero;
    }
  }

  static FlagCombination? _combination(String? name, double weightA) {
    if (name == null || name == 'none') return null;
    const map = {
      'mix': FlagCombineMode.mix,
      'diagonal': FlagCombineMode.diagonalSplit,
      'noiseMask': FlagCombineMode.torn,
      'wavy': FlagCombineMode.wave,
      'verticalSplit': FlagCombineMode.vertical,
      'horizontalSplit': FlagCombineMode.horizontal,
      'stripes': FlagCombineMode.stripes,
      'checker': FlagCombineMode.checker,
      'radial': FlagCombineMode.radial,
    };
    final mode = map[name];
    if (mode == null) return null;
    return FlagCombination(mode: mode, weightA: weightA);
  }

  static Placement? _placement(Map<String, Object?> j) {
    final anchor = j['placement'] as String?;
    final offset = (j['placementOffset'] as num?)?.toDouble() ?? 0.0;
    final scale = (j['heroScale'] as num?)?.toDouble() ?? 1.0;
    if (anchor == null && offset == 0.0 && scale == 1.0) return null;
    // Map the named anchor + signed offset to normalised anchor coordinates.
    var ax = 0.5, ay = 0.5;
    switch (anchor) {
      case 'topCenter':
        ay = 0.25 + offset * 0.25;
        break;
      case 'bottomCenter':
        ay = 0.75 + offset * 0.25;
        break;
      case 'left':
        ax = 0.25 + offset * 0.25;
        break;
      case 'right':
        ax = 0.75 + offset * 0.25;
        break;
      case 'center':
      default:
        break;
    }
    return Placement(anchorX: ax, anchorY: ay, scale: scale);
  }

  static ColourStrategy _strategy(String? colourTreatment) {
    switch (colourTreatment) {
      case 'duotone':
        return ColourStrategy.duotone;
      case 'monochrome':
      case 'mono':
        return ColourStrategy.monochrome;
      default:
        return ColourStrategy.flagDerived;
    }
  }
}
