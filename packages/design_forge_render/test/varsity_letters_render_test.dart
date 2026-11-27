import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('outline rings: bands in order outside the silhouette', () {
    const n = 60;
    final px = Uint8List(n * n * 4);
    for (var y = 20; y < 40; y++) {
      for (var x = 20; x < 40; x++) {
        final i = (y * n + x) * 4;
        px[i] = px[i + 3] = 255; // red square
      }
    }
    final out = Keyline.outlineRings(px, n, n, [2, 3], [
      [0, 0, 255],
      [0, 255, 0],
    ]);
    int ch(int x, int k) => out[(30 * n + x) * 4 + k];
    expect(ch(19, 2), greaterThan(200), reason: 'inner band blue');
    expect(ch(16, 1), greaterThan(200), reason: 'outer band green');
    expect(out[(30 * n + 10) * 4 + 3], 0, reason: 'nothing beyond the bands');
  });

  testWidgets('varsity letters: the embedded font draws real letters, flag stretched',
      (tester) async {
    late Uint8List px;
    late int w, h;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(
          assets: SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()));
      final img = (await renderer.render(
        const DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef('de')]),
          composition: Composition(
              family: DesignFamily.singleHero, orientation: Orientation.landscape),
          clip: Clip(shapeId: 'text', text: 'DEU', font: 'varsity', scale: 0.9, flagFit: 'stretch'),
        ),
        const RenderTarget(width: 500, height: 400, paintBackground: false),
      ))
          .image;
      w = img.width;
      h = img.height;
      px = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
          .buffer
          .asUint8List();
    });
    // Stretched flag: black, red and gold all appear inside the letters.
    var black = 0, red = 0, gold = 0, ink = 0;
    for (var i = 0; i < w * h * 4; i += 4) {
      if (px[i + 3] < 200) continue;
      ink++;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      if (r < 40 && g < 40 && b < 40) black++;
      if (r > 180 && g < 60 && b < 60) red++;
      if (r > 200 && g > 150 && b < 60) gold++;
    }
    expect(ink, greaterThan(w * h * 0.05));
    expect(black, greaterThan(ink * 0.1));
    expect(red, greaterThan(ink * 0.1));
    expect(gold, greaterThan(ink * 0.1));
  });
}
