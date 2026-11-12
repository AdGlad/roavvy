import 'design_recipe.dart';

/// The recipe type id used in presets, exports and docs.
const String kPortraitTornFlagRecipeType = 'portrait_torn_flag';

/// Parameters of the `portrait_torn_flag` recipe
/// ([DesignFamily.portraitTornFlag]): one flag turned to portrait and torn into
/// ragged hanging strips — the classic distressed "torn flag" t-shirt.
///
/// Geometry is described in the ROTATED flag's own unit space: `u` runs across
/// the portrait flag (0 = left, 1 = right), `v` runs down it (0 = top). All
/// lengths are fractions, so the same parameters reproduce the same design at
/// any output resolution.
///
/// Unlike most recipe groups, [toJson] writes EVERY field: this group is new,
/// so there are no legacy recipe ids to protect, and an explicit preset file is
/// easier to read and diff than one that hides its defaults.
class TornStrips {
  const TornStrips({
    this.rotateClockwise = true,
    this.mirror = false,
    this.margin = 0.04,
    this.flagAspect = 0,
    this.flagVariant,
    this.cutMode = cutsFromFlag,
    this.stripCount = 13,
    this.fringeCount = 9,
    this.fringeDepth = 0.35,
    this.spacingJitter = 0.08,
    this.gap = 0.04,
    this.widthWobble = 0.3,
    this.curvature = 0.75,
    this.waviness = 0.35,
    this.swayCoherence = 0.8,
    this.tearLength = 0.38,
    this.tearPoint = 0.75,
    this.tearJag = 0.6,
    this.topVariation = 0.18,
    this.breakChance = 0.35,
    this.blockWidth = 0.54,
    this.blockHeight = 0.57,
    this.blockTear = 0.6,
    this.edgeRoughness = 0.6,
    this.distress = 0.75,
    this.distressScale = 0.6,
    this.edgeWear = 0.3,
    this.saturation = 0.95,
    this.hueShift = 0.0,
    this.brightness = -0.08,
    this.vintage = 0.1,
    this.knockoutWhite = false,
  });

  /// Turn the landscape flag 90° clockwise (a US canton lands top-RIGHT, as on
  /// the reference shirt); false = counter-clockwise.
  final bool rotateClockwise;

  /// Mirror the portrait flag left↔right after rotating. Clockwise + mirror puts
  /// a canton top-LEFT, which is flag-code-correct for a vertical display.
  final bool mirror;

  /// Empty space around the flag, as a fraction of the canvas (each side).
  final double margin;

  /// Flag length ÷ width to draw at. 0 = the artwork's own aspect (4:3 for the
  /// standard flags, 1.9 for `official` US). Other values stretch the artwork
  /// along its length.
  final double flagAspect;

  /// Alternative flag artwork, drawn instead of the standard bundled flag when
  /// it exists: `official` = `flags/svg/official/<code>.svg`, true-proportion
  /// artwork (currently the US). Null or empty = the standard 4:3 artwork.
  final String? flagVariant;

  /// Cut lines follow the flag's own lengthwise stripes ([cutMode] default).
  /// A flag without any (Seychelles, Japan, France…) gets a torn fringe
  /// instead, so strips are never invented across a design without stripes.
  static const String cutsFromFlag = 'flag';

  /// Evenly spaced full-length cuts ([stripCount]) — a stylised look that
  /// ignores the flag's design, so it must be chosen explicitly.
  static const String cutsEven = 'even';

  /// Short tears at the free end only ([fringeCount], [fringeDepth]); the flag
  /// stays whole above them.
  static const String cutsFringe = 'fringe';

  /// Where the cut lines come from: [cutsFromFlag], [cutsEven] or [cutsFringe].
  final String cutMode;

  /// Number of strips in [cutsEven] mode.
  final int stripCount;

  /// Number of tongues in a fringe.
  final int fringeCount;

  /// How far up the flag a fringe's tears reach, as a fraction of its length.
  final double fringeDepth;

  /// How unevenly even/fringe cuts are spaced (0 = even, 1 = up to half a
  /// strip off). Cuts taken from the flag are never moved.
  final double spacingJitter;

  /// Transparent gap torn out at each cut, as a fraction of a US-stripe
  /// width (the tear detail unit on every flag).
  final double gap;

  /// Slow drift of each tear line to either side of its cut (0 = straight).
  final double widthWobble;

  /// How far the strips sway sideways as they hang (0 = straight down).
  final double curvature;

  /// How many bends the sway has (0 = one long curve, 1 = rippling).
  final double waviness;

  /// How much the strips sway together, like one flag in the wind (1), versus
  /// each on its own path (0).
  final double swayCoherence;

  /// How much strip lengths vary: ends fall between `1 - tearLength` and 1.
  final double tearLength;

  /// How pointed a strip's torn end is (0 = blunt, 1 = long spike).
  final double tearPoint;

  /// How jagged a torn end is (0 = clean cut, 1 = ragged).
  final double tearJag;

  /// How far below the top the free (unjoined) strips start, at most.
  final double topVariation;

