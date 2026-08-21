import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies silhouette clipping renders a non-blank, differently-shaped result,
/// and (with OUT set) exports samples to eyeball.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('silhouette clip masks the artwork', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    expect(source!.silhouetteSlugs(), isNotEmpty,
        reason: 'silhouette SVGs must be discoverable');

    final renderer = CanvasRenderer(assets: source.resolver());

    DesignRecipe clipped(String flag, String slug) => DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef(flag)]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: Clip.shape(ClipShape.animalSilhouette, code: slug),
        );

    late RenderResult eagle;
    late RenderResult plain;
    await tester.runAsync(() async {
      eagle = await renderer.render(
          clipped('us', 'us_bald_eagle'), RenderTarget.preview(size: 384, background: const Color(0xFFF2F2F2)));
      plain = await renderer.render(
        DesignRecipe(
          seed: 1,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
        ),
        RenderTarget.preview(size: 384, background: const Color(0xFFF2F2F2)),
      );
    });

    // The clipped render differs from the unclipped one.
    expect(eagle.imageHash, isNot(plain.imageHash));
    expect(eagle.pngBytes.length, greaterThan(500));

    final out = Platform.environment['OUT'];
    if (out != null) {
      await tester.runAsync(() async {
        for (final e in const [
          ('us', 'us_bald_eagle'),
          ('gb', 'gb_lion'),
          ('jp', 'jp_mount_fuji'),
          ('fr', 'fr_eiffel_tower'),
          ('br', 'br_jaguar'),
        ]) {
          final r = await renderer.render(clipped(e.$1, e.$2),
              RenderTarget.preview(size: 384, background: const Color(0xFFF2F2F2)));
          File('$out/silhouette_${e.$2}.png').writeAsBytesSync(r.pngBytes);
        }
      });
      // ignore: avoid_print
      print('wrote silhouette samples to $out');
    }
  });
}
