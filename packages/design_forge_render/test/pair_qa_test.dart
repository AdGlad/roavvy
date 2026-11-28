import 'dart:typed_data';

import 'package:design_forge/design_forge.dart';
import 'package:design_forge_render/design_forge_render.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 100, _h = 100;

/// Two flags side by side: [left] fills x < [seam], [right] the rest, each as
/// horizontal bands of the given colours (top to bottom).
Uint8List _pair(List<List<int>> left, List<List<int>> right,
    {int seam = 50, int gap = 0}) {
  final px = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if ((x - seam).abs() < gap) continue;
      final bands = x < seam ? left : right;
      final c = bands[y * bands.length ~/ _h];
      final i = (y * _w + x) * 4;
      px[i] = c[0];
      px[i + 1] = c[1];
      px[i + 2] = c[2];
      px[i + 3] = 255;
    }
  }
  return px;
}

const _red = [206, 17, 38], _white = [255, 255, 255];
const _yellow = [252, 209, 22], _blue = [0, 56, 147];

void main() {
  test('distinct flags pass: seam legible, halves balanced', () {
    final r = PairQa.analyse(
        _pair([_yellow, _blue, _red], [_red, _white, _red]), _w, _h);
    expect(r.status, QaStatus.pass, reason: '${r.toJson()}');
    expect((r.metrics['pair'] as Map)['leftShare'], closeTo(0.5, 0.01));
  });

  test('look-alike flags (Indonesia + Monaco) warn at a plain seam', () {
    final r = PairQa.analyse(_pair([_red, _white], [_red, _white]), _w, _h);
    expect(r.soft.map((f) => f.code), contains('pair_seam'));
    expect(r.status, QaStatus.warn);
  });

  test('a drawn seam (gap) is always legible', () {
    final r = PairQa.analyse(
        _pair([_red, _white], [_red, _white], gap: 2), _w, _h,
        geometry: PairGeometry(
            crops: const [], seam: PairSeam([(0.5, 0), (0.5, 1)], gap: 0.04)));
    expect(r.soft.map((f) => f.code), isNot(contains('pair_seam')));
  });

  test('a channel drawn by the renderer counts as a seam, unreported', () {
    final r = PairQa.analyse(
        _pair([_red, _white], [_red, _white], gap: 2), _w, _h);
    expect(r.soft.map((f) => f.code), isNot(contains('pair_seam')));
  });

  test('the seam follows reported geometry', () {
    // Ink split at x = 30: with the default centre seam the halves are
    // unbalanced, with the real seam the colours are judged correctly.
    final img = _pair([_red, _white], [_red, _white], seam: 30);
    final centre = PairQa.analyse(img, _w, _h);
    expect(centre.soft.map((f) => f.code), contains('pair_seam'));
    final real = PairQa.analyse(img, _w, _h,
        geometry: PairGeometry(crops: const [], seam: PairSeam.vertical(0.3)));
    expect((real.metrics['pair'] as Map)['leftShare'], closeTo(0.3, 0.01));
    expect(real.soft.map((f) => f.code), contains('pair_balance'));
  });

  test('an emblem cut by the crop fails hard', () {
    final img = _pair([_yellow, _blue, _red], [_red, _white, _red]);
    final cut = PairQa.analyse(img, _w, _h,
        geometry: PairGeometry(crops: const [
          FlagCrop(slot: 1, code: 'mx', visible: FlagBox(0, 0, 0.45, 1)),
        ]));
    expect(cut.hard.map((f) => f.code), ['pair_emblem']);
    expect(cut.status, QaStatus.fail);

    final whole = PairQa.analyse(img, _w, _h,
        geometry: PairGeometry(crops: const [
          FlagCrop(slot: 1, code: 'mx', visible: FlagBox(0.25, 0, 0.5, 1)),
        ]));
    expect(whole.hard, isEmpty);
  });

  test('the canton must survive a half-flag crop', () {
    final us = FlagFocus.of('us');
    final kept = FlagCrop(
        slot: 1, code: 'us', visible: FlagBox(us.windowLeft(0.5), 0, 0.5, 1));
    expect(PairQa.emblemFinding(kept), isNull);
    const lost =
        FlagCrop(slot: 1, code: 'us', visible: FlagBox(0.5, 0, 0.5, 1));
    expect(PairQa.emblemFinding(lost)?.code, 'pair_emblem');
  });

  test('swap sanity reports a failing swapped order', () {
    const ok = QaReport(hard: [], soft: [], metrics: {});
    const bad = QaReport(
        hard: [QaFinding('empty', 'Nothing rendered')], soft: [], metrics: {});
    expect(PairQa.swapFinding('co+us', ok), isNull);
    expect(PairQa.swapFinding('co+us', bad)?.code, 'pair_swap');
  });
}
