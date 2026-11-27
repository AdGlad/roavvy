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
  test('dyed: spikes cross a colour border, whites stay mostly white, edge goes soft', () {
    // Left half red, right half white, opaque.
    final px = Uint8List(_n * _n * 4);
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final i = (y * _n + x) * 4;
        final red = x < _n ~/ 2;
        px[i] = red ? 210 : 255;
        px[i + 1] = red ? 20 : 255;
        px[i + 2] = red ? 40 : 255;
        px[i + 3] = 255;
      }
    }
    final out = WearRaster.dyed(px, _n, _n, 0.8, 3);
    expect(out, WearRaster.dyed(px, _n, _n, 0.8, 3), reason: 'deterministic');
    expect(WearRaster.dyed(px, _n, _n, 0, 3), px);
    // Red spikes reach into the white side along the border (not a straight line).
    final reach = <int>{};
    for (var y = 20; y < _n - 20; y++) {
      var last = 0;
      for (var x = 0; x < _n; x++) {
        final i = (y * _n + x) * 4;
        if (out[i + 3] > 200 && out[i + 1] < out[i] * 0.6) last = x;
      }
      reach.add(last);
    }
    expect(reach.reduce((a, b) => a > b ? a : b) - reach.reduce((a, b) => a < b ? a : b),
        greaterThan(3), reason: 'the border is feathered into spikes');
    // Deep in the white side most pixels stay near white.
    var nearWhite = 0, total = 0;
    for (var y = 20; y < _n - 20; y++) {
      for (var x = _n - 60; x < _n - 20; x++) {
        final i = (y * _n + x) * 4;
        total++;
        if (out[i] > 200 && out[i + 1] > 170 && out[i + 2] > 170) nearWhite++;
      }
    }
    expect(nearWhite / total, greaterThan(0.6));
    // The canvas edge is feathered transparent.
    var edgeAlpha = 0;
    for (var x = 0; x < _n; x++) {
      edgeAlpha += out[x * 4 + 3];
    }
    expect(edgeAlpha / _n, lessThan(60));
    expect(out[((_n ~/ 2) * _n + _n ~/ 2) * 4 + 3], 255);
  });
}
