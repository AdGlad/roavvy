import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../../data/achievement_repository.dart';
import '../../data/firestore_sync_service.dart';
import '../../data/region_repository.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';
import '../../photo_scan_channel.dart';
import '../visits/review_screen.dart';

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

/// Result of resolving a batch of [PhotoRecord]s.
///
/// Contains both the per-country [accum] aggregates (for [InferredCountryVisit]
/// upsert) and the individual [photoDates] (for trip inference via [inferTrips]).
class BatchResult {
  const BatchResult({required this.accum, required this.photoDates});

  final Map<String, CountryAccum> accum;

  /// One record per photo that had a non-null [PhotoRecord.capturedAt] and a
  /// successfully resolved country code.
  final List<PhotoDateRecord> photoDates;
}

/// Resolves [photos] to a [BatchResult] using [countryResolver].
///
/// Coordinates are bucketed to a 0.5° grid (~55 km) before calling resolvers,
/// so that dense photo clusters make at most one lookup per unique bucket
/// (ADR-005, ADR-051). Public so the bucketing + accumulation logic can be
/// unit-tested independently of [initCountryLookup] and [Isolate.run].
///
/// [regionResolver] is optional. When provided, it is called (with the same
/// bucketed coordinates) only for photos whose country resolved successfully.
/// The resulting [PhotoDateRecord.regionCode] is null when [regionResolver] is
/// omitted or when it returns null for that bucket.
BatchResult resolveBatch(
    List<PhotoRecord> photos,
    String? Function(double lat, double lng) countryResolver, [
    String? Function(double lat, double lng)? regionResolver]) {
  final accum = <String, CountryAccum>{};
  final photoDates = <PhotoDateRecord>[];
  // Per-bucket caches so each unique 0.5° cell calls each resolver once.
  final countryBucketCache = <(double, double), String?>{};
  final regionBucketCache = <(double, double), String?>{};

  for (final photo in photos) {
    final bucketLat = (photo.lat * 2).roundToDouble() / 2;
    final bucketLng = (photo.lng * 2).roundToDouble() / 2;
    final key = (bucketLat, bucketLng);
    final code = countryBucketCache.putIfAbsent(
        key, () => countryResolver(photo.lat, photo.lng));
    if (code == null) continue;

    final a =
        CountryAccum(photoCount: 1, firstSeen: photo.capturedAt, lastSeen: photo.capturedAt);
    final existing = accum[code];
    accum[code] = existing == null ? a : existing.merge(a);

    if (photo.capturedAt != null) {
      final regionCode = regionResolver != null
          ? regionBucketCache.putIfAbsent(
              key, () => regionResolver(bucketLat, bucketLng))
          : null;
      photoDates.add(PhotoDateRecord(
          countryCode: code,
          capturedAt: photo.capturedAt!,
          regionCode: regionCode));
    }
  }

  return BatchResult(accum: accum, photoDates: photoDates);
}

/// Top-level function — safe to pass to [Isolate.run].
///
/// Initialises [country_lookup] and [region_lookup] in the background isolate
/// (each isolate has independent global state) then delegates to [resolveBatch].
BatchResult _resolvePhotos(
    Uint8List countryBytes, Uint8List regionBytes, List<PhotoRecord> photos) {
  initCountryLookup(countryBytes);
  initRegionLookup(regionBytes);
  return resolveBatch(photos, resolveCountry, resolveRegion);
}


// ── Scan result ────────────────────────────────────────────────────────────────

/// Drives the post-scan UI branch (ADR-024).
///
/// Set only on successful scan completion; cleared on scan start.
/// Only produced when the scan finds at least one geotagged photo — the
/// no-geotagged-photos path uses the existing [_EmptyResultsHint].
sealed class _ScanResult {}

class _NothingNew extends _ScanResult {}

class _NewCountriesFound extends _ScanResult {
  _NewCountriesFound(this.newCodes);
  final List<String> newCodes; // ISO 3166-1 alpha-2, sorted
}

