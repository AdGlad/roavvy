import 'dart:math' as math;

import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import '../../print_style/print_style.dart' show ColorTreatment, PrintStyleId;
import '../../product_mockup_specs.dart' show ImageSize;
import '../design_params.dart';
import '../../merch_preset.dart'
    show MerchCountrySource, MerchDensity, MerchStampMode;
import 'composition_family.dart';
import 'design_dna.dart';

/// How two flags are merged into one graphic (drives `flag_blend.frag`). Order
/// matters: `mix..wavy` are shader mode indices 0..3; `none` (last) means "don't
/// merge — render as an ordinary composition".
enum FlagCombination { mix, diagonal, noiseMask, wavy, none }

/// How a flag's own artwork is treated (a composable dimension). Most map to
/// full colour on today's renderer; the rest are forward-looking.
enum FlagTreatment { fullColour, tinted, monochrome, outline }

/// How the composition meets the canvas edge.
enum CropMode { contained, inset, bleed }

/// Flat vs overlapping layers.
enum LayerMode { flat, layered }

/// Where the dominant element sits.
enum PlacementAnchor { center, topCenter, bottomCenter, left, right }

/// A fully-specified, deterministic, PARAMETRIC design — the procedural
/// engine's output. Independently composable across composition · mask · flag
/// treatment · texture · colour · typography · placement · scale · cropping ·
/// rotation · layering. It is a *recipe*, never a rendered image; the same
/// `(engineVersion, grammarVersion, seed, context)` reproduces it exactly.
///
/// [toDesignParams] collapses the mapped subset to the existing renderable
/// genome, so every recipe is printable by construction. Forward-looking
/// dimensions (rotation, layering, free placement, flag treatment) are carried
/// for reproducibility and future rendering but do not yet change pixels.
class ProceduralDesignRecipe {
  const ProceduralDesignRecipe({
    required this.engineVersion,
    required this.grammarVersion,
    required this.seed,
    required this.scopeKey,
    required this.family,
    required this.hierarchy,
    required this.template,
    required this.layoutMode,
    required this.mask,
    required this.maskCode,
    required this.rowCount,
    required this.countryCodes,
    required this.heroCode,
    required this.source,
    required this.density,
    required this.jitter,
    required this.stampMode,
    required this.isPortrait,
    required this.imageSize,
    required this.garmentColour,
    required this.flagTreatment,
    required this.colourTreatment,
    required this.printStyle,
    required this.heroScale,
    required this.placement,
    required this.placementOffset,
    required this.cropMode,
    required this.rotationDeg,
    required this.layerMode,
    this.generator = 'grammar',
    // Flag-merge genes (only meaningful for 2-country "duo blend" designs;
    // [combination] == none for every other recipe).
    this.combination = FlagCombination.none,
    this.weightA = 0.5,
    this.rippleAmp = 0.0,
    this.rippleFreq = 3.0,
  });

  // Provenance / determinism
  final String engineVersion;
  final String grammarVersion;
  final int seed;
  final String scopeKey;
  final String generator;

  // Composition
  final CompositionFamily family;
  final HierarchyMode hierarchy;
  final CardTemplateType template;
  final FlagGridLayoutMode layoutMode;

  // Mask
  final GridClipShape mask;
  final String? maskCode;

  // Content
  final int rowCount;
  final List<String> countryCodes;
  final String? heroCode;
  final MerchCountrySource source;
  final MerchStampMode stampMode;

  // Scale / placement / crop / rotation / layering
  final double heroScale;
  final PlacementAnchor placement;
  final double placementOffset; // signed 0..1 along the anchor axis
  final CropMode cropMode;
  final double rotationDeg;
  final LayerMode layerMode;

  // Treatment (texture · colour · print character)
  final MerchDensity density;
  final double jitter;
  final bool isPortrait;
  final ImageSize imageSize;
  final String garmentColour;
  final FlagTreatment flagTreatment;
  final ColorTreatment colourTreatment;
  final PrintStyleId printStyle;

