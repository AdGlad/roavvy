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

void main() {
  const gen = ProceduralDesignGenerator();
  final ctx = DesignContext.of(
    scope: DesignScope.multiCountry,
    countryCodes: const ['fr', 'jp', 'us', 'br'],
  );

  test('recipes carry continuous treatment genes, captured in identity/json',
      () {
    final r = gen.generate(ctx, seed: 5).designs.first.recipe;
    final j = r.toJson();
    expect(j.keys, containsAll(['distress', 'grain', 'halftone', 'fade']));
    // Genes are within range.
    for (final g in [r.distress, r.grain, r.halftone, r.fade]) {
      expect(g, inInclusiveRange(0.0, 1.0));
    }
    expect(r.recipeId, contains(r.distress.toStringAsFixed(3)));
  });

  test('a treated recipe maps to a non-clean PrintStyleParams carrying genes',
      () {
    // Find a recipe with active treatment across seeds.
    ProceduralDesignRecipe? treated;
    for (var s = 0; s < 30 && treated == null; s++) {
      for (final d in gen.generate(ctx, seed: s).designs) {
        if (d.recipe.hasTreatment) treated = d.recipe;
      }
    }
    expect(treated, isNotNull);
    final p = treated!.toPrintStyleParams();
    expect(p.isClean, isFalse); // pipeline will actually apply it
    expect(p.distress, treated.distress);
    expect(p.grain, treated.grain);
    expect(p.halftone, treated.halftone);
    expect(p.fade, treated.fade);
  });

  test('an untreated recipe maps to a clean (no-op) PrintStyleParams', () {
    const r = ProceduralDesignRecipe(
      engineVersion: 'x',
      grammarVersion: 'x',
      seed: 1,
      scopeKey: 'k',
      family: CompositionFamily.repetitionField,
      hierarchy: HierarchyMode.uniform,
      template: CardTemplateType.grid,
      layoutMode: FlagGridLayoutMode.packedRow,
      mask: GridClipShape.none,
      maskCode: null,
      rowCount: 3,
      countryCodes: ['fr', 'jp'],
      heroCode: null,
      source: MerchCountrySource.allTime,
      density: MerchDensity.balanced,
      jitter: 0.2,
      stampMode: MerchStampMode.entryExit,
      isPortrait: false,
      imageSize: ImageSize.medium,
      garmentColour: 'Black',
      flagTreatment: FlagTreatment.fullColour,
      colourTreatment: ColorTreatment.none,
      printStyle: PrintStyleId.clean,
      heroScale: 0,
      placement: PlacementAnchor.center,
      placementOffset: 0,
      cropMode: CropMode.contained,
      rotationDeg: 0,
      layerMode: LayerMode.flat,
      // no treatment genes → all default 0
    );
    expect(r.hasTreatment, isFalse);
    expect(r.toPrintStyleParams().isClean, isTrue);
  });
}