  /// Chance that a free strip is torn clean through partway down, leaving a
  /// gap between an upper fragment and the rest of the strip.
  final double breakChance;

  /// Width of the intact block on the canton side, as a fraction of the flag
  /// width (0 = no block: every strip hangs free). US canton ≈ 0.54.
  final double blockWidth;

  /// Height of the intact block, as a fraction of the flag length. US canton
  /// ≈ 0.57 on the bundled 4:3 artwork.
  final double blockHeight;

  /// How ragged the block's exposed top and inner edges are.
  final double blockTear;

  /// Fraying of every tear line: fine notches plus occasional deeper bites,
  /// to either side of the cut so neighbouring strips keep their widths.
  final double edgeRoughness;

  /// Amount of grunge speckle worn out of the ink (0 = clean print).
  final double distress;

  /// Speckle size (0 = fine grain, 1 = coarse blotches).
  final double distressScale;

  /// Extra wear concentrated along torn edges, where ink cracks first.
  final double edgeWear;

  /// Ink saturation multiplier (1 = the flag's own colours).
  final double saturation;

  /// Hue rotation of the ink, in degrees (e.g. +8 pushes red toward crimson
  /// and navy toward indigo).
  final double hueShift;

  /// Ink brightness (-1 darker … 0 unchanged … 1 lighter).
  final double brightness;

  /// Warm, faded vintage cast (0 = none). Whites are left untinted.
  final double vintage;

  /// Drop near-white ink so the garment shows through (white stripes become
  /// gaps). Off by default: on a dark shirt the white stripes are printed.
  final bool knockoutWhite;

  Map<String, Object?> toJson() => {
        'rotateClockwise': rotateClockwise,
        'mirror': mirror,
        'margin': margin,
        'flagAspect': flagAspect,
        'flagVariant': flagVariant,
        'cutMode': cutMode,
        'stripCount': stripCount,
        'fringeCount': fringeCount,
        'fringeDepth': fringeDepth,
        'spacingJitter': spacingJitter,
        'gap': gap,
        'widthWobble': widthWobble,
        'curvature': curvature,
        'waviness': waviness,
        'swayCoherence': swayCoherence,
        'tearLength': tearLength,
        'tearPoint': tearPoint,
        'tearJag': tearJag,
        'topVariation': topVariation,
        'breakChance': breakChance,
        'blockWidth': blockWidth,
        'blockHeight': blockHeight,
        'blockTear': blockTear,
        'edgeRoughness': edgeRoughness,
        'distress': distress,
        'distressScale': distressScale,
        'edgeWear': edgeWear,
        'saturation': saturation,
        'hueShift': hueShift,
        'brightness': brightness,
        'vintage': vintage,
        'knockoutWhite': knockoutWhite,
      };

  factory TornStrips.fromJson(Map<String, Object?> json) {
    const d = TornStrips();
    double n(String k, double def) => (json[k] as num?)?.toDouble() ?? def;
    return TornStrips(
      rotateClockwise: json['rotateClockwise'] as bool? ?? d.rotateClockwise,
      mirror: json['mirror'] as bool? ?? d.mirror,
      margin: n('margin', d.margin),
      flagAspect: n('flagAspect', d.flagAspect),
      flagVariant: json['flagVariant'] as String?,
      cutMode: json['cutMode'] as String? ?? d.cutMode,
      stripCount: (json['stripCount'] as num?)?.toInt() ?? d.stripCount,
      fringeCount: (json['fringeCount'] as num?)?.toInt() ?? d.fringeCount,
      fringeDepth: n('fringeDepth', d.fringeDepth),
      spacingJitter: n('spacingJitter', d.spacingJitter),
      gap: n('gap', d.gap),
      widthWobble: n('widthWobble', d.widthWobble),
      curvature: n('curvature', d.curvature),
      waviness: n('waviness', d.waviness),
      swayCoherence: n('swayCoherence', d.swayCoherence),
      tearLength: n('tearLength', d.tearLength),
      tearPoint: n('tearPoint', d.tearPoint),
      tearJag: n('tearJag', d.tearJag),
      topVariation: n('topVariation', d.topVariation),
      breakChance: n('breakChance', d.breakChance),
      blockWidth: n('blockWidth', d.blockWidth),
      blockHeight: n('blockHeight', d.blockHeight),
      blockTear: n('blockTear', d.blockTear),
      edgeRoughness: n('edgeRoughness', d.edgeRoughness),
      distress: n('distress', d.distress),
      distressScale: n('distressScale', d.distressScale),
      edgeWear: n('edgeWear', d.edgeWear),
      saturation: n('saturation', d.saturation),
      hueShift: n('hueShift', d.hueShift),
      brightness: n('brightness', d.brightness),
      vintage: n('vintage', d.vintage),
      knockoutWhite: json['knockoutWhite'] as bool? ?? d.knockoutWhite,
    );
  }

