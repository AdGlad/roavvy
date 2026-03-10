import 'package:flutter/material.dart';
import 'photo_scan_channel.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  PhotoPermissionStatus? _permission;
  bool _scanning = false;
  ScanResult? _result;
  String? _error;

  Future<void> _requestPermission() async {
    try {
      final status = await requestPhotoPermission();
      setState(() {
        _permission = status;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await scanPhotos(limit: 100);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roavvy — Photo Scan Spike')),
      body: Padding(
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
              child: const Text('Scan 100 Most Recent Photos'),
            ),
            const SizedBox(height: 24),
            if (_error != null) _ErrorView(message: _error!),
            if (_scanning) const _ScanningView(),
            if (_result != null) Expanded(child: _ResultsView(result: _result!)),
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

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsCard(stats: result.stats),
        const SizedBox(height: 16),
        _CountryList(countries: result.countries),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final ScanStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan summary', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _StatRow(label: 'Assets inspected', value: '${stats.inspected}'),
            _StatRow(label: 'With location', value: '${stats.withLocation}'),
            _StatRow(label: 'Without location', value: '${stats.withoutLocation}'),
            _StatRow(label: 'Geocode successes', value: '${stats.geocodeSuccesses}'),
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
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CountryList extends StatelessWidget {
  const _CountryList({required this.countries});

  final List<DetectedCountry> countries;

  @override
  Widget build(BuildContext context) {
    if (countries.isEmpty) {
      return const Center(
        child: Text(
          'No geotagged photos found in the most recent 100 photos.\n'
          'Try enabling location on your camera or increasing the scan limit.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${countries.length} ${countries.length == 1 ? 'country' : 'countries'} detected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: countries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = countries[i];
                return ListTile(
                  leading: Text(
                    c.code,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  title: Text(c.name),
                  trailing: Text(
                    '${c.photoCount} photo${c.photoCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
