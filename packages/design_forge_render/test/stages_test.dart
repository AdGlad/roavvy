import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;
SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) => File('$_flagDir/$code.svg').readAsString());

Future<List<int>> _alphaAt(ui.Image img, List<(int, int)> points) async {
  final data = (await img.toByteData())!.buffer.asUint8List();
  final w = img.width;
  return [for (final (x, y) in points) data[(y * w + x) * 4 + 3]];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TornMaskGenerator geometry', () {
    testWidgets('interior stays intact; edges are eroded', (tester) async {
      await tester.runAsync(() async {
        const gen = TornMaskGenerator();
        const w = 256, h = 256;
        final mask = await gen.generate(
          w,
          h,
          const EdgeTreatment(
              style: TearStyle.heavyEdgeDamage, edgeDamage: 0.9, asymmetry: 0.5),
          12345,
        );
        // Centre 60% must be fully kept (no random holes).
        final centre = await _alphaAt(mask, const [
          (128, 128),
          (110, 128),
          (146, 128),
          (128, 110),
          (128, 146),
        ]);
        expect(centre.every((a) => a == 255), isTrue,
            reason: 'interior must not be torn');

        // Sample a ring of edge pixels; some must be removed.
        final edge = await _alphaAt(mask, [
          for (var x = 2; x < w; x += 8) (x, 2),
          for (var x = 2; x < w; x += 8) (x, h - 3),
          for (var y = 2; y < h; y += 8) (2, y),
          for (var y = 2; y < h; y += 8) (w - 3, y),
        ]);
        final removed = edge.where((a) => a == 0).length;
        expect(removed, greaterThan(edge.length ~/ 6),
            reason: 'edges must show real tearing');
      });
    });

    testWidgets('deterministic for same seed, varies by seed', (tester) async {
      await tester.runAsync(() async {
        const gen = TornMaskGenerator();
        const t = EdgeTreatment(edgeDamage: 0.7);
        final a = (await (await gen.generate(96, 96, t, 5)).toByteData())!
            .buffer
            .asUint8List();
        final b = (await (await gen.generate(96, 96, t, 5)).toByteData())!
            .buffer
            .asUint8List();
        final c = (await (await gen.generate(96, 96, t, 6)).toByteData())!
            .buffer
            .asUint8List();
        expect(a, b, reason: 'same seed → identical mask');
        expect(a, isNot(c), reason: 'different seed → different mask');
      });
    });
  });

  group('render determinism & effects', () {
    DesignRecipe torn() => DesignRecipe(
          seed: 99,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
          edgeTreatment: const EdgeTreatment(edgeDamage: 0.7),
          effects: const Effects(distress: 0.3, grain: 0.3),
          palette: const Palette(vintageGrade: 0.6),
        );

    testWidgets('same recipe → identical image hash', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final a = await r.render(torn(), RenderTarget.preview(size: 200));
        final b = await r.render(torn(), RenderTarget.preview(size: 200));
        expect(a.imageHash, b.imageHash);
      });
    });

    testWidgets('an effect changes the output', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final plain = DesignRecipe(
          seed: 99,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
        );
        final withHalftone = plain.copyWith(effects: const Effects(halftone: 1.0));
        final a = await r.render(plain, RenderTarget.preview(size: 200));
        final b = await r.render(withHalftone, RenderTarget.preview(size: 200));
        expect(a.imageHash, isNot(b.imageHash));
      });
    });
  });

  group('resolution independence', () {
    testWidgets('preview and print both render the same recipe non-blank',
        (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final recipe = DesignRecipe(
          seed: 3,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
          edgeTreatment: const EdgeTreatment(edgeDamage: 0.6),
        );
        final preview = await r.render(recipe, RenderTarget.preview(size: 128));
        final print = await r.render(
            recipe, RenderTarget.print(width: 512, height: 512));
        expect(preview.image.width, 128);
        expect(print.image.width, 512);
        // Both share the same recipeId (resolution is not part of the recipe).
        expect(preview.recipeId, print.recipeId);
        expect(preview.pngBytes.length, greaterThan(200));
        expect(print.pngBytes.length, greaterThan(200));
      });
    });
  });
}
