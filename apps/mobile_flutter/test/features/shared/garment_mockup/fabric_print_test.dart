import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/shared/garment_mockup/fabric_print.dart';

/// [FabricPrint.apply] prints artwork into the fabric: flat cloth leaves it
/// untouched; folds move it, light it and let the weave through.
void main() {
  const n = 40;

  /// Straight RGBA: a vertical red stripe (x 18..21) on transparent.
  Uint8List stripe() {
    final px = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 18; x < 22; x++) {
        final i = (y * n + x) * 4;
        px[i] = 200;
        px[i + 3] = 255;
      }
    }
    return px;
  }

  /// Grey shading photo, n×n, with luminance from [l].
  Uint8List shade(double Function(int x, int y) l) {
    final px = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final v = (l(x, y) * 255).round().clamp(0, 255);
        final i = (y * n + x) * 4;
        px[i] = px[i + 1] = px[i + 2] = v;
        px[i + 3] = 255;
      }
    }
    return px;
  }

  FabricPrintJob job(Uint8List shading) => FabricPrintJob(
    art: stripe(),
    artW: n,
    artH: n,
    shade: shading,
    shadeW: n,
    shadeH: n,
    printArea: (0, 0, 1, 1),
  );

  int red(Uint8List px, int x, int y) => px[(y * n + x) * 4];
  int alpha(Uint8List px, int x, int y) => px[(y * n + x) * 4 + 3];

  test('flat cloth prints the artwork unchanged', () {
    final out = FabricPrint.apply(job(shade((_, __) => 0.6)));
    for (var y = 2; y < n - 2; y++) {
      expect(alpha(out, 19, y), 255);
      expect(red(out, 19, y), closeTo(200, 2));
      expect(alpha(out, 10, y), 0, reason: 'transparent stays transparent');
    }
  });

  test('a fold darkens the ink and a ridge lightens it', () {
    // Darker band across the middle rows.
    final out = FabricPrint.apply(
      job(shade((_, y) => (y >= 16 && y < 24) ? 0.4 : 0.6)),
    );
    expect(red(out, 19, 20), lessThan(red(out, 19, 4)));
    expect(red(out, 19, 4), greaterThanOrEqualTo(200), reason: 'lifted');
  });

  test('a sloping fold bends the print', () {
    // Luminance ramps across x: the stripe shifts sideways.
    final out = FabricPrint.apply(job(shade((x, _) => 0.3 + 0.012 * x)));
    final flat = FabricPrint.apply(job(shade((_, __) => 0.6)));
    var moved = 0;
    for (var x = 14; x < 26; x++) {
      if ((alpha(out, x, 20) > 128) != (alpha(flat, x, 20) > 128)) moved++;
    }
    expect(moved, greaterThan(0));
  });

  test('the weave lets the cloth through the ink', () {
    // Fine checker: dark fibre flecks thin the ink.
    final out = FabricPrint.apply(
      job(shade((x, y) => (x + y).isEven ? 0.7 : 0.5)),
    );
    final alphas = {for (var y = 4; y < n - 4; y++) alpha(out, 19, y)};
    expect(alphas.length, greaterThan(1));
    expect(alphas.reduce((a, b) => a < b ? a : b), lessThan(255));
  });
}
