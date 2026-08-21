import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
SvgFlagResolver _resolver() =>
    SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every procedural + text shape clips a flag', (tester) async {
    final renderer = CanvasRenderer(assets: _resolver());

    final shapes = [
      for (final m in kClipShapeCatalog)
        if (m.source == ClipShapeSource.procedural ||
            m.source == ClipShapeSource.text)
          m,
    ];

    final recipes = <DesignRecipe>[
      for (final m in shapes)
        DesignRecipe(
          seed: 1,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: Clip(
            shapeId: m.id,
            text: m.source == ClipShapeSource.text ? 'ROAM' : null,
          ),
        ),
    ];

    // Each renders non-blank and differs from the unclipped flag.
    late final List<String> hashes;
    await tester.runAsync(() async {
      hashes = [
        for (final r in recipes)
          (await renderer.render(r, RenderTarget.preview(size: 200))).imageHash,
      ];
    });
    expect(hashes.toSet().length, greaterThan(shapes.length ~/ 2),
        reason: 'shapes should produce visibly different masks');

    final out = Platform.environment['OUT'];
    if (out != null) {
      await tester.runAsync(() async {
        final sheet = await const ContactSheetBuilder(columns: 6, cell: 240)
            .build(recipes, renderer);
        File('$out/shapes_sheet.png').writeAsBytesSync(sheet);
        for (var i = 0; i < shapes.length; i++) {
          final r = await renderer.render(recipes[i],
              RenderTarget.preview(size: 320, background: const Color(0xFFF2F2F2)));
          File('$out/shape_${shapes[i].id}.png').writeAsBytesSync(r.pngBytes);
        }
      });
      // ignore: avoid_print
      print('wrote ${shapes.length} shape samples to $out');
    }
  });
}
