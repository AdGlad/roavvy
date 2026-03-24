import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../map/trip_map_screen.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '';
  const base = 0x1F1E6;
  return String.fromCharCode(base + isoCode.codeUnitAt(0) - 65) +
      String.fromCharCode(base + isoCode.codeUnitAt(1) - 65);
}

String _fmtDate(DateTime dt, {bool showYear = true}) {
  final m = _months[dt.month - 1];
  return showYear ? '${dt.day} $m ${dt.year}' : '${dt.day} $m';
}

String _dateRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${_fmtDate(start, showYear: false)} – ${_fmtDate(end)}';
  }
  return '${_fmtDate(start)} – ${_fmtDate(end)}';
}

int _tripDays(DateTime start, DateTime end) =>
    end.difference(start).inDays + 1;

/// Chronological trip history, grouped by year with sticky section headers.
///
/// Entry point: Journal tab (index 1). Reads trips from [tripListProvider]
/// (a [FutureProvider] that is invalidated after clearAll and scan save —
/// ADR-081). Watches [effectiveVisitsProvider] for [CountryDetailSheet] data.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key, required this.onNavigateToScan});

  /// Called when the user taps "Scan Photos" in the empty state.
  final VoidCallback onNavigateToScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);
    final visitsAsync = ref.watch(effectiveVisitsProvider);

    final visitsByCode = <String, EffectiveVisitedCountry>{};
    visitsAsync.whenData((visits) {
      for (final v in visits) {
        visitsByCode[v.countryCode] = v;
      }
    });

    // Design Principle 3: no spinner — render nothing while loading.
    final trips = tripsAsync.valueOrNull;
    if (trips == null) return const SizedBox.shrink();

    if (trips.isEmpty) {
      return _EmptyState(onScanTap: onNavigateToScan);
    }

    return _JournalList(trips: trips, visitsByCode: visitsByCode);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScanTap});

  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: secondary),
            const SizedBox(height: 16),
            Text(
              'Your journal is empty',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your photos to build your travel history.',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onScanTap,
              child: const Text('Scan Photos'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Journal list ──────────────────────────────────────────────────────────────

class _JournalList extends StatelessWidget {
  const _JournalList({
    required this.trips,
    required this.visitsByCode,
  });

  final List<TripRecord> trips;
  final Map<String, EffectiveVisitedCountry> visitsByCode;

  @override
  Widget build(BuildContext context) {
    // Group trips by year; sort years descending; within year sort descending.
    final byYear = <int, List<TripRecord>>{};
    for (final t in trips) {
      byYear.putIfAbsent(t.startedOn.year, () => []).add(t);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final y in years) {
      byYear[y]!.sort((a, b) => b.startedOn.compareTo(a.startedOn));
    }

    final slivers = <Widget>[
      const SliverAppBar(
        title: Text('Journal'),
        floating: true,
        snap: true,
      ),
    ];

    for (final year in years) {
      final yearTrips = byYear[year]!;
      final tripWord = yearTrips.length == 1 ? 'trip' : 'trips';
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _YearHeaderDelegate(
            text: '$year  ·  ${yearTrips.length} $tripWord',
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final trip = yearTrips[index];
              final isLast = index == yearTrips.length - 1;
              return Column(
                children: [
                  _TripTile(
                    trip: trip,
                    visit: visitsByCode[trip.countryCode],
                  ),
                  if (!isLast) const Divider(height: 1, indent: 16),
                ],
              );
            },
            childCount: yearTrips.length,
          ),
        ),
      );
    }

    return CustomScrollView(slivers: slivers);
  }
}

// ── Year section header ───────────────────────────────────────────────────────

class _YearHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _YearHeaderDelegate({required this.text});

  final String text;
  static const double _height = 40;

  @override
  double get maxExtent => _height;
  @override
  double get minExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Semantics(
      header: true,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }

  @override
  bool shouldRebuild(_YearHeaderDelegate other) => text != other.text;
}

// ── Trip tile ─────────────────────────────────────────────────────────────────

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.visit});

  final TripRecord trip;
  final EffectiveVisitedCountry? visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    final countryName = kCountryNames[trip.countryCode] ?? trip.countryCode;
    final flag = _flagEmoji(trip.countryCode);
    final dateRange = _dateRange(trip.startedOn, trip.endedOn);
    final days = _tripDays(trip.startedOn, trip.endedOn);
    final dayWord = days == 1 ? 'day' : 'days';

    final semanticLabel = [
      countryName,
      '$dateRange, $days $dayWord',
      if (trip.photoCount > 0)
        '${trip.photoCount} ${trip.photoCount == 1 ? 'photo' : 'photos'}',
      if (trip.isManual) 'added manually',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      countryName,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateRange  ·  $days $dayWord',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: secondary),
                    ),
                    if (trip.photoCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📷 ${trip.photoCount} '
                        '${trip.photoCount == 1 ? 'photo' : 'photos'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: secondary),
                      ),
                    ],
                    if (trip.isManual) ...[
                      const SizedBox(height: 4),
                      Chip(
                        label: const Text('Added manually'),
                        labelStyle: theme.textTheme.labelSmall,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripMapScreen(trip: trip),
      ),
    );
  }
}
