import 'dart:math' as math;

import '../geo/flag_focus.dart';
import 'design_recipe.dart';

/// How the two flags of a [SplitPair] meet.
enum SplitSeam {
  /// A vertical line at [SplitPair.seamPosition].
  straight,

  /// A sweeping curve from one top corner side to the opposite bottom side,
  /// easing out, so flag B looks drawn across flag A like a curtain
  /// (Curtain Split, M209).
  curtain,

  /// A straight slanted line (Diagonal Split, M212).
  diagonal;

  static SplitSeam fromId(String? id) {
    for (final v in values) {
      if (v.name == id) return v;
    }
    return SplitSeam.curtain;
  }
}

/// The block's outer edge treatment.
enum SplitEdge {
  /// Clean rectangle.
  clean,

  /// Eroded, torn and speckled (grunge print).
  torn,

  /// Dry-brush edge (M208 `BrushEdge`). Until a renderer supports it, it is
  /// drawn as [torn].
  brush;

  static SplitEdge fromId(String? id) {
    for (final v in values) {
      if (v.name == id) return v;
    }
    return SplitEdge.torn;
  }
}

/// Two flags in one block, meeting along a seam (`DesignRecipe.splitPair`,
/// family [DesignFamily.splitPair]; ADR-185 §5). Flag A
/// (`content.flags[0]`) is left of the seam, flag B (`content.flags[1]`)
/// right of it. Each flag covers the whole block height and is cropped
/// around its [FlagFocus] so its canton or emblem stays in view.
///
/// Shared rules (not pack data):
///  * the seam's top goes to the flag whose focus sits high (a canton), so
///    the US keeps its stars on either side; [seamFlip] only decides when
///    neither or both do;
///  * when both flags need the top, the seam straightens and the block widens
///    (to at least 1.1:1), so both cantons fit;
///  * a flag whose protected part spans its whole width (Nepal's pennant) is
///    shrunk to fit its half instead of cropped;
///  * look-alike flags at the seam get an [autoGap] channel (decided by the
///    renderer from the pixels).
///
/// Like the other new groups, [toJson] writes every field.
class SplitPair {
  const SplitPair({
    this.seam = SplitSeam.curtain,
    this.seamPosition = 0.47,
    this.seamSlant = 0.27,
    this.seamCurve = 0.6,
    this.seamFlip = false,
    this.seamGap = 0.0,
    this.autoGap = 0.012,
    this.blockAspect = 0.86,
    this.margin = 0.04,
    this.rotateFlags = false,
    this.shadow = 0.3,
    this.edge = SplitEdge.torn,
    this.edgeWear = 0.6,
    this.distress = 0.6,
    this.distressScale = 0.5,
    this.scratches = 0.5,
    this.fade = 0.15,
  });

  /// Seam shape.
  final SplitSeam seam;

  /// The seam's x at mid height, as a fraction of the block width.
  final double seamPosition;

  /// Horizontal travel of the seam from top to bottom (fraction of block
  /// width); 0 = vertical. Ignored by [SplitSeam.straight].
  final double seamSlant;

  /// How much a curtain seam eases out (0 = straight slant, 1 = strong
  /// curve). Curtain only.
  final double seamCurve;

  /// Mirror the slant when the flags' foci don't decide it.
  final bool seamFlip;

  /// Width of a garment-colour channel along the seam (fraction of block
  /// width); 0 = the flags touch.
  final double seamGap;

  /// Channel width used instead when the two flags look alike along the seam
  /// (0 = never).
  final double autoGap;

  /// Block width / height.
  final double blockAspect;

  /// Space between the block and the canvas edge (fraction of the shorter
  /// canvas side).
  final double margin;

  /// Turn both flags a quarter turn so their stripes run down the block
  /// (Diagonal Split).
  final bool rotateFlags;

  /// Shade on flag A along the seam, as if B lies on top (0 = none).
  final double shadow;

  final SplitEdge edge;

  /// How deep the outer edge is eaten (0 = clean rectangle).
  final double edgeWear;

  /// Grunge speckle knockouts across both flags.
  final double distress;

  /// Size of the grunge flecks (0 fine … 1 coarse).
  final double distressScale;

  /// Thin scratch lines.
  final double scratches;

  /// Worn-print colour fade (desaturate and darken slightly).
  final double fade;

