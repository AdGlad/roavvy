import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_text_renderer.dart';
import 'timeline_layout_engine.dart';

// ── Colour palette (ink / amber) ──────────────────────────────────────────────
//
// The card is rendered in two contexts:
//   • Poster mode  (transparentBackground == false): classic dark-ink-on-
//     parchment "tour poster" look.
//   • Shirt mode   (transparentBackground == true): the design is composited
//     onto a garment whose colour we don't know directly. `textColor` is the
//     plumbed hint from CardImageRenderer (merchDefaultTextColor → white for a
//     dark shirt; the colour picker supplies black for a light shirt).
// `_resolvePalette()` derives ink / muted / accent / fill from those two inputs
// so Tour Dates stays legible on black, white and coloured shirts.

const _kInk = Color(0xFF2C1810); // poster: dark brown ink
const _kInkMuted = Color(0xFF6B5240); // poster: muted brown (dates)
const _kAmber = Color(0xFFD4A017); // gold accent (year labels / dividers)
const _kAmberDeep = Color(0xFFB8860B); // deeper gold, legible on light garments
const _kParchment = Color(0xFFF5F0E8); // poster: warm paper fill
const _kLightInk = Color(0xFFF7F2E9); // shirt: warm off-white ink

/// Graceful fallback glyph when a country code can't map to a flag emoji.
/// A globe renders in colour on any garment (unlike a white flag).
const _kFallbackFlag = '🌍';

/// Resolved, context-aware colour set for the timeline card.
///   ink   — country names
///   muted — dates / "more" note
///   accent— year labels + dividers
///   fill  — opaque background fill; null = transparent
typedef _Palette = ({Color ink, Color muted, Color accent, Color? fill});

/// Chooses ink / muted / accent / fill for a render context so "Tour Dates" is
/// legible on black, white and coloured shirts (M193). Pure — exposed for tests.
///
/// - Poster mode ([transparentBackground] == false): classic dark ink on
///   parchment, regardless of [textColor].
/// - Shirt mode ([transparentBackground] == true): derived from the [textColor]
///   hint. A light hint (or none → assume a dark garment) → light ink + bright
///   gold; a dark hint (light garment) → dark ink + a deeper gold accent.
@visibleForTesting
({Color ink, Color muted, Color accent, Color? fill}) resolveTimelinePalette({
  required bool transparentBackground,
  Color? textColor,
}) {
  if (!transparentBackground) {
    return (ink: _kInk, muted: _kInkMuted, accent: _kAmber, fill: _kParchment);
  }
  final hint = textColor;
  final onDarkGarment = hint == null || hint.computeLuminance() > 0.5;
  if (onDarkGarment) {
    final ink = hint ?? _kLightInk;
    return (
      ink: ink,
      muted: ink.withValues(alpha: 0.65),
      accent: _kAmber, // bright gold reads well on dark garments
      fill: null,
    );
  }
  // onDarkGarment is false here, so hint is guaranteed non-null.
  return (
    ink: hint,
    muted: hint.withValues(alpha: 0.65),
    accent: _kAmberDeep, // deeper gold for contrast on light garments
    fill: null,
  );
}

// ── Flag emoji helper ──────────────────────────────────────────────────────────

/// Maps an ISO 3166-1 alpha-2 code (e.g. "GB") to its flag emoji.
///
/// Hardened: normalises case/whitespace and validates that both characters are
/// A–Z before mapping to regional-indicator symbols. Lowercase or malformed
/// codes previously produced garbage glyphs; anything invalid now falls back to
/// [_kFallbackFlag] rather than silently returning an empty string.
String _flag(String code) {
  final c = code.trim().toUpperCase();
  if (c.length != 2) return _kFallbackFlag;
  final a = c.codeUnitAt(0);
  final b = c.codeUnitAt(1);
  const upperA = 65, upperZ = 90; // 'A'..'Z'
  if (a < upperA || a > upperZ || b < upperA || b > upperZ) {
    return _kFallbackFlag;
  }
  const base = 0x1F1E6; // regional indicator symbol 'A'
  return String.fromCharCode(base + a - upperA) +
      String.fromCharCode(base + b - upperA);
}

