import 'package:shared_models/shared_models.dart' show CardTemplateType;

import '../../../cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import '../../print_style/print_style.dart' show ColorTreatment, PrintStyleId;
import '../../product_mockup_specs.dart' show ImageSize;
import '../../merch_preset.dart'
    show MerchCountrySource, MerchDensity, MerchStampMode;
import 'composition_family.dart';
import 'design_context.dart';
import 'procedural_recipe.dart';

/// Curated "exemplar" recipes — proven looks (distilled from the reference
/// library) injected into the generator's candidate pool so they compete with
/// grammar-sampled designs on quality + diversity. Retargeted to the context's
/// country/garment and varied by seed; they are scored and selected like any
/// other candidate (never forced).
List<ProceduralDesignRecipe> curatedExemplars(
  DesignContext context,
  int seed, {
  required String engineVersion,
  required String grammarVersion,
}) {
  // Torn-flag exemplars are single-country by nature.
  if (context.countryCount != 1) return const [];
  final cc = context.countryCodes.first;
  final garment = context.garmentIsDark ? 'Black' : 'White';

  ProceduralDesignRecipe tornFlag({
    required PrintStyleId style,
    required ColorTreatment colour,
    required FlagTreatment flag,
    required double distress,
    required double grain,
    required int saltedSeed,
  }) =>
      ProceduralDesignRecipe(
        engineVersion: engineVersion,
        grammarVersion: grammarVersion,
        seed: saltedSeed & 0x7fffffff,
        scopeKey: context.scopeKey,
        generator: 'curated',
        family: CompositionFamily.singleHero,
        hierarchy: HierarchyMode.singleFocal,
        template: CardTemplateType.grid,
        layoutMode: FlagGridLayoutMode.packedRow,
        mask: GridClipShape.none, // the flag IS the graphic
        maskCode: null,
        rowCount: 1,
        countryCodes: context.countryCodes,
        heroCode: cc,
        source: MerchCountrySource.singleCountry,
        density: MerchDensity.balanced,
        jitter: 0.08,
        stampMode: MerchStampMode.entryExit,
        isPortrait: false,
        imageSize: ImageSize.large,
        garmentColour: garment,
        flagTreatment: flag,
        colourTreatment: colour,
        printStyle: style,
        heroScale: 0.85,
        placement: PlacementAnchor.center,
        placementOffset: 0,
        cropMode: CropMode.bleed,
        rotationDeg: 0,
        layerMode: LayerMode.flat,
        distress: distress,
        grain: grain,
      );

  return [
    // Full-colour torn flag.
    tornFlag(
      style: PrintStyleId.edgeTear,
      colour: ColorTreatment.none,
      flag: FlagTreatment.fullColour,
      distress: 0.45,
      grain: 0.22,
      saltedSeed: seed ^ 0x7011,
    ),
    // Mono tattered flag.
    tornFlag(
      style: PrintStyleId.edgeTear,
      colour: ColorTreatment.monoInk,
      flag: FlagTreatment.monochrome,
      distress: 0.62,
      grain: 0.30,
      saltedSeed: seed ^ 0x7022,
    ),
    // Grungy full-colour flag.
    tornFlag(
      style: PrintStyleId.grunge,
      colour: ColorTreatment.none,
      flag: FlagTreatment.fullColour,
      distress: 0.55,
      grain: 0.35,
      saltedSeed: seed ^ 0x7033,
    ),
  ];
}
