import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:design_lab/flag_source.dart';
import 'package:design_lab/recipe_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copies-per-country grids', (tester) async {
    final source = FlagSource.locate()!;
    final renderer = CanvasRenderer(assets: source.resolver());

    // Build via the editor draft (the same path the UI uses).
    DesignRecipe grid(List<String> countries, int copies) {
      final base = DesignRecipe(
        seed: 3,
        content: RecipeContent(flags: [for (final c in countries) FlagRef(c)]),
        composition: const Composition(family: DesignFamily.singleHero),
      );
      return (RecipeDraft(base)
            ..pattern = LabPattern.multi
            ..algorithm = FillAlgorithm.grid
            ..perCountry = copies)
          .toRecipe();
    }

    final au4 = grid(['au'], 4);
    final three2 = grid(['us', 'gb', 'fr'], 2);

    expect(au4.content.flags.length, 4);
    expect(three2.content.flags.length, 6);

    final out = Platform.environment['OUT'];
    await tester.runAsync(() async {
      for (final e in {'copies_au4': au4, 'copies_3countries_2each': three2}.entries) {
        final r = await renderer.render(e.value, RenderTarget.preview(size: 400));
        expect(r.pngBytes.length, greaterThan(500));
        if (out != null) File('$out/${e.key}.png').writeAsBytesSync(r.pngBytes);
      }
    });
  });
}