  // Flag-merge genes.
  final FlagCombination combination;
  final double weightA;
  final double rippleAmp;
  final double rippleFreq;

  /// Whether this recipe merges two flags into a single graphic.
  bool get isMerged =>
      combination != FlagCombination.none && countryCodes.length >= 2;

  int get countryCount => countryCodes.length;

  /// Country codes with the hero first (render emphasis), remainder stable.
  List<String> get orderedCodes {
    if (heroCode == null || !countryCodes.contains(heroCode)) {
      return countryCodes;
    }
    return [heroCode!, ...countryCodes.where((c) => c != heroCode)];
  }

  /// Collapse to the existing renderable genome. `.normalize()` guarantees a
  /// legal, printable `DesignParams` even if a forward-looking gene would be
  /// illegal on today's renderer.
  DesignParams toDesignParams() {
    final isGrid = template == CardTemplateType.grid;
    return DesignParams(
      template: template,
      source: source,
      countryCodes: orderedCodes,
      gridLayoutMode: isGrid ? layoutMode : FlagGridLayoutMode.packedRow,
      clipShape: isGrid ? mask : GridClipShape.none,
      clipCode: maskCode,
      rowCount: rowCount,
      density: density,
      jitter: jitter,
      stampMode: stampMode,
      isPortrait: isPortrait,
      imageSize: imageSize,
      shirtColour: garmentColour,
      seed: seed,
    ).normalize();
  }

  /// Stable identity over ALL recipe fields (superset of DesignParams.
  /// contentHash). Two recipes with the same id are byte-identical designs.
  String get recipeId => [
        engineVersion,
        grammarVersion,
        family.name,
        hierarchy.name,
        template.name,
        layoutMode.name,
        mask.name,
        maskCode ?? '',
        rowCount,
        (List.of(countryCodes)..sort()).join(','),
        heroCode ?? '',
        source.name,
        density.name,
        jitter.toStringAsFixed(3),
        stampMode.name,
        isPortrait ? 'p' : 'l',
        imageSize.name,
        garmentColour,
        flagTreatment.name,
        colourTreatment.name,
        printStyle.name,
        heroScale.toStringAsFixed(3),
        placement.name,
        placementOffset.toStringAsFixed(3),
        cropMode.name,
        rotationDeg.toStringAsFixed(2),
        layerMode.name,
        combination.name,
        weightA.toStringAsFixed(3),
        rippleAmp.toStringAsFixed(3),
        rippleFreq.toStringAsFixed(2),
        seed,
      ].join('|');

