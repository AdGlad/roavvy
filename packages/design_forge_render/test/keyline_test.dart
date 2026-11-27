import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

const _w = 60, _h = 60;

/// Premultiplied white square 20..40 with a 4×4 hole at 28..32.
Uint8List _squareWithHole() {
  final px = Uint8List(_w * _h * 4);
  for (var y = 20; y < 40; y++) {
    for (var x = 20; x < 40; x++) {
      if (x >= 28 && x < 32 && y >= 28 && y < 32) continue;
      final i = (y * _w + x) * 4;
      px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 255;
    }
  }
  return px;
}

int _alpha(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 3];

void main() {
  test('outlines the outer edge, not holes inside the artwork', () {
    final out = Keyline.outline(_squareWithHole(), _w, _h, 3, const [20, 20, 20]);
    expect(_alpha(out, 18, 30), 255, reason: 'keyline just outside the edge');
    expect(out[(30 * _w + 18) * 4], 20, reason: 'in the keyline colour');
    expect(_alpha(out, 10, 30), 0, reason: 'nothing far outside');
    expect(_alpha(out, 30, 30), 0, reason: 'interior hole stays transparent');
    expect(out[(25 * _w + 25) * 4], 255, reason: 'artwork untouched');
  });

  test('auto colour: dark on light garments, light on dark', () {
    expect(Keyline.autoFor(const Color(0xFFFFFFFF)), Keyline.dark);
    expect(Keyline.autoFor(const Color(0xFFD1D2D6)), Keyline.dark);
    expect(Keyline.autoFor(const Color(0xFF0E0E0E)), Keyline.light);
    expect(Keyline.autoFor(const Color(0xFFFF1B2B)), Keyline.light);
    expect(Keyline.autoFor(null), Keyline.dark);
  });

  test('outline settings: omitted at defaults, validated, round-trip', () {
    const base = Composition(family: DesignFamily.portraitTornFlag);
    expect(base.toJson().containsKey('outlineWidth'), isFalse);
    expect(base.toJson().containsKey('outlineColour'), isFalse);
    final c = base.copyWith(outlineWidth: 0.6, outlineColour: '#112233');
    final back = Composition.fromJson(c.toJson());
    expect(back.outlineWidth, 0.6);
    expect(back.outlineColour, '#112233');
    expect(() => Composition.fromJson({...c.toJson(), 'outlineColour': 'red'}),
        throwsFormatException);
    expect(() => Composition.fromJson({...c.toJson(), 'outlineWidth': 9}),
        throwsFormatException);
  });

  test('QA: an outline makes a white-on-white design read', () {
    // Straight RGBA, white square, no outline → its edge vanishes on White.
    final plain = _squareWithHole();
    final r0 = SignatureQa.analyse(plain, _w, _h);
    expect(r0.soft.map((f) => f.code), contains('contrast:White'));
    // Premultiplied == straight for opaque pixels; the keyline is opaque at
    // its core, so this is a fair straight-RGBA input for the check.
    final outlined = Keyline.outline(plain, _w, _h, 3, const [20, 20, 20]);
    final r1 = SignatureQa.analyse(outlined, _w, _h,
        thresholds: QaThresholds.standard.only([QaThresholds.orderableGarments.last]));
    expect(r1.soft.map((f) => f.code), isNot(contains('contrast:White')));
  });
}
