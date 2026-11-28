import 'iso3.dart';

/// An axis-aligned box in a flag's own normalised space: (0,0) is the top of
/// the hoist (pole side), (1,1) the bottom of the fly.
class FlagBox {
  const FlagBox(this.left, this.top, this.width, this.height);

  /// The whole flag.
  static const FlagBox full = FlagBox(0, 0, 1, 1);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get area => width * height;
  double get centreX => left + width / 2;
  double get centreY => top + height / 2;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  /// This box mirrored left↔right (a flag drawn fly-first).
  FlagBox get mirrored => FlagBox(1 - right, top, width, height);

  @override
  bool operator ==(Object other) =>
      other is FlagBox &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'FlagBox($left, $top, $width, $height)';
}

/// Where a flag's recognisable part sits (ADR-185 §4).
enum FlagFocusKind {
  /// Nothing to protect; any crop reads (stripes, plain tricolours).
  centre,

  /// The upper-hoist canton carries the identity (US stars, Union Jack).
  canton,

  /// A hoist triangle/band or an emblem set toward the hoist (Cuba, Portugal).
  hoist,

  /// A central emblem, disc or symbol (Mexico, Japan, Canada).
  emblem,

  /// The identity sits toward the fly (Pakistan's crescent, Rwanda's sun).
  fly,
}

/// The part of a flag that must stay visible when only some of the flag is
/// shown — half a flag in a split design, a crop in a heart (ADR-185 §4).
///
/// Shared engine data, not per pack: every pair composition crops a half
/// around [focusX]/[focusY], and pair QA fails a design that hides more than
/// 30% of [emblem].
class FlagFocus {
  const FlagFocus(this.kind, this.focusX, this.focusY, [this.emblem]);

  /// Default: no protected part, crop around the centre.
  static const FlagFocus plain = FlagFocus(FlagFocusKind.centre, 0.5, 0.5);

  final FlagFocusKind kind;

  /// The point a crop should be centred on (normalised flag space).
  final double focusX;
  final double focusY;

  /// The box that must stay visible, or null when any crop reads.
  final FlagBox? emblem;

  /// The focus for [code] (lowercase ISO alpha-2 or Roavvy flag code, e.g.
  /// `gb-sct`). Unknown and plain flags get [plain].
  static FlagFocus of(String code) => _table[code.toLowerCase()] ?? plain;

  /// Every flag code the engine knows (the alpha-3 table's keys).
  static Iterable<String> get knownCodes => kCountryAlpha3.keys;

  /// Codes with a hand-set focus (the rest are [plain]).
  static Iterable<String> get tunedCodes => _table.keys;

  /// The left edge, as a fraction of the flag's width, of a window
  /// [windowWidth] wide (0..1) that keeps the focus as central as possible
  /// while staying inside the flag. A half-flag crop uses `windowWidth: 0.5`.
  double windowLeft(double windowWidth) {
    final w = windowWidth.clamp(0.0, 1.0);
    return (focusX - w / 2).clamp(0.0, 1.0 - w);
  }

  /// Fraction (0..1) of [emblem] inside [visible]; 1 when there is no emblem.
  double visibleFraction(FlagBox visible) {
    final e = emblem;
    if (e == null || e.area <= 0) return 1;
    final l = e.left > visible.left ? e.left : visible.left;
    final r = e.right < visible.right ? e.right : visible.right;
    final t = e.top > visible.top ? e.top : visible.top;
    final b = e.bottom < visible.bottom ? e.bottom : visible.bottom;
    if (r <= l || b <= t) return 0;
    return ((r - l) * (b - t)) / e.area;
  }

  @override
  bool operator ==(Object other) =>
      other is FlagFocus &&
      other.kind == kind &&
      other.focusX == focusX &&
      other.focusY == focusY &&
      other.emblem == emblem;

  @override
  int get hashCode => Object.hash(kind, focusX, focusY, emblem);
}

// Shorthands for the table.
FlagFocus _canton(double w, double h) =>
    FlagFocus(FlagFocusKind.canton, w / 2, h / 2, FlagBox(0, 0, w, h));
FlagFocus _hoist(double l, double t, double w, double h) =>
    FlagFocus(FlagFocusKind.hoist, l + w / 2, t + h / 2, FlagBox(l, t, w, h));
