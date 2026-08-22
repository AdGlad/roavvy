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

    testWidgets('shatter warps the artwork, deterministically', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final plain = DesignRecipe(
          seed: 7,
          content: const RecipeContent(flags: [FlagRef('br')]),
          composition: const Composition(family: DesignFamily.singleHero),
        );
        final shattered =
            plain.copyWith(effects: const Effects(shatter: 0.85));
        final a = await r.render(plain, RenderTarget.preview(size: 200));
        final b = await r.render(shattered, RenderTarget.preview(size: 200));
        final b2 = await r.render(shattered, RenderTarget.preview(size: 200));
        expect(b.imageHash, isNot(a.imageHash), reason: 'shatter must alter it');
        expect(b.pngBytes.length, greaterThan(200), reason: 'non-blank');
        expect(b.imageHash, b2.imageHash, reason: 'deterministic for same seed');
      });
    });
  });

  group('halftone screen', () {
    // Mean absolute per-channel difference between two images over a central
    // INTERIOR patch. The original defect left the interior identical to the
    // unscreened flag (only an edge fringe changed) → this would be ~0; a screen
    // that re-covers the whole area changes the interior → this is large.
    Future<double> interiorDiff(ui.Image a, ui.Image b) async {
      final da = (await a.toByteData())!.buffer.asUint8List();
      final db = (await b.toByteData())!.buffer.asUint8List();
      final w = a.width, h = a.height;
      final x0 = w * 4 ~/ 10, x1 = w * 6 ~/ 10;
      final y0 = h * 4 ~/ 10, y1 = h * 6 ~/ 10;
      var sum = 0.0;
      var n = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          sum += (da[i] - db[i]).abs() +
              (da[i + 1] - db[i + 1]).abs() +
              (da[i + 2] - db[i + 2]).abs();
          n += 3;
        }
      }
      return sum / n;
    }

    DesignRecipe base(Effects? fx) => DesignRecipe(
          seed: 42,
          content: const RecipeContent(flags: [FlagRef('us')]),
          composition: const Composition(family: DesignFamily.singleHero),
          clip: const Clip(shapeId: 'circle'),
          effects: fx,
        );

    testWidgets('partial strength re-screens the whole area, not just edges',
        (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        const bg = ui.Color(0xFFF2F2F2);
        final plain =
            await r.render(base(null), RenderTarget.preview(size: 400, background: bg));
        final half = await r.render(
            base(const Effects(halftone: 0.5, halftoneScale: 6)),
            RenderTarget.preview(size: 400, background: bg));
        final full = await r.render(
            base(const Effects(halftone: 1.0, halftoneScale: 6)),
            RenderTarget.preview(size: 400, background: bg));

        // (a) full-strength halftone differs from the unscreened flag.
        expect(full.imageHash, isNot(plain.imageHash),
            reason: 'full halftone must change the image');
        // (b) partial strength differs from BOTH unscreened AND full.
        expect(half.imageHash, isNot(plain.imageHash),
            reason: 'partial halftone must change the image');
        expect(half.imageHash, isNot(full.imageHash),
            reason: 'partial must differ from full (real re-screen, not a copy)');

        // The core defect: at partial strength the screen must re-cover the
        // INTERIOR, not leave it identical to the unscreened flag with only an
        // edge fringe. A meaningful interior difference proves it re-screens.
        final dHalf = await interiorDiff(half.image, plain.image);
        final dFull = await interiorDiff(full.image, plain.image);
        expect(dHalf, greaterThan(12.0),
            reason: 'partial halftone must re-screen the interior, not stay flat');
        expect(dFull, greaterThan(12.0),
            reason: 'full halftone must re-screen the interior');
      });
    });

    testWidgets('deterministic for same seed', (tester) async {
      await tester.runAsync(() async {
        final r = CanvasRenderer(assets: _resolver());
        final a = await r.render(base(const Effects(halftone: 0.5)),
            RenderTarget.preview(size: 256));
        final b = await r.render(base(const Effects(halftone: 0.5)),
            RenderTarget.preview(size: 256));
        expect(a.imageHash, b.imageHash);
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
