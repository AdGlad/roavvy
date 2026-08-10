import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/flag_grid_layout_engine.dart'
    show FlagGridLayoutMode, GridClipShape;
import 'package:mobile_flutter/features/merch/design_engine/procedural/procedural.dart';
import 'package:mobile_flutter/features/merch/merch_preset.dart'
    show MerchCountrySource, MerchDensity, MerchStampMode;
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/product_mockup_specs.dart'
    show ImageSize;
import 'package:shared_models/shared_models.dart' show CardTemplateType;

/// The curated torn-flag recipe (single flag + Edge Tear + distress).
ProceduralDesignRecipe _tornFlag({
  PrintStyleId style = PrintStyleId.edgeTear,
  double distress = 0.45,
  double grain = 0.22,
  String garment = 'White',
  ColorTreatment colour = ColorTreatment.none,
}) =>
    ProceduralDesignRecipe(
      engineVersion: 'x',
      grammarVersion: 'x',
      seed: 424242,
      scopeKey: 'singleCountry:us',
      family: CompositionFamily.singleHero,
      hierarchy: HierarchyMode.singleFocal,
      template: CardTemplateType.grid,
      layoutMode: FlagGridLayoutMode.packedRow,
      mask: GridClipShape.none,
      maskCode: null,
      rowCount: 1,
      countryCodes: const ['us'],
      heroCode: 'us',
      source: MerchCountrySource.singleCountry,
      density: MerchDensity.balanced,
      jitter: 0.08,
      stampMode: MerchStampMode.entryExit,
      isPortrait: false,
      imageSize: ImageSize.large,
      garmentColour: garment,
      flagTreatment: FlagTreatment.fullColour,
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

void main() {
  test('torn-flag recipe applies Edge Tear\'s torn edges (roughEdges) + genes',
      () {
    final p = _tornFlag().toPrintStyleParams();
    expect(p.isClean, isFalse); // it WILL transform the flag
    expect(p.id, PrintStyleId.edgeTear);
    // The defining torn edge comes from the preset and must survive.
    expect(p.roughEdges, greaterThan(0.5));
    // The continuous genes override the amounts.
    expect(p.distress, 0.45);
    expect(p.grain, 0.22);
  });

  test('mono tattered variant collapses to a single ink', () {
    final p = _tornFlag(
      garment: 'Black',
      colour: ColorTreatment.monoInk,
      distress: 0.62,
      grain: 0.3,
    ).toPrintStyleParams();
    expect(p.colorTreatment, ColorTreatment.monoInk);
    expect(p.roughEdges, greaterThan(0.5)); // still torn
  });

  test('the recipe maps to a valid, printable genome', () {
    expect(_tornFlag().toDesignParams().isValid, isTrue);
  });
}