  Map<String, Object?> toJson() => {
        'seam': seam.name,
        'seamPosition': seamPosition,
        'seamSlant': seamSlant,
        'seamCurve': seamCurve,
        'seamFlip': seamFlip,
        'seamGap': seamGap,
        'autoGap': autoGap,
        'blockAspect': blockAspect,
        'margin': margin,
        'rotateFlags': rotateFlags,
        'shadow': shadow,
        'edge': edge.name,
        'edgeWear': edgeWear,
        'distress': distress,
        'distressScale': distressScale,
        'scratches': scratches,
        'fade': fade,
      };

  factory SplitPair.fromJson(Map<String, Object?> j) {
    const d = SplitPair();
    double n(String k, double f) => (j[k] as num?)?.toDouble() ?? f;
    return SplitPair(
      seam: SplitSeam.fromId(j['seam'] as String?),
      seamPosition: n('seamPosition', d.seamPosition),
      seamSlant: n('seamSlant', d.seamSlant),
      seamCurve: n('seamCurve', d.seamCurve),
      seamFlip: j['seamFlip'] as bool? ?? d.seamFlip,
      seamGap: n('seamGap', d.seamGap),
      autoGap: n('autoGap', d.autoGap),
      blockAspect: n('blockAspect', d.blockAspect),
      margin: n('margin', d.margin),
      rotateFlags: j['rotateFlags'] as bool? ?? d.rotateFlags,
      shadow: n('shadow', d.shadow),
      edge: SplitEdge.fromId(j['edge'] as String?),
      edgeWear: n('edgeWear', d.edgeWear),
      distress: n('distress', d.distress),
      distressScale: n('distressScale', d.distressScale),
      scratches: n('scratches', d.scratches),
      fade: n('fade', d.fade),
    );
  }
}

/// Canvas width / height for an orientation (the hosts' convention:
/// portrait 4:5, landscape 5:4).
double canvasAspectOf(Orientation o) => switch (o) {
      Orientation.portrait => 0.8,
      Orientation.landscape => 1.25,
      Orientation.square => 1.0,
    };

/// Where one flag of a split pair is drawn, in canvas pixels.
class SplitFlagPlacement {
  const SplitFlagPlacement({
    required this.slot,
    required this.code,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rotated,
    required this.region,
  });

  final int slot;
  final String code;

  /// The drawn flag's box (after any quarter turn).
  final double left, top, width, height;

  /// True = the flag is turned a quarter turn clockwise (its hoist at the top).
  final bool rotated;

  /// The flag's half of the block (canvas pixels), a closed polygon.
  final List<(double, double)> region;

  /// [p] (canvas pixels) in the flag's own normalised space.
  (double, double) toFlag((double, double) p) {
    final dx = (p.$1 - left) / width, dy = (p.$2 - top) / height;
    return rotated ? (dy, 1 - dx) : (dx, dy);
  }

  /// The visible part of the flag: [region] in flag space.
  List<(double, double)> get flagPolygon => [for (final p in region) toFlag(p)];
}

/// The resolved layout of a [SplitPair] on a canvas: pure maths shared by
/// the renderer and pair QA ([PairGeometry]), so both agree exactly.
///
/// All flags are 4:3 in the bundled set; [flagAspect] is that constant (the
/// renderer passes the measured aspect, which is the same).
class SplitPairLayout {
  SplitPairLayout._({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.blockLeft,
    required this.blockTop,
    required this.blockWidth,
    required this.blockHeight,
    required this.slant,
    required this.params,
    required this.flags,
  });

  static const double flagAspect = 4 / 3;

  /// Samples along the seam polyline.
  static const int seamSamples = 48;

  final double canvasWidth, canvasHeight;
  final double blockLeft, blockTop, blockWidth, blockHeight;

  /// The signed seam travel actually used (after the focus rule).
  final double slant;
  final SplitPair params;
  final List<SplitFlagPlacement> flags;

