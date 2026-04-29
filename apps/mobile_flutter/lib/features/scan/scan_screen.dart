import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:confetti/confetti.dart';
import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/providers.dart';
import '../cards/card_templates.dart';
import '../map/country_centroids.dart';
import '../map/country_visual_state.dart';
import '../map/globe_painter.dart';
import '../map/globe_projection.dart';
import '../xp/xp_event.dart';
import '../../data/achievement_repository.dart';
import '../../data/firestore_sync_service.dart';
import '../../data/region_repository.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';
import '../../photo_scan_channel.dart';
import '../visits/review_screen.dart';
import 'hero_analysis_channel.dart';
import 'hero_analysis_service.dart';
import 'hero_image_repository.dart';
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
  List<EffectiveVisitedCountry> _effectiveVisits = [];
  String? _error;
  _ScanProgress? _scanProgress;

  /// UTC timestamp of the last completed scan, or null if never scanned.
  /// Loaded in [_loadPersisted]; displayed near scan controls.
  DateTime? _lastScanAt;

  /// True after the first successful scan has completed (ADR-110).
  /// Set in [_loadPersisted]; used to gate scan-mode controls and auto-scan.
  bool _hasCompletedFirstScan = false;

  /// When true, [_scan] ignores [lastScanAt] and performs a full scan (M56-14).
  bool _forceFullScan = false;

  /// ISO codes of countries found for the first time during the current scan.
  /// Updated live during the scan loop. (ADR-083)
  final List<String> _liveNewCodes = [];

  /// Snapshot of existing country codes taken at scan start (T1/T2, ADR-130).
  /// Passed to [_ScanningView] so globe and list pre-populate immediately.
  /// Unmodifiable; derived from [_effectiveVisits] before scanning begins.
  List<String> _existingCodesAtScanStart = const [];

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
      final lastScanAt = await _repo.loadLastScanAt();
      if (!mounted) return;
      setState(() {
        _effectiveVisits = visits;
        _hasCompletedFirstScan = lastScanAt != null;
        _lastScanAt = lastScanAt;
        _loading = false;
      });

      // Check permission status silently so the scan button reflects current
      // access without showing a dialog (M78: auto-scan removed — user must
      // explicitly choose Incremental or Full and tap the button).
      if (lastScanAt != null) {
        try {
          final permission = await requestPhotoPermission();
          if (!mounted) return;
          setState(() => _permission = permission);
        } catch (_) {
          // Permission check failed — button stays disabled.
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

    // T1/T2 (ADR-130): capture existing codes for globe + list pre-population.
    // Unmodifiable copy so mid-scan user edits don't mutate the snapshot.
    final existingCodesSnapshot =
        List<String>.unmodifiable(preScanCodes.toList());

    setState(() {
      _scanning = true;
      _error = null;
      _scanProgress = const _ScanProgress(processed: 0);
      _liveNewCodes.clear();
      // T1/T2: expose snapshot to build() immediately (T4: pill shown now).
      _existingCodesAtScanStart = existingCodesSnapshot;
    });

    try {
      // T3 (ADR-129): load all known assetIds once before the batch loop.
      // Photos whose assetId is already recorded are skipped — makes
      // incremental scans robust to restored backups and iCloud imports.
      final knownAssetIds = await _repo.loadAllKnownAssetIds();

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
      var totalProcessed = 0;

      final scanStream = widget.scanStarter != null
          ? widget.scanStarter!(limit: 100000)
          : startPhotoScan(limit: 100000, sinceDate: sinceDate);
      await for (final event in scanStream) {
        if (event is ScanBatchEvent) {
          // T3 (ADR-129): filter out photos already recorded by assetId.
          // Photos with null assetId always pass through (no data loss).
          final filteredPhotos = event.photos
              .where((p) =>
                  p.assetId == null || !knownAssetIds.contains(p.assetId))
              .toList();
          final batchResult = await _resolveBatch(filteredPhotos);
          for (final entry in batchResult.accum.entries) {
            final existing = accum[entry.key];
            accum[entry.key] =
                existing == null ? entry.value : existing.merge(entry.value);
          }
          allPhotoDates.addAll(batchResult.photoDates);
          // Progress counts the raw batch size (pre-filter) so the number
          // reflects photos inspected, not just new ones resolved.
          totalProcessed += event.photos.length;

          // T5 (ADR-130): only codes NOT in preScanCodes are genuinely new.
          // The guard !preScanCodes.contains(code) ensures full-scan and
          // incremental-scan both animate the globe only to new discoveries.
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
        }
      }

      final inferred = accum.entries
          .map((e) => InferredCountryVisit(
                countryCode: e.key,
                inferredAt: preScanTimestamp,
                photoCount: e.value.photoCount,
                firstSeen: e.value.firstSeen,
                lastSeen: e.value.lastSeen,
              ))
          .toList();

      // Full scan rebuilds inferred from scratch; incremental upsert-merges
      // so that countries from before lastScanAt are preserved.
      if (_forceFullScan || sinceDate == null) {
        await _repo.clearAndSaveAllInferred(inferred);
      } else {
        await _repo.saveAllInferred(inferred);
      }
      await _repo.savePhotoDates(allPhotoDates);
      // M56-13: persist pre-scan timestamp (ADR-110).
      await _repo.saveLastScanAt(preScanTimestamp);

      // Re-infer all trips from the full photo date history and persist.
      final allDates = await _repo.loadPhotoDates();
      final inferredTrips = inferTrips(allDates);
      await _tripRepo.upsertAll(inferredTrips);
      await _regionRepo.upsertAll(inferRegionVisits(allDates, inferredTrips));

      // M89: Fire hero image analysis in the background after trips are saved.
      // Fire-and-forget — does not block the scan result screen.
      unawaited(HeroAnalysisService(
        repository: HeroImageRepository(ref.read(roavvyDatabaseProvider)),
        channel: HeroAnalysisChannel(),
      ).runForTrips(
        trips: inferredTrips,
        photoDateRecords: allDates,
      ));

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
      // Compute result summary when geotagged photos were found (ADR-024).
      _ScanResult? scanResult;
      if (effective.isNotEmpty) {
        final postScanCodes = effective.map((v) => v.countryCode).toSet();
        final newCodes = (postScanCodes.difference(preScanCodes)).toList()..sort();
        scanResult = newCodes.isEmpty ? _NothingNew() : _NewCountriesFound(newCodes);
      }

      if (mounted) {
        setState(() {
          _effectiveVisits = effective;
          _hasCompletedFirstScan = true;
          _lastScanAt = preScanTimestamp;
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
          // M90: trip IDs for new countries — passed to best-shot section.
          final newTripIds = inferredTrips
              .where((t) => newCodesSet.contains(t.countryCode))
              .map((t) => t.id)
              .toList();
          final nav = Navigator.of(context);
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => ScanSummaryScreen(
                newCountries: newCountries,
                newAchievementIds: newlyUnlockedIds.toList(),
                newCodes: newCodesList,
                newTripIds: newTripIds,
                onDone: () {
                  nav.pop();
                  widget.onScanComplete?.call();
                },
              ),
            ),
          );
        } else if (scanResult is _NothingNew) {
          // M78: All scan outcomes go through ScanSummaryScreen (T3).
          // State B ("All up to date") handles milestone/level-up checks + Rovy message.
          final nav = Navigator.of(context);
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => ScanSummaryScreen(
                newCountries: const [],
                newAchievementIds: newlyUnlockedIds.toList(),
                newCodes: const [],
                lastScanAt: preScanTimestamp,
                onDone: () {
                  nav.pop();
                  widget.onScanComplete?.call();
                },
              ),
            ),
          );
        }
        // else: effective.isEmpty — no geotagged photos found at all.
        // Stay on scan screen; _EmptyResultsHint is shown when !_scanning.
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanProgress = null;
          _existingCodesAtScanStart = const [];
        });
      }
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
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
                  // Scan mode selector — only visible after the first scan.
                  if (_hasCompletedFirstScan) ...[
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(_lastScanAt != null
                              ? 'New photos (since ${_fmtDate(_lastScanAt!)})'
                              : 'New photos'),
                          icon: const Icon(Icons.update),
                        ),
                        const ButtonSegment(
                          value: true,
                          label: Text('All photos'),
                          icon: Icon(Icons.refresh),
                        ),
                      ],
                      selected: {_forceFullScan},
                      onSelectionChanged: _scanning
                          ? null
                          : (s) => setState(() => _forceFullScan = s.first),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonal(
                    onPressed: (_permission?.canScan == true && !_scanning) ? _scan : null,
                    child: const Text('Scan my photo library'),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) _ErrorView(message: _error!),
                  // Scanning pill: shown immediately when scan starts before first batch arrives.
                  if (_scanning && (_scanProgress?.processed ?? 0) == 0 && _effectiveVisits.isNotEmpty)
                    const _ScanningPill(),
                  // M78: Unified persistent view — globe + country list + stamps always visible
                  // when the user has data. _ScanningView controls its own progress indicator
                  // via isScanning; existingCodes drives pre-population at rest.
                  if (_effectiveVisits.isNotEmpty || _scanning)
                    Expanded(
                      child: _ScanningView(
                        progress: _scanProgress,
                        liveNewCodes: List.unmodifiable(_liveNewCodes),
                        existingCodes: _scanning
                            ? _existingCodesAtScanStart
                            : _effectiveVisits.map((v) => v.countryCode).toList(),
                        isScanning: _scanning,
                      ),
                    )
                  // No data yet paths:
                  else if (_hasCompletedFirstScan) ...[
                    const SizedBox(height: 16),
                    const _EmptyResultsHint(),
                  ] else ...[
                    const SizedBox(height: 16),
                    const _NoScanYetHint(),
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
  const _ScanningView({
    this.progress,
    this.liveNewCodes = const [],
    this.existingCodes = const [],
    this.isScanning = false,
  });

  final _ScanProgress? progress;

  /// ISO codes of countries found for the first time during this scan.
  /// Updated in real time as each batch is processed. (ADR-083)
  final List<String> liveNewCodes;

  /// ISO codes of countries already known before this scan started (ADR-130).
  /// Used to pre-populate the globe and country list immediately.
  final List<String> existingCodes;

  /// Whether a scan is currently in progress. Controls progress indicator
  /// and count text visibility — false at rest (M78).
  final bool isScanning;

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
    _burstCooldown = Timer(const Duration(seconds: 8), () {});
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
            if (widget.isScanning) ...[
              const LinearProgressIndicator(value: null),
              const SizedBox(height: 6),
              Text(
                processed > 0 ? '$processed photos processed\u2026' : 'Starting scan\u2026',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
            ],
            // Animated globe — always visible (M78).
            _ScanGlobeWidget(
              liveNewCodes: widget.liveNewCodes,
              existingCodes: widget.existingCodes,
            ),
            const SizedBox(height: 8),
            // Two-panel: country list (left) | passport preview (right).
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LiveCountryList(
                      liveNewCodes: widget.liveNewCodes,
                      existingCodes: widget.existingCodes,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  Container(width: 1, color: theme.dividerColor),
                  Expanded(
                    child: _ScanPassportPreview(
                      liveNewCodes: widget.liveNewCodes,
                      existingCodes: widget.existingCodes,
                    ),
                  ),
                ],
              ),
            ),
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
        if (_confettiCtrl != null && !reduceMotion)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl!,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.6,
              numberOfParticles: 8,
              gravity: 0.1,
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