  TornStrips copyWith({
    bool? rotateClockwise,
    bool? mirror,
    double? margin,
    double? flagAspect,
    String? flagVariant,
    String? cutMode,
    int? stripCount,
    int? fringeCount,
    double? fringeDepth,
    double? spacingJitter,
    double? gap,
    double? widthWobble,
    double? curvature,
    double? waviness,
    double? swayCoherence,
    double? tearLength,
    double? tearPoint,
    double? tearJag,
    double? topVariation,
    double? breakChance,
    double? blockWidth,
    double? blockHeight,
    double? blockTear,
    double? edgeRoughness,
    double? distress,
    double? distressScale,
    double? edgeWear,
    double? saturation,
    double? hueShift,
    double? brightness,
    double? vintage,
    bool? knockoutWhite,
  }) =>
      TornStrips(
        rotateClockwise: rotateClockwise ?? this.rotateClockwise,
        mirror: mirror ?? this.mirror,
        margin: margin ?? this.margin,
        flagAspect: flagAspect ?? this.flagAspect,
        flagVariant: flagVariant ?? this.flagVariant,
        cutMode: cutMode ?? this.cutMode,
        stripCount: stripCount ?? this.stripCount,
        fringeCount: fringeCount ?? this.fringeCount,
        fringeDepth: fringeDepth ?? this.fringeDepth,
        spacingJitter: spacingJitter ?? this.spacingJitter,
        gap: gap ?? this.gap,
        widthWobble: widthWobble ?? this.widthWobble,
        curvature: curvature ?? this.curvature,
        waviness: waviness ?? this.waviness,
        swayCoherence: swayCoherence ?? this.swayCoherence,
        tearLength: tearLength ?? this.tearLength,
        tearPoint: tearPoint ?? this.tearPoint,
        tearJag: tearJag ?? this.tearJag,
        topVariation: topVariation ?? this.topVariation,
        breakChance: breakChance ?? this.breakChance,
        blockWidth: blockWidth ?? this.blockWidth,
        blockHeight: blockHeight ?? this.blockHeight,
        blockTear: blockTear ?? this.blockTear,
        edgeRoughness: edgeRoughness ?? this.edgeRoughness,
        distress: distress ?? this.distress,
        distressScale: distressScale ?? this.distressScale,
        edgeWear: edgeWear ?? this.edgeWear,
        saturation: saturation ?? this.saturation,
        hueShift: hueShift ?? this.hueShift,
        brightness: brightness ?? this.brightness,
        vintage: vintage ?? this.vintage,
        knockoutWhite: knockoutWhite ?? this.knockoutWhite,
      );
}

/// Builds a `portrait_torn_flag` [DesignRecipe] for one flag.
///
/// The recipe carries no palette, effects or edge treatment: the whole look —
/// tearing, distress and ink colour — is drawn by the torn-strip composition
/// from [params], so the generic stages leave it untouched. Size class is
/// `large` so the renderer never resamples the artwork; [TornStrips.margin]
/// sets the breathing room instead.
DesignRecipe portraitTornFlagRecipe({
  required String flagCode,
  required int seed,
  TornStrips params = const TornStrips(),
  RecipeProvenance? provenance,
}) =>
    DesignRecipe(
      seed: seed,
      content: RecipeContent(flags: [FlagRef(flagCode.toLowerCase())]),
      composition: const Composition(
        family: DesignFamily.portraitTornFlag,
        orientation: Orientation.portrait,
        sizeClass: SizeClass.large,
      ),
      tornStrips: params,
      provenance: provenance,
    );

/// A named, saved `portrait_torn_flag` configuration — what the Design Lab
/// writes to disk and what the mobile app loads. It wraps the complete
/// [DesignRecipe] (flag, seed, parameters, engine versions), so loading a
/// preset anywhere reproduces the same artwork at the same output size.
class TornFlagPreset {
  const TornFlagPreset(
      {required this.name, required this.recipe, this.notes, this.storedRecipeId});

  static const String format = 'roavvy.design_preset';
  static const int formatVersion = 1;

  final String name;
  final DesignRecipe recipe;
  final String? notes;

  /// The `recipeId` written in the file, if any. When it differs from
  /// `recipe.recipeId` the file was saved by an engine whose defaults or
  /// hashing have since changed — the artwork may no longer match the export.
  final String? storedRecipeId;

  bool get recipeIdMatchesFile =>
      storedRecipeId == null || storedRecipeId == recipe.recipeId;

  Map<String, Object?> toJson() => {
        'format': format,
        'formatVersion': formatVersion,
        'recipeType': kPortraitTornFlagRecipeType,
        'name': name,
        if (notes != null) 'notes': notes,
        'recipe': recipe.toJson(),
      };

  /// Accepts a preset wrapper, or a bare recipe JSON (named [fallbackName]).
  factory TornFlagPreset.fromJson(Map<String, Object?> json,
      {String fallbackName = 'Untitled'}) {
    final recipeJson = json['recipe'] is Map
        ? (json['recipe'] as Map).cast<String, Object?>()
        : json;
    return TornFlagPreset(
      name: json['recipe'] is Map
          ? json['name'] as String? ?? fallbackName
          : fallbackName,
      notes: json['notes'] as String?,
      recipe: DesignRecipe.fromJson(recipeJson),
      storedRecipeId: recipeJson['recipeId'] as String?,
    );
  }
}