// ── ScanScreen ─────────────────────────────────────────────────────────────────

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    this.onScanComplete,
    this.batchResolver,
    this.scanStarter,
    this.syncService,
  });

  /// Called after a scan finishes successfully. Used by [MainShell] to
  /// navigate to the Map tab.
  final VoidCallback? onScanComplete;

  /// Optional resolver override for widget tests. When non-null, replaces the
  /// [Isolate.run] call so tests can inject predetermined country results without
  /// real geodata.
  final Future<BatchResult> Function(List<PhotoRecord>)? batchResolver;

  /// Optional scan stream factory for widget tests. When non-null, replaces the
  /// real [startPhotoScan] EventChannel call so tests can inject a plain Dart
  /// stream without touching platform channel infrastructure.
  final Stream<ScanEvent> Function({int limit})? scanStarter;

  /// Sync service used to flush dirty records after a scan completes.
  /// Defaults to [FirestoreSyncService] when null.
  final SyncService? syncService;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  SyncService get _syncService => widget.syncService ?? FirestoreSyncService();

  late final VisitRepository _repo;
  late final AchievementRepository _achievementRepo;
  late final TripRepository _tripRepo;
  late final RegionRepository _regionRepo;

  PhotoPermissionStatus? _permission;
  bool _loading = true;
  bool _scanning = false;
  ScanStats? _lastScanStats;
  List<EffectiveVisitedCountry> _effectiveVisits = [];
  String? _error;
  _ScanProgress? _scanProgress;
  _ScanResult? _scanResult;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(visitRepositoryProvider);
    _achievementRepo = ref.read(achievementRepositoryProvider);
    _tripRepo = ref.read(tripRepositoryProvider);
    _regionRepo = ref.read(regionRepositoryProvider);
    _loadPersisted();
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

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Resolves [photos] to a country accumulator map.
  ///
  /// Uses the injected [batchResolver] when available (widget tests).
  /// Otherwise runs [_resolvePhotos] on a background isolate.
  Future<BatchResult> _resolveBatch(List<PhotoRecord> photos) {
    if (widget.batchResolver != null) return widget.batchResolver!(photos);
    final countryBytes = ref.read(geodataBytesProvider);
    final regionBytes = ref.read(regionGeodataBytesProvider);
    return Isolate.run(() => _resolvePhotos(countryBytes, regionBytes, photos));
  }

  Future<void> _scan() async {
    // Snapshot before scan starts to diff new countries afterwards (ADR-024).
    final preScanCodes = _effectiveVisits.map((v) => v.countryCode).toSet();

    setState(() {
      _scanning = true;
      _error = null;
      _scanProgress = const _ScanProgress(processed: 0);
      _scanResult = null;
    });

    try {
      // Read persisted timestamp for incremental scan (ADR-022).
      // null → full scan (first launch or after clearAll).
      final lastScanAt = await _repo.loadLastScanAt();

      final accum = <String, CountryAccum>{};
      final allPhotoDates = <PhotoDateRecord>[];
      ScanDoneEvent? doneEvent;
      var totalProcessed = 0;

      final scanStream = widget.scanStarter != null
          ? widget.scanStarter!(limit: 100000)
          : startPhotoScan(limit: 100000, sinceDate: lastScanAt);
      await for (final event in scanStream) {
        if (event is ScanBatchEvent) {
          final batchResult = await _resolveBatch(event.photos);
          for (final entry in batchResult.accum.entries) {
            final existing = accum[entry.key];
            accum[entry.key] =
                existing == null ? entry.value : existing.merge(entry.value);
          }
          allPhotoDates.addAll(batchResult.photoDates);
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

      await _repo.clearAndSaveAllInferred(inferred);
      await _repo.savePhotoDates(allPhotoDates);
      await _repo.saveLastScanAt(now);

      // Re-infer all trips from the full photo date history and persist.
      final allDates = await _repo.loadPhotoDates();
      final inferredTrips = inferTrips(allDates);
      await _tripRepo.upsertAll(inferredTrips);
      await _regionRepo.upsertAll(inferRegionVisits(allDates, inferredTrips));

      final effective = await _repo.loadEffective();

      // Evaluate achievements and persist any newly unlocked ones.
      final priorIds = (await _achievementRepo.loadAll()).toSet();
      final unlockedIds = AchievementEngine.evaluate(effective);
      final newlyUnlockedIds = unlockedIds.difference(priorIds);
      if (newlyUnlockedIds.isNotEmpty) {
        await _achievementRepo.upsertAll(newlyUnlockedIds, now);
      }

      // Flush dirty records to Firestore fire-and-forget (ADR-030).
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        unawaited(_syncService.flushDirty(uid, _repo, achievementRepo: _achievementRepo, tripRepo: _tripRepo));
      }
      final stats = ScanStats(
        inspected: doneEvent?.inspected ?? 0,
        withLocation: doneEvent?.withLocation ?? 0,
        geocodeSuccesses: resolveSuccesses,
      );

      // Compute result summary when geotagged photos were found (ADR-024).
      _ScanResult? scanResult;
      if (effective.isNotEmpty) {
        final postScanCodes = effective.map((v) => v.countryCode).toSet();
        final newCodes = (postScanCodes.difference(preScanCodes)).toList()..sort();
        scanResult = newCodes.isEmpty ? _NothingNew() : _NewCountriesFound(newCodes);
      }

      if (mounted) {
        setState(() {
          _lastScanStats = stats;
          _effectiveVisits = effective;
          _scanResult = scanResult;
        });
        ref.invalidate(effectiveVisitsProvider);
        _showAchievementSnackBars(newlyUnlockedIds);
        widget.onScanComplete?.call();
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

  void _showAchievementSnackBars(Set<String> ids) {
    if (ids.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final achievementById = {for (final a in kAchievements) a.id: a};
    for (final id in ids) {
      final title = achievementById[id]?.title ?? id;
      messenger.showSnackBar(SnackBar(content: Text('🏆 $title')));
    }
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          initialVisits: _effectiveVisits,
          repository: _repo,
          syncService: _syncService,
          uid: ref.read(currentUidProvider),
          achievementRepo: _achievementRepo,
          tripRepo: _tripRepo,
        ),
      ),
    );
    // Reload after review — ReviewScreen writes its delta on Save.
    final updated = await _repo.loadEffective();
    if (mounted) {
      setState(() => _effectiveVisits = updated);
      ref.invalidate(effectiveVisitsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
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
                  _PermissionPanel(
                    status: _permission,
                    onRequestPermission: _requestPermission,
                    onOpenSettings: _openSettings,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: (_permission?.canScan == true && !_scanning) ? _scan : null,
                    child: const Text('Scan my photo library'),
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
                    if (_scanResult != null) ...[
                      const SizedBox(height: 16),
                      switch (_scanResult!) {
                        _NothingNew() => const _NothingNewView(),
                        _NewCountriesFound(:final newCodes) =>
                          _NewCountriesView(newCodes: newCodes),
                      },
                    ],
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

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    required this.status,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  final PhotoPermissionStatus? status;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (status == null || status == PhotoPermissionStatus.notDetermined) {
      return _NotDeterminedPanel(onGrant: onRequestPermission);
    }
    return switch (status!) {
      PhotoPermissionStatus.notDetermined =>
        _NotDeterminedPanel(onGrant: onRequestPermission),
      PhotoPermissionStatus.authorized => const SizedBox.shrink(),
      PhotoPermissionStatus.limited => const _LimitedAccessPanel(),
      PhotoPermissionStatus.denied =>
        _DeniedPanel(onOpenSettings: onOpenSettings),
      PhotoPermissionStatus.restricted => const _RestrictedPanel(),
    };
  }
}

class _NotDeterminedPanel extends StatelessWidget {
  const _NotDeterminedPanel({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Roavvy reads location from your photos to detect visited countries. '
          'Photos never leave your device.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onGrant,
          child: const Text('Grant Access'),
        ),
      ],
    );
  }
}

class _LimitedAccessPanel extends StatelessWidget {
  const _LimitedAccessPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Limited access — Roavvy can only see the photos you\'ve '
              'selected. Update in Settings to scan your full library.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeniedPanel extends StatelessWidget {
  const _DeniedPanel({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Photo access is required to scan your travel history.',
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _RestrictedPanel extends StatelessWidget {
  const _RestrictedPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Access is restricted by your device settings.',
        style: TextStyle(color: Colors.red.shade700),
      ),
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
            _StatRow(label: 'Photos scanned', value: '${stats.inspected}'),
            _StatRow(label: 'With location', value: '${stats.withLocation}'),
            _StatRow(label: 'Countries detected', value: '$countryCount'),
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
              final name = kCountryNames[v.countryCode] ?? v.countryCode;
              return ListTile(
                title: Text(name),
                subtitle: Text(
                  v.countryCode,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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

class _NothingNewView extends StatelessWidget {
  const _NothingNewView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "You're up to date",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}

class _NewCountriesView extends StatelessWidget {
  const _NewCountriesView({required this.newCodes});
  final List<String> newCodes;

  @override
  Widget build(BuildContext context) {
    final count = newCodes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count new ${count == 1 ? 'country' : 'countries'} detected',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ...newCodes.map((code) => Text(kCountryNames[code] ?? code)),
      ],
    );
  }
}
