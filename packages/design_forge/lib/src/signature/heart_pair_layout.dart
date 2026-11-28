import 'dart:math' as math;

import '../geo/flag_focus.dart';
import '../recipe/design_recipe.dart';
import '../recipe/heart_pair.dart';
import 'pair_geometry.dart';

/// An axis-aligned rectangle in canvas pixels.
class HeartRect {
  const HeartRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centreX => left + width / 2;
  double get centreY => top + height / 2;

  HeartRect inflate(double d) =>
      HeartRect(left - d, top - d, width + 2 * d, height + 2 * d);

  @override
  String toString() => 'HeartRect($left, $top, $width, $height)';
}

/// One flag's part of a [HeartPair] design, in canvas pixels of the
/// design's own frame (before [rotationDeg] about [pivot]).
class HeartSlot {
  const HeartSlot({
    required this.slot,
    required this.code,
    required this.heart,
    required this.heartBox,
    required this.pivot,
    required this.rotationDeg,
    required this.region,
    required this.fitBox,
    required this.visibleBox,
    required this.flagDest,
  });

  /// 0 = country A, 1 = country B.
  final int slot;
  final String code;

  /// The heart outline this flag is painted into (closed polygon).
  final List<(double, double)> heart;
  final HeartRect heartBox;

  /// Rotation centre and angle (degrees, clockwise on screen).
  final (double, double) pivot;
  final double rotationDeg;

  /// Shared heart: the side of the seam this flag fills (closed polygon,
  /// generously past the heart); null = the whole heart.
  final List<(double, double)>? region;

  /// The part of the heart the flag is fitted to.
  final HeartRect fitBox;

  /// The part of the heart certainly showing this flag (for QA; the seam's
  /// far side is excluded).
  final HeartRect visibleBox;

  /// Where the whole flag image is drawn (its edges are extended past this
  /// box, so spilled brush strokes still carry the flag's colours).
  final HeartRect flagDest;

  /// What this slot shows of its flag, in the flag's own normalised space.
  FlagCrop crop() {
    double fx(double x) => (x - flagDest.left) / flagDest.width;
    double fy(double y) => (y - flagDest.top) / flagDest.height;
    final l = fx(visibleBox.left).clamp(0.0, 1.0);
    final r = fx(visibleBox.right).clamp(0.0, 1.0);
    final t = fy(visibleBox.top).clamp(0.0, 1.0);
    final b = fy(visibleBox.bottom).clamp(0.0, 1.0);
    return FlagCrop(
      slot: slot,
      code: code,
      visible: FlagBox(l, t, math.max(0, r - l), math.max(0, b - t)),
      polygon: [for (final (x, y) in heart) (fx(x), fy(y))],
    );
  }
}

/// The geometry of a [HeartPair] design (ADR-185, M210/M211): pure Dart, so
/// the renderer and pair QA ([PairGeometry.of]) agree exactly.
class HeartPairLayout {
  const HeartPairLayout({
    required this.width,
    required this.height,
    required this.slots,
    required this.seam,
    required this.gap,
  });

  /// Every bundled flag is drawn 4:3 (flag-icons `viewBox="0 0 640 480"`).
  static const double flagAspect = 4 / 3;

  final double width;
  final double height;
  final List<HeartSlot> slots;

  /// Where A meets B, top to bottom, canvas pixels.
  final List<(double, double)> seam;

  /// Width of the empty channel between A and B (0 for a shared heart).
  final double gap;

  /// The layout of [p] on a [width]×[height] canvas for countries [a], [b].
  static HeartPairLayout compute(
    HeartPair p, {
    required double width,
    required double height,
    required String a,
    required String b,
  }) =>
      p.isTwin
          ? _twin(p, width, height, a, b)
          : _shared(p, width, height, a, b);

