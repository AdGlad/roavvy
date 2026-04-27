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

  /// Number of trips omitted because they exceeded [TimelineLayoutEngine._kMaxEntries].
  final int truncatedCount;
}

/// Pure static layout engine for the Timeline card template (ADR-104 / M52).
///
/// Produces an ordered list of [TimelineEntry] objects from a list of
/// [TripRecord]s, capped at [_kMaxEntries]. Ordering is controlled by
/// [newestFirst] (default false = earliest → latest, per M86 spec).
class TimelineLayoutEngine {
  const TimelineLayoutEngine._();

  /// Maximum number of trip entries shown in a single timeline card.
  static const int kMaxEntries = 25;

  /// Lays out timeline entries from [trips].
  ///
  /// [newestFirst] — when true, sorts most-recent first (latest → earliest).
  ///   Default false = chronological (earliest → latest).
  ///
  /// [canvasSize] is retained for API compatibility but no longer used for
  /// truncation — the painter handles dynamic scaling instead.
  static TimelineLayoutResult layout({
    required List<TripRecord> trips,
    required List<String> countryCodes,
    Size canvasSize = Size.zero,
    bool newestFirst = false,
  }) {
    if (trips.isEmpty) {
      return const TimelineLayoutResult(entries: [], truncatedCount: 0);
    }

    final sorted = List<TripRecord>.from(trips)
      ..sort((a, b) => newestFirst
          ? b.startedOn.compareTo(a.startedOn)
          : a.startedOn.compareTo(b.startedOn));

    final allEntries = sorted.map((trip) {
      final duration = trip.endedOn.difference(trip.startedOn).inDays;
      return TimelineEntry(
        countryCode: trip.countryCode,
        countryName: kCountryNames[trip.countryCode] ?? trip.countryCode,
        entryDate: trip.startedOn,
        exitDate: trip.endedOn,
        durationDays: duration > 0 ? duration : null,
      );
    }).toList();

    final visible = allEntries.take(kMaxEntries).toList();
    return TimelineLayoutResult(
      entries: visible,
      truncatedCount: allEntries.length - visible.length,
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
