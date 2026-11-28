import 'dart:io';
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

DesignRecipe _recipe(HeartPair p, String a, String b, Orientation o) =>
    DesignRecipe(
      seed: 4,
      content: RecipeContent(flags: [FlagRef(a), FlagRef(b)]),
      composition: Composition(
          family: DesignFamily.singleHero,
          orientation: o,
          sizeClass: SizeClass.large),
      heartPair: p,
    );

Future<RenderResult> _render(DesignRecipe r, int w, int h) => CanvasRenderer(
        assets: SvgFlagResolver((c) => File('$_flagDir/$c.svg').readAsString()))
    .render(r, RenderTarget(width: w, height: h));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paintHatch fills the heart and keeps the top notch open',
      (tester) async {
    await tester.runAsync(() async {
      const box = HeartRect(50, 50, 300, 300 / 1.1);
      final pts = HeartPairLayout.heartPolygon(box);
      final heart = ui.Path()
        ..addPolygon([for (final (x, y) in pts) ui.Offset(x, y)], true);
      Future<Uint8List> mask(int seed) async {
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec);
        canvas.saveLayer(null, ui.Paint());
        BrushEdge.paintHatch(canvas, heart,
            angleDeg: -38, width: 20, spill: 0.5, seed: seed);
        canvas.restore();
        return _pixels(await rec.endRecording().toImage(400, 400));
      }

      final px = await mask(3);
      int a(int x, int y) => px[(y * 400 + x) * 4 + 3];
      // Solid inside (away from the dry streaks near the stroke ends).
      expect(a(200, 200), 255);
      expect(a(140, 150), 255);
      expect(a(260, 150), 255);
      // The notch between the lobes (just below the top edge, centred)
      // stays unpainted.
      expect(a(200, 62), lessThan(128));
      // Seeded: same seed, same mask; another seed differs.
      expect(await mask(3), px);
      expect(await mask(4) == px, isFalse);
    });
  });

  testWidgets('shared heart: A on the left, B on the right, deterministic',
      (tester) async {
    await tester.runAsync(() async {
      final r = _recipe(const HeartPair(scratches: 0, streaks: 0), 'co', 'de',
          Orientation.square);
      final res = await _render(r, 300, 300);
      final again = await _render(r, 300, 300);
      expect(res.imageHash, again.imageHash);
      final px = await _pixels(res.image);
      (int, int, int, int) at(int x, int y) {
        final i = (y * 300 + x) * 4;
        return (px[i], px[i + 1], px[i + 2], px[i + 3]);
      }

      // Colombia's yellow top band on the left lobe…
      final (lr, lg, lb, la) = at(90, 95);
      expect(la, 255);
      expect(lr > 200 && lg > 180 && lb < 80, isTrue,
          reason: 'yellow, got $lr,$lg,$lb');
      // …Germany's black top band on the right lobe.
      final (rr, rg, rb, ra) = at(215, 95);
      expect(ra, 255);
      expect(rr < 60 && rg < 60 && rb < 60, isTrue,
          reason: 'black, got $rr,$rg,$rb');
      // Outside the heart (corners) is clear.
      expect(at(5, 290).$4, 0);
    });
  });

  testWidgets('twin hearts: two separate hearts; Nepal sits on white',
      (tester) async {
    await tester.runAsync(() async {
      final r = _recipe(
          const HeartPair(layout: HeartPair.twin, scratches: 0, streaks: 0),
          'np',
          'ch',
          Orientation.landscape);
      final res = await _render(r, 500, 400);
      final px = await _pixels(res.image);
      int alpha(int x, int y) => px[(y * 500 + x) * 4 + 3];
      final l = HeartPairLayout.ofRecipe(r, height: 400)!;
      final (ax, ay) = l.slots[0].pivot;
      final (bx, by) = l.slots[1].pivot;
      // Both heart centres are painted (Nepal's transparent corners are
      // backed, so its heart is whole)…
      expect(alpha(ax.round(), ay.round()), 255);
      expect(alpha(bx.round(), by.round()), 255);
      // …the gap between them is not.
      expect(alpha(250, (ay + by) ~/ 2 + 40), 0);
    });
  });

  testWidgets('heart wall: one painted heart per country, deterministic',
      (tester) async {
    await tester.runAsync(() async {
      const codes = ['fr', 'jp', 'us', 'br', 'np', 'za', 'gb'];
      final r = DesignRecipe(
        seed: 2,
        content: RecipeContent(flags: [for (final c in codes) FlagRef(c)]),
        composition: const Composition(
            family: DesignFamily.singleHero,
            orientation: Orientation.portrait,
            sizeClass: SizeClass.large),
        heartWall: const HeartWall(scratches: 0, streaks: 0),
      );
      final res = await _render(r, 400, 500);
      expect((await _render(r, 400, 500)).imageHash, res.imageHash);
      final px = await _pixels(res.image);
      final l = HeartWallLayout.ofRecipe(r, height: 500)!;
      expect(l.slots, hasLength(codes.length));
      for (final s in l.slots) {
        final (x, y) = s.pivot;
        expect(px[(y.round() * 400 + x.round()) * 4 + 3], 255,
            reason: '${s.code} heart centre');
      }
      // Between rows (just under the first row's hearts) is empty.
      final row0 = l.slots.first.heartBox;
      final gapY = (row0.bottom + l.slots[l.columns].heartBox.top) ~/ 2;
      expect(px[(gapY * 400 + 2) * 4 + 3], 0);
    });
  });
}
