import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

/// A synthetic 4:3 "flag" (premultiplied RGBA): a blue top-left canton over
/// red/white horizontal stripes — enough structure to test rotation, strips
/// and colour without any SVG or GPU in the loop.
Uint8List _flag(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final canton = x < w * 0.57 && y < h * 0.54;
      final red = (y * 13 ~/ h).isEven;
      final c = canton
          ? const [25, 47, 93]
          : red
              ? const [189, 61, 68]
              : const [255, 255, 255];
      px[o] = c[0];
      px[o + 1] = c[1];
      px[o + 2] = c[2];
      px[o + 3] = 255;
    }
  }
  return px;
}

/// A stripeless synthetic flag: two colours split on the diagonal (like the
/// Seychelles' rays — nothing runs the full length).
Uint8List _diagonalFlag(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final c = x / w > y / h ? const [0, 61, 136] : const [214, 40, 40];
      px[o] = c[0];
      px[o + 1] = c[1];
      px[o + 2] = c[2];
      px[o + 3] = 255;
    }
  }
  return px;
}

/// Vertical tricolour (France-like): its bands run ACROSS the portrait flag.
Uint8List _verticalTricolour(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final band = x * 3 ~/ w;
      final c = const [
        [0, 85, 164],
        [255, 255, 255],
        [239, 65, 53]
      ][band];
      px[o] = c[0];
      px[o + 1] = c[1];
      px[o + 2] = c[2];
      px[o + 3] = 255;
    }
  }
  return px;
}

Uint8List _render(
    {int seed = 1,
    TornStrips params = const TornStrips(),
    int canvasW = 320,
    int canvasH = 400,
    Uint8List Function(int w, int h) flag = _flag}) {
  final length = TornStripsRaster.flagLengthFor(canvasW, canvasH, 4 / 3, params);
  final across = (length * 3 / 4).round();
  return const TornStripsRaster().render(
    flagRgba: flag(length, across),
    flagW: length,
    flagH: across,
    canvasW: canvasW,
    canvasH: canvasH,
    params: params,
    seed: seed,
  );
}

/// FNV-1a over the raw RGBA bytes → hex, masked to 63 bits (Dart ints are
/// signed, so a full 64-bit value would print negative).
String _hash(Uint8List b) {
  var h = 0xCBF29CE484222325;
  for (final x in b) {
    h ^= x;
    h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF;
  }
  return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}

double _opaqueFraction(Uint8List b) {
  var n = 0;
  for (var i = 3; i < b.length; i += 4) {
    if (b[i] > 127) n++;
  }
  return n / (b.length / 4);
}

