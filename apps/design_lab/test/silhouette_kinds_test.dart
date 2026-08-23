import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('silhouettes are categorised into animal / plant / landmark', () {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final byKind = source!.silhouettesByKind();

    expect(byKind['animal'], isNotEmpty);
    expect(byKind['plant'], isNotEmpty);
    expect(byKind['landmark'], isNotEmpty);

    expect(byKind['animal'], contains('us_bald_eagle'));
    expect(byKind['plant'], contains('fr_fleur_de_lis_iris'));
    expect(byKind['landmark'], contains('fr_eiffel_tower'));
    // Rich sets now available (from the silhouette_factory), not just animals.
    expect(byKind['plant']!.length, greaterThan(20));
    expect(byKind['landmark']!.length, greaterThan(20));

    // No slug appears in two kinds.
    final a = byKind['animal']!.toSet();
    final p = byKind['plant']!.toSet();
    final l = byKind['landmark']!.toSet();
    expect(a.intersection(p), isEmpty);
    expect(a.intersection(l), isEmpty);
    expect(p.intersection(l), isEmpty);
  });

  testWidgets('plant and landmark silhouette clips render', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());

    DesignRecipe clip(String flag, ClipShape shape, String slug) => DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef(flag)]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: Clip.shape(shape, code: slug),
        );

    final out = Platform.environment['OUT'];
    await tester.runAsync(() async {
      final samples = {
        'kind_landmark_eiffel':
            clip('fr', ClipShape.landmarkSilhouette, 'fr_eiffel_tower'),
        'kind_plant_fleur':
            clip('fr', ClipShape.plantSilhouette, 'fr_fleur_de_lis_iris'),
        'kind_animal_eagle':
            clip('us', ClipShape.animalSilhouette, 'us_bald_eagle'),
      };
      for (final e in samples.entries) {
        final res = await renderer.render(e.value,
            RenderTarget.preview(size: 384, background: const Color(0xFFF2F2F2)));
        expect(res.pngBytes.length, greaterThan(500));
        if (out != null) File('$out/${e.key}.png').writeAsBytesSync(res.pngBytes);
      }
    });
  });

  test('real passport stamps index by cc_direction slug', () {
    final source = FlagSource.locate()!;
    final slugs = source.passportStampSlugs();
    expect(slugs, isNotEmpty);
    // Country-prefixed like silhouettes, so single-country filtering works.
    expect(slugs, contains('sc_entry'));
    expect(slugs, contains('sc_exit'));
    expect(source.passportStampPath('sc_entry'), isNotNull);
  });

  testWidgets('a real passport entry/exit stamp clips the flag', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    final unclipped = DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('sc')]),
      composition: const Composition(family: DesignFamily.singleHero),
    );
    final stamped = DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('sc')]),
      composition: const Composition(family: DesignFamily.singleHero),
      clip: const Clip(shapeId: 'passportStampOutline', code: 'sc_entry'),
    );
    await tester.runAsync(() async {
      final a = await renderer.render(unclipped, RenderTarget.preview(size: 300));
      final b = await renderer.render(stamped, RenderTarget.preview(size: 300));
      expect(b.pngBytes.length, greaterThan(500));
      // The stamp mask must actually change the image (ink-only fill vs full flag).
      expect(b.imageHash, isNot(a.imageHash));
    });
  });

  testWidgets('passport page overlays both entry + exit stamps', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    // code is the country ISO cc; the resolver pulls sc_entry + sc_exit.
    final page = DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('sc')]),
      composition: const Composition(family: DesignFamily.singleHero),
      clip: const Clip(shapeId: 'passportPage', code: 'sc'),
    );
    final single = DesignRecipe(
      seed: 1,
      content: const RecipeContent(flags: [FlagRef('sc')]),
      composition: const Composition(family: DesignFamily.singleHero),
      clip: const Clip(shapeId: 'passportStampOutline', code: 'sc_entry'),
    );
    await tester.runAsync(() async {
      final p = await renderer.render(page, RenderTarget.preview(size: 320));
      final s = await renderer.render(single, RenderTarget.preview(size: 320));
      expect(p.pngBytes.length, greaterThan(1000));
      // Two overlaid stamps differ from a single stamp.
      expect(p.imageHash, isNot(s.imageHash));
    });
  });

  testWidgets('multi-country passport page overlays every country\'s stamps',
      (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    DesignRecipe page(String codes) => DesignRecipe(
          seed: 2,
          content: RecipeContent(
              flags: [for (final c in codes.split(',')) FlagRef(c)]),
          composition: const Composition(family: DesignFamily.grid),
          clip: Clip(shapeId: 'passportPage', code: codes),
        );
    await tester.runAsync(() async {
      final one = await renderer.render(page('sc'), RenderTarget.preview(size: 360));
      final three =
          await renderer.render(page('sc,au,gb'), RenderTarget.preview(size: 360));
      expect(three.pngBytes.length, greaterThan(1000));
      // Adding more countries' stamps changes the collage.
      expect(three.imageHash, isNot(one.imageHash));
      // Deterministic for the same country set.
      final three2 =
          await renderer.render(page('sc,au,gb'), RenderTarget.preview(size: 360));
      expect(three.imageHash, three2.imageHash);
    });
  });

  testWidgets('passport collage: random placement + scatter/size/ink options',
      (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    const code = 'sc|12 MAR 24|18 MAR 24;au|05 JUN 23|20 JUN 23;'
        'gb|01 SEP 22|14 SEP 22;fr|10 JUN 21|18 JUN 21';
    DesignRecipe page(
            {int seed = 2,
            double scatter = 0.5,
            double scale = 1.0,
            String? ink}) =>
        DesignRecipe(
          seed: seed,
          content: const RecipeContent(
              flags: [FlagRef('sc'), FlagRef('au'), FlagRef('gb'), FlagRef('fr')]),
          composition: const Composition(family: DesignFamily.grid),
          clip: Clip(
              shapeId: 'passportPage',
              code: code,
              scatter: scatter,
              scale: scale,
              ink: ink),
        );
    await tester.runAsync(() async {
      final a = await renderer.render(page(seed: 2), RenderTarget.preview(size: 360));
      // Different seed → different (random) placement.
      final b = await renderer.render(page(seed: 9), RenderTarget.preview(size: 360));
      expect(a.imageHash, isNot(b.imageHash),
          reason: 'placement must be randomised by seed');
      // Scatter and size change the layout.
      final wide =
          await renderer.render(page(scatter: 0.95), RenderTarget.preview(size: 360));
      expect(wide.imageHash, isNot(a.imageHash));
      final small =
          await renderer.render(page(scale: 0.55), RenderTarget.preview(size: 360));
      expect(small.imageHash, isNot(a.imageHash));
      // Ink modes differ from the flag fill and from each other.
      final black =
          await renderer.render(page(ink: 'black'), RenderTarget.preview(size: 360));
      final white =
          await renderer.render(page(ink: 'white'), RenderTarget.preview(size: 360));
      expect(black.imageHash, isNot(a.imageHash));
      expect(white.imageHash, isNot(black.imageHash));
    });
  });

  testWidgets('trip dates are stamped onto the passport stamp', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());
    DesignRecipe stamp(String code) => DesignRecipe(
          seed: 1,
          content: const RecipeContent(flags: [FlagRef('sc')]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: Clip(shapeId: 'passportStampOutline', code: code),
        );
    await tester.runAsync(() async {
      final noDate = await renderer.render(stamp('sc_exit'),
          RenderTarget.preview(size: 400));
      final dated = await renderer.render(stamp('sc_exit|12 MAR 24'),
          RenderTarget.preview(size: 400));
      // Drawing the date changes the stamp (the date is rendered into the ink).
      expect(dated.imageHash, isNot(noDate.imageHash),
          reason: 'the trip date must appear on the stamp');
      // And it is deterministic.
      final dated2 = await renderer.render(stamp('sc_exit|12 MAR 24'),
          RenderTarget.preview(size: 400));
      expect(dated.imageHash, dated2.imageHash);
    });
  });
}
