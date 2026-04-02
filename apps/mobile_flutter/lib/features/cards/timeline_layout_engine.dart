import 'dart:ui';

import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';

/// A single trip entry in the timeline card.
class TimelineEntry {
  const TimelineEntry({
    required this.countryCode,
    required this.countryName,
    required this.entryDate,
    required this.exitDate,
    this.durationDays,
  });

  final String countryCode;
  final String countryName;
  final DateTime entryDate;
  final DateTime exitDate;

  /// Trip duration in days, inclusive. May be null if dates are equal.
  final int? durationDays;
}

/// Result of [TimelineLayoutEngine.layout].
class TimelineLayoutResult {
  const TimelineLayoutResult({
    required this.entries,
    required this.truncatedCount,
  });

  final List<TimelineEntry> entries;

  /// Number of trips that were omitted because they did not fit the canvas.
  final int truncatedCount;
}

/// Pure static layout engine for the Timeline card template (ADR-104 / M52).
///
/// Produces an ordered list of [TimelineEntry] objects from a list of
/// [TripRecord]s, truncated to fit the available canvas height.
class TimelineLayoutEngine {
  const TimelineLayoutEngine._();

  /// Approximate height (logical px) of the card header section.
  static const double _kHeaderHeight = 64.0;

  /// Approximate height (logical px) of the card footer (branding).
  static const double _kFooterHeight = 36.0;

  /// Approximate height (logical px) of a year-divider row.
  static const double _kDividerHeight = 22.0;

  /// Lays out timeline entries from [trips] sorted most-recent first.
  ///
  /// [countryCodes] is used only when [trips] is empty — in that case there
  /// are no entries to display. When [trips] is non-empty, country names are
  /// looked up from [kCountryNames].
  ///
  /// [canvasSize] drives the truncation calculation. Entry row height is
  /// derived from the canvas height and clamped to [28, 52] logical pixels.
  static TimelineLayoutResult layout({
    required List<TripRecord> trips,
    required List<String> countryCodes,
    required Size canvasSize,
  }) {
    if (trips.isEmpty) {
      return const TimelineLayoutResult(entries: [], truncatedCount: 0);
    }

    // Sort most-recent first.
    final sorted = List<TripRecord>.from(trips)
      ..sort((a, b) => b.startedOn.compareTo(a.startedOn));

    // Estimate row height from canvas.
    final rowHeight =
        (canvasSize.height / 12.0).clamp(28.0, 52.0);

    // Available height for entry rows (subtract header, footer, and a small
    // vertical padding buffer).
    final usableHeight =
        canvasSize.height - _kHeaderHeight - _kFooterHeight - 8.0;

    // Build entries and track year-divider overhead.
    final allEntries = <TimelineEntry>[];
    for (final trip in sorted) {
      final duration = trip.endedOn.difference(trip.startedOn).inDays;
      allEntries.add(TimelineEntry(
        countryCode: trip.countryCode,
        countryName: kCountryNames[trip.countryCode] ?? trip.countryCode,
        entryDate: trip.startedOn,
        exitDate: trip.endedOn,
        durationDays: duration > 0 ? duration : null,
      ));
    }

    // Determine how many entries fit.
    double consumed = 0.0;
    int? lastYear;
    final visible = <TimelineEntry>[];

    for (final entry in allEntries) {
      final year = entry.entryDate.year;
      double rowCost = rowHeight;
      if (lastYear != year) {
        rowCost += _kDividerHeight;
        lastYear = year;
      }
      if (consumed + rowCost > usableHeight && visible.isNotEmpty) break;
      consumed += rowCost;
      visible.add(entry);
    }

    final truncatedCount = allEntries.length - visible.length;
    return TimelineLayoutResult(
      entries: visible,
      truncatedCount: truncatedCount,
    );
  }
}

// ── Date formatting ────────────────────────────────────────────────────────────

/// Formats a trip date range for display in the timeline card.
///
/// Rules (ADR-104):
/// - Same month + year → `"Mar 2023"`
/// - Same year, different month → `"Mar–Jun 2023"` (en-dash)
/// - Different year → `"Mar 2023–Jan 2024"` (en-dash)
String formatTimelineDate(DateTime entry, DateTime exit) {
  final entryStr = _monthYear(entry);
  if (entry.year == exit.year && entry.month == exit.month) {
    return entryStr;
  }
  if (entry.year == exit.year) {
    return '${_monthAbbr(entry.month)}–${_monthAbbr(exit.month)} ${entry.year}';
  }
  return '$entryStr–${_monthYear(exit)}';
}

String _monthYear(DateTime dt) => '${_monthAbbr(dt.month)} ${dt.year}';

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthAbbr(int month) => _kMonths[month - 1];
