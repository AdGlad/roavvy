import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 120, _h = 120;

/// Premultiplied: a red disc with a white band through it, on transparent.
Uint8List _art() {
  final px = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final dx = x - 60, dy = y - 60;
      if (dx * dx + dy * dy > 40 * 40) continue;
      final i = (y * _w + x) * 4;
      final white = y > 54 && y < 66;
      px[i] = 255;
      px[i + 1] = white ? 255 : 20;
      px[i + 2] = white ? 255 : 30;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  test('deterministic: same input and seed give identical bytes', () {
    final a = WatercolourRaster.paint(_art(), _w, _h, const Watercolour(), 7);
    final b = WatercolourRaster.paint(_art(), _w, _h, const Watercolour(), 7);
    expect(a, b);
    final c = WatercolourRaster.paint(_art(), _w, _h, const Watercolour(), 8);
    expect(a, isNot(c));
  });

  test('paints the shape, leaves the far background empty, whites become paper', () {
    final out = WatercolourRaster.paint(
        _art(), _w, _h, const Watercolour(splatter: 0), 7);
    expect(out[(60 * _w + 40) * 4 + 3], greaterThan(200), reason: 'inside');
    expect(out[(5 * _w + 5) * 4 + 3], 0, reason: 'far outside');
    // The white band is warm paper (#FBF6EC): blue below red.
    final i = (60 * _w + 60) * 4;
    expect(out[i + 3], greaterThan(200));
    expect(out[i + 2], lessThan(out[i]));
  });

  test('pigment varies across a flat colour (not a uniform fill)', () {
    final out = WatercolourRaster.paint(_art(), _w, _h, const Watercolour(), 7);
    final reds = <int>{
      for (var x = 30; x < 90; x += 3) out[(40 * _w + x) * 4 + 1],
    };
    expect(reds.length, greaterThan(4));
  });
}
