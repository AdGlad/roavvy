import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

final String _flagDir =
    Directory('../../apps/mobile_flutter/assets/flags/svg').absolute.path;

SvgFlagResolver _resolver() =>
    SvgFlagResolver((code) async => File('$_flagDir/$code.svg').readAsString());

DesignRecipe _pair(String a, String b, {SplitPair split = const SplitPair()}) =>
    DesignRecipe(
      seed: 3,
      content: RecipeContent(flags: [FlagRef(a), FlagRef(b)]),
      composition: const Composition(
          family: DesignFamily.splitPair,
          orientation: Orientation.portrait,
          sizeClass: SizeClass.large),
      splitPair: split,
    );

Future<Uint8List> _rgba(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
        .buffer
        .asUint8List();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WearRaster.grunge', () {
    Uint8List block(int n) {
      final px = Uint8List(n * n * 4);
      for (var y = 20; y < n - 20; y++) {
        for (var x = 20; x < n - 20; x++) {
          final i = (y * n + x) * 4;
          px[i] = 200;
          px[i + 1] = 30;
          px[i + 2] = 40;
          px[i + 3] = 255;
        }
      }
      return px;
    }

    Uint8List run(int seed) => WearRaster.grunge(block(200), 200, 200,
        left: 20, top: 20, right: 180, bottom: 180, seed: seed);

    test('is deterministic and seed-dependent', () {
      expect(run(4), run(4));
      expect(run(4), isNot(run(5)));
    });

    test('knocks out flecks and eats the edge, never adds ink', () {
      final src = block(200), out = run(4);
      var removed = 0, added = 0, edgeRemoved = 0;
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          final i = (y * 200 + x) * 4 + 3;
          if (src[i] == 0 && out[i] > 0) added++;
          if (src[i] > 0 && out[i] < 128) {
            removed++;
            if (x < 26 || x > 173 || y < 26 || y > 173) edgeRemoved++;
          }
        }
      }
      expect(added, 0);
      expect(removed, greaterThan(160 * 160 * 0.03));
      expect(removed, lessThan(160 * 160 * 0.5));
      expect(edgeRemoved, greaterThan(0));
    });
  });

  testWidgets('Curtain Split renders both flags, deterministically',
      (tester) async {
    late RenderResult a, b;
    late Uint8List px;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      const target = RenderTarget(width: 320, height: 400);
      a = await renderer.render(_pair('us', 'co'), target);
      b = await renderer.render(_pair('us', 'co'), target);
      px = await _rgba(a.image);
    });
    expect(a.imageHash, b.imageHash);
    // Colombia's yellow on the right, US navy on the left, near the top.
    bool near(int x, int y, List<int> c) {
      final i = (y * 320 + x) * 4;
      return (px[i] - c[0]).abs() +
              (px[i + 1] - c[1]).abs() +
              (px[i + 2] - c[2]).abs() <
          120;
    }

    var yellow = 0, navy = 0;
    for (var y = 60; y < 120; y += 4) {
      for (var x = 20; x < 300; x += 4) {
        if (near(x, y, [252, 209, 22])) yellow++;
        if (near(x, y, [60, 59, 110])) navy++;
      }
    }
    expect(yellow, greaterThan(20));
    expect(navy, greaterThan(20));
  });

  testWidgets('look-alike flags get a garment-colour channel at the seam',
      (tester) async {
    late QaReport withGap;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      final recipe = _pair('id', 'mc',
          split: const SplitPair(
              distress: 0, scratches: 0, edge: SplitEdge.clean, fade: 0));
      final r = await renderer.render(
          recipe, const RenderTarget(width: 320, height: 400));
      withGap =
          await PairQa.checkImage(r.image, geometry: PairGeometry.of(recipe));
    });
    expect(withGap.soft.map((f) => f.code), isNot(contains('pair_seam')),
        reason: '${withGap.toJson()}');
  });

  testWidgets('Diagonal Split: brushed edge, bare channel, deterministic',
      (tester) async {
    const diagonal = SplitPair(
      seam: SplitSeam.diagonal,
      seamSlant: 0.78,
      seamFlip: true,
      seamGap: 0.035,
      blockAspect: 0.66,
      rotateFlags: true,
      edge: SplitEdge.brush,
      distress: 0,
      scratches: 0,
      fade: 0,
      edgeWear: 0,
      shadow: 0,
    );
    const w = 320, h = 400;
    final recipe = _pair('dz', 'py', split: diagonal);
    late RenderResult a, b;
    late Uint8List px;
    await tester.runAsync(() async {
      final renderer = CanvasRenderer(assets: _resolver());
      const target = RenderTarget(width: w, height: h);
      a = await renderer.render(recipe, target);
      b = await renderer.render(recipe, target);
      px = await _rgba(a.image);
    });
    expect(a.imageHash, b.imageHash);
    final layout = SplitPairLayout.of(recipe, w.toDouble(), h.toDouble())!;
    // Layout points → image (the size class scales the art about its centre).
    final scale = recipe.composition.sizeClass.scale;
    int alphaAt(double x, double y) {
      final sx = (w / 2 + (x - w / 2) * scale).round().clamp(0, w - 1);
      final sy = (h / 2 + (y - h / 2) * scale).round().clamp(0, h - 1);
      return px[(sy * w + sx) * 4 + 3];
    }

    // The middle of the channel is bare garment along most of the seam.
    var bare = 0, samples = 0;
    for (final (x, y) in layout.seamPoints.skip(8).take(32)) {
      samples++;
      if (alphaAt(x, y) < 40) bare++;
    }
    expect(bare, greaterThan(samples * 0.6), reason: 'channel $bare/$samples');

    // Either side of the channel is inked.
    final (mx, my) = layout.seamPoints[24];
    final off = layout.blockWidth * 0.12;
    expect(alphaAt(mx - off, my), greaterThan(200));
    expect(alphaAt(mx + off, my), greaterThan(200));

    // The block's left edge is brushed, not one straight column.
    final edgeXs = <int>[];
    for (var y = layout.blockTop + 30;
        y < layout.blockTop + layout.blockHeight - 30;
        y += 4) {
      var x = 0;
      while (x < w ~/ 2 && alphaAt(x.toDouble(), y) < 128) {
        x++;
      }
      edgeXs.add(x);
    }
    edgeXs.sort();
    expect(edgeXs.last - edgeXs.first, greaterThan(0));
  });
}
