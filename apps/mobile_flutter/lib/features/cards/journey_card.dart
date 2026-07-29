import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import 'card_text_renderer.dart';
import 'flag_tile_renderer.dart';

/// Visual style for the "Journeys" card type ([CardTemplateType.journeys]).
enum JourneyStyle {
  /// Flags of the visited countries as stops on the route, in selection order.
  flags,

  /// Dated trips as stops on the route, in chronological order — each stop is
  /// labelled with its country name and year. Filterable by [JourneyCard.yearRange].
  trips,
}

/// A single stop on the journey route.
class _Stop {
  const _Stop({required this.code, required this.label, this.sub});

  /// ISO 3166-1 alpha-2 country code (lowercase) — flag cache key.
  final String code;

  /// Primary label under the stop (country name).
  final String label;

  /// Optional secondary label (e.g. the trip year) — only in the trips style.
  final String? sub;
}

/// **Journeys** design type: countries (or dated trips) placed as flag "stops"
/// along a subtle dotted winding travel route. Deliberately its own type — not
/// a flag-grid layout — with two [JourneyStyle]s.
class JourneyCard extends StatefulWidget {
  const JourneyCard({
    super.key,
    required this.countryCodes,
    this.trips = const [],
    this.style = JourneyStyle.flags,
    this.yearRange,
    this.aspectRatio = 1.5,
    this.title,
    this.subtitleOverride,
    this.dateLabel,
    this.textColor,
    this.transparentBackground = false,
    this.onAssetsLoaded,
  });

  /// Visited-country codes (uppercase ISO2) — used by [JourneyStyle.flags].
  final List<String> countryCodes;

  /// Dated trips — used (and required) by [JourneyStyle.trips].
  final List<TripRecord> trips;

  final JourneyStyle style;

  /// Inclusive `(minYear, maxYear)` filter applied to trips. Null → all years.
  final (int, int)? yearRange;

  final double aspectRatio;
  final String? title;
  final String? subtitleOverride;
  final String? dateLabel;
  final Color? textColor;
  final bool transparentBackground;
  final VoidCallback? onAssetsLoaded;

  /// The distinct trip years present in [trips], ascending. Handy for driving a
  /// year-range slider in the configurator.
  static List<int> tripYears(List<TripRecord> trips) {
    final years = {for (final t in trips) t.startedOn.year}.toList()..sort();
    return years;
  }

  @override
  State<JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<JourneyCard> {
  // Flag width the painter renders at (and the cache key). Fixed so preload and
  // paint agree; cover-fit into small discs so this is plenty of resolution.
  static const double _flagWidth = 128.0;
  // Cap on stops so the route stays legible on a shirt.
  static const int _maxStops = 30;

  final FlagImageCache _cache = FlagImageCache(maxEntries: 120);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  bool _preloadStarted = false;
  bool _onAssetsLoadedFired = false;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  @override
  void didUpdateWidget(JourneyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCodes != widget.countryCodes ||
        oldWidget.trips != widget.trips ||
        oldWidget.style != widget.style ||
        oldWidget.yearRange != widget.yearRange) {
      _preloadStarted = false;
      _onAssetsLoadedFired = false;
      _preload();
    }
  }

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  List<_Stop> _stops() {
    if (widget.style == JourneyStyle.trips) {
      final range = widget.yearRange;
      final sorted = [...widget.trips]
        ..sort((a, b) => a.startedOn.compareTo(b.startedOn));
      final filtered = range == null
          ? sorted
          : sorted
              .where((t) =>
                  t.startedOn.year >= range.$1 && t.startedOn.year <= range.$2)
              .toList();
      final capped = filtered.take(_maxStops);
      return [
        for (final t in capped)
          _Stop(
            code: t.countryCode.toLowerCase(),
            label: kCountryNames[t.countryCode.toUpperCase()] ??
                t.countryCode.toUpperCase(),
            sub: '${t.startedOn.year}',
          ),
      ];
    }
    return [
      for (final c in widget.countryCodes.take(_maxStops))
        _Stop(
          code: c.toLowerCase(),
          label: kCountryNames[c.toUpperCase()] ?? c.toUpperCase(),
        ),
    ];
  }

