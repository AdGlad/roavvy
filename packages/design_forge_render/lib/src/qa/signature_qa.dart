import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Automatic quality checks for a Signature Recipe render (ADR-181 §4).
///
/// Runs on the transparent ARTWORK layer (what is printed), never on a
/// composite with a garment behind it. Pure over RGBA bytes so it is fast,
/// isolate-friendly and unit-testable on synthetic images; [checkImage] is the
/// convenience wrapper for a rendered [ui.Image].
///
/// **Hard** findings block approval in the Lab. **Soft** findings are shown
/// to the owner, who accepts or fixes them.
class SignatureQa {
  const SignatureQa._();

  static Future<QaReport> checkImage(
    ui.Image image, {
    QaThresholds thresholds = QaThresholds.standard,
    bool allowBleed = false,
  }) async {
    // Straight (un-premultiplied) colour: a half-transparent edge pixel must
    // be judged by its real colour, not one darkened by its own alpha.
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    return analyse(data!.buffer.asUint8List(), image.width, image.height,
        thresholds: thresholds, allowBleed: allowBleed);
  }

  /// A report for a render that threw instead of producing an image.
  static QaReport renderFailed(Object error) => QaReport(
        hard: [QaFinding('render_error', 'Render failed: $error')],
        soft: const [],
        metrics: const {},
      );

  /// [rgba] is STRAIGHT (un-premultiplied) RGBA.
  static QaReport analyse(
    Uint8List rgba,
    int width,
    int height, {
    QaThresholds thresholds = QaThresholds.standard,
    bool allowBleed = false,
  }) {
    final t = thresholds;
    final n = width * height;
    final ink = Uint8List(n); // 1 where alpha > inkAlpha
    var inkCount = 0;
    var alphaSum = 0.0;
    final lowContrast = List<double>.filled(t.garments.length, 0);
    final garmentLum = [for (final g in t.garments) _lum(g.$1)];
    final garmentRgb = [
      for (final g in t.garments)
        [(g.$1.r * 255).round(), (g.$1.g * 255).round(), (g.$1.b * 255).round()],
    ];
    final maxDist2 = t.minColourDistance * t.minColourDistance;

    for (var i = 0; i < n; i++) {
      final a = rgba[i * 4 + 3];
      if (a <= t.inkAlpha) continue;
      ink[i] = 1;
      inkCount++;
      final w = a / 255.0;
      alphaSum += w;
      final r = rgba[i * 4], gr = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
      final l = _lumRgb(r, gr, b);
      for (var g = 0; g < garmentLum.length; g++) {
        // Vanishes only when close in BOTH brightness and colour: green on a
        // red shirt has similar luminance but is plainly visible.
        if (_ratio(l, garmentLum[g]) >= t.minContrastRatio) continue;
        final dr = r - garmentRgb[g][0],
            dg = gr - garmentRgb[g][1],
            db = b - garmentRgb[g][2];
        if (dr * dr + dg * dg + db * db < maxDist2) lowContrast[g] += w;
      }
    }

    // The design's OUTER edge: ink pixels touching empty space that connects
    // to the canvas border. Holes inside the artwork (distress) don't count —
    // what matters on a shirt is whether the shape reads, not whether every
    // colour inside it does.
    final exterior = Uint8List(n);
    final stack = <int>[];
    void reach(int i) {
      if (ink[i] == 0 && exterior[i] == 0) {
        exterior[i] = 1;
        stack.add(i);
      }
    }

    for (var x = 0; x < width; x++) {
      reach(x);
      reach((height - 1) * width + x);
    }
    for (var y = 0; y < height; y++) {
      reach(y * width);
      reach(y * width + width - 1);
    }
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % width;
      if (x > 0) reach(i - 1);
      if (x < width - 1) reach(i + 1);
      if (i >= width) reach(i - width);
      if (i < n - width) reach(i + width);
    }
    var edgeCount = 0;
    final edgeVanish = List<int>.filled(t.garments.length, 0);
    for (var i = 0; i < n; i++) {
      if (ink[i] == 0) continue;
      final x = i % width;
      final onEdge = (x > 0 && exterior[i - 1] == 1) ||
          (x < width - 1 && exterior[i + 1] == 1) ||
          (i >= width && exterior[i - width] == 1) ||
          (i < n - width && exterior[i + width] == 1);
      if (!onEdge) continue;
      edgeCount++;
      final r = rgba[i * 4], gr = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
      final l = _lumRgb(r, gr, b);
      for (var g = 0; g < garmentLum.length; g++) {
        if (_ratio(l, garmentLum[g]) >= t.minContrastRatio) continue;
        final dr = r - garmentRgb[g][0],
            dg = gr - garmentRgb[g][1],
            db = b - garmentRgb[g][2];
        if (dr * dr + dg * dg + db * db < maxDist2) edgeVanish[g]++;
      }
    }

