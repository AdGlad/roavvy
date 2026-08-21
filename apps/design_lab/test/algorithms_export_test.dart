import 'dart:io';
import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every fill algorithm (with distinct flags, and with repeated single
/// flags) into one contact sheet so the layouts can be eyeballed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all fill algorithms', (tester) async {
    final source = FlagSource.locate();
    expect(source, isNotNull);
    final renderer = CanvasRenderer(assets: source!.resolver());

    const distinct = ['us', 'gb', 'fr', 'de', 'jp', 'br', 'it', 'ca'];

    DesignRecipe multi(FillAlgorithm algo, List<String> codes) => DesignRecipe(
          seed: 7,
          content: RecipeContent(flags: [for (final c in codes) FlagRef(c)]),
          composition: Composition(
              family: DesignFamily.grid, fillAlgorithm: algo),
        );

    final recipes = <DesignRecipe>[];
    // Each algorithm with 8 distinct flags…
    for (final a in FillAlgorithm.values) {
      recipes.add(multi(a, distinct));
    }
    // …and each with 12 instances of the SAME flag.
    for (final a in FillAlgorithm.values) {
      recipes.add(multi(a, List.filled(12, 'us')));
    }

    late final Uint8List sheet;
    await tester.runAsync(() async {
      sheet = await const ContactSheetBuilder(columns: 8, cell: 240)
          .build(recipes, renderer);
    });
    expect(sheet.length, greaterThan(1000));

    final out = Platform.environment['OUT'];
    if (out != null) {
      // Also write individual algorithm tiles (distinct flags) for close-ups.
      await tester.runAsync(() async {
        for (final a in FillAlgorithm.values) {
          final res = await renderer.render(multi(a, distinct),
              RenderTarget.preview(size: 400, background: const Color(0xFFF2F2F2)));
          File('$out/algo_${a.name}.png').writeAsBytesSync(res.pngBytes);
        }
      });
      File('$out/algorithms_sheet.png').writeAsBytesSync(sheet);
      // ignore: avoid_print
      print('wrote algorithm samples to $out');
    }
  });
}