  void _preload() {
    if (_preloadStarted) return;
    _preloadStarted = true;
    final codes = {for (final s in _stops()) s.code};
    final pending = codes
        .where((c) =>
            FlagTileRenderer.hasSvg(c) && _cache.get(c, _flagWidth) == null)
        .toList();
    if (pending.isEmpty) {
      _fireLoaded();
      return;
    }
    var remaining = pending.length;
    for (final code in pending) {
      FlagTileRenderer.loadSvgToCache(code, _flagWidth, _cache).then((_) {
        if (!mounted) return;
        _repaint.value++;
        if (--remaining == 0) _fireLoaded();
      });
    }
  }

  void _fireLoaded() {
    if (_onAssetsLoadedFired) return;
    _onAssetsLoadedFired = true;
    widget.onAssetsLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _JourneyPainter(
            stops: _stops(),
            countryCount: widget.style == JourneyStyle.trips
                ? {for (final s in _stops()) s.code}.length
                : widget.countryCodes.length,
            title: widget.title ?? 'MY JOURNEY',
            subtitleOverride: widget.subtitleOverride,
            dateLabel: widget.dateLabel,
            textColor: widget.textColor,
            transparentBackground: widget.transparentBackground,
            cache: _cache,
            flagWidth: _flagWidth,
            repaint: _repaint,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _JourneyPainter extends CustomPainter {
  _JourneyPainter({
    required this.stops,
    required this.countryCount,
    required this.title,
    required this.subtitleOverride,
    required this.dateLabel,
    required this.textColor,
    required this.transparentBackground,
    required this.cache,
    required this.flagWidth,
    required this.repaint,
  }) : super(repaint: repaint);

  final List<_Stop> stops;
  final int countryCount;
  final String title;
  final String? subtitleOverride;
  final String? dateLabel;
  final Color? textColor;
  final bool transparentBackground;
  final FlagImageCache cache;
  final double flagWidth;
  final ValueNotifier<int> repaint;

  static const double _topH = CardTextRenderer.titleZoneH;
  static const double _botH = CardTextRenderer.brandingZoneH;
  static final Paint _placeholder = Paint()..color = const Color(0x22FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final stripColor = transparentBackground
        ? Colors.transparent
        : CardTextRenderer.defaultStripColor;
    final ink = textColor ??
        (transparentBackground
            ? Colors.white
            : CardTextRenderer.defaultTextColor);

    CardTextRenderer.drawTitle(canvas, size, title,
        textColor: ink, stripColor: stripColor);
    CardTextRenderer.drawBranding(
      canvas,
      size,
      countryCount: countryCount,
      dateLabel: dateLabel ?? '',
      subtitleLine: subtitleOverride,
      textColor: ink,
      stripColor: stripColor,
    );

    final n = stops.length;
    if (n == 0) return;

    const pad = 12.0;
    final zoneLeft = pad;
    final zoneTop = _topH + pad;
    final zoneW = size.width - pad * 2;
    final zoneH = size.height - _topH - _botH - pad * 2;
    if (zoneW <= 0 || zoneH <= 0) return;

    final hasSub = stops.any((s) => s.sub != null);

    // Serpentine node grid: cols chosen for roughly square cells; rows fill
    // downward. Even rows run left→right, odd rows right→left so the connecting
    // route is one continuous winding line.
    final cols = math.max(1, math.min(n, math.sqrt(n * zoneW / zoneH).round()));
    final rows = (n / cols).ceil();
    final cellW = zoneW / cols;
    final cellH = zoneH / rows;

    // Reserve room for the label(s) beneath each flag node.
    final labelH =
        (cellH * (hasSub ? 0.34 : 0.24)).clamp(hasSub ? 14.0 : 8.0, 34.0);
    final radius =
        (math.min(cellW, cellH - labelH) * 0.5 * 0.74).clamp(6.0, 90.0);
    final ring = math.max(1.4, radius * 0.10);

    final centers = <Offset>[];
    for (var i = 0; i < n; i++) {
      final r = i ~/ cols;
      var c = i % cols;
      if (r.isOdd) c = cols - 1 - c; // serpentine
      final cx = zoneLeft + (c + 0.5) * cellW;
      final cy = zoneTop + r * cellH + (cellH - labelH) * 0.5;
      centers.add(Offset(cx, cy));
    }

    // 1. Dotted winding route + origin/destination pins.
    if (n >= 2) {
      final route = _smoothPathThrough(centers);
      final routePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.09)
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: 0.55);
      final dash = math.max(3.0, radius * 0.14);
      _drawDashedPath(canvas, route, routePaint, dash: dash, gap: dash * 0.9);

      final pinR = math.max(3.0, radius * 0.28);
      final pinPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.08)
        ..color = ink.withValues(alpha: 0.7);
      final startDir = _dir(centers[1], centers[0]);
      final endDir = _dir(centers[n - 2], centers[n - 1]);
      canvas.drawCircle(
          centers.first + startDir * (radius + ring + pinR + 3), pinR, pinPaint);
      canvas.drawCircle(
          centers.last + endDir * (radius + ring + pinR + 3), pinR, pinPaint);
    }

    // 2. Flag stops + labels, in route order.
    for (var i = 0; i < n; i++) {
      final center = centers[i];
      final stop = stops[i];
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawCircle(
        center,
        radius + ring,
        Paint()
          ..color = (transparentBackground ? Colors.white : ink)
              .withValues(alpha: 0.12),
      );

      final image = cache.get(stop.code, flagWidth);
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      if (image != null) {
        _drawFlagCover(canvas, image, rect);
      } else {
        canvas.drawCircle(center, radius, _placeholder);
      }
      canvas.restore();

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..color = ink.withValues(alpha: 0.85),
      );

      var labelY = center.dy + radius + ring + labelH * 0.10;
      labelY = _drawLabel(
        canvas,
        stop.label,
        center.dx,
        labelY,
        cellW * 0.96,
        (radius * 0.40).clamp(7.0, 15.0),
        FontWeight.w600,
        ink,
      );
      if (stop.sub != null) {
        _drawLabel(
          canvas,
          stop.sub!,
          center.dx,
          labelY,
          cellW * 0.96,
          (radius * 0.34).clamp(6.0, 13.0),
          FontWeight.w400,
          ink.withValues(alpha: 0.75),
        );
      }
    }
  }

  /// Draws a centred single-line label at (cx, top); returns the y below it.
  double _drawLabel(Canvas canvas, String text, double cx, double top,
      double maxW, double fontSize, FontWeight weight, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 0.2,
          decoration: TextDecoration.none,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    tp.paint(canvas, Offset(cx - tp.width / 2, top));
    return top + tp.height;
  }

  void _drawFlagCover(Canvas canvas, ui.Image image, Rect bounds) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return;
    final s = math.max(bounds.width / iw, bounds.height / ih);
    final w = iw * s, h = ih * s;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH(bounds.center.dx - w / 2, bounds.center.dy - h / 2, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static Offset _dir(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    return len == 0 ? const Offset(1, 0) : d / len;
  }

  /// Smooth Catmull-Rom spline through [pts] as a cubic Bézier path.
  static Path _smoothPathThrough(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) return path;
    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
      final c1 =
          Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 =
          Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  static void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_JourneyPainter old) =>
      old.stops != stops ||
      old.countryCount != countryCount ||
      old.title != title ||
      old.subtitleOverride != subtitleOverride ||
      old.dateLabel != dateLabel ||
      old.textColor != textColor ||
      old.transparentBackground != transparentBackground ||
      old.flagWidth != flagWidth;
}
