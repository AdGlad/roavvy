import 'dart:io';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flag SVGs live in the mobile app for now; Phase 8 introduces a shared asset
/// package. The Lab/tests read them straight from disk (no asset bundle).
final String _flagDir = () {
  // package cwd is packages/design_forge_render during `flutter test`.
  return Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
}();

SvgFlagResolver _resolver() => SvgFlagResolver((code) async {
      final file = File('$_flagDir/$code.svg');
      return file.readAsString();
    });

DesignRecipe _single(String code) => DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef(code)]),
      composition: const Composition(family: DesignFamily.singleHero),
    );

bool _isPng(List<int> b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 && // P
    b[2] == 0x4E && // N
    b[3] == 0x47; // G

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flag SVG assets are present on disk', () {
    expect(File('$_flagDir/jp.svg').existsSync(), isTrue,
        reason: 'expected flag SVGs at $_flagDir');
  });

  testWidgets('single flag renders headlessly to a PNG (no widget tree)',
      (tester) async {
    late RenderResult result;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      result = await renderer.render(
        _single('jp'),
        RenderTarget.preview(size: 256),
      );
    });

    expect(result.image.width, 256);
    expect(result.image.height, 256);
    expect(_isPng(result.pngBytes), isTrue);
    expect(result.pngBytes.length, greaterThan(200));
    expect(result.recipeId, isNotEmpty);
    expect(result.imageHash, hasLength(16));
  });

  testWidgets('render is deterministic — same recipe → same image hash',
      (tester) async {
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      final a = await renderer.render(_single('fr'), RenderTarget.preview(size: 256));
      final b = await renderer.render(_single('fr'), RenderTarget.preview(size: 256));
      expect(a.recipeId, b.recipeId);
      expect(a.imageHash, b.imageHash);
    });
  });

  testWidgets('multi-flag grid composition renders headlessly', (tester) async {
    late RenderResult result;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      final recipe = DesignRecipe(
        seed: 2,
        content: const RecipeContent(
          flags: [FlagRef('jp'), FlagRef('fr'), FlagRef('de'), FlagRef('it')],
        ),
        composition: const Composition(family: DesignFamily.grid),
      );
      result = await renderer.render(
        recipe,
        RenderTarget.preview(size: 300, background: const Color(0xFF101010)),
      );
    });
    expect(_isPng(result.pngBytes), isTrue);
    expect(result.image.width, 300);
  });
}
