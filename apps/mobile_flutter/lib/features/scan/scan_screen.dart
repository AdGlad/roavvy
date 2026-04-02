import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:confetti/confetti.dart';
import 'package:country_lookup/country_lookup.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../xp/xp_event.dart';
import '../../data/achievement_repository.dart';
import '../../data/firestore_sync_service.dart';
import '../../data/region_repository.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';
import '../../photo_scan_channel.dart';
import '../visits/review_screen.dart';
import 'scan_summary_screen.dart';

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
          regionCode: regionCode,
          assetId: photo.assetId));
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

  /// True after the first successful scan has completed (ADR-110).
  /// Set in [_loadPersisted]; used to gate scan-mode controls and auto-scan.
  bool _hasCompletedFirstScan = false;

  /// When true, [_scan] ignores [lastScanAt] and performs a full scan (M56-14).
  bool _forceFullScan = false;

  /// ISO codes of countries found for the first time during the current scan.
  /// Updated live during the scan loop. (ADR-083)
  final List<String> _liveNewCodes = [];

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
      final hasFirstScan = await _repo.hasCompletedFirstScan();
      if (!mounted) return;
      setState(() {
        _effectiveVisits = visits;
        _hasCompletedFirstScan = hasFirstScan;
        _loading = false;
      });

      // M56-15: auto-run incremental scan on app open after first scan.
      // requestPhotoPermission returns current status without a dialog when
      // the user has already made a permission decision.
      if (hasFirstScan && !_scanning) {
        try {
          final permission = await requestPhotoPermission();
          if (!mounted) return;
          setState(() => _permission = permission);
          if (permission.canScan) {
            _scan(); // fire-and-forget incremental auto-scan (ADR-110)
          }
        } catch (_) {
          // Permission check failed — skip auto-scan silently.
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load saved visits: $e';
          _loading = false;
        });
      }
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
      _liveNewCodes.clear();
    });

    try {
      // Read persisted timestamp for incremental scan (ADR-022, ADR-110).
      // null → full scan (first launch or after clearAll).
      final lastScanAt = await _repo.loadLastScanAt();

      // M56-13: capture pre-scan timestamp BEFORE startPhotoScan to avoid
      // silently skipping photos added during the scan (ADR-110).
      final preScanTimestamp = DateTime.now().toUtc();

      // M56-14: respect user's choice — full scan ignores lastScanAt.
      final sinceDate = _forceFullScan ? null : lastScanAt;

      final accum = <String, CountryAccum>{};
      final allPhotoDates = <PhotoDateRecord>[];
      ScanDoneEvent? doneEvent;
      var totalProcessed = 0;

      final scanStream = widget.scanStarter != null
          ? widget.scanStarter!(limit: 100000)
          : startPhotoScan(limit: 100000, sinceDate: sinceDate);
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

          // Detect countries found for the first time this scan (ADR-083).
          for (final code in batchResult.accum.keys) {
            if (!preScanCodes.contains(code) && !_liveNewCodes.contains(code)) {
              _liveNewCodes.add(code);
            }
          }

          if (mounted) {
            setState(() {
              _scanProgress = _ScanProgress(processed: totalProcessed);
              // _liveNewCodes is updated in-place; setState triggers rebuild.
            });
          }
        } else if (event is ScanDoneEvent) {
          doneEvent = event;
        }
      }

      final resolveSuccesses =
          accum.values.fold(0, (sum, a) => sum + a.photoCount);
      final inferred = accum.entries
          .map((e) => InferredCountryVisit(
                countryCode: e.key,
                inferredAt: preScanTimestamp,
                photoCount: e.value.photoCount,
                firstSeen: e.value.firstSeen,
                lastSeen: e.value.lastSeen,
              ))
          .toList();

      await _repo.clearAndSaveAllInferred(inferred);
      await _repo.savePhotoDates(allPhotoDates);
      // M56-13: persist pre-scan timestamp (ADR-110).
      await _repo.saveLastScanAt(preScanTimestamp);

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
        await _achievementRepo.upsertAll(newlyUnlockedIds, preScanTimestamp);
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
          _hasCompletedFirstScan = true; // M56-15: reveal scan mode toggle
        });
        ref.invalidate(effectiveVisitsProvider);
        ref.invalidate(tripListProvider);        // ADR-081: refresh Journal tab
        ref.invalidate(regionCountProvider);    // refresh Stats regions count
        ref.invalidate(countryTripCountsProvider);
        ref.invalidate(earliestVisitYearProvider);

        // Award XP: scan completion + any new countries (fire-and-forget).
        final xpNotifier = ref.read(xpNotifierProvider.notifier);
        unawaited(xpNotifier.award(XpEvent(
          id: '${preScanTimestamp.microsecondsSinceEpoch}-scan',
          reason: XpReason.scanCompleted,
          amount: 25,
          awardedAt: preScanTimestamp,
        )));
        if (scanResult is _NewCountriesFound) {
          for (var i = 0; i < scanResult.newCodes.length; i++) {
            unawaited(xpNotifier.award(XpEvent(
              id: '${preScanTimestamp.microsecondsSinceEpoch}-country-$i',
              reason: XpReason.newCountry,
              amount: 50,
              awardedAt: preScanTimestamp,
            )));
          }
        }

        if (scanResult is _NewCountriesFound) {
          // Push ScanSummaryScreen — confetti fires here (ADR-059).
          final newCodesList = scanResult.newCodes; // sorted List<String>
          final newCodesSet = newCodesList.toSet();
          final newCountries =
              effective.where((v) => newCodesSet.contains(v.countryCode)).toList();
          final nav = Navigator.of(context);
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => ScanSummaryScreen(
                newCountries: newCountries,
                newAchievementIds: newlyUnlockedIds.toList(),
                newCodes: newCodesList,
                onDone: () {
                  nav.pop();
                  widget.onScanComplete?.call();
                },
              ),
            ),
          );
        } else {
          widget.onScanComplete?.call();
        }
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
          syncService: _syncService,
          uid: ref.read(currentUidProvider),
          achievementRepo: _achievementRepo,
          tripRepo: _tripRepo,
          xpNotifier: ref.read(xpNotifierProvider.notifier),
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
                  // M56-14: scan mode selector — only after first scan.
                  if (_hasCompletedFirstScan && !_scanning)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Incremental scan'),
                            icon: Icon(Icons.update),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Full scan'),
                            icon: Icon(Icons.refresh),
                          ),
                        ],
                        selected: {_forceFullScan},
                        onSelectionChanged: (s) =>
                            setState(() => _forceFullScan = s.first),
                      ),
                    ),
                  FilledButton.tonal(
                    onPressed: (_permission?.canScan == true && !_scanning) ? _scan : null,
                    child: const Text('Scan my photo library'),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) _ErrorView(message: _error!),
                  if (_scanning)
                    _ScanningView(
                      progress: _scanProgress,
                      liveNewCodes: List.unmodifiable(_liveNewCodes),
                    ),
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