// ── TimelineCard ──────────────────────────────────────────────────────────────

/// Travel card template ("Tour Dates"): dated travel log rendered as a
/// canvas-drawn image, styled like a concert-tour poster.
///
/// Trips default to **latest→earliest** ordering (M193): like a real tour
/// poster the most recent / upcoming dates read best at the top. Uses
/// [CardTextRenderer] for the shared title/branding zones (M86). Supports up
/// to [TimelineLayoutEngine.kMaxEntries] = 25 trips with dynamic font scaling.
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.trips,
    required this.countryCodes,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
    this.titleOverride,
    this.subtitleOverride,
    this.newestFirst = true,
    this.transparentBackground = true,
    this.textColor,
  });

  final List<TripRecord> trips;
  final List<String> countryCodes;
  final double aspectRatio;
  final String dateLabel;

  /// Optional title override. When null or empty no title zone is drawn.
  final String? titleOverride;

  /// Structured branding line (ADR-157). When non-null, replaces legacy branding.
  final String? subtitleOverride;

  /// When true, orders entries most-recent first (latest → earliest).
  /// Default true (M193): a "tour" poster reads best latest-first — headline
  /// dates on top — matching how concert tour posters are laid out. Set false
  /// for a strictly chronological travel log.
  final bool newestFirst;

  /// When true, the card background is fully transparent (default true =
  /// transparent; set false to paint the parchment fill).
  final bool transparentBackground;

  /// Optional colour hint for the design, plumbed from CardImageRenderer.
  ///
  /// Used to adapt the whole palette (see [_resolvePalette]), not just the
  /// text: a light [textColor] (e.g. [Colors.white], for a dark shirt) yields
  /// light ink + bright gold accent; a dark [textColor] (e.g. [Colors.black],
  /// for a light shirt) yields dark ink + a deeper gold accent. When null and
  /// [transparentBackground] is true we assume a dark garment and use light
  /// ink; when null in poster mode we use the classic parchment palette.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final result = TimelineLayoutEngine.layout(
            trips: trips,
            countryCodes: countryCodes,
            canvasSize: size,
            newestFirst: newestFirst,
          );
          return CustomPaint(
            size: size,
            painter: _TimelinePainter(
              entries: result.entries,
              truncatedCount: result.truncatedCount,
              countryCodes: countryCodes,
              dateLabel: dateLabel,
              titleOverride: titleOverride,
              subtitleOverride: subtitleOverride,
              transparentBackground: transparentBackground,
              newestFirst: newestFirst,
              textColor: textColor,
            ),
          );
        },
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.entries,
    required this.truncatedCount,
    required this.countryCodes,
    required this.dateLabel,
    required this.titleOverride,
    this.subtitleOverride,
    required this.transparentBackground,
    required this.newestFirst,
    this.textColor,
  });

  final List<TimelineEntry> entries;
  final int truncatedCount;
  final List<String> countryCodes;
  final String dateLabel;
  final String? titleOverride;
  final String? subtitleOverride;
  final bool transparentBackground;
  final bool newestFirst;
  final Color? textColor;

  late final _Palette _palette = resolveTimelinePalette(
    transparentBackground: transparentBackground,
    textColor: textColor,
  );
  Color get _inkColor => _palette.ink;
  Color get _inkMutedColor => _palette.muted;
  Color get _accentColor => _palette.accent;
  Color get _fillColor => _palette.fill ?? _kParchment;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background.
    // When transparent, explicitly clear the entire canvas to alpha=0 using
    // BlendMode.clear. Without this, undrawn pixels retain the platform's
    // default clear colour (black or white) in RepaintBoundary.toImage()
    // captures, producing an opaque background in exported PNGs.
    if (transparentBackground) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = const Color(0x00000000)
          ..blendMode = BlendMode.clear,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _fillColor,
      );
    }

    // 2. Text zones.
    final hasTitle = titleOverride != null && titleOverride!.isNotEmpty;
    if (hasTitle) {
      CardTextRenderer.drawTitle(canvas, size, titleOverride!);
    }
    CardTextRenderer.drawBranding(
      canvas,
      size,
      countryCount: countryCodes.length,
      dateLabel: dateLabel,
      customLabel: titleOverride,
      subtitleLine: subtitleOverride,
    );

    // 3. Entry zone.
    const topH = CardTextRenderer.titleZoneH;
    const botH = CardTextRenderer.brandingZoneH;
    final zoneTop = hasTitle ? topH : 0.0;
    final zoneH = size.height - (hasTitle ? topH : 0.0) - botH;

    if (zoneH <= 0 || entries.isEmpty) return;
    _drawEntries(canvas, size.width, zoneTop, zoneH);
  }

  void _drawEntries(Canvas canvas, double width, double zoneTop, double zoneH) {
    const kPadH = 6.0; // vertical padding inside zone
    final available = zoneH - kPadH * 2;
    if (available <= 0) return;

    // Count unique year groups.
    final years = <int>{};
    for (final e in entries) {
      years.add(e.entryDate.year);
    }
    final divCount = years.length;

    // Compute divider + row heights dynamically so all entries fit.
    final (rowH, divH) = _computeHeights(entries.length, divCount, available);

    // Most recent trip shows only the entry month/year (no exit date).
    // newestFirst=true → entries[0] is most recent; false → entries.last.
    final mostRecentIdx = newestFirst ? 0 : entries.length - 1;

    // Build date strings upfront.
    final dateStrs = [
      for (var i = 0; i < entries.length; i++)
        // Passing same date for entry/exit causes formatTimelineDate to return "Mon YYYY".
        i == mostRecentIdx
            ? formatTimelineDate(entries[i].entryDate, entries[i].entryDate)
            : formatTimelineDate(entries[i].entryDate, entries[i].exitDate),
    ];

    // Single global font size that fits every entry without wrapping.
    const kPad = 10.0; // horizontal padding
    final fontSize = _computeFontSize(rowH, width, kPad, [
      for (final e in entries) e.countryName,
    ], dateStrs);
    final flagFontSize = (fontSize * 1.5).clamp(8.0, 28.0);

    double y = zoneTop + kPadH;
    int? lastYear;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final year = entry.entryDate.year;
      if (lastYear != year && divH > 0) {
        _drawYearDivider(canvas, width, y, divH, year, fontSize * 0.85, kPad);
        y += divH;
        lastYear = year;
      } else {
        lastYear = year;
      }
      _drawEntryRow(
        canvas,
        width,
        y,
        rowH,
        entry,
        dateStrs[i],
        fontSize,
        flagFontSize,
        kPad,
      );
      y += rowH;
    }

    if (truncatedCount > 0) {
      _drawMoreNote(canvas, width, y, truncatedCount, fontSize, kPad);
    }
  }

  /// Finds the largest font size ≥ 5.0 (step 0.5) where every entry's country
  /// name and date fit on one line without wrapping.
  double _computeFontSize(
    double rowH,
    double width,
    double hPad,
    List<String> names,
    List<String> dates,
  ) {
    double fs = (rowH * 0.65).clamp(5.0, 20.0);
    while (fs > 5.0) {
      if (_allTextFits(fs, width, hPad, names, dates)) return fs;
      fs -= 0.5;
    }
    return 5.0;
  }

  bool _allTextFits(
    double fs,
    double width,
    double hPad,
    List<String> names,
    List<String> dates,
  ) {
    // Flag emoji rendered at 1.5× font size; estimated rendered width ~2× font.
    final flagEst = fs * 2.0;
    // Date column: wider fraction to accommodate cross-year "Mar 2023–Jan 2024".
    const dateColFraction = 0.43;
    final dateColW = width * dateColFraction;
    // Name column: remainder after left pad, flag, gaps, and date column.
    final nameColW = width - hPad * 2 - flagEst - 10 - dateColW;
    if (nameColW <= 0) return false;

    for (var i = 0; i < names.length; i++) {
      final tpName = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: nameColW);
      if (tpName.didExceedMaxLines) return false;

      final tpDate = TextPainter(
        text: TextSpan(
          text: dates[i],
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w700,
            fontFamily: 'CourierNew',
            fontFamilyFallback: const ['Courier', 'monospace'],
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: dateColW);
      if (tpDate.didExceedMaxLines) return false;
    }
    return true;
  }

  // Dynamically compute divider height and row height to fit all entries.
  (double rowH, double divH) _computeHeights(
    int n,
    int divCount,
    double available,
  ) {
    if (n == 0) return (24.0, 14.0);

    // Try full divider height (14px).
    const fullDivH = 14.0;
    var rowH = (available - divCount * fullDivH) / n;
    if (rowH >= 8.0) {
      return (rowH.clamp(8.0, 32.0), fullDivH);
    }

    // Try reduced dividers (8px).
    const minDivH = 8.0;
    rowH = (available - divCount * minDivH) / n;
    if (rowH >= 8.0) {
      return (rowH.clamp(8.0, 32.0), minDivH);
    }

    // Skip dividers entirely.
    rowH = available / n;
    return (rowH.clamp(8.0, 32.0), 0.0);
  }

  void _drawYearDivider(
    Canvas canvas,
    double width,
    double y,
    double divH,
    int year,
    double fontSize,
    double hPad,
  ) {
    final midY = y + divH / 2;

    // Year label.
    final tp = TextPainter(
      text: TextSpan(
        text: '$year',
        style: TextStyle(
          color: _accentColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(hPad, midY - tp.height / 2));

    // Amber divider line to the right of the year label.
    canvas.drawLine(
      Offset(hPad + tp.width + 4, midY),
      Offset(width - hPad, midY),
      Paint()
        ..color = _accentColor.withValues(alpha: 0.45)
        ..strokeWidth = 0.5,
    );
  }

  void _drawEntryRow(
    Canvas canvas,
    double width,
    double y,
    double rowH,
    TimelineEntry entry,
    String dateStr,
    double fontSize,
    double flagFontSize,
    double hPad,
  ) {
    const dateColFraction = 0.43;
    final dateColW = width * dateColFraction;
    final midY = y + rowH / 2;

    // Date (right-aligned, bold, monospace, single line — font pre-sized to fit).
    final tpDate = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          color: _inkMutedColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'CourierNew',
          fontFamilyFallback: const ['Courier', 'monospace'],
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: dateColW);

    final dateX = width - hPad - tpDate.width;
    tpDate.paint(canvas, Offset(dateX, midY - tpDate.height / 2));

    // Flag emoji.
    final tpFlag = TextPainter(
      text: TextSpan(
        text: _flag(entry.countryCode),
        style: TextStyle(
          fontSize: flagFontSize,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tpFlag.paint(canvas, Offset(hPad, midY - tpFlag.height / 2));

    // Country name (bold, single line — font pre-sized so it never wraps).
    final nameX = hPad + tpFlag.width + 4;
    final nameMaxW = dateX - nameX - 6;
    if (nameMaxW > 0) {
      final tpName = TextPainter(
        text: TextSpan(
          text: entry.countryName,
          style: TextStyle(
            color: _inkColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: nameMaxW);

      tpName.paint(canvas, Offset(nameX, midY - tpName.height / 2));
    }
  }

  void _drawMoreNote(
    Canvas canvas,
    double width,
    double y,
    int count,
    double fontSize,
    double hPad,
  ) {
    final text = 'and $count more ${count == 1 ? 'trip' : 'trips'}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _inkMutedColor,
          fontSize: (fontSize * 0.9).clamp(5.0, 11.0),
          fontStyle: FontStyle.italic,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - hPad * 2);

    tp.paint(canvas, Offset(hPad, y + 2));
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.entries != entries ||
      old.truncatedCount != truncatedCount ||
      old.countryCodes != countryCodes ||
      old.dateLabel != dateLabel ||
      old.titleOverride != titleOverride ||
      old.transparentBackground != transparentBackground ||
      old.newestFirst != newestFirst ||
      old.textColor != textColor;
}
