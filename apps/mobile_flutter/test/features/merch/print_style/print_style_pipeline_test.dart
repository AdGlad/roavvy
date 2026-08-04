import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/print_style/artwork_detail_analyzer.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style.dart';
import 'package:mobile_flutter/features/merch/print_style/print_style_pipeline.dart';

// ── Image helpers ──────────────────────────────────────────────────────────

Future<ui.Image> imageFromRgba(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

Future<Uint8List> rgbaOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Future<Uint8List> pngOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Opaque solid image of [w]×[h] filled with (r,g,b,255).
Future<ui.Image> solid(int w, int h, int r, int g, int b) {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    rgba[o] = r;
    rgba[o + 1] = g;
    rgba[o + 2] = b;
    rgba[o + 3] = 255;
  }
  return imageFromRgba(rgba, w, h);
}

/// Opaque centre block on a transparent border, so we can test that
/// transparent areas stay transparent.
Future<ui.Image> borderedBlock(int size) {
  final rgba = Uint8List(size * size * 4);
  final lo = size ~/ 4, hi = size - size ~/ 4;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final o = (y * size + x) * 4;
      final inside = x >= lo && x < hi && y >= lo && y < hi;
      rgba[o] = 200;
      rgba[o + 1] = 60;
      rgba[o + 2] = 60;
      rgba[o + 3] = inside ? 255 : 0;
    }
  }
  return imageFromRgba(rgba, size, size);
}

int totalAlpha(Uint8List rgba) {
  var sum = 0;
  for (var i = 0; i < rgba.length ~/ 4; i++) {
    sum += rgba[i * 4 + 3];
  }
  return sum;
}

/// Fraction of pixels whose alpha is below [threshold] (i.e. "gap" pixels).
double gapFraction(Uint8List rgba, {int threshold = 128}) {
  final n = rgba.length ~/ 4;
  var g = 0;
  for (var i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] < threshold) g++;
  }
  return g / n;
}

