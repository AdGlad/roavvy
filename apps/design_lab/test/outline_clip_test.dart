import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('country + continent outline clips render', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    expect(source!.countryPathsDir.existsSync(), isTrue);
    expect(source.continents(), isNotEmpty);

    final renderer = CanvasRenderer(assets: source.resolver());

    DesignRecipe outline(String flag, ClipShape shape, String code) =>
        DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef(flag)]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: Clip.shape(shape, code: code),
        );

    final out = Platform.environment['OUT'];
    late RenderResult france;
    late RenderResult plain;
    await tester.runAsync(() async {
      france = await renderer.render(
          outline('fr', ClipShape.countryOutline, 'fr'),
          RenderTarget.preview(size: 400, background: const Color(0xFFF2F2F2)));
      plain = await renderer.render(
        DesignRecipe(
            seed: 1,
            content: const RecipeContent(flags: [FlagRef('fr')]),
            composition: const Composition(family: DesignFamily.singleHero)),
        RenderTarget.preview(size: 400, background: const Color(0xFFF2F2F2)),
      );
      if (out != null) {
        File('$out/outline_country_fr.png').writeAsBytesSync(france.pngBytes);
        final eu = await renderer.render(
            DesignRecipe(
              seed: 1,
              content: const RecipeContent(
                  flags: [FlagRef('fr'), FlagRef('de'), FlagRef('it'), FlagRef('es')]),
              composition: const Composition(
                  family: DesignFamily.grid, fillAlgorithm: FillAlgorithm.grid),
              clip: Clip.shape(ClipShape.continentOutline, code: 'europe'),
            ),
            RenderTarget.preview(size: 400, background: const Color(0xFFF2F2F2)));
        File('$out/outline_continent_europe.png').writeAsBytesSync(eu.pngBytes);
      }
    });

    // Country-outline clip differs from the unclipped flag.
    expect(france.imageHash, isNot(plain.imageHash));
    expect(france.pngBytes.length, greaterThan(500));
  });
}
