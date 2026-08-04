import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/print_style/artwork_detail_analyzer.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_pipeline.dart';

Future<ui.Image> imageFromRgba(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

Future<Uint8List> rgbaOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// 64×64: flat opaque grey, with a high-contrast checkerboard "emblem" in the
/// centre (strong local edges the protection mask should spare).
Future<ui.Image> emblemImage() async {
  const n = 64;
  final rgba = Uint8List(n * n * 4);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final o = (y * n + x) * 4;
      final inCentre = x >= 20 && x < 44 && y >= 20 && y < 44;
      final v = inCentre ? (((x ~/ 2) + (y ~/ 2)).isEven ? 255 : 0) : 128;
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
  }
  return imageFromRgba(rgba, n, n);
}

double meanAlphaIn(Uint8List rgba, int w, int x0, int y0, int x1, int y1) {
  var sum = 0, count = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      sum += rgba[(y * w + x) * 4 + 3];
      count++;
    }
  }
  return count == 0 ? 0 : sum / count;
}

int totalAlpha(Uint8List rgba) {
  var s = 0;
  for (var i = 0; i < rgba.length ~/ 4; i++) {
    s += rgba[i * 4 + 3];
  }
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pipeline = PrintStylePipeline.instance;

  group('local protection mask', () {
    test('high-edge emblem area keeps more ink than without the mask',
        () async {
      final img = await emblemImage();
      final detail = await ArtworkDetailAnalyzer.analyze(img);
      expect(detail.protection, greaterThan(0));

      // Hold detailFactor constant so we isolate the *local* mask effect.
      final base = kPrintStylePresets[PrintStyleId.grunge]!
          .copyWith(seed: 21, detailFactor: 1.0);
      final withMask = base.copyWith(detail: detail);

      final maskedRgba = await rgbaOf(await pipeline.apply(img, withMask));
      final plainRgba = await rgbaOf(await pipeline.apply(img, base));

      // Centre (emblem) retains more ink with the protection mask.
      final centreMasked = meanAlphaIn(maskedRgba, 64, 22, 22, 42, 42);
      final centrePlain = meanAlphaIn(plainRgba, 64, 22, 22, 42, 42);
      expect(centreMasked, greaterThan(centrePlain));
    });
  });

  group('duotone extensibility', () {
    // Proves a *new* style needs only params — the pipeline is unchanged.
    test('maps dark ink toward colour A and bright ink toward colour B',
        () async {
      // Horizontal gradient, fully opaque.
      const n = 32;
      final rgba = Uint8List(n * n * 4);
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          final o = (y * n + x) * 4;
          final v = (x * 255 ~/ (n - 1));
          rgba[o] = v;
          rgba[o + 1] = v;
          rgba[o + 2] = v;
          rgba[o + 3] = 255;
        }
      }
      final img = await imageFromRgba(rgba, n, n);

      final params = PrintStyleParams(
        id: PrintStyleId.clean, // any id; behaviour comes from params only
        colorTreatment: ColorTreatment.duotone,
        duotoneA: const ui.Color(0xFF1A0E00), // near-black shadow
        duotoneB: Colors.orange, // highlight
      );
      // Force a non-clean path by using a distinct id purely for the pipeline
      // (clean short-circuits). Use retro id but only duotone params set.
      final styled = await pipeline.apply(
        img,
        params.copyWith(id: PrintStyleId.retro),
      );
      final out = await rgbaOf(styled);

      // Left (dark) pixel ≈ colour A (low channels); right (bright) ≈ B (orange).
      final leftO = ((n ~/ 2) * n + 1) * 4;
      final rightO = ((n ~/ 2) * n + (n - 2)) * 4;
      expect(out[leftO], lessThan(60)); // dark shadow
      expect(out[rightO], greaterThan(180)); // orange R high
      expect(out[rightO + 2], lessThan(120)); // orange B low
      // Alpha preserved.
      expect(out[leftO + 3], 255);
      expect(out[rightO + 3], 255);
    });
  });

  group('printability guard', () {
    test('no preset wipes out the design (ink survives) on a busy design',
        () async {
      final img = await emblemImage();
      final detail = await ArtworkDetailAnalyzer.analyze(img);
      final before = totalAlpha(await rgbaOf(img));
      for (final id in PrintStyleId.values) {
        final params =
            kPrintStylePresets[id]!.copyWith(seed: 5).resolvedFor(detail);
        final after = totalAlpha(await rgbaOf(await pipeline.apply(img, params)));
        // At least a third of the ink survives for every style.
        expect(after, greaterThan(before * 0.33), reason: id.name);
      }
    });
  });
}