    final hard = <QaFinding>[];
    final soft = <QaFinding>[];
    final coverage = inkCount / n;

    // Empty = no design: almost no ink, or ink that spans only a sliver of the
    // print area. Measured by FOOTPRINT (bounding box), not ink area, so
    // line-art (a thin-outlined passport stamp) is not mistaken for empty.
    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var i = 0; i < n; i++) {
      if (ink[i] == 0) continue;
      final x = i % width, y = i ~/ width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final footprint =
        maxX < 0 ? 0.0 : (maxX - minX + 1) * (maxY - minY + 1) / n;
    if (coverage < t.minCoverage || footprint < t.minFootprint) {
      hard.add(QaFinding('empty',
          'Artwork spans ${_pct(footprint)} of the print area with ${_pct(coverage)} ink '
          '(min ${_pct(t.minFootprint)} span, ${_pct(t.minCoverage)} ink)'));
    } else if (coverage > t.maxCoverage) {
      hard.add(QaFinding('flooded',
          'Artwork covers ${_pct(coverage)} of the print area (max ${_pct(t.maxCoverage)})'));
    }

    // Ink touching the print-area edge means the design is cut off.
    final ring = math.max(2, (math.min(width, height) * t.edgeRingFraction).round());
    var ringPx = 0, ringInk = 0;
    for (var y = 0; y < height; y++) {
      final inYBand = y < ring || y >= height - ring;
      for (var x = 0; x < width; x++) {
        if (!inYBand && x >= ring && x < width - ring) continue;
        ringPx++;
        ringInk += ink[y * width + x];
      }
    }
    final edgeShare = ringPx == 0 ? 0.0 : ringInk / ringPx;
    if (!allowBleed && edgeShare > t.maxEdgeShare) {
      hard.add(QaFinding('clipped',
          'Artwork runs into the edge of the print area (${_pct(edgeShare)} of the border)'));
    }

    // Isolated specks: ink pixels with at most one inked neighbour. They print
    // as dust and drop out of DTG prints.
    var specks = 0;
    if (inkCount > 0) {
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          final i = y * width + x;
          if (ink[i] == 0) continue;
          final nb = ink[i - 1] + ink[i + 1] + ink[i - width] + ink[i + width] +
              ink[i - width - 1] + ink[i - width + 1] +
              ink[i + width - 1] + ink[i + width + 1];
          if (nb <= 1) specks++;
        }
      }
    }
    final speckShare = inkCount == 0 ? 0.0 : specks / inkCount;
    if (speckShare > t.maxSpeckShare) {
      soft.add(QaFinding('specks',
          '${_pct(speckShare)} of the ink is isolated specks that may not print'));
    }

    final contrast = <String, double>{};
    final edge = <String, double>{};
    for (var g = 0; g < t.garments.length; g++) {
      final name = t.garments[g].$2;
      contrast[name] = alphaSum == 0 ? 0.0 : lowContrast[g] / alphaSum;
      final share = edgeCount == 0 ? 0.0 : edgeVanish[g] / edgeCount;
      edge[name] = share;
      if (share > t.maxEdgeVanishShare) {
        soft.add(QaFinding('contrast:$name',
            '${_pct(share)} of the design\'s outline disappears on $name'));
      }
    }

    return QaReport(
      hard: hard,
      soft: soft,
      metrics: {
        'coverage': _round(coverage),
        'footprint': _round(footprint),
        'edgeShare': _round(edgeShare),
        'speckShare': _round(speckShare),
        // Share of the outer edge that vanishes per garment (drives warnings).
        'edgeVanish': {
          for (final e in edge.entries) e.key: _round(e.value),
        },
        // Share of all ink that vanishes per garment (information only).
        'lowContrast': {
          for (final e in contrast.entries) e.key: _round(e.value),
        },
      },
    );
  }

  static double _lum(ui.Color c) => _lumRgb(
      (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

  static double _lumRgb(int r, int g, int b) =>
      0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);

  static final List<double> _linTable = [
    for (var v = 0; v < 256; v++)
      v / 255 <= 0.04045
          ? v / 255 / 12.92
          : math.pow((v / 255 + 0.055) / 1.055, 2.4).toDouble(),
  ];

  static double _lin(int v) => _linTable[v];

  static double _ratio(double a, double b) =>
      (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  static double _round(double v) => (v * 10000).roundToDouble() / 10000;
}

/// One QA result line. [code] is stable (for filtering and reports).
class QaFinding {
  const QaFinding(this.code, this.message);

  final String code;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'message': message};

  @override
  String toString() => '$code: $message';
}