  /// Lays out [recipe] (two flags + `splitPair`) on a [w]×[h] canvas. Null
  /// when the recipe is not a split pair of two flags.
  static SplitPairLayout? of(DesignRecipe recipe, double w, double h,
      {double aspectA = flagAspect, double aspectB = flagAspect}) {
    final p = recipe.splitPair;
    final codes = recipe.content.flags;
    if (p == null || codes.length < 2) return null;
    final a = codes[0].code, b = codes[1].code;
    final fa = FlagFocus.of(a), fb = FlagFocus.of(b);

    // Focus rule: the top goes to the flag that needs it.
    const high = 0.45;
    final needA = _needsTop(fa, p.rotateFlags, high);
    final needB = _needsTop(fb, p.rotateFlags, high);
    var slant = p.seam == SplitSeam.straight ? 0.0 : p.seamSlant;
    var blockAspect = p.blockAspect;
    var position = p.seamPosition;
    if (needA && !needB) {
      slant = slant.abs();
    } else if (needB && !needA) {
      slant = -slant.abs();
    } else if (needA && needB && !p.rotateFlags) {
      slant = 0;
      position = 0.5;
      blockAspect = math.max(blockAspect, 1.1);
    } else if (p.seamFlip) {
      slant = -slant;
    }
    // A wide canton (an ensign's Union Jack) needs the block a little wider
    // to fit the top of its half.
    if (needA != needB && !p.rotateFlags) {
      final e = (needA ? fa : fb).emblem!;
      // The half's narrowest share of the block over the canton's rows.
      var share = 1.0;
      for (var i = 0; i <= 10; i++) {
        final x = _seamX(
            p.seam, position, slant, p.seamCurve, e.top + e.height * i / 10);
        share = math.min(share, needA ? x : 1 - x);
      }
      if (share > 0) {
        final want = e.width * (needA ? aspectA : aspectB) * 0.7 / share;
        blockAspect = math.max(blockAspect, math.min(want, 1.15));
      }
    }

    // Block, centred.
    final m = p.margin * math.min(w, h);
    final aw = w - 2 * m, ah = h - 2 * m;
    var bh = ah, bw = bh * blockAspect;
    if (bw > aw) {
      bw = aw;
      bh = bw / blockAspect;
    }
    final bl = (w - bw) / 2, bt = (h - bh) / 2;

    final layout = SplitPairLayout._(
      canvasWidth: w,
      canvasHeight: h,
      blockLeft: bl,
      blockTop: bt,
      blockWidth: bw,
      blockHeight: bh,
      slant: slant,
      params: SplitPair(
        seam: p.seam,
        seamPosition: position,
        seamSlant: p.seamSlant,
        seamCurve: p.seamCurve,
        seamFlip: p.seamFlip,
        seamGap: p.seamGap,
        autoGap: p.autoGap,
        blockAspect: blockAspect,
        margin: p.margin,
        rotateFlags: p.rotateFlags,
        shadow: p.shadow,
        edge: p.edge,
        edgeWear: p.edgeWear,
        distress: p.distress,
        distressScale: p.distressScale,
        scratches: p.scratches,
        fade: p.fade,
      ),
      flags: const [],
    );
    final flags = [
      layout._place(0, a, fa, aspectA),
      layout._place(1, b, fb, aspectB),
    ];
    return SplitPairLayout._(
      canvasWidth: w,
      canvasHeight: h,
      blockLeft: bl,
      blockTop: bt,
      blockWidth: bw,
      blockHeight: bh,
      slant: slant,
      params: layout.params,
      flags: flags,
    );
  }

  static bool _needsTop(FlagFocus f, bool rotated, double high) {
    final e = f.emblem;
    if (e == null) return false;
    if (rotated) return false;
    // A canton / hoist emblem sitting in the upper part of the flag.
    return f.focusY < high && e.height < 0.8;
  }

  /// The seam's x (fraction of block width) at block height [t] (0 top … 1
  /// bottom).
  double seamAt(double t) =>
      _seamX(params.seam, params.seamPosition, slant, params.seamCurve, t);

  static double _seamX(
      SplitSeam seam, double position, double slant, double curve, double t) {
    final tt = t.clamp(0.0, 1.0);
    switch (seam) {
      case SplitSeam.straight:
        return position;
      case SplitSeam.diagonal:
        return position + slant * (0.5 - tt);
      case SplitSeam.curtain:
        // Eases out: most of the sweep happens near the top.
        final e = 1 - math.pow(1 - tt, 1 + curve.clamp(0.0, 2.0));
        return position + slant * (0.5 - e);
    }
  }

