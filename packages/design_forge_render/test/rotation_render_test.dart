import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

/// Bounding box of inked pixels: (left, top, right, bottom).
(int, int, int, int) _bbox(Uint8List px, int w, int h) {
  var l = w, t = h, r = -1, b = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] > 32) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  return (l, t, r, b);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(Uint8List, int, int)> render(int rotation, {String flag = 'us'}) async {
    final renderer = CanvasRenderer(
        assets: SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()));
    final recipe = DesignRecipe(
      seed: 1,
      content: RecipeContent(flags: [FlagRef(flag)]),
      composition: Composition(
          family: DesignFamily.portraitTornFlag,
          sizeClass: SizeClass.large,
          rotation: rotation),
      tornStrips: const TornStrips(),
    );
    // As RenderService.targetFor does: the canvas takes the turned shape.
    final landscape = recipe.composition.canvasOrientation == Orientation.landscape;
    final img = (await renderer.render(
            recipe,
            RenderTarget(
                width: landscape ? 400 : 320,
                height: landscape ? 320 : 400,
                paintBackground: false)))
        .image;
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (bytes!.buffer.asUint8List(), img.width, img.height);
  }

  test('a quarter turn swaps the canvas shape', () {
    Composition c(int r) =>
        Composition(family: DesignFamily.portraitTornFlag, rotation: r);
    expect(c(0).canvasOrientation, Orientation.portrait);
    expect(c(90).canvasOrientation, Orientation.landscape);
    expect(c(180).canvasOrientation, Orientation.portrait);
    expect(c(270).canvasOrientation, Orientation.landscape);
  });

  testWidgets('90° and 270° fill a landscape canvas as fully as 0° fills portrait',
      (tester) async {
    await tester.runAsync(() async {
      final (p0, w0, h0) = await render(0);
      final b0 = _bbox(p0, w0, h0);
      expect((w0, h0), (320, 400));
      final tall = (b0.$4 - b0.$2) / h0, wide0 = (b0.$3 - b0.$1) / w0;
      for (final deg in [90, 270]) {
        final (p, w, h) = await render(deg);
        expect((w, h), (400, 320), reason: 'landscape canvas at $deg°');
        final b = _bbox(p, w, h);
        // The turned design spans the canvas the way it did upright.
        expect(((b.$3 - b.$1) / w - tall).abs(), lessThan(0.02));
        expect(((b.$4 - b.$2) / h - wide0).abs(), lessThan(0.02));
      }
    });
  });

  testWidgets('90° is the upright render turned anticlockwise',
      (tester) async {
    await tester.runAsync(() async {
      // The free (torn) end is at the bottom upright; turned anticlockwise it
      // must land on the right, where a real flag frays (the fly end).
      final (p0, w0, h0) = await render(0, flag: 'jp');
      final (p90, w, h) = await render(90, flag: 'jp');
      expect((w, h), (h0, w0));
      // Compare WHERE the ink is (alpha > 32): resampling the distress
      // texture softens partial-alpha edges slightly differently once turned.
      var agree = 0, ink = 0, kept = 0;
      for (var y = 0; y < h0; y++) {
        for (var x = 0; x < w0; x++) {
          // Anticlockwise: source (x, y) -> (y, w0 - 1 - x).
          final ink0 = p0[(y * w0 + x) * 4 + 3] > 32;
          final ink90 = p90[((w0 - 1 - x) * w + y) * 4 + 3] > 32;
          if (ink0 == ink90) agree++;
          if (ink0) {
            ink++;
            if (ink90) kept++;
          }
        }
      }
      expect(kept / ink, greaterThan(0.999), reason: 'every inked pixel moves, none is lost');
      expect(agree / (w0 * h0), greaterThan(0.985), reason: 'only faint specks differ');
    });
  });
}