  /// Estimate this recipe's position on each abstract design principle, WITHOUT
  /// rendering. This is the bridge between concrete parameters and the Style DNA
  /// axes — used for quality scoring and DNA alignment. Cheap and deterministic.
  Map<DesignPrinciple, double> estimatePrinciples() {
    final n = countryCount;
    final logN = math.log(n + 1) / math.log(60); // 0..~1 across 1..60 countries
    final ps = _printCharOf(printStyle);

    // Hierarchy: strong when a single element dominates; weak for uniform fields.
    final hierarchyBase = switch (hierarchy) {
      HierarchyMode.singleFocal => 0.9,
      HierarchyMode.dominantAccent => 0.75,
      HierarchyMode.radial => 0.7,
      HierarchyMode.typeLed => 0.72,
      HierarchyMode.dualZone => 0.6,
      HierarchyMode.sequence => 0.5,
      HierarchyMode.uniform => 0.25,
    };
    final heroBoost = heroCode != null ? heroScale * 0.15 : 0.0;

    final negSpace = switch (density) {
          MerchDensity.sparse => 0.7,
          MerchDensity.balanced => 0.45,
          MerchDensity.dense => 0.22,
        } +
        (_isCutout ? 0.1 : 0.0) -
        logN * 0.15;

    final symmetry = switch (hierarchy) {
      HierarchyMode.radial => 0.9,
      HierarchyMode.uniform => 0.55,
      HierarchyMode.dualZone => 0.2,
      _ => mask == GridClipShape.circle ? 0.75 : 0.45,
    };

    final layout = switch (layoutMode) {
      FlagGridLayoutMode.montage => 0.72,
      FlagGridLayoutMode.treemap => 0.6,
      FlagGridLayoutMode.packedRow => 0.3,
      FlagGridLayoutMode.normalizedGrid => 0.2,
    };

    final geometry = switch (mask) {
      GridClipShape.circle => 0.8,
      GridClipShape.heart => 0.55,
      GridClipShape.countryOutline ||
      GridClipShape.continentOutline =>
        0.35,
      GridClipShape.animalSilhouette ||
      GridClipShape.plantSilhouette ||
      GridClipShape.landmarkSilhouette =>
        0.3,
      GridClipShape.none => 0.6,
    };

    final repetition =
        hierarchy == HierarchyMode.uniform ? 0.85 : (0.15 + logN * 0.5);

    final typography = switch (template) {
      CardTemplateType.typography || CardTemplateType.wordCloud => 0.85,
      CardTemplateType.frontRibbon => 0.55,
      CardTemplateType.timeline => 0.45,
      CardTemplateType.badge => 0.4,
      _ => 0.2,
    };

    final colourRel = switch (colourTreatment) {
          ColorTreatment.none => 0.75,
          ColorTreatment.muted => 0.5,
          ColorTreatment.vintageWarm => 0.45,
          ColorTreatment.duotone => 0.4,
          ColorTreatment.monoInk => 0.15,
        } *
        (flagTreatment == FlagTreatment.monochrome ? 0.4 : 1.0);

    final visualDensity =
        (logN * 0.6 + switch (density) {
          MerchDensity.sparse => 0.1,
          MerchDensity.balanced => 0.3,
          MerchDensity.dense => 0.5,
        })
            .clamp(0.0, 1.0);

    double v(double x) => x.clamp(0.0, 1.0);
    return {
      DesignPrinciple.visualHierarchy: v(hierarchyBase + heroBoost),
      DesignPrinciple.scale: v(hierarchy == HierarchyMode.uniform
          ? 0.4 - logN * 0.1
          : heroScale.clamp(0.2, 0.95)),
      DesignPrinciple.cropping: v(switch (cropMode) {
        CropMode.contained => 0.12,
        CropMode.inset => 0.3,
        CropMode.bleed => 0.7,
      }),
      DesignPrinciple.negativeSpace: v(negSpace),
      DesignPrinciple.symmetry: v(symmetry),
      DesignPrinciple.layout: v(layout),
      DesignPrinciple.geometry: v(geometry),
      DesignPrinciple.repetition: v(repetition),
      DesignPrinciple.texture: v(ps.texture),
      DesignPrinciple.distress: v(ps.distress),
      DesignPrinciple.typography: v(typography),
      DesignPrinciple.colourRelationships: v(colourRel),
      DesignPrinciple.layering: v(layerMode == LayerMode.layered
          ? 0.6 + (_isCutout ? 0.1 : 0)
          : 0.15 + (_isCutout ? 0.15 : 0)),
      DesignPrinciple.edgeTreatment: v(ps.edge),
      DesignPrinciple.printCharacter: v(ps.printChar),
      DesignPrinciple.visualDensity: visualDensity,
    };
  }

  bool get _isCutout =>
      mask == GridClipShape.countryOutline ||
      mask == GridClipShape.continentOutline ||
      mask == GridClipShape.animalSilhouette ||
      mask == GridClipShape.plantSilhouette ||
      mask == GridClipShape.landmarkSilhouette ||
      mask == GridClipShape.heart;

