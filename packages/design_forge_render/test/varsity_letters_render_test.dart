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

  testWidgets('stretch also fits a drawn shape: a German star shows all three bands',
      (tester) async {
    late Uint8List px;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(
          assets: SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()));
      final img = (await renderer.render(
        const DesignRecipe(
          seed: 1,
          content: RecipeContent(flags: [FlagRef('de')]),
          composition: Composition(
              family: DesignFamily.singleHero, orientation: Orientation.square),
          clip: Clip(shapeId: 'star', scale: 0.94, flagFit: 'stretch'),
        ),
        const RenderTarget(width: 300, height: 300, paintBackground: false),
      ))
          .image;
      px = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
          .buffer
          .asUint8List();
    });
    // Top point (black), centre (red), lower arms (gold).
    List<int> at(int x, int y) => px.sublist((y * 300 + x) * 4, (y * 300 + x) * 4 + 4);
    expect(at(150, 40)[0], lessThan(40), reason: 'black at the top point');
    expect(at(150, 150)[0], greaterThan(180), reason: 'red across the middle');
    expect(at(150, 150)[1], lessThan(60));
    var gold = 0;
    for (var y = 210; y < 290; y++) {
      for (var x = 0; x < 300; x++) {
        final p = at(x, y);
        if (p[3] > 200 && p[0] > 200 && p[1] > 150 && p[2] < 60) gold++;
      }
    }
    expect(gold, greaterThan(500), reason: 'gold in the lower arms');
  });
}

