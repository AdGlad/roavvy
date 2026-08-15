import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_mask_renderer.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_recipe.dart';

/// A fully-opaque solid-colour square, standing in for intact flag artwork.
Future<ui.Image> _solid(int size, int argb) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = ui.Color(argb),
  );
  final img = await rec.endRecording().toImage(size, size);
  return img;
}

Future<int> _alphaAt(ui.Image img, int x, int y) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = (y * img.width + x) * 4;
  return data!.getUint8(i + 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => TornMaskRenderer.instance.clearCache());

  test('keepMask produces an image within the size cap', () async {
    final img = await TornMaskRenderer.instance.keepMask(
        sampleTornRecipe(TearStyle.ragged, 1),
        width: 4000,
        height: 2000,
        cap: 512);
    expect(img.width, 512);
    expect(img.height, 256);
  });

  test('applyTo carves the torn perimeter but keeps the centre opaque',
      () async {
    final flag = await _solid(160, 0xFF3366CC);
    final torn = await TornMaskRenderer.instance
        .applyTo(flag, sampleTornRecipe(TearStyle.heavyEdgeDamage, 2));
    expect(torn.width, 160);
    // Centre survives (interior never tears).
    expect(await _alphaAt(torn, 80, 80), 255);
    flag.dispose();
    torn.dispose();
  });

  test('an asymmetric recipe removes more of the fly edge than the hoist',
      () async {
    final flag = await _solid(200, 0xFFFFFFFF);
    final torn = await TornMaskRenderer.instance
        .applyTo(flag, sampleTornRecipe(TearStyle.asymmetricTear, 3));
    final data =
        (await torn.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int transparentColumn(int x) {
      var n = 0;
      for (var y = 0; y < torn.height; y++) {
        final a = data.getUint8((y * torn.width + x) * 4 + 3);
        if (a < 32) n++;
      }
      return n;
    }

    final fly = transparentColumn(torn.width - 2); // right edge
    final hoist = transparentColumn(1); // left edge
    expect(fly, greaterThan(hoist),
        reason: 'fly edge should be more torn than the hoist');
    flag.dispose();
    torn.dispose();
  });

  test('masks are cached and reused for the same recipe + size', () async {
    final r = sampleTornRecipe(TearStyle.battleWorn, 7);
    final a = await TornMaskRenderer.instance.keepMask(r, width: 128, height: 128);
    final b = await TornMaskRenderer.instance.keepMask(r, width: 128, height: 128);
    expect(identical(a, b), isTrue);
  });
}