  ProceduralDesignRecipe copyWith({
    PrintStyleId? printStyle,
    ColorTreatment? colourTreatment,
    String? garmentColour,
    int? seed,
  }) =>
      ProceduralDesignRecipe(
        engineVersion: engineVersion,
        grammarVersion: grammarVersion,
        seed: seed ?? this.seed,
        scopeKey: scopeKey,
        family: family,
        hierarchy: hierarchy,
        template: template,
        layoutMode: layoutMode,
        mask: mask,
        maskCode: maskCode,
        rowCount: rowCount,
        countryCodes: countryCodes,
        heroCode: heroCode,
        source: source,
        density: density,
        jitter: jitter,
        stampMode: stampMode,
        isPortrait: isPortrait,
        imageSize: imageSize,
        garmentColour: garmentColour ?? this.garmentColour,
        flagTreatment: flagTreatment,
        colourTreatment: colourTreatment ?? this.colourTreatment,
        printStyle: printStyle ?? this.printStyle,
        heroScale: heroScale,
        placement: placement,
        placementOffset: placementOffset,
        cropMode: cropMode,
        rotationDeg: rotationDeg,
        layerMode: layerMode,
        generator: generator,
        combination: combination,
        weightA: weightA,
        rippleAmp: rippleAmp,
        rippleFreq: rippleFreq,
      );

  /// Compact JSON for batch archives / regression goldens (no rendered image).
  Map<String, dynamic> toJson() => {
        'engineVersion': engineVersion,
        'grammarVersion': grammarVersion,
        'seed': seed,
        'scopeKey': scopeKey,
        'generator': generator,
        'family': family.name,
        'hierarchy': hierarchy.name,
        'template': template.name,
        'layoutMode': layoutMode.name,
        'mask': mask.name,
        'maskCode': maskCode,
        'rowCount': rowCount,
        'countryCodes': countryCodes,
        'heroCode': heroCode,
        'source': source.name,
        'density': density.name,
        'jitter': jitter,
        'stampMode': stampMode.name,
        'isPortrait': isPortrait,
        'imageSize': imageSize.name,
        'garmentColour': garmentColour,
        'flagTreatment': flagTreatment.name,
        'colourTreatment': colourTreatment.name,
        'printStyle': printStyle.name,
        'heroScale': heroScale,
        'placement': placement.name,
        'placementOffset': placementOffset,
        'cropMode': cropMode.name,
        'rotationDeg': rotationDeg,
        'layerMode': layerMode.name,
        'combination': combination.name,
        'weightA': weightA,
        'rippleAmp': rippleAmp,
        'rippleFreq': rippleFreq,
        'recipeId': recipeId,
      };
}

/// Print-character facets derived from a print style (texture/distress/edge/
/// printChar), used by principle estimation.
class _PrintFacets {
  const _PrintFacets(this.texture, this.distress, this.edge, this.printChar);
  final double texture;
  final double distress;
  final double edge;
  final double printChar;
}

_PrintFacets _printCharOf(PrintStyleId s) => switch (s) {
      PrintStyleId.clean => const _PrintFacets(0.05, 0.0, 0.05, 0.05),
      PrintStyleId.vintage => const _PrintFacets(0.5, 0.55, 0.35, 0.4),
      PrintStyleId.retro => const _PrintFacets(0.4, 0.35, 0.2, 0.55),
      PrintStyleId.halftone => const _PrintFacets(0.4, 0.1, 0.15, 0.9),
      PrintStyleId.stamp => const _PrintFacets(0.35, 0.5, 0.55, 0.55),
      PrintStyleId.grunge => const _PrintFacets(0.8, 0.85, 0.6, 0.5),
      PrintStyleId.riso => const _PrintFacets(0.45, 0.3, 0.25, 0.85),
      PrintStyleId.newsprint => const _PrintFacets(0.5, 0.35, 0.25, 0.85),
      PrintStyleId.sunFaded => const _PrintFacets(0.3, 0.4, 0.2, 0.3),
      PrintStyleId.photocopy => const _PrintFacets(0.55, 0.5, 0.4, 0.7),
      PrintStyleId.edgeTear => const _PrintFacets(0.3, 0.5, 0.85, 0.35),
      PrintStyleId.acidWash => const _PrintFacets(0.45, 0.45, 0.25, 0.4),
    };
