import '../geo/flag_focus.dart';
import '../recipe/design_recipe.dart';
import 'heart_pair_layout.dart';
import '../recipe/split_pair.dart';

/// The part of one flag a two-country design shows (ADR-185 §4), in the
/// flag's own normalised space (see [FlagBox]).
///
/// [visible] bounds what is shown. [polygon], when given, is the exact shown
/// region (e.g. one side of a diagonal seam), also in flag space; the box
/// then only bounds it.
class FlagCrop {
  const FlagCrop({
    required this.slot,
    required this.code,
    required this.visible,
    this.polygon,
  });

  /// 0 = country A (left/top), 1 = country B.
  final int slot;
  final String code;
  final FlagBox visible;
  final List<(double, double)>? polygon;

  FlagFocus get focus => FlagFocus.of(code);

  /// Fraction (0..1) of the flag's emblem this crop keeps visible; 1 when
  /// the flag has no emblem.
  double get emblemVisible {
    final e = focus.emblem;
    if (e == null) return 1;
    final poly = polygon;
    if (poly == null) return focus.visibleFraction(visible);
    // Sample the emblem box on a grid and count points inside the polygon.
    const n = 24;
    var inside = 0;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final x = e.left + e.width * (i + 0.5) / n;
        final y = e.top + e.height * (j + 0.5) / n;
        if (visible.contains(x, y) && pointInPolygon(x, y, poly)) inside++;
      }
    }
    return inside / (n * n);
  }

  /// Even-odd point-in-polygon test.
  static bool pointInPolygon(double x, double y, List<(double, double)> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final (xi, yi) = poly[i];
      final (xj, yj) = poly[j];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// The line where the two flags of a pair design meet, in the artwork's
/// normalised space ((0,0) top-left, (1,1) bottom-right of the render).
class PairSeam {
  const PairSeam(this.points, {this.gap = 0});

  /// A straight vertical seam at x = [x].
  factory PairSeam.vertical(double x) => PairSeam([(x, 0), (x, 1)]);

  /// The seam as a polyline, top to bottom (at least two points).
  final List<(double, double)> points;

  /// Width of the garment-colour channel along the seam (fraction of the
  /// artwork width); > 0 means the seam is drawn, so flags never touch.
  final double gap;

  /// The seam's x at height [y] (linear between points; clamped).
  double xAt(double y) {
    if (points.length < 2) return points.isEmpty ? 0.5 : points.first.$1;
    for (var i = 0; i < points.length - 1; i++) {
      final (x0, y0) = points[i];
      final (x1, y1) = points[i + 1];
      if (y >= y0 && y <= y1) {
        final t = y1 == y0 ? 0.0 : (y - y0) / (y1 - y0);
        return x0 + (x1 - x0) * t;
      }
    }
    return y < points.first.$2 ? points.first.$1 : points.last.$1;
  }
}

/// What a pair composition reports about its geometry so pair QA can check
/// it (ADR-185 §4): which part of each flag is shown, and where the seam is.
///
/// Geometry is derived from the recipe alone — pure, no rendering — so the
/// same recipe always reports the same crops. A composition that lays out two
/// flags adds its family to [of]; until then QA falls back to a vertical seam
/// through the middle and skips the emblem check.
class PairGeometry {
  const PairGeometry({required this.crops, this.seam});

  final List<FlagCrop> crops;
  final PairSeam? seam;

  /// The geometry [recipe] draws, or null when its composition does not
  /// report one (single-flag designs, and pair compositions not yet wired).
  static PairGeometry? of(DesignRecipe recipe) {
    // Shared Heart / Twin Hearts (M210/M211).
    final hearts = HeartPairLayout.ofRecipe(recipe);
    if (hearts != null) {
      return hearts.toPairGeometry(scale: recipe.composition.sizeClass.scale);
    }
    return switch (recipe.composition.family) {
      DesignFamily.splitPair => _splitPair(recipe),
      _ => null,
    };
  }

  /// [SplitPairLayout] on a unit-height canvas of the recipe's shape. Only
  /// unrotated designs report (a turned design's seam is not vertical-ish).
  static PairGeometry? _splitPair(DesignRecipe recipe) {
    if (recipe.composition.rotation != 0) return null;
    final aspect = canvasAspectOf(recipe.composition.canvasOrientation);
    final layout = SplitPairLayout.of(recipe, aspect * 1000, 1000);
    if (layout == null) return null;
    final seam = layout.renderSeam(recipe.composition.sizeClass.scale);
    return PairGeometry(
      crops: [
        for (final f in layout.flags) _crop(f),
      ],
      seam: PairSeam(seam.seam, gap: seam.gap),
    );
  }

  static FlagCrop _crop(SplitFlagPlacement f) {
    final poly = f.flagPolygon;
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final (x, y) in poly) {
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
    l = l.clamp(0.0, 1.0);
    t = t.clamp(0.0, 1.0);
    r = r.clamp(0.0, 1.0);
    b = b.clamp(0.0, 1.0);
    return FlagCrop(
      slot: f.slot,
      code: f.code,
      visible: FlagBox(l, t, r - l, b - t),
      polygon: poly,
    );
  }
}
