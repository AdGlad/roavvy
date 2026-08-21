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
}