  static HeartPairLayout _shared(
      HeartPair p, double w, double h, String a, String b) {
    final size = p.heartScale.clamp(0.1, 1.0) * math.min(w, h);
    final hw = size, hh = size / heartAspect;
    final box = HeartRect((w - hw) / 2, (h - hh) / 2, hw, hh);
    final heart = heartPolygon(box);

    // The seam: a gently bowed, slightly leaning vertical line.
    final seam = <(double, double)>[];
    const n = 24;
    final over = hh * 0.15;
    for (var i = 0; i <= n; i++) {
      final t = -0.15 + 1.3 * i / n;
      final x = box.left +
          hw * p.seamPosition.clamp(0.3, 0.7) +
          p.seamCurve.clamp(-1.0, 1.0) * hw * 0.035 * math.sin(math.pi * t) +
          p.seamLean.clamp(-1.0, 1.0) * hw * 0.04 * (2 * t - 1);
      seam.add((x, box.top + hh * t));
    }
    final xs = [
      for (final (x, y) in seam)
        if (y >= box.top && y <= box.bottom) x
    ];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final top = box.top - over, bottom = box.bottom + over;

    HeartSlot slot(int i, String code) {
      final left = i == 0;
      final fit = left
          ? HeartRect(box.left, box.top, maxX - box.left, hh)
          : HeartRect(minX, box.top, box.right - minX, hh);
      final visible = left
          ? HeartRect(box.left, box.top, minX - box.left, hh)
          : HeartRect(maxX, box.top, box.right - maxX, hh);
      final region = left
          ? [(-w, top), ...seam, (-w, bottom)]
          : [...seam, (2 * w, bottom), (2 * w, top)];
      return HeartSlot(
        slot: i,
        code: code,
        heart: heart,
        heartBox: box,
        pivot: (box.centreX, box.centreY),
        rotationDeg: 0,
        region: region,
        fitBox: fit,
        visibleBox: visible,
        flagDest: fitInHeart(fit, visible, heart, code, p.squeeze,
            (box.left + hw * (left ? 0.28 : 0.72), box.top + hh * 0.42)),
      );
    }

    return HeartPairLayout(
      width: w,
      height: h,
      slots: [slot(0, a), slot(1, b)],
      seam: seam,
      gap: 0,
    );
  }

  static HeartPairLayout _twin(
      HeartPair p, double w, double h, String a, String b) {
    final tilt = p.tilt.clamp(-30.0, 30.0);
    final rad = tilt.abs() * math.pi / 180;
    final cos = math.cos(rad), sin = math.sin(rad);
    // A negative gap overlaps the hearts a little (B is painted over A).
    var gapPx = p.gap.clamp(-0.1, 0.3) * w;
    var hw = (p.heartScale.clamp(0.1, 1.0) * w - gapPx) / 2;
    var hh = hw / heartAspect;
    // Tilted hearts swing their tips inward: keep them apart.
    double lean() => hh / 2 * sin;
    // Fit the pair, tilted and with room for the brush strokes that spill
    // past the outline, inside the canvas (so the print edge is never hit).
    final margin = 0.075; // of the heart's width
    final outer =
        gapPx / 2 + lean() + hw / 2 + hw / 2 * cos + hh / 2 * sin + hw * margin;
    final tall = hh / 2 * cos + hw / 2 * sin + hw * margin;
    final s =
        math.min(1.0, math.min(w / 2 * 0.99 / outer, h / 2 * 0.97 / tall));
    hw *= s;
    hh *= s;
    gapPx *= s;
    final half = gapPx / 2 + lean() + hw / 2;

    HeartSlot slot(int i, String code) {
      final cx = w / 2 + (i == 0 ? -half : half);
      final box = HeartRect(cx - hw / 2, (h - hh) / 2, hw, hh);
      final heart = heartPolygon(box);
      return HeartSlot(
        slot: i,
        code: code,
        heart: heart,
        heartBox: box,
        pivot: (box.centreX, box.centreY),
        // A turns anticlockwise, B clockwise: the tops lean apart and the
        // tips point in toward each other (as in the reference).
        rotationDeg: i == 0 ? -tilt : tilt,
        region: null,
        fitBox: box,
        visibleBox: box,
        flagDest: fitInHeart(box, box, heart, code, p.squeeze,
            (box.centreX, box.top + hh * 0.42)),
      );
    }

    return HeartPairLayout(
      width: w,
      height: h,
      slots: [slot(0, a), slot(1, b)],
      seam: [(w / 2, 0), (w / 2, h)],
      gap: gapPx,
    );
  }

  /// Where to draw [code]'s whole flag so it covers [box]: true proportions
  /// cropped around the flag's focus, squeezed toward a stretch by
  /// [squeeze], and squeezed further if the emblem/canton would not fit.
  static HeartRect fitFlag(HeartRect box, String code, double squeeze) {
    final focus = FlagFocus.of(code);
    final s = squeeze.clamp(0.0, 1.0);
    var dh = math.max(box.height, box.width / flagAspect);
    var dw = dh * flagAspect;
    dw = dw + (box.width - dw) * s;
    dh = dh + (box.height - dh) * s;
    final e = focus.emblem;
    if (e != null) {
      if (e.width > 0) dw = math.min(dw, 0.96 * box.width / e.width);
      if (e.height > 0) dh = math.min(dh, 0.96 * box.height / e.height);
    }
    dw = math.max(dw, box.width);
    dh = math.max(dh, box.height);
    final ww = box.width / dw, wh = box.height / dh;
    final fl = (focus.focusX - ww / 2).clamp(0.0, 1.0 - ww);
    final ft = (focus.focusY - wh / 2).clamp(0.0, 1.0 - wh);
    return HeartRect(box.left - fl * dw, box.top - ft * dh, dw, dh);
  }

