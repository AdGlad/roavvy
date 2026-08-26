import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported print effects: riso / newsprint / sunFaded / photocopy each visibly
/// change the render, and the identity (no effect) render is unchanged.

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

DesignRecipe _withEffects(Effects fx) => DesignRecipe(
      seed: 7,
      content: const RecipeContent(flags: [FlagRef('us')]),
      composition: const Composition(family: DesignFamily.singleHero),
      effects: fx,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> hashOf(Effects fx) async {
    final r = CanvasRenderer(assets: _resolver());
    final res = await r.render(_withEffects(fx), RenderTarget.preview(size: 200));
    return res.imageHash;
  }

  group('ported print effects', () {
    testWidgets('each effect changes the output; identity does not',
        (tester) async {
      await tester.runAsync(() async {
        final baseline = await hashOf(const Effects());
        expect(await hashOf(const Effects()), baseline,
            reason: 'no effect must be reproducible');
        expect(await hashOf(const Effects(riso: 0.9)), isNot(baseline),
            reason: 'riso must change the render');
        expect(await hashOf(const Effects(newsprint: 0.9)), isNot(baseline),
            reason: 'newsprint must change the render');
        expect(await hashOf(const Effects(sunFaded: 0.9)), isNot(baseline),
            reason: 'sunFaded must change the render');
        expect(await hashOf(const Effects(photocopy: 0.9)), isNot(baseline),
            reason: 'photocopy must change the render');
      });
    });
  });
}