// ── _ScanningView (Tasks 146, 147, 148 — M43) ─────────────────────────────────

class _ScanningView extends ConsumerStatefulWidget {
  const _ScanningView({this.progress, this.liveNewCodes = const []});

  final _ScanProgress? progress;

  /// ISO codes of countries found for the first time during this scan.
  /// Updated in real time as each batch is processed. (ADR-083)
  final List<String> liveNewCodes;

  @override
  ConsumerState<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends ConsumerState<_ScanningView> {
  // ── Toast state ──────────────────────────────────────────────────────────────
  String? _toastCode;
  AnimationController? _toastCtrl;
  Animation<Offset>? _toastSlide;
  Timer? _toastTimer;

  // ── Confetti ─────────────────────────────────────────────────────────────────
  ConfettiController? _confettiCtrl;
  int _burstCount = 0;
  Timer? _burstCooldown;

  @override
  void initState() {
    super.initState();
    // ConfettiController created unconditionally; reduce-motion guard applied
    // in _maybeBurst() and build() where MediaQuery is safely accessible.
    _confettiCtrl = ConfettiController(duration: const Duration(milliseconds: 800));
  }

  @override
  void didUpdateWidget(_ScanningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liveNewCodes.length > oldWidget.liveNewCodes.length) {
      final newCode = widget.liveNewCodes.last;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _showToast(newCode);
        _maybeBurst();
      }
    }
  }

  void _showToast(String code) {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _toastCode = code);
    _toastCtrl?.dispose();
    _toastCtrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    );
    _toastSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _toastCtrl!, curve: Curves.easeOut));
    _toastCtrl!.forward();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _toastCtrl?.reverse().then((_) {
        if (mounted) setState(() => _toastCode = null);
      });
    });
  }

  void _maybeBurst() {
    if (_burstCount >= 5) return;
    if (_burstCooldown?.isActive == true) return;
    _confettiCtrl?.play();
    _burstCount++;
    _burstCooldown = Timer(const Duration(milliseconds: 500), () {});
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastCtrl?.dispose();
    _burstCooldown?.cancel();
    _confettiCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final processed = widget.progress?.processed ?? 0;
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(value: null),
            const SizedBox(height: 8),
            Text(
              processed > 0 ? '$processed photos processed\u2026' : 'Starting scan\u2026',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text('Detecting visited countries'),
            const SizedBox(height: 12),
            _ScanLiveMap(liveNewCodes: widget.liveNewCodes),
            if (widget.liveNewCodes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Countries found',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Newest first.
              for (final code in widget.liveNewCodes.reversed)
                _LiveCountryRow(isoCode: code, reduceMotion: reduceMotion),
            ],
          ],
        ),
        // Toast overlay
        if (_toastCode != null && _toastSlide != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _toastSlide!,
              child: _DiscoveryToastBanner(code: _toastCode!),
            ),
          ),
        // Confetti — skip when reduce-motion is enabled
        if (_confettiCtrl != null && !MediaQuery.disableAnimationsOf(context))
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl!,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.6,
              numberOfParticles: 8,
              gravity: 0.3,
              shouldLoop: false,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
                Colors.amber[400]!,
                Colors.amber[700]!,
              ],
            ),
          ),
      ],
    );
  }
}

