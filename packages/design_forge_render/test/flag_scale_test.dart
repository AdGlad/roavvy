import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a smaller flag behind a shape leaves no gaps and shows more flag',
      (tester) async {
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(
          assets: SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()));
      Future<(int, int)> stats(double scale) async {
        // Japan, square: count disc (red) pixels and transparent pixels inside
        // a centred square well within the heart.
        final img = (await renderer.render(
          DesignRecipe(
            seed: 1,
            content: const RecipeContent(flags: [FlagRef('jp')]),
            composition: const Composition(
                family: DesignFamily.singleHero, orientation: Orientation.square),
            clip: Clip(shapeId: 'heart', flagScale: scale),
          ),
          const RenderTarget(width: 200, height: 200, paintBackground: false),
        ))
            .image;
        final px = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
        var red = 0, holes = 0;
        for (var y = 0; y < 200; y++) {
          for (var x = 0; x < 200; x++) {
            final i = (y * 200 + x) * 4;
            if (px[i + 3] > 200 && px[i] > 150 && px[i + 1] < 90) red++;
            if (x > 70 && x < 130 && y > 60 && y < 120 && px[i + 3] < 200) holes++;
          }
        }
        return (red, holes);
      }

      final (redFull, holesFull) = await stats(1.0);
      final (redSmall, holesSmall) = await stats(0.8);
      expect(holesFull, 0);
      expect(holesSmall, 0, reason: 'mirrored fill: no gaps inside the shape');
      expect(redSmall, lessThan(redFull * 0.8),
          reason: 'the disc is drawn smaller, so more of the white field shows');
    });
  });
}