/// Mean per-pixel channel spread (|R-G|+|G-B|) over opaque pixels — 0 for a
/// perfectly grayscale (mono-ink) image.
double meanChannelSpread(Uint8List rgba) {
  final n = rgba.length ~/ 4;
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    if (rgba[o + 3] < 32) continue;
    sum += (rgba[o] - rgba[o + 1]).abs() + (rgba[o + 1] - rgba[o + 2]).abs();
    count++;
  }
  return count == 0 ? 0 : sum / count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pipeline = PrintStylePipeline.instance;

  group('clean pass-through', () {
    test('applyToBytes returns the exact same bytes for clean', () async {
      final img = await solid(16, 16, 10, 20, 30);
      final png = await pngOf(img);
      final out = await pipeline.applyToBytes(
        png,
        kPrintStylePresets[PrintStyleId.clean]!,
      );
      expect(identical(out, png), isTrue);
    });

    test('apply() with clean preserves pixels', () async {
      final img = await solid(16, 16, 10, 20, 30);
      final before = await rgbaOf(img);
      final styled = await pipeline.apply(
        img,
        kPrintStylePresets[PrintStyleId.clean]!,
      );
      final after = await rgbaOf(styled);
      expect(after, equals(before));
    });
  });

  group('determinism', () {
    test('same params + seed → identical output bytes', () async {
      final img = await solid(24, 24, 180, 40, 40);
      final png = await pngOf(img);
      final params = kPrintStylePresets[PrintStyleId.grunge]!
          .copyWith(seed: 12345)
          .resolvedFor(ArtworkDetail.none);
      final a = await pipeline.applyToBytes(png, params);
      final b = await pipeline.applyToBytes(png, params);
      expect(a, equals(b));
    });

    test('different seed → different output', () async {
      final img = await solid(24, 24, 180, 40, 40);
      final png = await pngOf(img);
      final base =
          kPrintStylePresets[PrintStyleId.grunge]!.resolvedFor(ArtworkDetail.none);
      final a = await pipeline.applyToBytes(png, base.copyWith(seed: 1));
      final b = await pipeline.applyToBytes(png, base.copyWith(seed: 2));
      expect(a, isNot(equals(b)));
    });
  });

  group('distress → transparency', () {
    test('grunge removes ink (alpha drops) but leaves some ink', () async {
      final img = await solid(48, 48, 200, 40, 40);
      final beforeAlpha = totalAlpha(await rgbaOf(img));
      final params = kPrintStylePresets[PrintStyleId.grunge]!
          .copyWith(seed: 99)
          .resolvedFor(ArtworkDetail.none);
      final styled = await pipeline.apply(img, params);
      final after = await rgbaOf(styled);
      final afterAlpha = totalAlpha(after);
      // Ink loss: total alpha decreases.
      expect(afterAlpha, lessThan(beforeAlpha));
      // Recognisability: the bulk of the ink survives (not wiped out).
      expect(afterAlpha, greaterThan(beforeAlpha * 0.3));
      // At least some pixels stay strongly inked.
      var strong = 0;
      for (var i = 0; i < after.length ~/ 4; i++) {
        if (after[i * 4 + 3] > 150) strong++;
      }
      expect(strong, greaterThan(0));
    });

    test('transparent areas stay transparent', () async {
      final img = await borderedBlock(48);
      final params = kPrintStylePresets[PrintStyleId.grunge]!
          .copyWith(seed: 7)
          .resolvedFor(ArtworkDetail.none);
      final styled = await pipeline.apply(img, params);
      final after = await rgbaOf(styled);
      // Corner pixel (in the transparent border) must remain fully transparent.
      expect(after[3], 0); // top-left
      final lastO = (48 * 48 - 1) * 4;
      expect(after[lastO + 3], 0); // bottom-right
    });

    test('detailFactor reduces ink loss for detailed artwork', () async {
      final img = await solid(48, 48, 200, 40, 40);
      final beforeAlpha = totalAlpha(await rgbaOf(img));
      final base = kPrintStylePresets[PrintStyleId.grunge]!.copyWith(seed: 3);

      final lowProtection = base.copyWith(detailFactor: 1.0);
      final highProtection = base.copyWith(detailFactor: 0.2);

      final lossLow =
          beforeAlpha - totalAlpha(await rgbaOf(await pipeline.apply(img, lowProtection)));
      final lossHigh =
          beforeAlpha - totalAlpha(await rgbaOf(await pipeline.apply(img, highProtection)));

      // More protection (lower detailFactor) → less ink removed.
      expect(lossHigh, lessThan(lossLow));
    });
  });

  group('halftone', () {
    test('creates a dot screen: gaps go partly transparent, dots stay inked',
        () async {
      final img = await solid(64, 64, 40, 90, 200);
      final params = const PrintStyleParams(
        id: PrintStyleId.halftone,
        halftone: 0.85,
        halftoneScale: 0.1,
      ).resolvedFor(ArtworkDetail.none);
      final after = await rgbaOf(await pipeline.apply(img, params));
      // Dots keep full ink somewhere…
      var maxA = 0;
      var minA = 255;
      for (var i = 0; i < 64 * 64; i++) {
        final a = after[i * 4 + 3];
        if (a > maxA) maxA = a;
        if (a < minA) minA = a;
      }
      expect(maxA, 255);
      // …and gaps lose ink somewhere.
      expect(minA, lessThan(255));
      expect(gapFraction(after), greaterThan(0.0));
    });

    test('dot frequency is resolution-independent', () async {
      const params = PrintStyleParams(
        id: PrintStyleId.halftone,
        halftone: 0.85,
        halftoneScale: 0.1,
      );
      final small = await rgbaOf(
        await pipeline.apply(await solid(80, 80, 30, 30, 30), params),
      );
      final large = await rgbaOf(
        await pipeline.apply(await solid(160, 160, 30, 30, 30), params),
      );
      // Same normalised scale → similar gap coverage at both resolutions.
      expect((gapFraction(small) - gapFraction(large)).abs(), lessThan(0.1));
    });

    test('detailFactor reduces the halftone effect', () async {
      final img = await solid(64, 64, 30, 30, 30);
      const base = PrintStyleParams(
        id: PrintStyleId.halftone,
        halftone: 0.85,
        halftoneScale: 0.1,
      );
      final full = await rgbaOf(
        await pipeline.apply(img, base.copyWith(detailFactor: 1.0)),
      );
      final protected = await rgbaOf(
        await pipeline.apply(img, base.copyWith(detailFactor: 0.2)),
      );
      // Less halftone → fewer transparent gaps → more ink retained.
      expect(gapFraction(protected), lessThan(gapFraction(full)));
    });
  });

  group('passport stamp', () {
    test('mono-ink desaturates toward a single ink colour', () async {
      final img = await solid(48, 48, 210, 40, 40); // saturated red
      final beforeSpread = meanChannelSpread(await rgbaOf(img));
      final params = kPrintStylePresets[PrintStyleId.stamp]!
          .copyWith(seed: 4)
          .resolvedFor(ArtworkDetail.none);
      final after = await rgbaOf(await pipeline.apply(img, params));
      expect(meanChannelSpread(after), lessThan(beforeSpread));
      expect(meanChannelSpread(after), lessThan(20));
    });

    test('produces uneven ink (alpha varies)', () async {
      final img = await solid(48, 48, 200, 200, 200);
      final params = kPrintStylePresets[PrintStyleId.stamp]!
          .copyWith(seed: 4)
          .resolvedFor(ArtworkDetail.none);
      final after = await rgbaOf(await pipeline.apply(img, params));
      var minA = 255, maxA = 0;
      for (var i = 0; i < 48 * 48; i++) {
        final a = after[i * 4 + 3];
        if (a < minA) minA = a;
        if (a > maxA) maxA = a;
      }
      expect(maxA - minA, greaterThan(0)); // not a flat fill anymore
    });
  });

  group('colour treatment', () {
    test('fade-only changes colour but preserves alpha', () async {
      final img = await solid(16, 16, 200, 40, 40);
      final before = await rgbaOf(img);
      final params = const PrintStyleParams(
        id: PrintStyleId.retro,
        fade: 0.6,
        colorTreatment: ColorTreatment.muted,
      );
      final styled = await pipeline.apply(img, params);
      final after = await rgbaOf(styled);
      // Alpha untouched (no distress/rough).
      for (var i = 0; i < 16 * 16; i++) {
        expect(after[i * 4 + 3], before[i * 4 + 3]);
      }
      // Colour changed (desaturated/faded), so RGB differs somewhere.
      var changed = false;
      for (var i = 0; i < before.length; i++) {
        if (before[i] != after[i]) {
          changed = true;
          break;
        }
      }
      expect(changed, isTrue);
    });
  });
}
