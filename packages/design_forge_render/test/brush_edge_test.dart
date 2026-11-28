import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

Future<Uint8List> _pixels(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();

int _alpha(Uint8List px, int w, int x, int y) => px[(y * w + x) * 4 + 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const w = 300, h = 200;
  const p = BrushStroke();
  const rect = ui.Rect.fromLTWH(40, 40, 220, 120);

  test('outline is deterministic and seed-dependent', () {
    final shape = ui.Path()..addRect(rect);
    final a = BrushEdge.outline(shape, p, 7).getBounds();
    final b = BrushEdge.outline(shape, p, 7).getBounds();
    final c = BrushEdge.outline(shape, p, 8).getBounds();
    expect(a, b);
    expect(a == c, isFalse);
  });

  testWidgets('solid inside, gently moved long edges, spiky trailing end',
      (tester) async {
    await tester.runAsync(() async {
      final px = await _pixels(await BrushEdge.maskForRect(rect, w, h, p, 3));
      // The whole interior is paint: no gaps through the stripes.
      for (var y = 60; y < 140; y++) {
        for (var x = 70; x < 210; x++) {
          expect(_alpha(px, w, x, y), 255, reason: 'inside at $x,$y');
        }
      }
      // Trailing edge: along a column just past the box, paint comes and
      // goes (spikes and notches); the leading edge stays nearly straight.
      int changes(int x) {
        var n = 0, prev = _alpha(px, w, x, 50) > 127;
        for (var y = 51; y < 150; y++) {
          final on = _alpha(px, w, x, y) > 127;
          if (on != prev) n++;
          prev = on;
        }
        return n;
      }

      final trailing =
          [for (var x = 235; x < 285; x++) changes(x)].reduce(math.max);
      expect(trailing, greaterThan(6), reason: 'jagged lift-off');
      expect(changes(44), lessThan(4), reason: 'clean leading edge');
      // Anti-aliased: partial alpha exists along the outline.
      var partial = 0;
      for (var i = 3; i < px.length; i += 4) {
        if (px[i] > 0 && px[i] < 255) partial++;
      }
      expect(partial, greaterThan(50));
      expect(_alpha(px, w, 5, 5), 0);
    });
  });

  testWidgets('vertical strokes spike at the bottom instead', (tester) async {
    await tester.runAsync(() async {
      final px = await _pixels(
          await BrushEdge.maskForRect(rect, w, h, p, 3, vertical: true));

      var changes = 0;
      for (var y = 140; y < 175; y++) {
        var n = 0, prev = _alpha(px, w, 40, y) > 127;
        for (var x = 41; x < 260; x++) {
          final on = _alpha(px, w, x, y) > 127;
          if (on != prev) n++;
          prev = on;
        }
        changes = math.max(changes, n);
      }
      expect(changes, greaterThan(6));
    });
  });

  testWidgets('narrow parts are roughened, never cut away (heart tip)',
      (tester) async {
    await tester.runAsync(() async {
      final heart = ShapeGeometry.build(
          'heart', const ui.Rect.fromLTWH(50, 10, 200, 180), 0)!;
      const rough = BrushStroke(dryness: 1, liftFray: 1, spill: 1);
      final px =
          await _pixels(await BrushEdge.maskForPath(heart, w, h, rough, 1));
      // Every row of the tip region still holds paint (it may lean).
      final tipBottom = heart.getBounds().bottom.floor();
      var painted = 0;
      for (var y = tipBottom - 40; y < tipBottom - 8; y++) {
        var any = false;
        for (var x = 100; x < 200; x++) {
          if (_alpha(px, w, x, y) > 127) any = true;
        }
        if (any) painted++;
      }
      expect(painted, 32);
    });
  });

  testWidgets('brushArtwork: spikes carry the neighbouring paint',
      (tester) async {
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec)
        ..drawRect(const ui.Rect.fromLTWH(40, 40, 220, 60),
            ui.Paint()..color = const ui.Color(0xFFFF0000))
        ..drawRect(const ui.Rect.fromLTWH(40, 100, 220, 60),
            ui.Paint()..color = const ui.Color(0xFF0000FF));
      final art = await rec.endRecording().toImage(w, h);
      final out = await _pixels(await BrushEdge.brushArtwork(art, p, 2,
          shape: ui.Path()..addRect(rect)));
      // Every painted pixel past the original right edge is red or blue.
      for (var y = 40; y < 160; y++) {
        for (var x = 261; x < 295; x++) {
          final i = (y * w + x) * 4;
          if (out[i + 3] < 250) continue;
          expect(out[i] > 200 || out[i + 2] > 200, isTrue);
          expect(out[i + 1] < 40, isTrue);
        }
      }
      final colour = BrushEdge.extendColour(Uint8List(16), 2, 2, 4);
      expect(colour.every((b) => b == 0), isTrue, reason: 'nothing to extend');
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
