import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../../core/region_names.dart';
import '../visits/trip_edit_sheet.dart';
import 'photo_gallery_screen.dart';

/// Bottom sheet shown when the user taps a country on the map.
///
/// Visited countries show trip count, a chronological trip list, and a
/// "manually added" badge when there is no photo evidence. Unvisited countries
/// show an add action.
///
/// [onAdd] is called when the user confirms adding an unvisited country.
/// Null means no add button (used for already-visited countries).
///
/// When [tripFilter] is non-null (set by [JournalScreen]), the Photos tab
/// shows only photos taken during that trip's date range. (ADR-082)
class CountryDetailSheet extends ConsumerStatefulWidget {
  const CountryDetailSheet({
    super.key,
    required this.isoCode,
    this.visit,
    this.onAdd,
    this.tripFilter,
  });

  /// ISO 3166-1 alpha-2 code of the tapped country.
  final String isoCode;

  /// Non-null if the country is in the effective visited set.
  final EffectiveVisitedCountry? visit;

  /// Called when the user taps "Add to my countries". Null = button not shown.
  final Future<void> Function()? onAdd;

  /// When non-null, the Photos tab filters to this trip's date range. (ADR-082)
  final TripRecord? tripFilter;

  @override
  ConsumerState<CountryDetailSheet> createState() => _CountryDetailSheetState();
}

class _CountryDetailSheetState extends ConsumerState<CountryDetailSheet> {
  bool _saving = false;
  bool _regionsExpanded = false;
  late Future<List<TripRecord>> _tripsFuture;
  late Future<List<RegionVisit>> _regionsFuture;
  late Future<List<String>> _assetIdsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture =
        ref.read(tripRepositoryProvider).loadByCountry(widget.isoCode);
    _regionsFuture =
        ref.read(regionRepositoryProvider).loadByCountry(widget.isoCode);
    // When a trip filter is provided, show only photos from that trip's
    // date range; otherwise show all country photos. (ADR-082)
    final tripF = widget.tripFilter;
    _assetIdsFuture = tripF != null
        ? ref.read(visitRepositoryProvider).loadAssetIdsByDateRange(
            widget.isoCode, tripF.startedOn, tripF.endedOn)
        : ref.read(visitRepositoryProvider).loadAssetIds(widget.isoCode);
  }

  void _reload() {
    setState(() {
      _tripsFuture =
          ref.read(tripRepositoryProvider).loadByCountry(widget.isoCode);
    });
    ref.invalidate(travelSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = kCountryNames[widget.isoCode] ?? widget.isoCode;
    final visit = widget.visit;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (visit != null && !visit.hasPhotoEvidence)
                    const Chip(label: Text('Added manually')),
                ],
              ),
            ),
            const TabBar(
              tabs: [Tab(text: 'Details'), Tab(text: 'Photos')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Details tab ─────────────────────────────────────────
                  FutureBuilder<List<TripRecord>>(
                    future: _tripsFuture,
                    builder: (context, snapshot) {
                      final trips = snapshot.data ?? [];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Visited country section ─────────────────
                            if (visit != null) ...[
                              Text(_tripCountLine(trips, visit)),
                              const SizedBox(height: 12),
                              if (trips.isEmpty)
                                const _EmptyTripsMessage()
                              else
                                ...trips.map(
                                  (t) => GestureDetector(
                                    onTap: () => _openEditTrip(t),
                                    onLongPress: () => _confirmDelete(t),
                                    child: _TripCard(trip: t),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _AddTripButton(onTap: _openAddTrip),

                              // ── Region section ─────────────────────────
                              FutureBuilder<List<RegionVisit>>(
                                future: _regionsFuture,
                                builder: (context, snapshot) {
                                  final regions = snapshot.data ?? [];
                                  if (regions.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final codes = regions
                                      .map((r) => r.regionCode)
                                      .toSet()
                                      .toList()
                                    ..sort((a, b) =>
                                        (kRegionNames[a] ?? a)
                                            .compareTo(kRegionNames[b] ?? b));
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      InkWell(
                                        onTap: () => setState(() =>
                                            _regionsExpanded =
                                                !_regionsExpanded),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${codes.length} '
                                                  'region${codes.length == 1 ? '' : 's'} '
                                                  'visited',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                              Icon(
                                                _regionsExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_regionsExpanded)
                                        ...codes.map(
                                          (code) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, bottom: 4),
                                            child: Text(
                                              kRegionNames[code] ?? code,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),

                            // ── Unvisited country section ───────────────
                            ] else if (widget.onAdd != null) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _handleAdd,
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Add to my countries'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Photos tab ──────────────────────────────────────────
                  FutureBuilder<List<String>>(
                    future: _assetIdsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return PhotoGalleryScreen(assetIds: snapshot.data!);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tripCountLine(List<TripRecord> trips, EffectiveVisitedCountry visit) {
    final count = trips.length;
    final countStr = count == 1 ? '1 trip' : '$count trips';
    final year = visit.firstSeen?.year.toString() ?? '—';
    return '$countStr · First visited $year';
  }

  Future<void> _openAddTrip() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TripEditSheet(countryCode: widget.isoCode),
    );
    if (result == true && mounted) _reload();
  }

  Future<void> _openEditTrip(TripRecord trip) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          TripEditSheet(countryCode: widget.isoCode, existingTrip: trip),
    );
    if (result == true && mounted) _reload();
  }

  Future<void> _confirmDelete(TripRecord trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(tripRepositoryProvider).delete(trip.id);
      _reload();
    }
  }

  Future<void> _handleAdd() async {
    setState(() => _saving = true);
    await widget.onAdd!();
    if (mounted) Navigator.of(context).pop(true);
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _EmptyTripsMessage extends StatelessWidget {
  const _EmptyTripsMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No trip data — add a trip manually',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _AddTripButton extends StatelessWidget {
  const _AddTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add),
      label: const Text('Add trip manually'),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripRecord trip;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String _dateRange(TripRecord t) {
    final s = t.startedOn;
    final e = t.endedOn;
    if (s.year == e.year) return '${_fmt(s)} – ${_fmt(e)} ${e.year}';
    return '${_fmt(s)} ${s.year} – ${_fmt(e)} ${e.year}';
  }

  static String _duration(TripRecord t) {
    final days = t.endedOn.difference(t.startedOn).inDays + 1;
    return days == 1 ? '1 day' : '$days days';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateRange(trip),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_duration(trip)}  ·  📷 ${trip.photoCount} photo${trip.photoCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (trip.isManual)
              Chip(
                label: const Text('Added manually'),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }
}
