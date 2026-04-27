import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_text_renderer.dart';
import 'timeline_layout_engine.dart';

// ── Colour palette (ink / amber) ──────────────────────────────────────────────

const _kInk = Color(0xFF2C1810);
const _kInkMuted = Color(0xFF6B5240);
const _kAmber = Color(0xFFD4A017);
const _kParchment = Color(0xFFF5F0E8);

// ── Flag emoji helper ──────────────────────────────────────────────────────────

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── TimelineCard ──────────────────────────────────────────────────────────────

/// Travel card template: dated travel log rendered as a canvas-drawn image.
///
/// Trips are listed chronologically (earliest→latest by default). Uses
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
    this.newestFirst = false,
    this.transparentBackground = false,
  });

  final List<TripRecord> trips;
  final List<String> countryCodes;
  final double aspectRatio;
  final String dateLabel;

  /// Optional title override. When null or empty no title zone is drawn.
  final String? titleOverride;

  /// When true, orders entries most-recent first (latest → earliest).
  /// Default false = chronological (earliest → latest).
  final bool newestFirst;

  /// When true, the card background is fully transparent (default false =
  /// parchment fill). Set true for merch / overlay use.
  final bool transparentBackground;

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
              transparentBackground: transparentBackground,
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
    required this.transparentBackground,
  });

  final List<TimelineEntry> entries;
  final int truncatedCount;
  final List<String> countryCodes;
  final String dateLabel;
  final String? titleOverride;
  final bool transparentBackground;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background.
    if (!transparentBackground) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kParchment,
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
    final fontSize = (rowH * 0.52).clamp(6.0, 14.0);
    final dateFontSize = (rowH * 0.44).clamp(6.0, 12.0);
    final flagFontSize = (rowH * 0.56).clamp(6.0, 16.0);

    double y = zoneTop + kPadH;
    int? lastYear;
    const kPad = 10.0; // horizontal padding

    for (final entry in entries) {
      final year = entry.entryDate.year;
      if (lastYear != year && divH > 0) {
        _drawYearDivider(canvas, width, y, divH, year, fontSize * 0.85, kPad);
        y += divH;
        lastYear = year;
      } else {
        lastYear = year;
      }
      _drawEntryRow(canvas, width, y, rowH, entry, fontSize, dateFontSize,
          flagFontSize, kPad);
      y += rowH;
    }

    if (truncatedCount > 0) {
      _drawMoreNote(canvas, width, y, truncatedCount, dateFontSize, kPad);
    }
  }

  // Dynamically compute divider height and row height to fit all entries.
  (double rowH, double divH) _computeHeights(
      int n, int divCount, double available) {
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

  void _drawYearDivider(Canvas canvas, double width, double y, double divH,
      int year, double fontSize, double hPad) {
    final midY = y + divH / 2;

    // Year label.
    final tp = TextPainter(
      text: TextSpan(
        text: '$year',
        style: TextStyle(
          color: _kAmber,
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
        ..color = _kAmber.withValues(alpha: 0.45)
        ..strokeWidth = 0.5,
    );
  }

  void _drawEntryRow(
    Canvas canvas,
    double width,
    double y,
    double rowH,
    TimelineEntry entry,
    double fontSize,
    double dateFontSize,
    double flagFontSize,
    double hPad,
  ) {
    final dateStr = formatTimelineDate(entry.entryDate, entry.exitDate);

    // Date (right-aligned, bold, monospace).
    final tpDate = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          color: _kInkMuted,
          fontSize: dateFontSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'CourierNew',
          fontFamilyFallback: const ['Courier', 'monospace'],
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width * 0.38);

    final dateX = width - hPad - tpDate.width;
    final midY = y + rowH / 2;
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

    // Country name (bold, ink, fills remaining space).
    final nameX = hPad + tpFlag.width + 4;
    final nameMaxW = dateX - nameX - 6;
    if (nameMaxW > 0) {
      final tpName = TextPainter(
        text: TextSpan(
          text: entry.countryName,
          style: TextStyle(
            color: _kInk,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      )..layout(maxWidth: nameMaxW);

      tpName.paint(canvas, Offset(nameX, midY - tpName.height / 2));
    }
  }

  void _drawMoreNote(Canvas canvas, double width, double y, int count,
      double fontSize, double hPad) {
    final text = 'and $count more ${count == 1 ? 'trip' : 'trips'}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _kInkMuted,
          fontSize: (fontSize * 0.9).clamp(6.0, 11.0),
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
      old.transparentBackground != transparentBackground;
}
