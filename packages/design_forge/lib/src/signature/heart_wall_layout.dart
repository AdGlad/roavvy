import 'dart:math' as math;

import '../determinism/deterministic_rng.dart';
import '../recipe/design_recipe.dart';
import '../recipe/heart_wall.dart';
import 'heart_pair_layout.dart';

/// The geometry of a [HeartWall] design (M214): one equal heart per country,
/// in list order, in rows; the last row centred. Pure Dart, so tests and QA
/// see exactly what the renderer draws. Each heart is a [HeartSlot] (slot =
/// list index) fitted with [HeartPairLayout.fitInHeart], so emblems stay in
/// view.
class HeartWallLayout {
  const HeartWallLayout({
    required this.width,
    required this.height,
    required this.columns,
    required this.rows,
    required this.slots,
  });

  final double width;
  final double height;
  final int columns;
  final int rows;
  final List<HeartSlot> slots;

  /// Room left around each heart for the brush strokes that spill past its
  /// outline, as a fraction of the heart's width.
  static const double strokeMargin = 0.06;

  /// The column count (1..[maxColumns]) that makes [n] equal hearts biggest
  /// on a [w]×[h] canvas, with [spacing] (fraction of a heart) between them.
  static int bestColumns(
      int n, double w, double h, int maxColumns, double spacing) {
    var best = 1;
    var bestSize = 0.0;
    for (var c = 1; c <= math.min(n, maxColumns); c++) {
      final r = (n / c).ceil();
      final size = _heartWidth(c, r, w, h, spacing);
      if (size > bestSize + 1e-9) {
        best = c;
        bestSize = size;
      }
    }
    return best;
  }

  static double _heartWidth(int c, int r, double w, double h, double sp) {
    final pitchW = 1 + sp + 2 * strokeMargin;
    final pitchH = 1 / HeartPairLayout.heartAspect + sp + 2 * strokeMargin;
    return math.min(w / (c * pitchW), h / (r * pitchH));
  }

  static HeartWallLayout compute(
    HeartWall p, {
    required double width,
    required double height,
    required List<String> codes,
    int seed = 1,
  }) {
    final n = codes.length;
    if (n == 0) {
      return HeartWallLayout(
          width: width, height: height, columns: 0, rows: 0, slots: const []);
    }
    final sp = p.spacing.clamp(0.0, 1.0);
    final aw = width * p.fill.clamp(0.2, 1.0);
    final ah = height * p.fill.clamp(0.2, 1.0);
    final cols = bestColumns(n, aw, ah, p.maxColumns.clamp(1, 12), sp);
    final rows = (n / cols).ceil();
    final hw = _heartWidth(cols, rows, aw, ah, sp);
    final hh = hw / HeartPairLayout.heartAspect;
    final pitchX = hw * (1 + sp + 2 * strokeMargin);
    final pitchY = hh + hw * (sp + 2 * strokeMargin);
    final gridH = rows * pitchY;
    final top = (height - gridH) / 2 + (pitchY - hh) / 2;
    final jitter = p.tiltJitter.clamp(0.0, 20.0);

    final slots = <HeartSlot>[];
    for (var i = 0; i < n; i++) {
      final row = i ~/ cols, col = i % cols;
      // The last row (if short) is centred.
      final inRow = row == rows - 1 ? n - row * cols : cols;
      final rowW = inRow * pitchX;
      final left = (width - rowW) / 2 + col * pitchX + (pitchX - hw) / 2;
      final box = HeartRect(left, top + row * pitchY, hw, hh);
      final heart = HeartPairLayout.heartPolygon(box);
      final rng = DeterministicRng(
          DeterministicRng.hashString('heartWall|$seed|$i|${codes[i]}'));
      final tilt = jitter == 0 ? 0.0 : (rng.nextDouble() * 2 - 1) * jitter;
      slots.add(HeartSlot(
        slot: i,
        code: codes[i],
        heart: heart,
        heartBox: box,
        pivot: (box.centreX, box.centreY),
        rotationDeg: tilt,
        region: null,
        fitBox: box,
        visibleBox: box,
        flagDest: HeartPairLayout.fitInHeart(box, box, heart, codes[i],
            p.squeeze, (box.centreX, box.top + hh * 0.42)),
      ));
    }
    return HeartWallLayout(
        width: width, height: height, columns: cols, rows: rows, slots: slots);
  }

  /// [recipe]'s wall at its canvas aspect, or null without
  /// [DesignRecipe.heartWall].
  static HeartWallLayout? ofRecipe(DesignRecipe recipe,
      {double height = 1000}) {
    final p = recipe.heartWall;
    if (p == null) return null;
    final aspect = switch (recipe.composition.orientation) {
      Orientation.portrait => 0.8,
      Orientation.landscape => 1.25,
      Orientation.square => 1.0,
    };
    return compute(p,
        width: height * aspect,
        height: height,
        codes: [for (final f in recipe.content.flags) f.code],
        seed: recipe.seed);
  }
}
