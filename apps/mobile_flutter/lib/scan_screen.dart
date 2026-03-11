import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'data/db/roavvy_database.dart';
import 'data/visit_repository.dart';
import 'features/scan/scan_mapper.dart';
import 'features/visits/review_screen.dart';
import 'photo_scan_channel.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.repository});

  /// Injected repository. When null the screen opens the production Drift DB.
  /// Pass a non-null value in tests to avoid file-system access.
  final VisitRepository? repository;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final VisitRepository _repo;

  PhotoPermissionStatus? _permission;
  bool _loading = true;
  bool _scanning = false;
  ScanResult? _lastScanResult;
  List<EffectiveVisitedCountry> _effectiveVisits = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        VisitRepository(RoavvyDatabase(driftDatabase(name: 'roavvy')));
    _loadPersisted();
  }

  @override
  void dispose() {
    // Close only the DB we opened ourselves; injected test repos are managed
    // by the caller.
    if (widget.repository == null) _repo.close();
    super.dispose();
  }

  Future<void> _loadPersisted() async {
    try {
      final visits = await _repo.loadEffective();
      setState(() {
        _effectiveVisits = visits;
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

      // Clear stale inferred data then persist the new scan results.
      await _repo.clearInferred();
      final visits = toInferredVisits(result.countries, now: now);
      await _repo.saveAllInferred(visits);

      final effective = await _repo.loadEffective();
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          initialVisits: _effectiveVisits,
          repository: _repo,
        ),
      ),
    );
    // Reload after review — ReviewScreen writes its delta on Save.
    final updated = await _repo.loadEffective();
    if (mounted) setState(() => _effectiveVisits = updated);
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
        Text('Scanning photos and reverse-geocoding\u2026'),
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
            _StatRow(label: 'Geocode failures', value: '${stats.geocodeFailures}'),
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
  final List<EffectiveVisitedCountry> visits;

  @override
  Widget build(BuildContext context) {
    final sorted = [...visits]
      ..sort((a, b) => a.countryCode.compareTo(b.countryCode));
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (v.photoCount > 0)
                      Text(
                        '${v.photoCount} photo${v.photoCount == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    if (!v.hasPhotoEvidence) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                    ],
                  ],
                ),
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
