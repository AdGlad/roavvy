import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'features/scan/scan_mapper.dart';
import 'features/visits/review_screen.dart';
import 'features/visits/visit_store.dart';
import 'photo_scan_channel.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  PhotoPermissionStatus? _permission;
  bool _loading = true; // true while loading persisted visits on first frame
  bool _scanning = false;
  ScanResult? _lastScanResult;
  List<CountryVisit> _effectiveVisits = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    try {
      final saved = await VisitStore.load();
      setState(() {
        _effectiveVisits = effectiveVisits(saved);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load saved visits: $e';
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await requestPhotoPermission();
      setState(() {
        _permission = status;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await scanPhotos(limit: 500);
      final now = DateTime.now().toUtc();

      // Convert scan output → domain visits and merge with any saved manual edits.
      final fromScan = toCountryVisits(result.countries, now: now);
      final saved = await VisitStore.load();
      final merged = [...fromScan, ...saved];
      final effective = effectiveVisits(merged);

      // Persist the full merged list (including manual tombstones).
      await VisitStore.save(merged);

      setState(() {
        _lastScanResult = result;
        _effectiveVisits = effective;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push<List<CountryVisit>>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(initialVisits: _effectiveVisits),
      ),
    );
    // Reload from store — ReviewScreen writes on Save.
    final saved = await VisitStore.load();
    setState(() => _effectiveVisits = effectiveVisits(saved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roavvy — Photo Scan'),
        actions: [
          if (_effectiveVisits.isNotEmpty)
            TextButton(
              onPressed: _openReview,
              child: const Text('Review & Edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PermissionStatus(status: _permission),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _requestPermission,
                    child: const Text('Request Permission'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: (_permission?.canScan == true && !_scanning) ? _scan : null,
                    child: const Text('Scan 500 Most Recent Photos'),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) _ErrorView(message: _error!),
                  if (_scanning) const _ScanningView(),
                  if (!_scanning) ...[
                    if (_lastScanResult != null)
                      _StatsCard(
                        stats: _lastScanResult!.stats,
                        countryCount: _effectiveVisits.length,
                      ),
                    if (_effectiveVisits.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Expanded(child: _VisitList(visits: _effectiveVisits)),
                    ] else if (_lastScanResult != null) ...[
                      const SizedBox(height: 16),
                      const _EmptyResultsHint(),
                    ] else if (_effectiveVisits.isEmpty && _lastScanResult == null) ...[
                      const SizedBox(height: 16),
                      const _NoScanYetHint(),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PermissionStatus extends StatelessWidget {
  const _PermissionStatus({required this.status});
  final PhotoPermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final label = status?.label ?? 'Unknown — tap Request Permission';
    final colour = switch (status) {
      PhotoPermissionStatus.authorized => Colors.green,
      PhotoPermissionStatus.limited => Colors.orange,
      PhotoPermissionStatus.denied => Colors.red,
      PhotoPermissionStatus.restricted => Colors.red,
      _ => Colors.grey,
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: colour),
        const SizedBox(width: 8),
        Text('Permission: $label', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Scanning photos and reverse-geocoding…'),
        Text(
          'This may take a few seconds.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.countryCount});
  final ScanStats stats;
  final int countryCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last scan', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _StatRow(label: 'Assets scanned', value: '${stats.inspected}'),
            _StatRow(label: 'With location', value: '${stats.withLocation}'),
            _StatRow(label: 'Without location', value: '${stats.withoutLocation}'),
            _StatRow(label: 'Geocode successes', value: '${stats.geocodeSuccesses}'),
            _StatRow(label: 'Unique countries', value: '$countryCount'),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({required this.visits});
  final List<CountryVisit> visits;

  @override
  Widget build(BuildContext context) {
    // Sort A→Z by country code for a consistent display order.
    final sorted = [...visits]..sort((a, b) => a.countryCode.compareTo(b.countryCode));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${sorted.length} ${sorted.length == 1 ? 'country' : 'countries'} visited',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = sorted[i];
              return ListTile(
                leading: Text(
                  v.countryCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: v.source == VisitSource.manual
                    ? const Icon(Icons.person, size: 14, color: Colors.grey)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoScanYetHint extends StatelessWidget {
  const _NoScanYetHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Grant permission then tap Scan to detect\nthe countries in your photo library.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}

class _EmptyResultsHint extends StatelessWidget {
  const _EmptyResultsHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No geotagged photos found.\n'
        'Enable location on your camera or increase the scan limit.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}
