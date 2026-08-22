import 'dart:convert';

import 'package:design_forge/design_forge.dart';
import 'package:test/test.dart';

DesignRecipe _full() => DesignRecipe(
      seed: 77,
      content: const RecipeContent(flags: [FlagRef('us'), FlagRef('gb')]),
      composition: const Composition(
        family: DesignFamily.grid,
        layoutMode: LayoutMode.montage,
        fillAlgorithm: FillAlgorithm.voronoi,
        rowCount: 3,
        density: Density.dense,
        jitter: 0.4,
        placement: Placement(anchorY: 0.4, scale: 1.2),
      ),
      flagCombination: const FlagCombination(
        mode: FlagCombineMode.diagonalSplit,
        weightA: 0.7,
      ),
      clip: Clip.shape(ClipShape.countryOutline, code: 'us', feather: 0.05),
      edgeTreatment: const EdgeTreatment(
        style: TearStyle.battleWorn,
        edgeDamage: 0.8,
        asymmetry: 0.9,
      ),
      palette: const Palette(
        garmentColour: 'Black',
        strategy: ColourStrategy.duotone,
        accents: ['#ff0000', '#0000ff'],
        vintageGrade: 0.6,
      ),
      effects: const Effects(
        distress: 0.4,
        grain: 0.3,
        halftone: 0.5,
        halftoneAngle: 45.0,
        rippleAmp: 0.2,
      ),
      typography: const Typography(
        titleStyle: 'condensed',
        textCase: TextCase.upper,
        placement: TextPlacement.bottom,
      ),
      motifs: const [Motif(kind: MotifKind.landmark, slug: 'big_ben', countryCode: 'gb')],
    );

void main() {
  group('full recipe (all dimension groups)', () {
    test('round-trips losslessly and preserves recipeId', () {
      final r = _full();
      final decoded = DesignRecipe.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);

      expect(decoded.recipeId, r.recipeId);
      expect(decoded.composition.layoutMode, LayoutMode.montage);
      expect(decoded.composition.fillAlgorithm, FillAlgorithm.voronoi);
      expect(decoded.composition.rowCount, 3);
      expect(decoded.composition.placement?.scale, 1.2);
      expect(decoded.flagCombination?.mode, FlagCombineMode.diagonalSplit);
      expect(decoded.clip?.shape, ClipShape.countryOutline);
      expect(decoded.clip?.code, 'us');
      expect(decoded.edgeTreatment?.style, TearStyle.battleWorn);
      expect(decoded.palette?.strategy, ColourStrategy.duotone);
      expect(decoded.palette?.accents, ['#ff0000', '#0000ff']);
      expect(decoded.effects?.halftoneAngle, 45.0);
      expect(decoded.typography?.textCase, TextCase.upper);
      expect(decoded.motifs.single.slug, 'big_ben');
    });

    test('absent optional groups do not change the hash (append-only compat)', () {
      // A minimal recipe and one with an all-default (but present) group whose
      // toJson is minimal must differ only when a group is actually present.
      final minimal = DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: const Composition(family: DesignFamily.singleHero),
      );
      final withEmptyMotifs = minimal.copyWith(motifs: const []);
      expect(withEmptyMotifs.recipeId, minimal.recipeId);
    });

    test('adding a real group changes the hash', () {
      final minimal = DesignRecipe(
        seed: 1,
        content: const RecipeContent(flags: [FlagRef('us')]),
        composition: const Composition(family: DesignFamily.singleHero),
      );
      final withClip =
          minimal.copyWith(clip: Clip.shape(ClipShape.heart));
      expect(withClip.recipeId, isNot(minimal.recipeId));
    });

    test('unknown enum values decode to defaults (forward compatible)', () {
      final j = _full().toJson();
      (j['flagCombination'] as Map)['mode'] = 'futureMode';
      (j['clip'] as Map)['shapeId'] = 'futureShape';
      final decoded = DesignRecipe.fromJson(j);
      expect(decoded.flagCombination?.mode, FlagCombineMode.mix);
      // Unknown/new shape id → not an asset-backed resolver shape.
      expect(decoded.clip?.shapeId, 'futureShape');
      expect(decoded.clip?.resolverShape, ClipShape.none);
    });

    test('Effects.isIdentity distinguishes no-op treatments', () {
      expect(const Effects().isIdentity, isTrue);
      expect(const Effects(grain: 0.1).isIdentity, isFalse);
    });

    test('ClipShape.needsCode flags single-country outline/silhouette shapes', () {
      expect(ClipShape.countryOutline.needsCode, isTrue);
      expect(ClipShape.animalSilhouette.needsCode, isTrue);
      expect(ClipShape.passportStampOutline.needsCode, isTrue);
      expect(ClipShape.passportPage.needsCode, isTrue);
      expect(ClipShape.heart.needsCode, isFalse);
      expect(ClipShape.circle.needsCode, isFalse);
    });

    test('passport clip shapes are registered + browsable in the Travel family', () {
      final travel = clipShapesByFamily(ShapeFamily.travel).map((m) => m.id).toSet();
      expect(travel, containsAll(<String>['passportStampOutline', 'passportPage']));
      // Both are resolver-backed with the right kind.
      expect(clipShapeMetaById('passportStampOutline')!.resolverKind,
          ClipShape.passportStampOutline);
      expect(clipShapeMetaById('passportPage')!.resolverKind, ClipShape.passportPage);
    });
  });
}