// ── Scanning pill (T4, ADR-130) ───────────────────────────────────────────────

/// Subtle "Scanning your library…" pill shown immediately when an auto-scan
/// starts (before the first batch arrives). Gives instant visual feedback
/// so the user knows scanning is in progress even before the globe populates.
class _ScanningPill extends StatelessWidget {
  const _ScanningPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Scanning your library\u2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

// ── Animated globe for scan-in-progress screen ────────────────────────────────

/// Spinning globe widget shown during scanning.
///
/// When [liveNewCodes] grows by one, the globe smoothly animates to that
/// country's centroid and zooms in so the full country is visible. The newest
/// country is rendered as [CountryVisualState.newlyDiscovered] (bright gold);
/// all previously found countries are [CountryVisualState.visited] (depth gold).
/// A soft pulsing halo sits over the newest country's centroid.
///
/// [existingCodes] are countries known before this scan; they are shown in
/// [CountryVisualState.visited] from the start with no animation (ADR-130).
class _ScanGlobeWidget extends ConsumerStatefulWidget {
  const _ScanGlobeWidget({
    required this.liveNewCodes,
    this.existingCodes = const [],
  });
  final List<String> liveNewCodes;

  /// ISO codes already known before this scan. Pre-populate the globe without
  /// triggering travel animations (ADR-130).
  final List<String> existingCodes;

