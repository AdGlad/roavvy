import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_geometry_generator.dart';
import 'package:mobile_flutter/features/merch/design_engine/torn/torn_recipe.dart';

const gen = TornGeometryGenerator();

/// Count torn (alpha == 0) pixels inside the fractional rectangle
/// [x0,x1) × [y0,y1) of the mask.
int _tornIn(TornMask m, double x0, double x1, double y0, double y1) {
  var n = 0;
  final xa = (x0 * m.width).round();
  final xb = (x1 * m.width).round();
  final ya = (y0 * m.height).round();
  final yb = (y1 * m.height).round();
  for (var y = ya; y < yb; y++) {
    for (var x = xa; x < xb; x++) {
      if (m.alphaAt(x, y) == 0) n++;
    }
  }
  return n;
}

void main() {
  test('mask has the requested dimensions and is binary', () {
    final m = gen.generate(sampleTornRecipe(TearStyle.ragged, 1),
        width: 96, height: 128);
    expect(m.width, 96);
    expect(m.height, 128);
    expect(m.alpha.length, 96 * 128);
    expect(m.alpha.every((a) => a == 0 || a == 255), isTrue);
  });

  test('generation is deterministic for the same recipe', () {
    final r = sampleTornRecipe(TearStyle.battleWorn, 9);
    final a = gen.generate(r, width: 80, height: 80);
    final b = gen.generate(r, width: 80, height: 80);
    expect(a.alpha, b.alpha);
  });

  test('different seeds give materially different silhouettes', () {
    final a = gen.generate(sampleTornRecipe(TearStyle.ragged, 1),
        width: 160, height: 160);
    final b = gen.generate(sampleTornRecipe(TearStyle.ragged, 2),
        width: 160, height: 160);
    var diff = 0;
    for (var i = 0; i < a.alpha.length; i++) {
      if (a.alpha[i] != b.alpha[i]) diff++;
    }
    expect(diff, greaterThan(a.alpha.length ~/ 250),
        reason: 'seeds should change the silhouette');
  });

  test('damage stays on the outer edges — the centre is untouched', () {
    // A light family (shallow depth) must leave the inner 60% fully intact.
    final m = gen.generate(sampleTornRecipe(TearStyle.lightlyWorn, 4),
        width: 200, height: 200);
    expect(_tornIn(m, 0.2, 0.8, 0.2, 0.8), 0,
        reason: 'no holes in the middle of the flag');
  });

  test('even a heavy family keeps the deep interior intact', () {
    // maxTearDepth caps at ~0.38; the innermost 20% band must never be reached.
    for (final s in TearStyle.values) {
      final m = gen.generate(sampleTornRecipe(s, 5), width: 160, height: 160);
      expect(_tornIn(m, 0.4, 0.6, 0.4, 0.6), 0, reason: s.name);
    }
  });

  test('asymmetricTear removes far more on the fly edge than the hoist', () {
    var fly = 0;
    var hoist = 0;
    for (var seed = 0; seed < 6; seed++) {
      final m = gen.generate(sampleTornRecipe(TearStyle.asymmetricTear, seed),
          width: 160, height: 160);
      fly += _tornIn(m, 0.9, 1.0, 0.0, 1.0); // right edge column
      hoist += _tornIn(m, 0.0, 0.1, 0.0, 1.0); // left edge column
    }
    expect(fly, greaterThan(hoist * 3),
        reason: 'fly edge should dominate the hoist');
  });

  test('a torn family actually removes material', () {
    final m = gen.generate(sampleTornRecipe(TearStyle.battleWorn, 2),
        width: 128, height: 128);
    expect(m.removedFraction, greaterThan(0.02));
  });

  /// Count kept↔torn transitions scanning down a single column.
  int transitionsInColumn(TornMask m, int x) {
    var t = 0;
    var prev = m.alphaAt(x, 0) != 0;
    for (var y = 1; y < m.height; y++) {
      final kept = m.alphaAt(x, y) != 0;
      if (kept != prev) t++;
      prev = kept;
    }
    return t;
  }

  test('the fly edge breaks into separated fingers, not one solid bite', () {
    // Near the outer edge the alpha must alternate kept/gap many times along the
    // edge (separated tapering fingers), not read as a single contiguous block.
    final m = gen.generate(sampleTornRecipe(TearStyle.asymmetricTear, 3),
        width: 240, height: 240);
    final col = (0.97 * m.width).round();
    expect(transitionsInColumn(m, col), greaterThanOrEqualTo(6),
        reason: 'fingers should separate along the fly edge');
  });

  test('fingers taper — more cloth survives deeper in the band than at the tip',
      () {
    // Slice a heavy fly edge at two penetrations: the shallow (near-body) slice
    // must keep more cloth than the outer (tip) slice.
    final m = gen.generate(sampleTornRecipe(TearStyle.heavyEdgeDamage, 7),
        width: 240, height: 240);
    var keptOuter = 0; // near the outer edge (finger tips)
    var keptInner = 0; // near the body (finger bases)
    final xOuter = (0.98 * m.width).round();
    final xInner = (0.90 * m.width).round();
    for (var y = 0; y < m.height; y++) {
      if (m.alphaAt(xOuter, y) != 0) keptOuter++;
      if (m.alphaAt(xInner, y) != 0) keptInner++;
    }
    expect(keptInner, greaterThan(keptOuter),
        reason: 'bases wider than tips');
  });
}