FlagFocus _emblem(double l, double t, double w, double h) =>
    FlagFocus(FlagFocusKind.emblem, l + w / 2, t + h / 2, FlagBox(l, t, w, h));
FlagFocus _fly(double l, double t, double w, double h) =>
    FlagFocus(FlagFocusKind.fly, l + w / 2, t + h / 2, FlagBox(l, t, w, h));

/// A hoist triangle/chevron reaching [depth] of the width. The protected
/// part is its middle (the apex side and the star or emblem it carries), not
/// the thin corners along the hoist: a crop may lose those, and a flag turned
/// upright in a narrow half (Diagonal Split, M212) could never show the
/// whole hoist.
FlagFocus _triangle(double depth) => _hoist(0, 0.2, depth, 0.6);

/// Nordic cross: no emblem, but keep the crossing in view.
const FlagFocus _nordic = FlagFocus(FlagFocusKind.hoist, 0.37, 0.5);

/// Blue/red ensign: Union Jack canton (half width, half height).
final FlagFocus _ensign = _canton(0.5, 0.5);

// Hand-set values. Approximate by design: they steer crops and QA, they are
// not artwork. Boxes are generous rather than tight.
final Map<String, FlagFocus> _table = {
  // Cantons.
  'us': _canton(0.4, 0.54),
  'um': _canton(0.4, 0.54),
  'as': _triangle(0.55),
  'gr': _canton(0.37, 0.56),
  'my': _canton(0.5, 0.57),
  'lr': _canton(0.26, 0.46),
  'uy': _canton(0.38, 0.56),
  'tw': _canton(0.5, 0.5),
  'cl': _canton(0.33, 0.5),
  'tg': _canton(0.38, 0.6),
  'cn': _canton(0.4, 0.5),
  'sg': _canton(0.42, 0.5),
  'ws': _canton(0.5, 0.5),
  'to': _canton(0.42, 0.5),
  'mm': _emblem(0.3, 0.15, 0.4, 0.7),
  'bm': _ensign,
  'ky': _ensign,
  'vg': _ensign,
  'ai': _ensign,
  'ms': _ensign,
  'tc': _ensign,
  'fk': _ensign,
  'gs': _ensign,
  'io': _ensign,
  'pn': _ensign,
  'sh': _ensign,
  'ck': _ensign,
  'nu': _canton(0.5, 0.5),
  'tv': _ensign,
  'fj': _ensign,
  'au': _ensign,
  'nz': _ensign,
  'hm': _ensign,
  'na': _canton(0.4, 0.5),
  'mt': _canton(0.2, 0.3),
  'si': _canton(0.36, 0.5),
  // Hoist triangles, chevrons and bands.
  'cu': _triangle(0.43),
  'pr': _triangle(0.43),
  'bs': _triangle(0.36),
  'cz': _triangle(0.5),
  'jo': _triangle(0.5),
  'ps': _triangle(0.5),
  'sd': _triangle(0.36),
  'ss': _triangle(0.4),
  'km': _triangle(0.45),
  'ph': _triangle(0.45),
  'er': _triangle(0.6),
  'mz': _triangle(0.45),
  'tl': _triangle(0.45),
  'gq': _emblem(0.4, 0.3, 0.2, 0.4),
  'st': _triangle(0.3),
  'gy': _triangle(0.55),
  'zw': _triangle(0.4),
  'vu': _triangle(0.5),
  'bh': _hoist(0, 0, 0.3, 1),
  'qa': _hoist(0, 0, 0.35, 1),
  'ae': _hoist(0, 0, 0.25, 1),
  'by': _hoist(0, 0, 0.12, 1),
  'mg': _hoist(0, 0, 0.33, 1),
  'bj': _hoist(0, 0, 0.4, 1),
  'gw': _hoist(0, 0, 0.33, 1),
  'om': _hoist(0, 0, 0.27, 0.45),
  'pt': _hoist(0.24, 0.22, 0.32, 0.56),
  'es': _hoist(0.16, 0.24, 0.24, 0.52),
  'mn': _hoist(0.08, 0.12, 0.2, 0.76),
  'tr': _hoist(0.22, 0.2, 0.38, 0.6),
  'dz': _emblem(0.3, 0.18, 0.4, 0.64),
  'kz': _emblem(0.12, 0.1, 0.6, 0.7),
  'tm': _hoist(0.08, 0, 0.34, 1),
  'sk': _hoist(0.14, 0.18, 0.3, 0.64),
  'rs': _hoist(0.2, 0.15, 0.3, 0.7),
  'me': _emblem(0.3, 0.15, 0.4, 0.7),
  'bd': _emblem(0.25, 0.2, 0.4, 0.6),
  'pw': _emblem(0.25, 0.2, 0.4, 0.6),
  've': _emblem(0.25, 0.3, 0.5, 0.35),
  'ml': FlagFocus.plain,
  // Central emblems, discs and symbols.
  'mx': _emblem(0.38, 0.24, 0.24, 0.52),
  'cr': _emblem(0.28, 0.32, 0.18, 0.36),
  'py': _emblem(0.4, 0.33, 0.2, 0.34),
  'br': _emblem(0.25, 0.12, 0.5, 0.76),
  'ca': _emblem(0.3, 0.1, 0.4, 0.8),
  'in': _emblem(0.42, 0.35, 0.16, 0.3),
  'ar': _emblem(0.42, 0.35, 0.16, 0.3),
  'jp': _emblem(0.3, 0.2, 0.4, 0.6),
  'kr': _emblem(0.15, 0.1, 0.7, 0.8),
  'la': _emblem(0.35, 0.3, 0.3, 0.4),
  'ne': _emblem(0.42, 0.36, 0.16, 0.28),
  'ch': _emblem(0.27, 0.19, 0.47, 0.62),
  'ge': _emblem(0.25, 0.15, 0.5, 0.7),
  'il': _emblem(0.33, 0.25, 0.34, 0.5),
  'lb': _emblem(0.3, 0.25, 0.4, 0.5),
  'cy': _emblem(0.2, 0.2, 0.6, 0.6),
  'xk': _emblem(0.25, 0.15, 0.5, 0.7),
  'sa': _emblem(0.15, 0.15, 0.7, 0.7),
  'af': _emblem(0.36, 0.2, 0.28, 0.6),
  'tn': _emblem(0.3, 0.2, 0.4, 0.6),
  'vn': _emblem(0.32, 0.2, 0.36, 0.6),
  'ma': _emblem(0.35, 0.25, 0.3, 0.5),
  'eg': _emblem(0.4, 0.33, 0.2, 0.34),
  'ir': _emblem(0.4, 0.3, 0.2, 0.4),
  'iq': _emblem(0.25, 0.35, 0.5, 0.3),
  'sy': _emblem(0.2, 0.35, 0.6, 0.3),
  'ye': FlagFocus.plain,
  'hr': _emblem(0.38, 0.2, 0.24, 0.5),
  'ad': _emblem(0.38, 0.25, 0.24, 0.5),
  'ec': _emblem(0.35, 0.2, 0.3, 0.6),
  'bo': _emblem(0.38, 0.28, 0.24, 0.44),
  'gt': _emblem(0.38, 0.25, 0.24, 0.5),
  'hn': _emblem(0.3, 0.33, 0.4, 0.34),
  'sv': _emblem(0.38, 0.3, 0.24, 0.4),
  'ni': _emblem(0.38, 0.3, 0.24, 0.4),
  'do': _emblem(0.4, 0.3, 0.2, 0.4),
  'ht': _emblem(0.38, 0.3, 0.24, 0.4),
  'bz': _emblem(0.25, 0.15, 0.5, 0.7),
  'pe': _emblem(0.4, 0.25, 0.2, 0.5),
  'sr': _emblem(0.38, 0.25, 0.24, 0.5),
  'pa': _hoist(0.12, 0.1, 0.26, 0.32),
  'ke': _emblem(0.35, 0.15, 0.3, 0.7),
  'ug': _emblem(0.38, 0.25, 0.24, 0.5),
  'et': _emblem(0.3, 0.2, 0.4, 0.6),
  'gh': _emblem(0.4, 0.33, 0.2, 0.34),
  'sn': _emblem(0.4, 0.33, 0.2, 0.34),
  'cm': _emblem(0.4, 0.33, 0.2, 0.34),
  'ls': _emblem(0.38, 0.3, 0.24, 0.4),
  'sz': _emblem(0.2, 0.25, 0.6, 0.5),
  'mw': _emblem(0.3, 0, 0.4, 0.35),
  'ao': _emblem(0.3, 0.2, 0.4, 0.6),
  'kh': _emblem(0.3, 0.28, 0.4, 0.44),
  'bt': _emblem(0.32, 0.25, 0.36, 0.5),
  'np': _hoist(0, 0, 0.6, 1),
  'lk': _fly(0.38, 0.08, 0.58, 0.84),
  'pk': _fly(0.4, 0.15, 0.5, 0.7),
  'rw': _fly(0.7, 0.05, 0.25, 0.4),
  'uz': _hoist(0.05, 0.05, 0.4, 0.3),
  'az': _emblem(0.35, 0.36, 0.3, 0.28),
  'kg': _emblem(0.3, 0.2, 0.4, 0.6),
  'tj': _emblem(0.38, 0.3, 0.24, 0.4),
  'eu': _emblem(0.25, 0.12, 0.5, 0.76),
  'un': _emblem(0.25, 0.15, 0.5, 0.7),
  'gb-wls': _emblem(0.12, 0.1, 0.76, 0.8),
  'ki': _emblem(0.3, 0.08, 0.4, 0.5),
  'pg': _fly(0.55, 0.05, 0.4, 0.45),
  'sb': _canton(0.4, 0.5),
  'mh': _canton(0.4, 0.6),
  'fm': _emblem(0.3, 0.2, 0.4, 0.6),
  'nr': _canton(0.4, 0.8),
  'cv': _hoist(0.15, 0.3, 0.4, 0.5),
  'mu': FlagFocus.plain,
  'jm': FlagFocus.plain,
  'ag': _emblem(0.25, 0, 0.5, 0.6),
  'bb': _emblem(0.38, 0.25, 0.24, 0.5),
  'dm': _emblem(0.35, 0.25, 0.3, 0.5),
  'gd': _emblem(0.1, 0.1, 0.8, 0.8),
  'kn': _emblem(0.2, 0.2, 0.6, 0.6),
  'lc': _emblem(0.3, 0.15, 0.4, 0.7),
  'vc': _emblem(0.35, 0.2, 0.3, 0.6),
  'tt': _emblem(0.3, 0.1, 0.4, 0.8),
  'cd': _canton(0.35, 0.5),
  'cg': _emblem(0.3, 0.1, 0.4, 0.8),
  'tz': _emblem(0.3, 0.1, 0.4, 0.8),
  'zm': _fly(0.7, 0.05, 0.28, 0.95),
  'bf': _emblem(0.4, 0.33, 0.2, 0.34),
  'gn': FlagFocus.plain,
  'so': _emblem(0.35, 0.25, 0.3, 0.5),
  'dj': _triangle(0.45),
  'ly': _emblem(0.35, 0.3, 0.3, 0.4),
  'mr': _emblem(0.3, 0.2, 0.4, 0.6),
  'cf': _canton(0.3, 0.3),
  'td': FlagFocus.plain,
  'bi': _emblem(0.3, 0.2, 0.4, 0.6),
  'sc': _hoist(0, 0.5, 0.5, 0.5),
  'mk': _emblem(0.3, 0.2, 0.4, 0.6),
  'al': _emblem(0.2, 0.1, 0.6, 0.8),
  'ba': _emblem(0.2, 0, 0.6, 1),
  'md': _emblem(0.38, 0.25, 0.24, 0.5),
  'li': _canton(0.35, 0.5),
  'sm': _emblem(0.38, 0.25, 0.24, 0.5),
  'va': _fly(0.55, 0.2, 0.4, 0.6),
  'mc': FlagFocus.plain,
  'id': FlagFocus.plain,
  'dk': _nordic,
  'se': _nordic,
  'no': _nordic,
  'fi': _nordic,
  'is': _nordic,
  'fo': _nordic,
  'ax': _nordic,
  'gb-sct': FlagFocus.plain,
  'gb-eng': FlagFocus.plain,
  'gb-nir': _emblem(0.3, 0.2, 0.4, 0.6),
  'gl': _hoist(0.1, 0.15, 0.45, 0.7),
  'aq': _emblem(0.2, 0.15, 0.6, 0.7),
};
