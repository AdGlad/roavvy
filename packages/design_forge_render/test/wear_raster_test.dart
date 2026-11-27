import 'dart:typed_data';

import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

const _n = 200;

/// Opaque saturated red, premultiplied.
Uint8List _red() {
  final px = Uint8List(_n * _n * 4);
  for (var i = 0; i < px.length; i += 4) {
    px[i] = 210;
    px[i + 1] = 20;
    px[i + 2] = 40;
    px[i + 3] = 255;
  }
  return px;
}

void main() {
  test('acid wash bleaches parts of the colour toward pale grey, deterministically', () {
    final out = WearRaster.acidWash(_red(), _n, _n, 0.8, 5);
    expect(out, WearRaster.acidWash(_red(), _n, _n, 0.8, 5));
    var bleached = 0, untouched = 0;
    for (var i = 0; i < out.length; i += 4) {
      if (out[i + 1] > 120) bleached++; // green rises as red goes pale
      if (out[i + 1] < 40) untouched++;
    }
    expect(bleached, greaterThan(_n * _n * 0.05));
    expect(untouched, greaterThan(_n * _n * 0.2), reason: 'not everything is bleached');
    expect(WearRaster.acidWash(_red(), _n, _n, 0, 5), _red());
  });

  test('cracks knock thin lines out of the ink', () {
    final out = WearRaster.cracks(_red(), _n, _n, 0.6, 5);
    var holes = 0;
    for (var i = 3; i < out.length; i += 4) {
      if (out[i] < 128) holes++;
    }
    expect(holes, greaterThan(50));
    expect(holes, lessThan(_n * _n * 0.1), reason: 'thin cracks, not erasure');
    expect(WearRaster.cracks(_red(), _n, _n, 0, 5), _red());
  });
}
