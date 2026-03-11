import 'dart:isolate';
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import 'data/db/roavvy_database.dart';
import 'data/visit_repository.dart';
import 'features/visits/review_screen.dart';
import 'photo_scan_channel.dart';

// ── Background isolate helpers ─────────────────────────────────────────────────

/// Per-country accumulator used during batch processing.
///
/// Public so widget tests can inject predetermined results via [ScanScreen.batchResolver].
class CountryAccum {
  const CountryAccum({
    required this.photoCount,
    this.firstSeen,
    this.lastSeen,
  });

  final int photoCount;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  CountryAccum merge(CountryAccum other) => CountryAccum(
        photoCount: photoCount + other.photoCount,
        firstSeen: _earlier(firstSeen, other.firstSeen),
        lastSeen: _later(lastSeen, other.lastSeen),
      );
}

DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Resolves a batch of [PhotoRecord]s to per-country accumulators.
///
/// Top-level function — safe to pass to [Isolate.run].
/// [initCountryLookup] is called on entry because each isolate has independent
/// global state (the engine is not shared across isolate boundaries).
Map<String, CountryAccum> _resolvePhotos(
    Uint8List geodataBytes, List<PhotoRecord> photos) {
  initCountryLookup(geodataBytes);
  final result = <String, CountryAccum>{};

  for (final photo in photos) {
    // Bucket coordinates into a 0.5° grid (~55 km) to avoid resolving
    // near-duplicate shots at the same location. (ADR-005)
    final bucketLat = (photo.lat * 2).roundToDouble() / 2;
    final bucketLng = (photo.lng * 2).roundToDouble() / 2;
    final code = resolveCountry(bucketLat, bucketLng);
    if (code == null) continue;

    final accum =
        CountryAccum(photoCount: 1, firstSeen: photo.capturedAt, lastSeen: photo.capturedAt);
    final existing = result[code];
    result[code] = existing == null ? accum : existing.merge(accum);
  }

  return result;
}

// ── ScanScreen ─────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.repository,
    this.geodataBytes,
    this.batchResolver,
    this.scanStarter,
  });

  /// Injected repository. Null = production Drift DB.
  final VisitRepository? repository;

  /// Raw ne_countries.bin bytes passed to background isolates for offline
  /// country resolution. Null in tests that do not exercise resolution.
  final Uint8List? geodataBytes;

  /// Optional resolver override for widget tests. When non-null, replaces the
  /// [Isolate.run] call so tests can inject predetermined country results without
  /// real geodata.
  final Future<Map<String, CountryAccum>> Function(List<PhotoRecord>)? batchResolver;

  /// Optional scan stream factory for widget tests. When non-null, replaces the
  /// real [startPhotoScan] EventChannel call so tests can inject a plain Dart
  /// stream without touching platform channel infrastructure.
  final Stream<ScanEvent> Function({int limit})? scanStarter;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final VisitRepository _repo;

  PhotoPermissionStatus? _permission;
  bool _loading = true;
  bool _scanning = false;
  ScanStats? _lastScanStats;
  List<EffectiveVisitedCountry> _effectiveVisits = [];
  String? _error;
  _ScanProgress? _scanProgress;

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

  /// Resolves [photos] to a country accumulator map.
  ///
  /// Uses the injected [batchResolver] when available (widget tests).
  /// Otherwise runs [_resolvePhotos] on a background isolate.
  Future<Map<String, CountryAccum>> _resolveBatch(List<PhotoRecord> photos) {
    if (widget.batchResolver != null) return widget.batchResolver!(photos);
    final bytes = widget.geodataBytes;
    if (bytes == null) return Future.value({});
    return Isolate.run(() => _resolvePhotos(bytes, photos));
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _scanProgress = const _ScanProgress(processed: 0);
    });

    try {
      final accum = <String, CountryAccum>{};
      ScanDoneEvent? doneEvent;
      var totalProcessed = 0;

      final scanStream = widget.scanStarter != null
          ? widget.scanStarter!(limit: 500)
          : startPhotoScan(limit: 500);
      await for (final event in scanStream) {
        if (event is ScanBatchEvent) {
          final batchResult = await _resolveBatch(event.photos);
          for (final entry in batchResult.entries) {
            final existing = accum[entry.key];
            accum[entry.key] =
                existing == null ? entry.value : existing.merge(entry.value);
          }
          totalProcessed += event.photos.length;
          if (mounted) {
            setState(() => _scanProgress = _ScanProgress(processed: totalProcessed));
          }
        } else if (event is ScanDoneEvent) {
          doneEvent = event;
        }
      }

      final resolveSuccesses =
          accum.values.fold(0, (sum, a) => sum + a.photoCount);
      final now = DateTime.now().toUtc();
      final inferred = accum.entries
          .map((e) => InferredCountryVisit(
                countryCode: e.key,
                inferredAt: now,
                photoCount: e.value.photoCount,
                firstSeen: e.value.firstSeen,
                lastSeen: e.value.lastSeen,
              ))
          .toList();

      await _repo.clearInferred();
      await _repo.saveAllInferred(inferred);

      final effective = await _repo.loadEffective();
      final stats = ScanStats(
        inspected: doneEvent?.inspected ?? 0,
        withLocation: doneEvent?.withLocation ?? 0,
        geocodeSuccesses: resolveSuccesses,
      );

      if (mounted) {
        setState(() {
          _lastScanStats = stats;
          _effectiveVisits = effective;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanProgress = null;
        });
      }
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
                  if (_scanning) _ScanningView(progress: _scanProgress),
                  if (!_scanning) ...[
                    if (_lastScanStats != null)
                      _StatsCard(
                        stats: _lastScanStats!,
                        countryCount: _effectiveVisits.length,
                      ),
                    if (_effectiveVisits.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Expanded(child: _VisitList(visits: _effectiveVisits)),
                    ] else if (_lastScanStats != null) ...[
                      const SizedBox(height: 16),
                      const _EmptyResultsHint(),
                    ] else if (_effectiveVisits.isEmpty && _lastScanStats == null) ...[
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

// ── Progress ───────────────────────────────────────────────────────────────────

class _ScanProgress {
  const _ScanProgress({required this.processed});
  final int processed;
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
  const _ScanningView({this.progress});
  final _ScanProgress? progress;

  @override
  Widget build(BuildContext context) {
    final processed = progress?.processed ?? 0;
    return Column(
      children: [
        LinearProgressIndicator(value: null),
        const SizedBox(height: 8),
        Text(
          processed > 0 ? '$processed photos processed\u2026' : 'Starting scan\u2026',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        const Text('Detecting visited countries'),
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
