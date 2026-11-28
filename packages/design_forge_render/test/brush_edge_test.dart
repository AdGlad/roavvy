import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

/// An opaque red rectangle on transparent, premultiplied RGBA.
Uint8List _block(int w, int h, int l, int t, int r, int b) {
  final px = Uint8List(w * h * 4);
  for (var y = t; y < b; y++) {
    for (var x = l; x < r; x++) {
      final i = (y * w + x) * 4;
      px[i] = px[i + 3] = 255;
    }
  }
  return px;
}

int _alpha(Uint8List px, int w, int x, int y) => px[(y * w + x) * 4 + 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const w = 300, h = 200;
  const p = BrushStroke();

  test('brush edge is deterministic and seed-dependent', () {
    final src = _block(w, h, 40, 40, 260, 160);
    final a = BrushEdge.paint(src, w, h, p, 7);
    final b = BrushEdge.paint(src, w, h, p, 7);
    final c = BrushEdge.paint(src, w, h, p, 8);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('keeps the middle whole, bites only the edges, frays the end', () {
    final src = _block(w, h, 40, 40, 260, 160);
    final out = BrushEdge.paint(src, w, h, p, 3);
    // Middle (where an emblem sits) untouched.
    for (var y = 70; y < 130; y++) {
      for (var x = 80; x < 200; x++) {
        expect(_alpha(out, w, x, y), 255, reason: 'centre at $x,$y');
      }
    }
    int cleared(int x0, int x1, int y0, int y1) {
      var n = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          if (_alpha(src, w, x, y) == 255 && _alpha(out, w, x, y) < 128) n++;
        }
      }
      return n;
    }

    expect(cleared(80, 220, 40, 50), greaterThan(0), reason: 'top streaks');
    expect(cleared(80, 220, 150, 160), greaterThan(0),
        reason: 'bottom streaks');
    final trailing = cleared(240, 260, 60, 140);
    final leading = cleared(40, 60, 60, 140);
    expect(trailing, greaterThan(leading * 3),
        reason: 'end frays, start clean');
    // Nothing paints far from the shape.
    expect(_alpha(out, w, 5, 5), 0);
  });

  test('vertical strokes brush the left/right edges instead', () {
    final src = _block(w, h, 40, 40, 260, 160);
    final out = BrushEdge.paint(src, w, h, p, 3, vertical: true);
    var leftBites = 0;
    for (var y = 60; y < 140; y++) {
      for (var x = 40; x < 50; x++) {
        if (_alpha(out, w, x, y) < 128) leftBites++;
      }
    }
    expect(leftBites, greaterThan(0));
  });

  testWidgets('mask helpers brush any path', (tester) async {
    await tester.runAsync(() async {
      final heart = ShapeGeometry.build(
          'heart', const ui.Rect.fromLTWH(50, 20, 200, 160), 0)!;
      final m = await BrushEdge.maskForPath(heart, w, h, p, 1);
      final r = await BrushEdge.maskForRect(
          const ui.Rect.fromLTWH(40, 40, 220, 120), w, h, p, 1);
      expect(m.width, w);
      expect(r.height, h);
      final px = (await r.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      expect(_alpha(px, w, 150, 100), 255);
      expect(_alpha(px, w, 5, 5), 0);
    });
  });

  testWidgets('brush flag stage: stroke + handwritten caption, deterministic',
      (tester) async {
    const recipe = DesignRecipe(
      seed: 4,
      content: RecipeContent(flags: [FlagRef('gr')]),
      composition: Composition(
          family: DesignFamily.singleHero, orientation: Orientation.landscape),
      brushStroke: BrushStroke(skew: 2),
      captions: Captions(
          top: 'GREECE', font: 'handwritten', colour: '#FFFFFF', grit: 0),
    );
    late RenderResult a, b;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(
          assets:
              SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()));
      const target =
          RenderTarget(width: 500, height: 400, paintBackground: false);
      a = await renderer.render(recipe, target);
      b = await renderer.render(recipe, target);
      expect(await embeddedFontFamily('handwritten'), HandwrittenFont.family);
    });
    expect(a.imageHash, b.imageHash);
    final px = (await tester.runAsync(() =>
            a.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!
        .buffer
        .asUint8List();
    int al(int x, int y) => px[(y * 500 + x) * 4 + 3];
    // Caption band (top) has white ink; flag centre is opaque blue/white.
    var capInk = 0;
    for (var y = 10; y < 70; y++) {
      for (var x = 0; x < 500; x++) {
        if (al(x, y) > 200) capInk++;
      }
    }
    expect(capInk, greaterThan(500));
    expect(al(250, 240), 255);
    expect(al(3, 397), 0);
  });
}