  /// Share of the emblem kept visible (as pair QA measures it) needed before
  /// [fitInHeart] stops adjusting a flag.
  static const double emblemTarget = 0.8;

  /// [fitFlag], then — when the heart's curves would hide too much of the
  /// flag's emblem/canton — shrinks the flag step by step (to at most
  /// [minShrink]) while sliding its focus toward [safe] (the roomiest point
  /// of this part of the heart), until [emblemTarget] of the emblem shows.
  /// The flag's edge colours extend past it, so a shrunken flag still fills
  /// the heart.
  static HeartRect fitInHeart(
    HeartRect fit,
    HeartRect visible,
    List<(double, double)> heart,
    String code,
    double squeeze,
    (double, double) safe, {
    double minShrink = 0.55,
  }) {
    final base = fitFlag(fit, code, squeeze);
    final focus = FlagFocus.of(code);
    final e = focus.emblem;
    if (e == null) return base;
    double vis(HeartRect d) {
      const n = 14;
      var inside = 0;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          final x = d.left + d.width * (e.left + e.width * (i + 0.5) / n);
          final y = d.top + d.height * (e.top + e.height * (j + 0.5) / n);
          if (x >= visible.left &&
              x <= visible.right &&
              y >= visible.top &&
              y <= visible.bottom &&
              FlagCrop.pointInPolygon(x, y, heart)) {
            inside++;
          }
        }
      }
      return inside / (n * n);
    }

    var best = base;
    var bestV = vis(base);
    if (bestV >= emblemTarget) return best;
    final fx = base.left + base.width * focus.focusX;
    final fy = base.top + base.height * focus.focusY;
    const steps = 18;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final k = 1 - (1 - minShrink) * t;
      final tx = fx + (safe.$1 - fx) * t, ty = fy + (safe.$2 - fy) * t;
      final dw = base.width * k, dh = base.height * k;
      final d =
          HeartRect(tx - focus.focusX * dw, ty - focus.focusY * dh, dw, dh);
      final v = vis(d);
      if (v > bestV + 1e-9) {
        best = d;
        bestV = v;
      }
      if (v >= emblemTarget) break;
    }
    return best;
  }

  /// The pair-QA view of this layout, normalised to the rendered image
  /// (the artwork is drawn centred at [scale] of the canvas).
  PairGeometry toPairGeometry({double scale = 1}) {
    (double, double) norm((double, double) p) => (
          0.5 + (p.$1 / width - 0.5) * scale,
          0.5 + (p.$2 / height - 0.5) * scale,
        );
    final pts = [for (final p in seam) norm(p)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return PairGeometry(
      crops: [for (final s in slots) s.crop()],
      seam: PairSeam(pts, gap: gap / width * scale),
    );
  }

  /// [recipe]'s layout at its orientation's aspect, or null without
  /// [DesignRecipe.heartPair] or two flags.
  static HeartPairLayout? ofRecipe(DesignRecipe recipe,
      {double height = 1000}) {
    final p = recipe.heartPair;
    final flags = recipe.content.flags;
    if (p == null || flags.length < 2) return null;
    final aspect = switch (recipe.composition.orientation) {
      Orientation.portrait => 0.8,
      Orientation.landscape => 1.25,
      Orientation.square => 1.0,
    };
    return compute(p,
        width: height * aspect,
        height: height,
        a: flags[0].code,
        b: flags[1].code);
  }

  /// Width / height of the classic heart curve.
  static final double heartAspect = () {
    final pts = _unitHeart();
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final (x, y) in pts) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    return (maxX - minX) / (maxY - minY);
  }();

  /// The heart outline (the same curve as the `heart` clip shape) fitted
  /// to [box], as a closed polygon.
  static List<(double, double)> heartPolygon(HeartRect box, {int steps = 200}) {
    final pts = _unitHeart(steps);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final (x, y) in pts) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final bw = maxX - minX, bh = maxY - minY;
    final s = math.min(box.width / bw, box.height / bh);
    final cx = box.centreX - (minX + bw / 2) * s;
    final cy = box.centreY - (minY + bh / 2) * s;
    return [for (final (x, y) in pts) (x * s + cx, y * s + cy)];
  }

  static List<(double, double)> _unitHeart([int steps = 200]) => [
        for (var i = 0; i < steps; i++)
          () {
            final t = i / steps * 2 * math.pi;
            final x = 16 * math.pow(math.sin(t), 3).toDouble();
            final y = 13 * math.cos(t) -
                5 * math.cos(2 * t) -
                2 * math.cos(3 * t) -
                math.cos(4 * t);
            return (x, -y);
          }(),
      ];
}