void main() {
  test('pixel-identical for the same inputs (no GPU in the loop)', () {
    expect(_hash(_render()), _hash(_render()));
  });

  test('regression: synthetic-flag output matches the approved hash', () {
    // Pure-Dart output is bit-stable on every 64-bit VM, so this is an exact
    // golden. If the geometry/distress/colour code changes ON PURPOSE, review
    // the full-pipeline goldens visually, then update this value.
    expect(_hash(_render()), _kApprovedHash);
  });

  test('seed changes the tearing', () {
    expect(_hash(_render(seed: 1)), isNot(_hash(_render(seed: 2))));
  });

  test('every tuning group changes the output', () {
    final base = _hash(_render());
    for (final p in const [
      TornStrips(cutMode: TornStrips.cutsEven, stripCount: 8),
      TornStrips(cutMode: TornStrips.cutsFringe),
      TornStrips(curvature: 0.9),
      TornStrips(tearLength: 0.1),
      TornStrips(edgeRoughness: 0),
      TornStrips(distress: 0),
      TornStrips(saturation: 0.3),
      TornStrips(blockWidth: 0),
      TornStrips(swayCoherence: 0),
      TornStrips(breakChance: 1),
      TornStrips(edgeWear: 0),
      TornStrips(hueShift: 15),
      TornStrips(brightness: 0.3),
    ]) {
      expect(_hash(_render(params: p)), isNot(base), reason: '${p.toJson()}');
    }
  });

  test('background stays transparent outside the flag', () {
    final b = _render();
    for (final (x, y) in const [(0, 0), (319, 0), (0, 399), (319, 399)]) {
      expect(b[(y * 320 + x) * 4 + 3], 0, reason: 'corner ($x,$y)');
    }
  });

  test('clockwise rotation puts the canton top-right, mirror top-left', () {
    // Sample just inside the flag, below the torn top edge of the block.
    bool blueAt(Uint8List b, int x, int y) {
      final o = (y * 320 + x) * 4;
      return b[o + 3] > 0 && b[o + 2] > b[o] + 40;
    }

    const clean = TornStrips(distress: 0, blockTear: 0, edgeRoughness: 0);
    final cw = _render(params: clean);
    final mirrored = _render(params: clean.copyWith(mirror: true));
    // Flag is ~150px wide, centred → spans roughly x 85..235.
    expect(blueAt(cw, 200, 120), isTrue);
    expect(blueAt(cw, 110, 120), isFalse);
    expect(blueAt(mirrored, 110, 120), isTrue);
  });

  test('the design is resolution-independent (same coverage at 2× size)', () {
    final small = _opaqueFraction(_render(canvasW: 320, canvasH: 400));
    final large = _opaqueFraction(_render(canvasW: 640, canvasH: 800));
    expect((small - large).abs(), lessThan(0.02),
        reason: 'small=$small large=$large');
  });

  test('brightness and vintage leave whites white', () {
    // White stripes must not turn grey or cream on a white shirt.
    const p = TornStrips(
        distress: 0, edgeWear: 0, brightness: -0.4, vintage: 1, saturation: 1);
    final b = _render(params: p);
    var whites = 0;
    for (var i = 0; i < b.length; i += 4) {
      // Interior white (not an anti-aliased blend with a red neighbour).
      if (b[i + 3] == 255 && b[i] > 243 && b[i + 1] > 243) {
        expect(b[i + 2], greaterThan(238));
        whites++;
      }
    }
    expect(whites, greaterThan(1000));
  });

  group('cut lines come from the flag', () {
    test('lengthwise boundaries: stripes found, none invented', () {
      expect(TornStripsRaster.lengthwiseBoundaries(_flag(400, 300), 400, 300),
          hasLength(12));
      expect(
          TornStripsRaster.lengthwiseBoundaries(
              _diagonalFlag(400, 300), 400, 300),
          isEmpty);
      expect(
          TornStripsRaster.lengthwiseBoundaries(
              _verticalTricolour(400, 300), 400, 300),
          isEmpty);
    });

    // A clean render (no sway, tears, wear or tongues reaching this high) so
    // any transparency across the flag's middle can only be an invented cut.
    const clean = TornStrips(
      curvature: 0,
      widthWobble: 0,
      edgeRoughness: 0,
      distress: 0,
      edgeWear: 0,
      topVariation: 0,
      blockWidth: 0,
      breakChance: 0,
      fringeDepth: 0.2,
    );

    int holesInMiddleRow(Uint8List b) {
      const y = 200;
      var first = -1, last = -1;
      for (var x = 0; x < 320; x++) {
        if (b[(y * 320 + x) * 4 + 3] > 0) {
          if (first < 0) first = x;
          last = x;
        }
      }
      var holes = 0;
      for (var x = first + 2; x < last - 2; x++) {
        if (b[(y * 320 + x) * 4 + 3] < 250) holes++;
      }
      return holes;
    }

    test('a stripeless flag is never cut into strips', () {
      expect(holesInMiddleRow(_render(params: clean, flag: _diagonalFlag)), 0);
      expect(
          holesInMiddleRow(_render(params: clean, flag: _verticalTricolour)), 0);
    });

    test('even cuts are an explicit choice — and they do cut', () {
      expect(
          holesInMiddleRow(_render(
              params: clean.copyWith(cutMode: TornStrips.cutsEven),
              flag: _diagonalFlag)),
          greaterThan(0));
    });

    test('torn stripes keep their true width', () {
      // Tear lines wander to either side of the cut rather than eroding both
      // edges, so the red stripes keep their share of the width.
      final b = _render(
          params: const TornStrips(
              curvature: 0,
              distress: 0,
              edgeWear: 0,
              blockWidth: 0,
              gap: 0,
              tearLength: 0));
      // Below the synthetic canton (which ends 57% down the flag).
      var red = 0, ink = 0;
      for (var y = 270; y < 340; y++) {
        for (var x = 0; x < 320; x++) {
          final o = (y * 320 + x) * 4;
          if (b[o + 3] < 128) continue;
          ink++;
          if (b[o] > 150 && b[o + 1] < 120) red++;
        }
      }
      // 7 of the 13 synthetic stripes are red.
      expect(red / ink, closeTo(7 / 13, 0.04));
    });
  });

  test('knockout white removes the white stripes', () {
    final keep = _opaqueFraction(_render(params: const TornStrips(distress: 0)));
    final drop = _opaqueFraction(_render(
        params: const TornStrips(distress: 0, knockoutWhite: true)));
    expect(drop, lessThan(keep * 0.85));
  });
}

const _kApprovedHash = '5a8663e7ba8e6fc7';
