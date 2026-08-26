import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// Render consumption of the new recipe fields: copiesPerCountry (B3),
/// passport stampMode (B4), sizeClass + statementHero (B5).

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

Future<String> _hash(DesignRecipe r) async {
  final res = await CanvasRenderer(assets: _resolver())
      .render(r, RenderTarget.preview(size: 220));
  return res.imageHash;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('copiesPerCountry (B3)', () {
    testWidgets('repeating one country into a grid changes the render',
        (tester) async {
      await tester.runAsync(() async {
        DesignRecipe recipe(int copies) => DesignRecipe(
              seed: 3,
              content: const RecipeContent(flags: [FlagRef('us')]),
              composition: Composition(
                family: DesignFamily.grid,
                copiesPerCountry: copies,
              ),
            );
        final one = await _hash(recipe(1));
        final many = await _hash(recipe(6));
        expect(many, isNot(one),
            reason: '6 copies must tile into a grid, not a single hero');
      });
    });
  });
}