// ── Discovery toast banner ────────────────────────────────────────────────────

class _DiscoveryToastBanner extends StatelessWidget {
  const _DiscoveryToastBanner({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = _flagEmoji(code);
    final name = kCountryNames[code] ?? code;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('New Country!', style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            )),
            const SizedBox(width: 8),
            Text('$flag $name', style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Inline scan world map ─────────────────────────────────────────────────────

class _ScanLiveMap extends ConsumerStatefulWidget {
  const _ScanLiveMap({required this.liveNewCodes});
  final List<String> liveNewCodes;

  @override
  ConsumerState<_ScanLiveMap> createState() => _ScanLiveMapState();
}

class _ScanLiveMapState extends ConsumerState<_ScanLiveMap> {
  final _mapController = MapController();
  Timer? _debounceTimer;
  String? _pendingCode;

  @override
  void didUpdateWidget(_ScanLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liveNewCodes.length > oldWidget.liveNewCodes.length) {
      _scheduleCamera(widget.liveNewCodes.last);
    }
  }

  void _scheduleCamera(String code) {
    _pendingCode = code;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _pendingCode == null) return;
      final polygons = ref.read(polygonsProvider);
      final matches = polygons.where((p) => p.isoCode == _pendingCode).toList();
      if (matches.isEmpty) return;
      final allPoints = [
        for (final p in matches)
          for (final (lat, lng) in p.vertices) LatLng(lat, lng),
      ];
      if (allPoints.isEmpty) return;
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
      );
      _pendingCode = null;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    if (polygons.isEmpty) return const SizedBox.shrink();

    final discoveredSet = widget.liveNewCodes.toSet();

    final unvisitedPolygons = polygons
        .where((p) => !discoveredSet.contains(p.isoCode))
        .map((p) => Polygon(
              points: [for (final (lat, lng) in p.vertices) LatLng(lat, lng)],
              color: const Color(0xFF1E3A5F),
            ))
        .toList();

    final visitedPolygons = polygons
        .where((p) => discoveredSet.contains(p.isoCode))
        .map((p) => Polygon(
              points: [for (final (lat, lng) in p.vertices) LatLng(lat, lng)],
              color: const Color(0xFFD4A017),
            ))
        .toList();

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(20, 0),
            initialZoom: 1.5,
            interactionOptions: InteractionOptions(flags: 0),
          ),
          children: [
            ColoredBox(color: const Color(0xFF0D2137)),
            PolygonLayer(polygons: unvisitedPolygons),
            PolygonLayer(polygons: visitedPolygons),
          ],
        ),
      ),
    );
  }
}

class _LiveCountryRow extends StatefulWidget {
  const _LiveCountryRow({required this.isoCode, required this.reduceMotion});

  final String isoCode;
  final bool reduceMotion;

  @override
  State<_LiveCountryRow> createState() => _LiveCountryRowState();
}

class _LiveCountryRowState extends State<_LiveCountryRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flag = _flagEmoji(widget.isoCode);
    final name = kCountryNames[widget.isoCode] ?? widget.isoCode;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns the Unicode flag emoji for a 2-letter ISO country code.
String _flagEmoji(String code) {
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + code.codeUnitAt(0)) +
      String.fromCharCode(base + code.codeUnitAt(1));
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