  /// The seam polyline in canvas pixels, top to bottom.
  List<(double, double)> get seamPoints => [
        for (var i = 0; i <= seamSamples; i++)
          (
            blockLeft + seamAt(i / seamSamples) * blockWidth,
            blockTop + i / seamSamples * blockHeight,
          ),
      ];

  double get _minSeam {
    var v = double.infinity;
    for (var i = 0; i <= seamSamples; i++) {
      v = math.min(v, seamAt(i / seamSamples));
    }
    return v;
  }

  double get _maxSeam {
    var v = -double.infinity;
    for (var i = 0; i <= seamSamples; i++) {
      v = math.max(v, seamAt(i / seamSamples));
    }
    return v;
  }

  /// Half the explicit gap, in block-width fractions.
  double get _halfGap => params.seamGap / 2;

  /// Slot [slot]'s half of the block (canvas pixels).
  List<(double, double)> regionOf(int slot, {double gap = -1}) {
    final hg = gap < 0 ? _halfGap : gap / 2;
    final bl = blockLeft, bt = blockTop, bw = blockWidth, bh = blockHeight;
    final seam = [
      for (var i = 0; i <= seamSamples; i++)
        (i / seamSamples, seamAt(i / seamSamples)),
    ];
    if (slot == 0) {
      return [
        (bl, bt),
        for (final (t, x) in seam)
          (bl + (x - hg).clamp(0.0, 1.0) * bw, bt + t * bh),
        (bl, bt + bh),
      ];
    }
    return [
      for (final (t, x) in seam)
        (bl + (x + hg).clamp(0.0, 1.0) * bw, bt + t * bh),
      (bl + bw, bt + bh),
      (bl + bw, bt),
    ];
  }

  SplitFlagPlacement _place(int slot, String code, FlagFocus f, double aspect) {
    final rot = params.rotateFlags;
    // Drawn size in "units" before scaling: unrotated r×1, rotated 1×r.
    final w0 = rot ? 1.0 : aspect, h0 = rot ? aspect : 1.0;
    final bl = blockLeft, bt = blockTop, bw = blockWidth, bh = blockHeight;
    final hg = _halfGap;
    // Horizontal extent the flag must cover (canvas px).
    final c0 = slot == 0 ? bl : bl + (_minSeam + hg).clamp(0.0, 1.0) * bw;
    final c1 = slot == 0 ? bl + (_maxSeam - hg).clamp(0.0, 1.0) * bw : bl + bw;
    var s = math.max(bh / h0, (c1 - c0) / w0);
    var dw = s * w0, dh = s * h0;

    // Focus and protected box in drawn units (0..1 of the drawn box).
    final fdx = rot ? 1 - f.focusY : f.focusX;
    final fdy = rot ? f.focusX : f.focusY;
    final e = f.emblem;
    final ex0 = e == null ? 0.0 : (rot ? 1 - e.bottom : e.left);
    final ex1 = e == null ? 0.0 : (rot ? 1 - e.top : e.right);
    final ey0 = e == null ? 0.0 : (rot ? e.left : e.top);
    final ey1 = e == null ? 0.0 : (rot ? e.right : e.bottom);

    // The half's horizontal span (canvas px) at block height t.
    (double, double) spanAt(double t) {
      final x = seamAt(t);
      return slot == 0
          ? (bl, bl + (x - hg).clamp(0.0, 1.0) * bw)
          : (bl + (x + hg).clamp(0.0, 1.0) * bw, bl + bw);
    }

    var top = _clamp(bt + bh / 2 - fdy * dh, bt + bh - dh, bt);
    final tf = ((top + fdy * dh - bt) / bh).clamp(0.0, 1.0);
    final (fl, fr) = spanAt(tf);

    SplitFlagPlacement at(double left) => SplitFlagPlacement(
          slot: slot,
          code: code,
          left: left,
          top: top,
          width: dw,
          height: dh,
          rotated: rot,
          region: regionOf(slot),
        );

    // Nothing protected: show a window from the hoist (a plain tricolour
    // keeps its first colour), or around the focus for a tuned flag.
    if (e == null) {
      final win = ((fr - fl) / dw).clamp(0.0, 1.0);
      final wl = f.kind == FlagFocusKind.centre
          ? 0.0
          : (fdx - win / 2).clamp(0.0, 1.0 - win);
      return at(_clamp(fl - wl * dw, c1 - dw, c0));
    }

    // Share of the protected box inside the half, averaged over its rows.
    double visible(double left, double top, double dw, double dh) {
      final eL = left + ex0 * dw, eR = left + ex1 * dw;
      if (eR <= eL) return 1;
      const n = 16;
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        final y = top + (ey0 + (ey1 - ey0) * (i + 0.5) / n) * dh;
        final t = (y - bt) / bh;
        if (t < 0 || t > 1) continue;
        final (l, r) = spanAt(t);
        final o = math.min(eR, r) - math.max(eL, l);
        sum += o <= 0 ? 0 : o / (eR - eL);
      }
      return sum / n;
    }