  @override
  ConsumerState<_ScanGlobeWidget> createState() => _ScanGlobeWidgetState();
}

class _ScanGlobeWidgetState extends ConsumerState<_ScanGlobeWidget>
    with TickerProviderStateMixin {
  // Current rendered projection.
  GlobeProjection _projection = const GlobeProjection(scale: 1.0);

  // Animation driving globe travel to a new country.
  AnimationController? _travelCtrl;
  Animation<double>? _travelAnim;

  // Animation that zooms back out after arriving at a country.
  AnimationController? _zoomOutCtrl;

  // Slow idle spin when no country update is in flight.
  late final AnimationController _spinCtrl;

  // Pulse halo for the newest country.
  late final AnimationController _pulseCtrl;

  // Projection at the start of the last travel animation.
  GlobeProjection _fromProjection = const GlobeProjection(scale: 1.0);
  // Target projection for the current travel animation.
  GlobeProjection _toProjection = const GlobeProjection(scale: 1.0);

  // ISO code of the country currently highlighted (newest).
  String? _highlightedCode;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ScanGlobeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liveNewCodes.length > oldWidget.liveNewCodes.length) {
      _travelTo(widget.liveNewCodes.last);
    }
  }

  void _travelTo(String code) {
    final centroid = kCountryCentroids[code];
    final targetLat = centroid != null ? centroid.$1 * math.pi / 180.0 : 0.0;
    final targetLng = centroid != null ? centroid.$2 * math.pi / 180.0 : 0.0;

    const zoomInScale = 1.4;
    final departureScale = _projection.scale;

    // Cancel any in-progress zoom-out before starting a new travel.
    _zoomOutCtrl?.dispose();
    _zoomOutCtrl = null;

    _fromProjection = _projection;
    final dLng = _angularDelta(_fromProjection.rotLng, -targetLng);
    // rotLat = +targetLat (positive) centres the country vertically.
    // rotLng targets -targetLng via the shortest arc.
    _toProjection = GlobeProjection(
      rotLat: targetLat,
      rotLng: _fromProjection.rotLng + dLng,
      scale: zoomInScale,
    );

    _travelCtrl?.dispose();
    _travelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _travelAnim = CurvedAnimation(
      parent: _travelCtrl!,
      curve: Curves.easeInOut,
    );

    _travelCtrl!.addListener(() {
      if (!mounted) return;
      final t = _travelAnim!.value;
      setState(() {
        _projection = GlobeProjection(
          rotLat: _lerpDouble(_fromProjection.rotLat, _toProjection.rotLat, t),
          rotLng: _lerpDouble(_fromProjection.rotLng, _toProjection.rotLng, t),
          scale: _lerpDouble(departureScale, zoomInScale, t),
        );
      });
    });

    _travelCtrl!.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      setState(() => _projection = _toProjection);

      // Phase 2: zoom back out to normal scale.
      final lockedLat = _toProjection.rotLat;
      final lockedLng = _toProjection.rotLng;
      _zoomOutCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      final zoomAnim = CurvedAnimation(
        parent: _zoomOutCtrl!,
        curve: Curves.easeOut,
      );
      _zoomOutCtrl!.addListener(() {
        if (!mounted) return;
        setState(() {
          _projection = GlobeProjection(
            rotLat: lockedLat,
            rotLng: lockedLng,
            scale: _lerpDouble(zoomInScale, 1.0, zoomAnim.value),
          );
        });
      });
      _zoomOutCtrl!.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() {
            _projection = GlobeProjection(
              rotLat: lockedLat,
              rotLng: lockedLng,
              scale: 1.0,
            );
          });
        }
      });
      _zoomOutCtrl!.forward();
    });

    setState(() => _highlightedCode = code);
    _travelCtrl!.forward();
  }

  /// Angular delta from [from] to [to], clamped to [−π, π].
  double _angularDelta(double from, double to) {
    var d = to - from;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _travelCtrl?.dispose();
    _zoomOutCtrl?.dispose();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = ref.watch(polygonsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Build visual states (ADR-130):
    // - existingCodes (known before scan) → visited (muted gold), no animation.
    // - liveNewCodes (found this scan)    → visited, upgraded to newlyDiscovered
    //   for the highlighted (most recent) code.
    final visualStates = <String, CountryVisualState>{};
    for (final code in widget.existingCodes) {
      visualStates[code] = CountryVisualState.visited;
    }
    for (final code in widget.liveNewCodes) {
      visualStates[code] = CountryVisualState.visited;
    }
    if (_highlightedCode != null) {
      visualStates[_highlightedCode!] = CountryVisualState.newlyDiscovered;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_spinCtrl, _pulseCtrl]),
      builder: (context, _) {
        // Compute inside builder so values update every animation tick.
        final isIdle = (_travelCtrl == null || !_travelCtrl!.isAnimating) &&
            (_zoomOutCtrl == null || !_zoomOutCtrl!.isAnimating);
        final displayProjection = (isIdle && !reduceMotion)
            ? GlobeProjection(
                rotLat: _projection.rotLat,
                rotLng: _projection.rotLng + _spinCtrl.value * 0.3,
                scale: _projection.scale,
              )
            : _projection;
        final pulseValue = reduceMotion ? 0.0 : _pulseCtrl.value;

        return SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: GlobePainter(
                polygons: polygons,
                visualStates: visualStates,
                tripCounts: const {},
                projection: displayProjection,
                highlightedCode: _highlightedCode,
                pulseValue: pulseValue,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

// ── Left panel: growing country list ─────────────────────────────────────────

class _LiveCountryList extends StatelessWidget {
  const _LiveCountryList({
    required this.liveNewCodes,
    required this.reduceMotion,
    this.existingCodes = const [],
  });
  final List<String> liveNewCodes;
  final bool reduceMotion;

  /// ISO codes already known before this scan (ADR-130). Shown in a muted
  /// "already visited" style without animation. Rendered above new discoveries.
  final List<String> existingCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExisting = existingCodes.isNotEmpty;
    final hasNew = liveNewCodes.isNotEmpty;

    if (!hasExisting && !hasNew) {
      return const Center(
        child: Text(
          'Countries will appear here\u2026',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        // Existing countries — muted, no animation.
        for (final code in existingCodes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Text(
                  _flagEmoji(code),
                  style: const TextStyle(fontSize: 20, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kCountryNames[code] ?? code,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        // Divider between sections when both are populated.
        if (hasExisting && hasNew)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1),
          ),
        // New discoveries — animated slide-in.
        for (final code in liveNewCodes)
          _LiveCountryRow(isoCode: code, reduceMotion: reduceMotion),
      ],
    );
  }
}

// ── Right panel: live passport stamp preview ──────────────────────────────────

class _ScanPassportPreview extends StatelessWidget {
  const _ScanPassportPreview({
    required this.liveNewCodes,
    this.existingCodes = const [],
  });
  final List<String> liveNewCodes;

  /// Countries already visited before this scan — shown in stamp grid
  /// alongside newly discovered ones (M78, T2).
  final List<String> existingCodes;

  @override
  Widget build(BuildContext context) {
    final allCodes = [...existingCodes, ...liveNewCodes];
    if (allCodes.isEmpty) {
      return const Center(
        child: Text(
          'Stamp preview',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final ratio = (h > 0 && h.isFinite) ? w / h : 3.0 / 2.0;
        return PassportStampsCard(
          countryCodes: allCodes,
          aspectRatio: ratio,
          trips: const [],
          entryOnly: true,
        );
      },
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

