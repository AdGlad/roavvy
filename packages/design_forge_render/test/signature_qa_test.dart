import 'dart:typed_data';

import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 100, _h = 125;

/// A transparent canvas with an opaque [rgb] rectangle in it.
Uint8List _canvas({
  int left = 20,
  int top = 20,
  int right = 80,
  int bottom = 105,
  List<int> rgb = const [200, 30, 40],
}) {
  final px = Uint8List(_w * _h * 4);
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final i = (y * _w + x) * 4;
      px[i] = rgb[0];
      px[i + 1] = rgb[1];
      px[i + 2] = rgb[2];
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  test('a centred, mid-tone design passes', () {
    final r = SignatureQa.analyse(_canvas(), _w, _h);
    expect(r.hard, isEmpty);
    expect(r.status, isNot(QaStatus.fail));
  });

  test('an empty render fails as empty', () {
    final r = SignatureQa.analyse(Uint8List(_w * _h * 4), _w, _h);
    expect(r.hard.map((f) => f.code), contains('empty'));
    expect(r.status, QaStatus.fail);
  });

  test('a full-bleed render fails as flooded and clipped', () {
    final r = SignatureQa.analyse(
        _canvas(left: 0, top: 0, right: _w, bottom: _h), _w, _h);
    expect(r.hard.map((f) => f.code), containsAll(['flooded', 'clipped']));
  });

  test('touching one edge is clipped unless bleed is allowed', () {
    final px = _canvas(left: 0);
    expect(SignatureQa.analyse(px, _w, _h).hard.map((f) => f.code),
        contains('clipped'));
    expect(SignatureQa.analyse(px, _w, _h, allowBleed: true).hard, isEmpty);
  });

  test('white artwork warns that it disappears on a white shirt only', () {
    final r = SignatureQa.analyse(_canvas(rgb: const [255, 255, 255]), _w, _h);
    final codes = r.soft.map((f) => f.code).toSet();
    expect(codes, contains('contrast:White'));
    expect(codes, isNot(contains('contrast:Black')));
    expect(r.status, QaStatus.warn);
  });

  test('similar brightness but different hue does not count as vanishing', () {
    // Brazil-green on a red shirt: close in luminance, far apart in colour.
    final r = SignatureQa.analyse(_canvas(rgb: const [0, 155, 58]), _w, _h);
    expect(r.soft.map((f) => f.code), isNot(contains('contrast:Red')));
  });

  test('scattered specks warn', () {
    final px = _canvas(right: 40, bottom: 60);
    for (var y = 70; y < 120; y += 3) {
      for (var x = 45; x < 95; x += 3) {
        px[(y * _w + x) * 4 + 3] = 255;
      }
    }
    final r = SignatureQa.analyse(px, _w, _h);
    expect(r.soft.map((f) => f.code), contains('specks'));
  });

  test('render failures are hard failures', () {
    final r = SignatureQa.renderFailed(StateError('no flag'));
    expect(r.status, QaStatus.fail);
    expect(r.toJson()['status'], 'fail');
  });
}
