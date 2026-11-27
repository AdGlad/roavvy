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
    final img = (await renderer.render(
            recipe,
            const RenderTarget(
                width: 320, height: 400, paintBackground: false)))
        .image;
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (bytes!.buffer.asUint8List(), img.width, img.height);
  }

  testWidgets('90° and 270° lay a portrait design on its side, centred, inside the canvas',
      (tester) async {
    await tester.runAsync(() async {
      final (p0, w, h) = await render(0);
      final b0 = _bbox(p0, w, h);
      expect(b0.$4 - b0.$2, greaterThan(b0.$3 - b0.$1), reason: 'portrait at 0°');
      for (final deg in [90, 270]) {
        final (p, _, _) = await render(deg);
        final b = _bbox(p, w, h);
        final bw = b.$3 - b.$1, bh = b.$4 - b.$2;
        expect(bw, greaterThan(bh), reason: 'landscape at $deg°');
        expect(b.$1, greaterThanOrEqualTo(0));
        expect(b.$3, lessThan(w));
        // Centred vertically (within a few pixels).
        expect(((b.$2 + b.$4) / 2 - h / 2).abs(), lessThan(h * 0.08));
      }
    });
  });

  testWidgets('90° anticlockwise moves the torn (bottom) end to the right',
      (tester) async {
    await tester.runAsync(() async {
      // Japan: one white field, frayed only at the free end. At 0° the ragged
      // end is at the bottom; turned anticlockwise it must be on the right,
      // where a real flag frays (the fly end).
      final (p0, w, h) = await render(0, flag: 'jp');
      final (p90, _, _) = await render(90, flag: 'jp');
      double inkShare(Uint8List px, int x0, int y0, int x1, int y1) {
        var ink = 0, all = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            all++;
            if (px[(y * w + x) * 4 + 3] > 32) ink++;
          }
        }
        return ink / all;
      }

      final b0 = _bbox(p0, w, h);
      final top0 = inkShare(p0, b0.$1, b0.$2, b0.$3, b0.$2 + 12);
      final bottom0 = inkShare(p0, b0.$1, b0.$4 - 12, b0.$3, b0.$4);
      expect(bottom0, lessThan(top0), reason: 'frayed end is ragged (less ink)');

      final b = _bbox(p90, w, h);
      final left = inkShare(p90, b.$1, b.$2, b.$1 + 12, b.$4);
      final right = inkShare(p90, b.$3 - 12, b.$2, b.$3, b.$4);
      expect(right, lessThan(left), reason: 'frayed end now on the right');
    });
  });
}
