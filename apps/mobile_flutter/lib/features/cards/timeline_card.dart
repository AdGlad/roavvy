import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'card_branding_footer.dart';
import 'timeline_layout_engine.dart';

// ── Colour palette (parchment / ink / amber) ──────────────────────────────────

const _kParchment = Color(0xFFF5F0E8);
const _kInk = Color(0xFF2C1810);
const _kInkMuted = Color(0xFF6B5240);
const _kAmber = Color(0xFFD4A017);
const _kDividerAmber = Color(0xFFD4A017);

// ── Flag emoji helper ──────────────────────────────────────────────────────────

String _flag(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + code.codeUnitAt(0) - 65) +
      String.fromCharCode(base + code.codeUnitAt(1) - 65);
}

// ── TimelineCard ──────────────────────────────────────────────────────────────

/// Travel card template: dated travel log rendered on a parchment background.
///
/// Trips are listed most-recent first, grouped by year with amber dividers.
/// Truncated entries show a "and N more trips" note. Uses [TimelineLayoutEngine]
/// to determine how many entries fit on the canvas (ADR-104 / M52).
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.trips,
    required this.countryCodes,
    this.aspectRatio = 3.0 / 2.0,
    this.dateLabel = '',
  });

  final List<TripRecord> trips;
  final List<String> countryCodes;
  final double aspectRatio;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layoutResult = TimelineLayoutEngine.layout(
            trips: trips,
            countryCodes: countryCodes,
            canvasSize: size,
          );
          return _TimelineCardBody(
            entries: layoutResult.entries,
            truncatedCount: layoutResult.truncatedCount,
            countryCount: countryCodes.length,
            dateLabel: dateLabel,
          );
        },
      ),
    );
  }
}

class _TimelineCardBody extends StatelessWidget {
  const _TimelineCardBody({
    required this.entries,
    required this.truncatedCount,
    required this.countryCount,
    required this.dateLabel,
  });

  final List<TimelineEntry> entries;
  final int truncatedCount;
  final int countryCount;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kParchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _Header(dateLabel: dateLabel),
          // Entry list
          Expanded(
            child: entries.isEmpty
                ? const _EmptyState()
                : _EntryList(entries: entries, truncatedCount: truncatedCount),
          ),
          // Branding footer (amber text on parchment)
          CardBrandingFooter(
            countryCount: countryCount,
            dateLabel: dateLabel,
            textColor: _kAmber,
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.dateLabel});
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAVEL LOG',
            style: TextStyle(
              color: _kAmber,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: const TextStyle(
                color: _kInkMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Entry list ────────────────────────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.truncatedCount});
  final List<TimelineEntry> entries;
  final int truncatedCount;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    int? lastYear;

    for (final entry in entries) {
      final year = entry.entryDate.year;
      if (lastYear != year) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 2));
        rows.add(_YearDivider(year: year));
        rows.add(const SizedBox(height: 2));
        lastYear = year;
      }
      rows.add(_EntryRow(entry: entry));
    }

    if (truncatedCount > 0) {
      rows.add(const SizedBox(height: 4));
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'and $truncatedCount more ${truncatedCount == 1 ? 'trip' : 'trips'}',
            style: const TextStyle(
              color: _kInkMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: rows,
    );
  }
}

// ── Year divider ──────────────────────────────────────────────────────────────

class _YearDivider extends StatelessWidget {
  const _YearDivider({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            '$year',
            style: const TextStyle(
              color: _kAmber,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1,
              color: _kDividerAmber.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry row ─────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateStr = formatTimelineDate(entry.entryDate, entry.exitDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Flag emoji
          Text(
            _flag(entry.countryCode),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          // Country name (expands)
          Expanded(
            child: Text(
              entry.countryName,
              style: const TextStyle(
                color: _kInk,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Date (fixed width column, monospaced)
          Text(
            dateStr,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kInkMuted,
              fontSize: 11,
              fontFamily: 'CourierNew',
              fontFamilyFallback: ['Courier', 'monospace'],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No trips in this date range',
        style: TextStyle(color: _kInkMuted, fontSize: 13),
      ),
    );
  }
}