    // Comfortably above pair QA's 70% minimum (its sampling differs a little).
    const good = 0.78;
    // 1. Covering placements: the focus window first, then a sweep.
    final win = ((fr - fl) / dw).clamp(0.0, 1.0);
    final wl = (fdx - win / 2).clamp(0.0, 1.0 - win);
    final preferred = _clamp(fl - wl * dw, c1 - dw, c0);
    if (visible(preferred, top, dw, dh) >= good) return at(preferred);
    var best = preferred, bestVis = visible(preferred, top, dw, dh);
    final lo = math.min(c1 - dw, c0), hi = math.max(c1 - dw, c0);
    for (var i = 0; i <= 40; i++) {
      final left = lo + (hi - lo) * i / 40;
      final v = visible(left, top, dw, dh);
      if (v > bestVis + 1e-6) {
        best = left;
        bestVis = v;
      }
    }
    if (bestVis >= good) return at(best);
    final bestCovered = best, bestCoveredVis = bestVis;

    // 2. Uncovered: the protected box centred in its rows' mean span; the
    //    renderer extends an opaque flag's edge into the rest of the half.
    var ml = 0.0, mr = 0.0;
    var nl = double.infinity;
    var nr = -double.infinity;
    for (var i = 0; i <= 8; i++) {
      final y = top + (ey0 + (ey1 - ey0) * i / 8) * dh;
      final (l, r) = spanAt(((y - bt) / bh).clamp(0.0, 1.0));
      ml += l / 9;
      mr += r / 9;
      if (r - l < nr - nl || nl == double.infinity) {
        nl = l;
        nr = r;
      }
    }
    final centred = (ml + mr) / 2 - (ex0 + ex1) / 2 * dw;
    if (visible(centred, top, dw, dh) >= good) return at(centred);
    // Still above the QA minimum while covering: better than shrinking.
    if (bestCoveredVis >= 0.74) return at(bestCovered);

    // 3. Too wide for the half (Switzerland's cross, Nepal's pennant):
    //    shrink the flag until the box fits the narrowest of its rows, then
    //    re-measure those rows at the new size (they move as it shrinks).
    final ew = ex1 - ex0;
    var left = 0.0;
    for (var pass = 0; pass < 4; pass++) {
      s = math.min(s, (nr - nl) * 0.92 / (ew * w0));
      dw = s * w0;
      dh = s * h0;
      top = _clamp(bt + bh / 2 - (ey0 + ey1) / 2 * dh, bt, bt + bh - dh);
      nl = double.infinity;
      nr = -double.infinity;
      for (var i = 0; i <= 8; i++) {
        final y = top + (ey0 + (ey1 - ey0) * i / 8) * dh;
        final (l, r) = spanAt(((y - bt) / bh).clamp(0.0, 1.0));
        if (nl == double.infinity || r - l < nr - nl) {
          nl = l;
          nr = r;
        }
      }
      left = (nl + nr) / 2 - (ex0 + ex1) / 2 * dw;
    }
    return at(left);
  }

  /// [v] clamped to [lo, hi]; tolerant of [lo] > [hi] by float error (then
  /// the midpoint).
  static double _clamp(double v, double lo, double hi) =>
      lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);

  /// Pair QA geometry: crops in flag space and the seam in the artwork's
  /// normalised space, after the size class's centred [scale].
  ({List<(double, double)> seam, double gap}) renderSeam(double scale) {
    (double, double) n((double, double) p) => (
          0.5 + (p.$1 / canvasWidth - 0.5) * scale,
          0.5 + (p.$2 / canvasHeight - 0.5) * scale,
        );
    return (
      seam: [for (final p in seamPoints) n(p)],
      gap: params.seamGap * blockWidth / canvasWidth * scale,
    );
  }
}