enum QaStatus { pass, warn, fail }

class QaReport {
  const QaReport({required this.hard, required this.soft, required this.metrics});

  final List<QaFinding> hard;
  final List<QaFinding> soft;
  final Map<String, Object?> metrics;

  /// One report from several partial ones (e.g. one per garment group, when
  /// the artwork differs by garment): findings combined, metrics merged.
  factory QaReport.merge(List<QaReport> parts) {
    final hard = <QaFinding>[], soft = <QaFinding>[];
    final metrics = <String, Object?>{};
    final seen = <String>{};
    for (final p in parts) {
      for (final f in p.hard) {
        if (seen.add('h:${f.code}')) hard.add(f);
      }
      for (final f in p.soft) {
        if (seen.add('s:${f.code}')) soft.add(f);
      }
      for (final e in p.metrics.entries) {
        final v = e.value;
        if (v is Map && metrics[e.key] is Map) {
          metrics[e.key] = {...(metrics[e.key] as Map), ...v};
        } else {
          metrics.putIfAbsent(e.key, () => v);
        }
      }
    }
    return QaReport(hard: hard, soft: soft, metrics: metrics);
  }

  QaStatus get status => hard.isNotEmpty
      ? QaStatus.fail
      : soft.isNotEmpty
          ? QaStatus.warn
          : QaStatus.pass;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'hard': [for (final f in hard) f.toJson()],
        'soft': [for (final f in soft) f.toJson()],
        'metrics': metrics,
      };
}

/// Every QA threshold in one place, so they are tuned once (ADR-181 §4).
class QaThresholds {
  const QaThresholds({
    this.inkAlpha = 32,
    this.minCoverage = 0.01,
    this.minFootprint = 0.15,
    this.maxCoverage = 0.92,
    this.edgeRingFraction = 0.01,
    this.maxEdgeShare = 0.005,
    this.maxSpeckShare = 0.02,
    this.minContrastRatio = 1.5,
    this.minColourDistance = 110,
    this.maxEdgeVanishShare = 0.25,
    this.garments = orderableGarments,
  });

  /// The same thresholds, checking only [subset] of the garments.
  QaThresholds only(List<(ui.Color, String)> subset) => QaThresholds(
        inkAlpha: inkAlpha,
        minCoverage: minCoverage,
        minFootprint: minFootprint,
        maxCoverage: maxCoverage,
        edgeRingFraction: edgeRingFraction,
        maxEdgeShare: maxEdgeShare,
        maxSpeckShare: maxSpeckShare,
        minContrastRatio: minContrastRatio,
        minColourDistance: minColourDistance,
        maxEdgeVanishShare: maxEdgeVanishShare,
        garments: subset,
      );

  static const QaThresholds standard = QaThresholds();

  /// The garment colours a customer can actually order (the Studio palette
  /// minus Royal and Orange, which the supplier does not stock).
  static const List<(ui.Color, String)> orderableGarments = [
    (ui.Color(0xFF0E0E0E), 'Black'),
    (ui.Color(0xFF0F1830), 'Navy'),
    (ui.Color(0xFF424848), 'Dark Heather'),
    (ui.Color(0xFFFF1B2B), 'Red'),
    (ui.Color(0xFFD1D2D6), 'Sport Grey'),
    (ui.Color(0xFFFFFFFF), 'White'),
  ];

  /// Alpha above which a pixel counts as ink.
  final int inkAlpha;

  /// Ink area as a share of the print area: below [minCoverage] = empty,
  /// above [maxCoverage] = flooded.
  final double minCoverage;

  /// Bounding-box area of the ink as a share of the print area; below = empty
  /// (a design too small to be a T-shirt print).
  final double minFootprint;
  final double maxCoverage;

  /// Width of the border ring, as a share of the short side.
  final double edgeRingFraction;

  /// Max share of the border ring that may be inked before "clipped".
  final double maxEdgeShare;

  /// Max share of ink that may be isolated specks.
  final double maxSpeckShare;

  /// Ink vanishes on a garment when its luminance contrast ratio is below
  /// [minContrastRatio] AND its RGB distance (0–441) is below
  /// [minColourDistance].
  final double minContrastRatio;
  final double minColourDistance;

  /// Max share of the design's OUTER EDGE that may vanish on any one garment
  /// before it warns (the shape stops reading against the shirt).
  final double maxEdgeVanishShare;

  final List<(ui.Color, String)> garments;
}
