import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

const _n = 100;

/// Premultiplied frame: left half red, right half blue.
Uint8List _frame() {
  final px = Uint8List(_n * _n * 4);
  for (var y = 0; y < _n; y++) {
    for (var x = 0; x < _n; x++) {
      final i = (y * _n + x) * 4;
      if (x < _n / 2) {
        px[i] = 220;
      } else {
        px[i + 2] = 220;
      }
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  test('a ball inside the radius, a rim at its edge, nothing outside', () {
    final out = GlobeRaster.paint(
        _frame(), _n, _n, const Globe(rim: 0.1, sparkles: 0), 50, 50, 40);
    int a(int x, int y) => out[(y * _n + x) * 4 + 3];
    expect(a(2, 2), 0, reason: 'outside the ball');
    expect(a(50, 50), 255);
    // Left of centre is red, right of centre is blue (flag kept the right way).
    expect(out[(50 * _n + 35) * 4], greaterThan(out[(50 * _n + 35) * 4 + 2]));
    expect(out[(50 * _n + 65) * 4 + 2], greaterThan(out[(50 * _n + 65) * 4]));
    // Rim (between 36 and 40 px from centre) is white.
    final rim = (50 * _n + 12) * 4;
    expect(out[rim], greaterThan(230));
    expect(out[rim + 1], greaterThan(230));
    expect(out[rim + 2], greaterThan(230));
  });

  test('deterministic', () {
    const g = Globe();
    expect(GlobeRaster.paint(_frame(), _n, _n, g, 50, 50, 40),
        GlobeRaster.paint(_frame(), _n, _n, g, 50, 50, 40));
  });
}
