// The recolouring that lets the Studio show a garment colour no photograph
// exists for. If this drifts, shirts come out the wrong colour or full of holes.
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_mockup_spec.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/garment_tint.dart';

/// A stand-in for the bundled photography: a pure-white studio sweep with a
/// garment in the middle, shaded by a fold, and carrying one near-white
/// highlight *inside* the garment — the pixel a naive brightness threshold
/// would wrongly punch out.
Future<ui.Image> fakeShirtPhoto({
  int size = 64,
  int garmentGrey = 200,
  int foldGrey = 150,
  int highlight = 252,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  ui.Color grey(int v) => ui.Color.fromARGB(255, v, v, v);
  // Garment body, inset from every edge so the sweep reaches all borders.
  canvas.drawRect(
    ui.Rect.fromLTWH(size * 0.25, size * 0.25, size * 0.5, size * 0.5),
    ui.Paint()..color = grey(garmentGrey),
  );
  // A fold running through it.
  canvas.drawRect(
    ui.Rect.fromLTWH(size * 0.25, size * 0.45, size * 0.5, size * 0.08),
    ui.Paint()..color = grey(foldGrey),
  );
  // An enclosed highlight.
  canvas.drawRect(
    ui.Rect.fromLTWH(size * 0.45, size * 0.30, size * 0.08, size * 0.08),
    ui.Paint()..color = grey(highlight),
  );
  return recorder.endRecording().toImage(size, size);
}

Future<List<int>> rgbaAt(ui.Image img, int x, int y) async {
  final data = (await img.toByteData())!.buffer.asUint8List();
  final i = (y * img.width + x) * 4;
  return [data[i], data[i + 1], data[i + 2], data[i + 3]];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = 64;
  // Points in the fake photo, by role.
  const corner = (2, 2); // studio sweep
  const body = (20, 20); // plain garment
  const fold = (20, 30); // shaded garment
  const highlight = (30, 21); // near-white, enclosed by garment

  testWidgets('the studio backdrop becomes transparent', (tester) async {
    await tester.runAsync(() async {
      final out = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        const ui.Color(0xFF6B7350),
      );
      expect((await rgbaAt(out, corner.$1, corner.$2))[3], 0);
      expect((await rgbaAt(out, size - 3, size - 3))[3], 0);
      // The garment itself stays fully opaque.
      expect((await rgbaAt(out, body.$1, body.$2))[3], 255);
    });
  });

  testWidgets('a highlight enclosed by garment is NOT punched out', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final out = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        const ui.Color(0xFF6B7350),
      );
      // This is the whole reason the backdrop is flood-filled from the border
      // rather than thresholded: at 252 this pixel is brighter than the
      // backdrop floor, but it is not connected to the sweep.
      expect(
        (await rgbaAt(out, highlight.$1, highlight.$2))[3],
        255,
        reason: 'threshold-style masking punched a hole in the shirt',
      );
    });
  });

  testWidgets('lit fabric lands on the requested colour', (tester) async {
    await tester.runAsync(() async {
      const olive = ui.Color(0xFF6B7350);
      final out = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        olive,
      );
      // The contract: the garment's LIT tone reads as the swatch. Everything
      // shaded sits below it, which is what a photo of an olive shirt looks
      // like — light on cloth can only darken the dye.
      final lit = await rgbaAt(out, highlight.$1, highlight.$2);
      expect(lit[0], closeTo(olive.r * 255, 12));
      expect(lit[1], closeTo(olive.g * 255, 12));
      expect(lit[2], closeTo(olive.b * 255, 12));

      // …and shaded fabric sits below it, never over. (In this fixture the flat
      // body IS the lit tone — most of the garment is unshaded — so the fold is
      // what must come out darker.)
      final shaded = await rgbaAt(out, fold.$1, fold.$2);
      expect(shaded[1], lessThan(lit[1]));
      expect(shaded[1], greaterThan(0));
      final plain = await rgbaAt(out, body.$1, body.$2);
      expect(
        plain[1],
        lessThanOrEqualTo(lit[1]),
        reason: 'nothing may exceed the swatch the shirt is meant to be',
      );
    });
  });

  testWidgets('folds survive the recolour', (tester) async {
    await tester.runAsync(() async {
      final out = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        const ui.Color(0xFF6B7350),
      );
      final plain = await rgbaAt(out, body.$1, body.$2);
      final shaded = await rgbaAt(out, fold.$1, fold.$2);
      expect(
        shaded[1],
        lessThan(plain[1]),
        reason: 'the fold must stay darker than the body',
      );
    });
  });

  testWidgets('two different colours give two different shirts', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sand = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        const ui.Color(0xFFD8C9A3),
      );
      final navy = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size),
        const ui.Color(0xFF22303A),
      );
      final a = await rgbaAt(sand, body.$1, body.$2);
      final b = await rgbaAt(navy, body.$1, body.$2);
      expect(a, isNot(b));
      // Sand is far lighter than Navy — the ordering must survive.
      expect(a[0], greaterThan(b[0]));
    });
  });

  testWidgets('exposure differences between photos wash out', (tester) async {
    await tester.runAsync(() async {
      const olive = ui.Color(0xFF6B7350);
      // The same garment shot two stops apart must recolour to the same shirt.
      final bright = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size, garmentGrey: 220, foldGrey: 170),
        olive,
      );
      final dim = await GarmentTint.recolour(
        await fakeShirtPhoto(size: size, garmentGrey: 150, foldGrey: 100),
        olive,
      );
      final a = await rgbaAt(bright, body.$1, body.$2);
      final b = await rgbaAt(dim, body.$1, body.$2);
      for (var c = 0; c < 3; c++) {
        expect(
          a[c],
          closeTo(b[c], 24),
          reason: 'normalisation should absorb the exposure difference',
        );
      }
    });
  });

  testWidgets('cutout removes the backdrop without changing garment colour', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await fakeShirtPhoto(size: size);
      final before = await rgbaAt(src, body.$1, body.$2);
      final out = await GarmentTint.cutout(src);
      expect((await rgbaAt(out, corner.$1, corner.$2))[3], 0);
      expect(await rgbaAt(out, body.$1, body.$2), before);
    });
  });

  // ── The real bundled photography ───────────────────────────────────────────
  //
  // Synthetic fixtures cannot catch this class of bug: the first tint base was
  // the WHITE shirt, whose blown-out shoulders are pixel-identical to the white
  // studio sweep. The cutout leaked straight through them and bit black holes
  // out of both shoulders on screen. These run the actual assets.
  group('the fold map fed to the shading pass', () {
    testWidgets('is greyscale whatever colour the garment is', (tester) async {
      await tester.runAsync(() async {
        // A garment photographed in a saturated colour. The painter MULTIPLIES
        // the shading over the print, so if any of that colour survives into
        // the map it is multiplied straight into the ink.
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 64, 64),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
        canvas.drawRect(
          const ui.Rect.fromLTWH(16, 16, 32, 32),
          ui.Paint()..color = const ui.Color(0xFFFF1B2B), // Printful Red
        );
        canvas.drawRect(
          const ui.Rect.fromLTWH(16, 28, 32, 5),
          ui.Paint()..color = const ui.Color(0xFF8E0F18), // a fold in it
        );
        final red = await recorder.endRecording().toImage(64, 64);

        final map = await GarmentTint.luminanceMap(red);

        final lit = await rgbaAt(map, 20, 20);
        expect(lit[0], lit[1], reason: 'red channel leaked into the fold map');
        expect(lit[1], lit[2], reason: 'blue channel leaked into the fold map');
        expect(lit[3], 255, reason: 'the garment must stay opaque');

        // Anchored so lit fabric is white: multiplying it over ink is a no-op
        // everywhere the cloth is flat, which is what keeps the design's own
        // colours intact.
        expect(lit[0], greaterThan(240));

        // The fold is the only thing that darkens.
        final shaded = await rgbaAt(map, 20, 30);
        expect(shaded[0], lessThan(lit[0]));
        expect(shaded[0], shaded[1]);
        expect(shaded[1], shaded[2]);
      });
    });

    testWidgets('keeps the studio sweep out of the folds', (tester) async {
      await tester.runAsync(() async {
        final map = await GarmentTint.luminanceMap(
          await fakeShirtPhoto(size: size),
        );
        // Transparent backdrop => the shading pass cannot darken bare shirt
        // outside the garment.
        expect((await rgbaAt(map, corner.$1, corner.$2))[3], 0);
        expect((await rgbaAt(map, body.$1, body.$2))[3], 255);
        // The fold still reads darker than the flat body.
        final flat = (await rgbaAt(map, body.$1, body.$2))[0];
        final dip = (await rgbaAt(map, fold.$1, fold.$2))[0];
        expect(dip, lessThan(flat));
      });
    });
  });

  group('bundled tint bases', () {
    Future<ui.Image> loadAsset(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    /// Points that are unambiguously garment on both faces.
    const garmentPoints = <String, (double, double)>{
      'left shoulder': (0.30, 0.14),
      'right shoulder': (0.70, 0.14),
      'neck below collar': (0.50, 0.18),
      'left sleeve': (0.16, 0.30),
      'right sleeve': (0.84, 0.30),
      'chest centre': (0.50, 0.35),
      'belly': (0.50, 0.65),
      'hem': (0.50, 0.88),
    };

    for (final (face, path) in [
      ('front', BundledGarments.tintBaseFront),
      ('back', BundledGarments.tintBaseBack),
    ]) {
      testWidgets('the $face tint base cuts out without holing the garment', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final src = await loadAsset(path);
          final out = await GarmentTint.recolour(
            src,
            const ui.Color(0xFF6B7350),
          );
          src.dispose();

          for (final entry in garmentPoints.entries) {
            final x = (entry.value.$1 * out.width).round();
            final y = (entry.value.$2 * out.height).round();
            expect(
              (await rgbaAt(out, x, y))[3],
              255,
              reason: '${entry.key} was cut out of the $face garment',
            );
          }
        });
      });

      testWidgets('the $face studio sweep is fully removed', (tester) async {
        await tester.runAsync(() async {
          final src = await loadAsset(path);
          final out = await GarmentTint.recolour(
            src,
            const ui.Color(0xFF6B7350),
          );
          src.dispose();
          for (final p in [
            (2, 2),
            (out.width - 3, 2),
            (2, out.height - 3),
            (out.width - 3, out.height - 3),
          ]) {
            expect(
              (await rgbaAt(out, p.$1, p.$2))[3],
              0,
              reason: 'backdrop left behind at $p on the $face',
            );
          }
        });
      });
    }
  });
}
