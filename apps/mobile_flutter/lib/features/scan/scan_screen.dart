import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:country_lookup/country_lookup.dart';
import 'package:region_lookup/region_lookup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/country_names.dart';
import '../../core/flag_colours.dart';
import '../../core/globe_overlay.dart';
import '../../core/providers.dart';
import '../map/country_centroids.dart';
import '../map/country_visual_state.dart';
import '../map/globe_painter.dart';
import '../map/globe_projection.dart';
import '../xp/xp_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notification_service.dart';
import '../../data/achievement_repository.dart';
import '../../data/firestore_sync_service.dart';
import '../../data/heritage_repository.dart';
import '../../data/region_repository.dart';
import '../../data/trip_repository.dart';
import '../../data/visit_repository.dart';
import '../merch/merch_exclusive_design.dart';
import '../heritage/world_heritage_lookup_service.dart';
import '../../photo_scan_channel.dart';
import '../visits/review_screen.dart';
import 'hero_analysis_channel.dart';
import 'scan_audio_controller.dart';
import '../globe_replay/live_scan_replay_controller.dart';
import '../globe_replay/replay_data_source.dart';
import '../globe_replay/travel_replay_controller.dart';
import 'live_scan_replay_data_source.dart';
import 'hero_analysis_service.dart';
import 'hero_image_repository.dart';
import 'scan_summary_screen.dart';

// ── Background isolate helpers ─────────────────────────────────────────────────

/// Per-country accumulator used during batch processing.
///
/// Public so widget tests can inject predetermined results via [ScanScreen.batchResolver].
class CountryAccum {
  const CountryAccum({required this.photoCount, this.firstSeen, this.lastSeen});

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

/// Raw GPS record for a single photo, retained in-memory during scan to
/// populate trip GPS endpoints (ADR-157). Never persisted directly.
class PhotoGpsRecord {
  const PhotoGpsRecord({
    required this.countryCode,
    required this.capturedAt,
    required this.lat,
    required this.lng,
  });

  final String countryCode;
  final DateTime capturedAt;

  /// Raw (unbucketed) latitude — preserved for replay arc accuracy (M109).
  final double lat;

  /// Raw (unbucketed) longitude.
  final double lng;
}

/// Result of resolving a batch of [PhotoRecord]s.
///
/// Contains the per-country [accum] aggregates (for [InferredCountryVisit]
/// upsert), the individual [photoDates] (for trip inference via [inferTrips]),
/// and [photoGps] (raw GPS records for trip endpoint extraction, ADR-157).
class BatchResult {
  const BatchResult({
    required this.accum,
    required this.photoDates,
    required this.photoGps,
  });

  final Map<String, CountryAccum> accum;

  /// One record per photo that had a non-null [PhotoRecord.capturedAt] and a
  /// successfully resolved country code.
  final List<PhotoDateRecord> photoDates;

  /// Raw GPS per photo — used to extract first/last GPS endpoints per trip.
  /// Only photos with a resolved country code and non-null [capturedAt] are
  /// included. Never persisted; discarded after [_extractTripGps] runs.
  final List<PhotoGpsRecord> photoGps;
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
  String? Function(double lat, double lng)? regionResolver,
]) {
  final accum = <String, CountryAccum>{};
  final photoDates = <PhotoDateRecord>[];
  final photoGps = <PhotoGpsRecord>[];
  // Per-bucket caches so each unique 0.1° cell calls each resolver once.
  // 0.1° ≈ 11 km — small enough that a cell rarely straddles two countries,
  // large enough to provide meaningful cache benefit across a city's photos.
  // The resolver is always called with the bucket CENTRE, not the first
  // photo's exact coords, so the cached country is consistent for the cell
  // regardless of which photo is processed first (fixes border misassignment).
  final countryBucketCache = <(double, double), String?>{};
  final regionBucketCache = <(double, double), String?>{};

  for (final photo in photos) {
    final bucketLat = (photo.lat * 10).roundToDouble() / 10;
    final bucketLng = (photo.lng * 10).roundToDouble() / 10;
    final key = (bucketLat, bucketLng);
    final code = countryBucketCache.putIfAbsent(
      key,
      () => countryResolver(bucketLat, bucketLng),
    );
    if (code == null) continue;

    // Only count photos that have both a GPS fix AND a capture date.
    // Photos with GPS but no capturedAt cannot contribute to trip inference
    // or the photo gallery, so including them in accum would create ghost
    // country records (visited with 0 trips / 0 photos in the profile).
    if (photo.capturedAt == null) continue;

    final a = CountryAccum(
      photoCount: 1,
      firstSeen: photo.capturedAt,
      lastSeen: photo.capturedAt,
    );
    final existing = accum[code];
    accum[code] = existing == null ? a : existing.merge(a);

    final regionCode =
        regionResolver != null
            ? regionBucketCache.putIfAbsent(
              key,
              () => regionResolver(bucketLat, bucketLng),
            )
            : null;
    photoDates.add(
      PhotoDateRecord(
        countryCode: code,
        capturedAt: photo.capturedAt!,
        regionCode: regionCode,
        assetId: photo.assetId,
      ),
    );
    // Track raw GPS for trip endpoint extraction (ADR-157).
    photoGps.add(
      PhotoGpsRecord(
        countryCode: code,
        capturedAt: photo.capturedAt!,
        lat: photo.lat,
        lng: photo.lng,
      ),
    );
  }

  return BatchResult(accum: accum, photoDates: photoDates, photoGps: photoGps);
}

/// Top-level function — safe to pass to [Isolate.run].
///
/// Initialises [country_lookup] and [region_lookup] in the background isolate
/// (each isolate has independent global state) then delegates to [resolveBatch].
BatchResult _resolvePhotos(
  Uint8List countryBytes,
  Uint8List regionBytes,
  List<PhotoRecord> photos,
) {
  initCountryLookup(countryBytes);
  initRegionLookup(regionBytes);
  return resolveBatch(photos, resolveCountry, resolveRegion);
}

// ── Trip GPS enrichment (M109, ADR-157) ────────────────────────────────────────

/// Applies GPS endpoints from [photoGps] to each trip in [trips].
///
/// For each trip, finds all [PhotoGpsRecord] items whose country code matches
/// and whose [capturedAt] falls within `trip.startedOn..trip.endedOn`. The
/// first and last of these (chronologically) provide the GPS endpoints.
///
/// Returns a new list; trips with no matching GPS records are returned
/// unchanged (GPS fields remain null — centroid fallback applies at replay).
List<TripRecord> _applyTripGps(
  List<TripRecord> trips,
  List<PhotoGpsRecord> photoGps,
) {
  if (trips.isEmpty || photoGps.isEmpty) return trips;

  // Sort GPS records once ascending by capturedAt.
  final sorted = [...photoGps]
    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

  return trips.map((trip) {
    final inWindow =
        sorted
            .where(
              (g) =>
                  g.countryCode == trip.countryCode &&
                  !g.capturedAt.isBefore(trip.startedOn) &&
                  !g.capturedAt.isAfter(trip.endedOn),
            )
            .toList();

    if (inWindow.isEmpty) return trip;

    final first = inWindow.first;
    final last = inWindow.last;
    return TripRecord(
      id: trip.id,
      countryCode: trip.countryCode,
      startedOn: trip.startedOn,
      endedOn: trip.endedOn,
      photoCount: trip.photoCount,
      isManual: trip.isManual,
      firstLat: first.lat,
      firstLng: first.lng,
      lastLat: last.lat,
      lastLng: last.lng,
    );
  }).toList();
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
    this.autoStart = false,
    this.initialForceFullScan = false,
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

  /// When true, [_ScanScreenState] automatically starts the scan after
  /// persisted state is loaded — no user interaction required.
  /// Used when scan is triggered from the [MapScreen] action bar.
  final bool autoStart;

  /// When true, forces a full scan regardless of [lastScanAt].
  /// Applied at startup before auto-scan begins.
  final bool initialForceFullScan;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  SyncService get _syncService => widget.syncService ?? FirestoreSyncService();

  late final VisitRepository _repo;
  late final AchievementRepository _achievementRepo;
  late final TripRepository _tripRepo;
  late final RegionRepository _regionRepo;
  late final HeritageRepository _heritageRepo;

  PhotoPermissionStatus? _permission;
  bool _loading = true;
  bool _scanning = false;
  bool _cancelled = false;
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

  /// Countries found for the first time during the current scan.
  /// Updated live during the scan loop. (ADR-083, M121)
  final List<_DiscoveryEntry> _liveNewEntries = [];

  /// Snapshot of existing countries taken at scan start (T1/T2, ADR-130, M121).
  /// Passed to [_ScanningView] so globe and list pre-populate immediately.
  /// Unmodifiable; derived from [_effectiveVisits] before scanning begins.
  List<_DiscoveryEntry> _existingEntriesAtScanStart = const [];

  /// Number of unique heritage sites found so far in the current scan (T2, M123).
  /// Updated live from [whsAccum.length] in the scan loop. Reset at scan start.
  int _liveHeritageCount = 0;

  /// Country-count achievement IDs unlocked so far in this scan, in order (T1, M125).
  /// Passed to [_ScanningView] to fire toast banners in real time.
  final List<String> _achievementsUnlockedInOrder = [];

  /// Deduplication guard — prevents the same achievement from firing twice per scan.
  final Set<String> _achievementsToastedThisScan = {};

  /// Inferred trip count from accumulated photo dates, updated each batch (T2, M125).
  int _liveTripCount = 0;

  /// Heritage sites discovered so far in this scan — full objects for
  /// colour-coding (cultural=amber, natural=green) and tap-tooltip (M128).
  List<VisitedHeritageSite> _liveHeritageSites = const [];

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repo = ref.read(visitRepositoryProvider);
    _achievementRepo = ref.read(achievementRepositoryProvider);
    _tripRepo = ref.read(tripRepositoryProvider);
    _regionRepo = ref.read(regionRepositoryProvider);
    _heritageRepo = ref.read(heritageRepositoryProvider);
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    try {
      final visits = await _repo.loadEffective();
      final lastScanAt = await _repo.loadLastScanAt();
      if (!mounted) return;
      if (widget.initialForceFullScan) _forceFullScan = true;
      setState(() {
        _effectiveVisits = visits;
        _hasCompletedFirstScan = lastScanAt != null;
        _lastScanAt = lastScanAt;
        _loading = false;
      });
      // In autoStart mode, request permission before starting the scan.
      // On a fresh install _permission is null/notDetermined; calling
      // requestPhotoPermission() first ensures a single iOS dialog appears
      // and the native scan channel gets access immediately — avoiding the
      // race condition where two concurrent permission calls freeze the scan.
      if (widget.autoStart) {
        try {
          final permission = await requestPhotoPermission();
          if (!mounted) return;
          setState(() => _permission = permission);
        } catch (_) {
          // Permission check failed — leave _permission as-is.
        }
      }

      // Auto-start scan when triggered from the main-screen action bar.
      // Only skip if the user explicitly denied or restricted access.
      if (widget.autoStart &&
          _permission != PhotoPermissionStatus.denied &&
          _permission != PhotoPermissionStatus.restricted) {
        unawaited(_scan());
      }

      // For non-autoStart screens with a prior scan: check permission silently
      // so the scan button reflects current access without showing a dialog.
      if (!widget.autoStart && lastScanAt != null) {
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
    // Capture navigator before any async gap.
    final nav = Navigator.of(context);

    // Snapshot before scan starts to diff new countries afterwards (ADR-024).
    final preScanCodes = _effectiveVisits.map((v) => v.countryCode).toSet();

    // T1/T2 (ADR-130, M121): capture existing entries for globe + feed pre-population.
    // Unmodifiable copy so mid-scan user edits don't mutate the snapshot.
    final existingEntriesSnapshot = List<_DiscoveryEntry>.unmodifiable(
      _effectiveVisits
          .map(
            (v) => _DiscoveryEntry(
              isoCode: v.countryCode,
              photoCount: v.photoCount,
              firstSeenYear: v.firstSeen?.year,
            ),
          )
          .toList(),
    );

    setState(() {
      _scanning = true;
      _error = null;
      _scanProgress = const _ScanProgress(processed: 0);
      _liveNewEntries.clear();
      _liveHeritageCount = 0;
      _achievementsUnlockedInOrder.clear();
      _liveTripCount = 0;
      _liveHeritageSites = const [];
      // Pre-populate with thresholds already satisfied by existing countries
      // so we only toast achievements that are NEW during this scan (T1, M125).
      _achievementsToastedThisScan
        ..clear()
        ..addAll(
          _kAchievementThresholds
              .where((t) => existingEntriesSnapshot.length >= t)
              .map((t) => 'countries_$t'),
        );
      // T1/T2: expose snapshot to build() immediately (T4: pill shown now).
      _existingEntriesAtScanStart = existingEntriesSnapshot;
    });

    // M132: push live replay immediately so the user watches their travels
    // unfold in real time as batches arrive. The replay and the scan run
    // concurrently; liveSource bridges them.
    TravelReplayController.setCentroids(kCountryCentroids);
    LiveScanReplayController.setCentroids(kCountryCentroids);
    final liveSource = LiveScanReplayDataSource();

    // Mutable closure variable set just before liveSource.markScanComplete()
    // so that onScanComplete can push the correct ScanSummaryScreen.
    ScanSummaryScreen Function()? buildSummary;

    // M134: show animation via MainShell overlay instead of pushing a route.
    // This lets the animation run on the main-screen globe without a navigator
    // transition. The overlay is dismissed when the scan replay drains, then
    // the summary screen is pushed from ScanScreen's own navigator context.
    ref
        .read(globeOverlayProvider.notifier)
        .showScan(
          liveSource,
          initialCollectedCodes:
              _forceFullScan
                  ? const []
                  : _existingEntriesAtScanStart.map((e) => e.isoCode).toList(),
          onScanComplete: () {
            ref.read(globeOverlayProvider.notifier).hide();
            final factory = buildSummary;
            if (factory != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  nav.push(MaterialPageRoute<void>(builder: (_) => factory()));
              });
            } else if (mounted) {
              // Nothing new found: pop ScanScreen back to map.
              nav.pop();
            }
          },
        );

    // M132: live-replay trip tracking state.
    // Trips are emitted as completed (stable) legs in chronological order so
    // the globe replay mirrors the historical replay exactly — every trip,
    // not just new countries.
    String? liveLastCountry;
    final liveEmittedYears = <int>{};
    final liveEmittedHeritageSiteIds = <String>{};
    var liveStableTripCount = 0;

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

      // M132: live replay achievement tracking — start empty so achievements
      // fire in order as countries accumulate, matching the historical replay.
      var liveSeenCountryCodes = <String>{};
      var liveSeenAchievementIds = <String>{};
      // M133: track countries seen in replay so far for first-visit detection.
      final liveFirstVisitCodes = <String>{};

      final accum = <String, CountryAccum>{};
      final allPhotoDates = <PhotoDateRecord>[];
      final allPhotoGps = <PhotoGpsRecord>[];
      var totalProcessed = 0;

      // M119: WHS accumulator keyed by siteId; merged across all batches.
      final whsAccum = <String, VisitedHeritageSite>{};
      // Snapshot of already-visited siteIds for new-discovery detection.
      final preScanHeritageSiteIds =
          (await _heritageRepo.loadAll()).map((s) => s.siteId).toSet();

      final scanStream =
          widget.scanStarter != null
              ? widget.scanStarter!(limit: 100000)
              : startPhotoScan(limit: 100000, sinceDate: sinceDate);
      await for (final event in scanStream) {
        if (_cancelled) break;
        if (event is ScanBatchEvent) {
          // T3 (ADR-129): filter out photos already recorded by assetId.
          // Photos with null assetId always pass through (no data loss).
          final filteredPhotos =
              event.photos
                  .where(
                    (p) =>
                        p.assetId == null || !knownAssetIds.contains(p.assetId),
                  )
                  .toList();
          final batchResult = await _resolveBatch(filteredPhotos);
          for (final entry in batchResult.accum.entries) {
            final existing = accum[entry.key];
            accum[entry.key] =
                existing == null ? entry.value : existing.merge(entry.value);
          }
          allPhotoDates.addAll(batchResult.photoDates);
          // ADR-157 fix: GPS must cover ALL photos in the batch (including
          // previously-known ones filtered by T3) so that trip endpoints use
          // actual photo coordinates rather than country centroids. The T3
          // filter guards accum and photoDates only — GPS collection is exempt.
          final gpsSource =
              filteredPhotos.length < event.photos.length
                  ? await _resolveBatch(event.photos)
                  : batchResult;
          allPhotoGps.addAll(gpsSource.photoGps);

          // M119: WHS lookup — fast in-memory, no isolate needed (ADR-163).
          if (gpsSource.photoGps.isNotEmpty) {
            final gpsRecords =
                gpsSource.photoGps
                    .map((r) => (r.lat, r.lng, r.countryCode))
                    .toList();
            final whsMatches = WorldHeritageLookupService.findBatch(gpsRecords);
            for (int i = 0; i < whsMatches.length; i++) {
              final match = whsMatches[i];
              if (match == null) continue;
              final gps = gpsSource.photoGps[i];
              final siteId = match.site.siteId;
              final existing = whsAccum[siteId];
              if (existing == null) {
                whsAccum[siteId] = VisitedHeritageSite(
                  siteId: siteId,
                  name: match.site.name,
                  countryCode: match.site.countryCode,
                  category: match.site.category,
                  latitude: match.site.latitude,
                  longitude: match.site.longitude,
                  inscriptionYear: match.site.inscriptionYear,
                  firstSeen: gps.capturedAt,
                  lastSeen: gps.capturedAt,
                  photoCount: 1,
                  confidence: match.confidence,
                  nearestDistanceKm: match.distanceKm,
                );
              } else {
                whsAccum[siteId] = existing.copyWith(
                  firstSeen:
                      gps.capturedAt.isBefore(existing.firstSeen)
                          ? gps.capturedAt
                          : existing.firstSeen,
                  lastSeen:
                      gps.capturedAt.isAfter(existing.lastSeen)
                          ? gps.capturedAt
                          : existing.lastSeen,
                  photoCount: existing.photoCount + 1,
                  confidence:
                      (existing.confidence == 'strong' ||
                              match.confidence == 'strong')
                          ? 'strong'
                          : 'nearby',
                  nearestDistanceKm: math.min(
                    existing.nearestDistanceKm,
                    match.distanceKm,
                  ),
                );
              }
            }
          }

          // Progress counts the raw batch size (pre-filter) so the number
          // reflects photos inspected, not just new ones resolved.
          totalProcessed += event.photos.length;

          // T5 (ADR-130, M121): only codes NOT in preScanCodes are genuinely new.
          // The guard ensures full-scan and incremental-scan both animate the
          // globe only to new discoveries. Build _DiscoveryEntry with accum data.
          final existingEntryCodes =
              _liveNewEntries.map((e) => e.isoCode).toSet();
          for (final entry in batchResult.accum.entries) {
            final code = entry.key;
            if (!preScanCodes.contains(code) &&
                !existingEntryCodes.contains(code)) {
              _liveNewEntries.add(
                _DiscoveryEntry(
                  isoCode: code,
                  photoCount: entry.value.photoCount,
                  firstSeenYear: entry.value.firstSeen?.year,
                  heritageSiteNames:
                      whsAccum.values
                          .where((s) => s.countryCode == code)
                          .map((s) => s.name)
                          .toList(),
                ),
              );
            }
          }

          if (mounted) {
            setState(() {
              _scanProgress = _ScanProgress(
                processed: totalProcessed,
                countriesFound: _liveNewEntries.length,
              );
              // _liveNewEntries is updated in-place; setState triggers rebuild.
              // Update live heritage count from whsAccum (T2, M123).
              _liveHeritageCount = whsAccum.length;
              // T1, M125: detect country-count achievement unlocks live.
              final totalCountries =
                  _liveNewEntries.length + _existingEntriesAtScanStart.length;
              for (final threshold in _kAchievementThresholds) {
                final id = 'countries_$threshold';
                if (totalCountries >= threshold &&
                    !_achievementsToastedThisScan.contains(id)) {
                  _achievementsToastedThisScan.add(id);
                  _achievementsUnlockedInOrder.add(id);
                }
              }
              // T2, M125: live trip count from in-memory inference.
              _liveTripCount = inferTrips(allPhotoDates).length;
              // T1, M126/M128: thread heritage sites for colour-coded globe dots.
              _liveHeritageSites = whsAccum.values.toList();
            });
          }

          // M132 (redesigned): emit completed trips as replay legs so the live
          // globe replay is structurally identical to the historical replay —
          // every trip in chronological order, not just new countries.
          //
          // Since photos arrive oldest-first (ascending: true in Swift), all
          // trips in inferTrips(allPhotoDates) except the last are "stable"
          // (the scan has moved past them and they won't grow further).
          // The last trip is still open — more photos might extend it.
          final batchTrips = inferTrips(allPhotoDates);
          final newStableCount =
              batchTrips.length > 1 ? batchTrips.length - 1 : 0;

          for (var i = liveStableTripCount; i < newStableCount; i++) {
            final trip = batchTrips[i];
            final toCode = trip.countryCode;
            final from = liveLastCountry ?? toCode;

            // Year banner when the year changes.
            if (liveEmittedYears.add(trip.startedOn.year)) {
              liveSource.addEvent(YearStartedEvent(year: trip.startedOn.year));
            }

            // Leg: previous country → this country (skip self-loops).
            if (from != toCode) {
              final fromGps =
                  allPhotoGps.where((g) => g.countryCode == from).toList()
                    ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
              final toGps =
                  allPhotoGps
                      .where(
                        (g) =>
                            g.countryCode == toCode &&
                            !g.capturedAt.isBefore(trip.startedOn),
                      )
                      .toList()
                    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
              liveSource.addEvent(
                CountryDiscoveredEvent(
                  fromCode: from,
                  toCode: toCode,
                  date: trip.startedOn,
                  fromLat: fromGps.isNotEmpty ? fromGps.first.lat : null,
                  fromLng: fromGps.isNotEmpty ? fromGps.first.lng : null,
                  toLat: toGps.isNotEmpty ? toGps.first.lat : null,
                  toLng: toGps.isNotEmpty ? toGps.first.lng : null,
                  isFirstVisit: liveFirstVisitCodes.add(toCode),
                ),
              );
            }
            liveLastCountry = toCode;

            // Heritage overlays — deduplicated across batches.
            for (final entry in whsAccum.entries.where(
              (e) => e.value.countryCode == toCode,
            )) {
              if (liveEmittedHeritageSiteIds.add(entry.key)) {
                liveSource.addEvent(
                  HeritageSiteDiscoveredEvent(
                    countryCode: toCode,
                    siteName: entry.value.name,
                    siteType: entry.value.category,
                  ),
                );
              }
            }

            // Achievement overlays: fire when this trip's country tips a new
            // threshold that wasn't already unlocked before the scan.
            liveSeenCountryCodes.add(toCode);
            final nowUnlocked = AchievementEngine.evaluate(
              liveSeenCountryCodes
                  .map(
                    (c) => EffectiveVisitedCountry(
                      countryCode: c,
                      hasPhotoEvidence: true,
                    ),
                  )
                  .toList(),
              tripCount: i + 1,
            );
            final newlyUnlocked = nowUnlocked.difference(
              liveSeenAchievementIds,
            );
            liveSeenAchievementIds = nowUnlocked;
            for (final id in newlyUnlocked) {
              final achievement =
                  kAchievements.where((a) => a.id == id).firstOrNull;
              if (achievement != null) {
                liveSource.addEvent(
                  AchievementUnlockedEvent(
                    achievementId: id,
                    title: achievement.title,
                    subtitle: achievement.description,
                    countryCode: toCode,
                  ),
                );
              }
            }
          }
          liveStableTripCount = newStableCount;

          // Progress update for "Scanning live…" chip.
          liveSource.addEvent(
            ScanProgressUpdatedEvent(processedCount: totalProcessed),
          );
        }
      }

      final inferred =
          accum.entries
              .map(
                (e) => InferredCountryVisit(
                  countryCode: e.key,
                  inferredAt: preScanTimestamp,
                  photoCount: e.value.photoCount,
                  firstSeen: e.value.firstSeen,
                  lastSeen: e.value.lastSeen,
                ),
              )
              .toList();

      // Full scan merges with fresh photo counts; incremental upsert-merges
      // accumulate counts. Neither path deletes countries not found in this run
      // so history from previous scans is always preserved.
      if (_forceFullScan || sinceDate == null) {
        await _repo.mergeFullScanInferred(inferred);
      } else {
        await _repo.saveAllInferred(inferred);
      }
      await _repo.savePhotoDates(allPhotoDates);
      // M56-13: persist pre-scan timestamp (ADR-110).
      await _repo.saveLastScanAt(preScanTimestamp);

      // Re-infer all trips from the full photo date history and persist.
      final allDates = await _repo.loadPhotoDates();
      // Load existing GPS before re-inferring so incremental scans do not
      // overwrite previously-stored GPS coordinates with null (ADR-157 fix).
      // On an incremental scan allPhotoGps only contains new photos, so trips
      // not covered by this batch would lose their GPS without this fallback.
      final existingGps = {
        for (final t in await _tripRepo.loadAll())
          if (t.firstLat != null || t.lastLat != null) t.id: t,
      };
      final rawTrips = inferTrips(allDates);
      // M109: enrich inferred trips with GPS endpoints from scan (ADR-157).
      final withGps = _applyTripGps(rawTrips, allPhotoGps);
      final inferredTrips =
          withGps.map((t) {
            // If this scan batch already provided GPS, use it.
            if (t.firstLat != null || t.lastLat != null) return t;
            // Otherwise preserve previously-stored GPS from the database.
            final prev = existingGps[t.id];
            if (prev == null) return t;
            return TripRecord(
              id: t.id,
              countryCode: t.countryCode,
              startedOn: t.startedOn,
              endedOn: t.endedOn,
              photoCount: t.photoCount,
              isManual: t.isManual,
              firstLat: prev.firstLat,
              firstLng: prev.firstLng,
              lastLat: prev.lastLat,
              lastLng: prev.lastLng,
            );
          }).toList();
      await _tripRepo.upsertAll(inferredTrips);
      await _regionRepo.upsertAll(inferRegionVisits(allDates, inferredTrips));

      // M89: Fire hero image analysis in the background after trips are saved.
      // Fire-and-forget — does not block the scan result screen.
      unawaited(
        HeroAnalysisService(
          repository: HeroImageRepository(ref.read(roavvyDatabaseProvider)),
          channel: HeroAnalysisChannel(),
        ).runForTrips(trips: inferredTrips, photoDateRecords: allDates),
      );

      final effective = await _repo.loadEffective();

      // M119: persist WHS visits and compute newly discovered sites.
      await _heritageRepo.upsertAll(whsAccum.values.toList());
      final newlyDiscoveredHeritageSites =
          whsAccum.values
              .where((s) => !preScanHeritageSiteIds.contains(s.siteId))
              .toList();
      // Invalidate heritage provider so map layer refreshes.
      if (mounted) ref.invalidate(visitedHeritageProvider);

      // Evaluate achievements and persist any newly unlocked ones.
      final priorIds = (await _achievementRepo.loadAll()).toSet();
      final tripCount = (await _tripRepo.loadAll()).length;
      final thisYear = DateTime.now().year;
      final thisYearCount =
          effective.where((v) => v.firstSeen?.year == thisYear).length;
      // M119: pass heritage counts for WHS achievements (ADR-166).
      final heritageCount = await _heritageRepo.loadVisitedCount();
      final heritageByCategory =
          await _heritageRepo.loadVisitedCountByCategory();
      final unlockedIds = AchievementEngine.evaluate(
        effective,
        tripCount: tripCount,
        thisYearCountryCount: thisYearCount,
        heritageCount: heritageCount,
        heritageByCategory: heritageByCategory,
      );
      final newlyUnlockedIds = unlockedIds.difference(priorIds);
      if (newlyUnlockedIds.isNotEmpty) {
        await _achievementRepo.upsertAll(newlyUnlockedIds, preScanTimestamp);
      }

      // Check for newly-unlocked exclusive merch designs (M144, ADR-176).
      unawaited(_checkExclusiveDesignUnlocks(effective));

      // Flush dirty records to Firestore fire-and-forget (ADR-030).
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        unawaited(
          _syncService.flushDirty(
            uid,
            _repo,
            achievementRepo: _achievementRepo,
            tripRepo: _tripRepo,
          ),
        );
      }
      // Compute result summary when geotagged photos were found (ADR-024).
      _ScanResult? scanResult;
      if (effective.isNotEmpty) {
        final postScanCodes = effective.map((v) => v.countryCode).toSet();
        final newCodes =
            (postScanCodes.difference(preScanCodes)).toList()..sort();
        scanResult =
            newCodes.isEmpty ? _NothingNew() : _NewCountriesFound(newCodes);
      }

      if (mounted) {
        setState(() {
          _effectiveVisits = effective;
          _hasCompletedFirstScan = true;
          _lastScanAt = preScanTimestamp;
        });
        ref.invalidate(effectiveVisitsProvider);
        ref.invalidate(tripListProvider); // ADR-081: refresh Journal tab
        ref.invalidate(regionCountProvider); // refresh Stats regions count
        ref.invalidate(countryTripCountsProvider);
        ref.invalidate(earliestVisitYearProvider);

        // Award XP: scan completion + any new countries (fire-and-forget).
        final xpNotifier = ref.read(xpNotifierProvider.notifier);
        unawaited(
          xpNotifier.award(
            XpEvent(
              id: '${preScanTimestamp.microsecondsSinceEpoch}-scan',
              reason: XpReason.scanCompleted,
              amount: 25,
              awardedAt: preScanTimestamp,
            ),
          ),
        );
        if (scanResult is _NewCountriesFound) {
          for (var i = 0; i < scanResult.newCodes.length; i++) {
            unawaited(
              xpNotifier.award(
                XpEvent(
                  id: '${preScanTimestamp.microsecondsSinceEpoch}-country-$i',
                  reason: XpReason.newCountry,
                  amount: 50,
                  awardedAt: preScanTimestamp,
                ),
              ),
            );
          }
        }

        // M132: wire the buildSummary factory before marking scan complete.
        // By the time onScanComplete fires (after replay drains), buildSummary
        // is already set.
        if (scanResult is _NewCountriesFound) {
          final newCodesList = scanResult.newCodes;
          final newCodesSet = newCodesList.toSet();
          final newCountries =
              effective
                  .where((v) => newCodesSet.contains(v.countryCode))
                  .toList();
          final newTripIds =
              inferredTrips
                  .where((t) => newCodesSet.contains(t.countryCode))
                  .map((t) => t.id)
                  .toList();
          final heritageNames =
              newlyDiscoveredHeritageSites.map((s) => s.name).toList();
          final achievementIds = newlyUnlockedIds.toList();
          final tripCount = inferredTrips.length;
          buildSummary =
              () => ScanSummaryScreen(
                newCountries: newCountries,
                newAchievementIds: achievementIds,
                newCodes: newCodesList,
                newTripIds: newTripIds,
                newHeritageSiteNames: heritageNames,
                totalTripCount: tripCount,
                onDone: () {
                  nav.pop(); // pop ScanSummaryScreen
                  nav.pop(); // pop ScanScreen (opaque:false — stays on stack otherwise, blocks all touches)
                  widget.onScanComplete?.call();
                },
              );
        } else if (scanResult is _NothingNew) {
          final achievementIds = newlyUnlockedIds.toList();
          final tripCount = inferredTrips.length;
          buildSummary =
              () => ScanSummaryScreen(
                newCountries: const [],
                newAchievementIds: achievementIds,
                newCodes: const [],
                lastScanAt: preScanTimestamp,
                totalTripCount: tripCount,
                onDone: () {
                  nav.pop(); // pop ScanSummaryScreen
                  nav.pop(); // pop ScanScreen (opaque:false — stays on stack otherwise, blocks all touches)
                  widget.onScanComplete?.call();
                },
              );
        }
        // else: effective.isEmpty — no geotagged photos; onScanComplete just pops.
      }

      // M132: emit any trips that were still "open" (the last trip) when the
      // scan loop finished. Now that scanning is done, all trips are stable.
      final finalTrips = inferTrips(allPhotoDates);
      for (var i = liveStableTripCount; i < finalTrips.length; i++) {
        final trip = finalTrips[i];
        final toCode = trip.countryCode;
        final from = liveLastCountry ?? toCode;

        if (liveEmittedYears.add(trip.startedOn.year)) {
          liveSource.addEvent(YearStartedEvent(year: trip.startedOn.year));
        }

        if (from != toCode) {
          final fromGps =
              allPhotoGps.where((g) => g.countryCode == from).toList()
                ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
          final toGps =
              allPhotoGps
                  .where(
                    (g) =>
                        g.countryCode == toCode &&
                        !g.capturedAt.isBefore(trip.startedOn),
                  )
                  .toList()
                ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
          liveSource.addEvent(
            CountryDiscoveredEvent(
              fromCode: from,
              toCode: toCode,
              date: trip.startedOn,
              fromLat: fromGps.isNotEmpty ? fromGps.first.lat : null,
              fromLng: fromGps.isNotEmpty ? fromGps.first.lng : null,
              toLat: toGps.isNotEmpty ? toGps.first.lat : null,
              toLng: toGps.isNotEmpty ? toGps.first.lng : null,
              isFirstVisit: liveFirstVisitCodes.add(toCode),
            ),
          );
        }
        liveLastCountry = toCode;

        for (final entry in whsAccum.entries.where(
          (e) => e.value.countryCode == toCode,
        )) {
          if (liveEmittedHeritageSiteIds.add(entry.key)) {
            liveSource.addEvent(
              HeritageSiteDiscoveredEvent(
                countryCode: toCode,
                siteName: entry.value.name,
                siteType: entry.value.category,
              ),
            );
          }
        }

        liveSeenCountryCodes.add(toCode);
        final nowUnlocked = AchievementEngine.evaluate(
          liveSeenCountryCodes
              .map(
                (c) => EffectiveVisitedCountry(
                  countryCode: c,
                  hasPhotoEvidence: true,
                ),
              )
              .toList(),
          tripCount: i + 1,
        );
        final newlyUnlocked = nowUnlocked.difference(liveSeenAchievementIds);
        liveSeenAchievementIds = nowUnlocked;
        for (final id in newlyUnlocked) {
          final achievement =
              kAchievements.where((a) => a.id == id).firstOrNull;
          if (achievement != null) {
            liveSource.addEvent(
              AchievementUnlockedEvent(
                achievementId: id,
                title: achievement.title,
                subtitle: achievement.description,
                countryCode: toCode,
              ),
            );
          }
        }
      }

      // M132: signal replay to drain and complete. Must come after buildSummary
      // is set so onScanComplete can push the correct screen.
      liveSource.markScanComplete();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanProgress = null;
          _existingEntriesAtScanStart = const [];
          _liveHeritageCount = 0;
          _liveTripCount = 0;
          _liveHeritageSites = const [];
          _achievementsUnlockedInOrder.clear();
          _achievementsToastedThisScan.clear();
        });
      }
    }
  }

  /// Checks whether any exclusive merch designs just unlocked for the first
  /// time after this scan and fires a local notification (M144, ADR-176).
  ///
  /// Uses [SharedPreferences] key `'exclusive_design_notified_ids'` to ensure
  /// each design notifies the user at most once.
  Future<void> _checkExclusiveDesignUnlocks(
    List<EffectiveVisitedCountry> effective,
  ) async {
    final countryCount = effective.length;
    final continentCount = effective
        .map((v) => kCountryContinent[v.countryCode])
        .whereType<String>()
        .toSet()
        .length;
    final ctx = MerchUnlockContext(
      countryCount: countryCount,
      continentCount: continentCount,
    );

    final prefs = await SharedPreferences.getInstance();
    final notifiedIds =
        prefs.getStringList('exclusive_design_notified_ids') ?? [];

    for (final design in kMerchExclusiveDesigns) {
      if (!design.isUnlocked(ctx)) continue;
      if (notifiedIds.contains(design.id)) continue;
      // Newly unlocked — notify once.
      notifiedIds.add(design.id);
      await prefs.setStringList('exclusive_design_notified_ids', notifiedIds);
      await NotificationService.instance.notifyExclusiveDesignUnlocked(
        designLabel: design.label,
      );
      break; // One notification per scan to avoid spam
    }
  }

  /// Country-count thresholds that unlock achievements (T1, M125).
  /// Must stay in sync with [kAchievements] in shared_models.
  static const _kAchievementThresholds = [
    1,
    3,
    5,
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    75,
    100,
    125,
    150,
    195,
  ];

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReviewScreen(
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
    // In autoStart mode, this widget is an invisible orchestrator — the
    // animation is shown via the MainShell overlay (M134).
    if (widget.autoStart) return const SizedBox.shrink();
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
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child:
                    kIsWeb
                        ? _WebFallbackView(effectiveVisits: _effectiveVisits)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PermissionPanel(
                              status: _permission,
                              onRequestPermission: _requestPermission,
                              onOpenSettings: _openSettings,
                            ),
                            const SizedBox(height: 12),
                            // Scan mode selector — only visible after the first scan (M122: compact).
                            if (_hasCompletedFirstScan) ...[
                              SegmentedButton<bool>(
                                style: SegmentedButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  textStyle:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('New'),
                                    icon: Icon(Icons.update),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('All'),
                                    icon: Icon(Icons.refresh),
                                  ),
                                ],
                                selected: {_forceFullScan},
                                onSelectionChanged:
                                    _scanning
                                        ? null
                                        : (s) => setState(
                                          () => _forceFullScan = s.first,
                                        ),
                              ),
                              if (_lastScanAt != null && !_forceFullScan)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Last scanned: ${_fmtDate(_lastScanAt!)}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            FilledButton.tonal(
                              onPressed:
                                  (_permission?.canScan == true && !_scanning)
                                      ? _scan
                                      : null,
                              child: const Text('Scan my photo library'),
                            ),
                            const SizedBox(height: 12),
                            if (_error != null) _ErrorView(message: _error!),
                            // Scanning pill: shown immediately when scan starts before first batch arrives.
                            if (_scanning &&
                                (_scanProgress?.processed ?? 0) == 0 &&
                                _existingEntriesAtScanStart.isNotEmpty)
                              const _ScanningPill(),
                            // M78: Unified persistent view — globe + country list + stamps always visible
                            // when the user has data. _ScanningView controls its own progress indicator
                            // via isScanning; existingCodes drives pre-population at rest.
                            if (_effectiveVisits.isNotEmpty || _scanning)
                              Expanded(
                                child: _ScanningView(
                                  progress: _scanProgress,
                                  liveNewEntries: List.unmodifiable(
                                    _liveNewEntries,
                                  ),
                                  existingEntries:
                                      _scanning
                                          ? _existingEntriesAtScanStart
                                          : _effectiveVisits
                                              .map(
                                                (v) => _DiscoveryEntry(
                                                  isoCode: v.countryCode,
                                                  photoCount: v.photoCount,
                                                  firstSeenYear:
                                                      v.firstSeen?.year,
                                                ),
                                              )
                                              .toList(),
                                  isScanning: _scanning,
                                  liveHeritageCount: _liveHeritageCount,
                                  achievementsUnlocked: List.unmodifiable(
                                    _achievementsUnlockedInOrder,
                                  ),
                                  liveTripCount: _liveTripCount,
                                  liveHeritageSites: _liveHeritageSites,
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

class _WebFallbackView extends StatelessWidget {
  const _WebFallbackView({required this.effectiveVisits});
  final List<EffectiveVisitedCountry> effectiveVisits;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone_iphone, size: 80, color: Colors.blueGrey),
        const SizedBox(height: 24),
        const Text(
          'Photo Scanning is Mobile Only',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'To protect your privacy, Roavvy scans your photo metadata directly on your device. This feature is only available in the Roavvy iOS app.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (effectiveVisits.isNotEmpty) ...[
          const Text(
            'You have travel data synced!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your World Map or Achievements tabs to see your history.',
            style: TextStyle(color: Colors.black54),
          ),
        ] else ...[
          const Text(
            'Download Roavvy on your iPhone to get started.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 48),
        Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Download_on_the_App_Store_Badge.svg/1200px-Download_on_the_App_Store_Badge.svg.png',
          height: 60,
        ),
      ],
    );
  }
}

// ── Progress ───────────────────────────────────────────────────────────────────

class _ScanProgress {
  const _ScanProgress({required this.processed, this.countriesFound = 0});
  final int processed;
  final int countriesFound;
}

// ── Discovery entry ────────────────────────────────────────────────────────────

/// A single discovered country with its scan-time metadata.
///
/// Used by [_DiscoveryFeed] to show emotional
/// context (first-visit year, photo count) without requiring callers to
/// look up [CountryAccum] at render time.
class _DiscoveryEntry {
  const _DiscoveryEntry({
    required this.isoCode,
    required this.photoCount,
    this.firstSeenYear,
    this.heritageSiteNames = const [],
  });

  final String isoCode;
  final int photoCount;

  /// Year of first photo evidence (null when unknown or not yet computed).
  final int? firstSeenYear;

  /// Names of newly discovered World Heritage Sites in this country (empty for pre-scan entries).
  final List<String> heritageSiteNames;
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
      PhotoPermissionStatus.notDetermined => _NotDeterminedPanel(
        onGrant: onRequestPermission,
      ),
      PhotoPermissionStatus.authorized => const SizedBox.shrink(),
      PhotoPermissionStatus.limited => const _LimitedAccessPanel(),
      PhotoPermissionStatus.denied => _DeniedPanel(
        onOpenSettings: onOpenSettings,
      ),
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
        FilledButton(onPressed: onGrant, child: const Text('Grant Access')),
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

// ── Celebration level (M122, ADR-169) ─────────────────────────────────────────

enum _CelebrationLevel { micro, medium, full }

// ── _ScanningView (Tasks 146, 147, 148 — M43; M121 emotional rewrite) ─────────

class _ScanningView extends ConsumerStatefulWidget {
  const _ScanningView({
    this.progress,
    this.liveNewEntries = const [],
    this.existingEntries = const [],
    this.isScanning = false,
    this.liveHeritageCount = 0,
    this.achievementsUnlocked = const [],
    this.liveTripCount = 0,
    this.liveHeritageSites = const [],
  });

  final _ScanProgress? progress;

  /// Countries found for the first time during this scan.
  /// Updated in real time as each batch is processed. (ADR-083, M121)
  final List<_DiscoveryEntry> liveNewEntries;

  /// Countries already known before this scan started (ADR-130, M121).
  /// Used to pre-populate the globe and discovery feed immediately.
  final List<_DiscoveryEntry> existingEntries;

  /// Whether a scan is currently in progress. Controls progress indicator
  /// and count text visibility — false at rest (M78).
  final bool isScanning;

  /// Number of unique UNESCO heritage sites found so far in this scan (T2, M123).
  final int liveHeritageCount;

  /// Country-count achievement IDs unlocked this scan, in order (T1, M125).
  /// Growing list — [_ScanningViewState] detects new additions via length delta.
  final List<String> achievementsUnlocked;

  /// Live inferred trip count from accumulated photo dates (T2, M125).
  final int liveTripCount;

  /// UNESCO heritage sites discovered so far — full objects for colour-coded
  /// globe dots (cultural=amber, natural=green) and tap-tooltip (M128).
  final List<VisitedHeritageSite> liveHeritageSites;

  @override
  ConsumerState<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends ConsumerState<_ScanningView>
    with TickerProviderStateMixin {
  // ── Audio (M124) ─────────────────────────────────────────────────────────────
  final ScanAudioController _scanAudio = ScanAudioController();

  // ── Confetti ─────────────────────────────────────────────────────────────────
  ConfettiController? _microCtrl;
  ConfettiController? _mediumCtrl;
  ConfettiController? _fullCtrl;
  List<Color> _confettiColors = const [
    Colors.amber,
    Colors.orange,
    Colors.blue,
  ];

  // GlobalKey to trigger globe milestone pulse on major milestones.
  final _globeKey = GlobalKey<_ScanGlobeWidgetState>();

  // ── First-country cinematic ───────────────────────────────────────────────────
  bool _firstCountryCinematicShown = false;
  bool _showCinematic = false;
  double _cinematicOpacity = 0.0;
  _DiscoveryEntry? _cinematicEntry;
  Timer? _cinematicTimer;

  @override
  void initState() {
    super.initState();
    _microCtrl = ConfettiController(
      duration: const Duration(milliseconds: 250),
    );
    _mediumCtrl = ConfettiController(
      duration: const Duration(milliseconds: 450),
    );
    _fullCtrl = ConfettiController(duration: const Duration(milliseconds: 750));
    _scanAudio.preload();
  }

  @override
  void didUpdateWidget(_ScanningView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.liveNewEntries.length > oldWidget.liveNewEntries.length) {
      final addedEntries = widget.liveNewEntries.sublist(
        oldWidget.liveNewEntries.length,
      );
      final totalAfter =
          widget.liveNewEntries.length + widget.existingEntries.length;

      if (!MediaQuery.disableAnimationsOf(context)) {
        for (final entry in addedEntries) {
          // Flag colours live.
          flagColours(entry.isoCode).then((colors) {
            if (mounted && colors != null)
              setState(() => _confettiColors = colors);
          });

          // First-country cinematic.
          if (!_firstCountryCinematicShown && widget.existingEntries.isEmpty) {
            _firstCountryCinematicShown = true;
            _triggerCinematic(entry);
          }

          // Burst confetti for major milestones.
          final totalBefore = totalAfter - addedEntries.length;
          const majorThresholds = {10, 25, 50};
          for (final t in majorThresholds) {
            if (totalBefore < t && totalAfter >= t) {
              _burstConfetti(_CelebrationLevel.full);
              _globeKey.currentState?.triggerMilestonePulse();
              break;
            }
          }
        }
      }
    }
  }

  // ── M131: Confetti helpers ─────────────────────────────────────────────────────

  void _burstConfetti(_CelebrationLevel level) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    switch (level) {
      case _CelebrationLevel.micro:
        _microCtrl?.play();
      case _CelebrationLevel.medium:
        _mediumCtrl?.play();
      case _CelebrationLevel.full:
        _fullCtrl?.play();
    }
  }

  void _triggerCinematic(_DiscoveryEntry entry) {
    setState(() {
      _cinematicEntry = entry;
      _showCinematic = true;
      _cinematicOpacity = 0.0;
    });
    // Fade in
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _cinematicOpacity = 1.0);
    });
    // Hold then fade out
    _cinematicTimer?.cancel();
    _cinematicTimer = Timer(const Duration(milliseconds: 1950), () {
      if (mounted) setState(() => _cinematicOpacity = 0.0);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showCinematic = false);
      });
    });
  }

  @override
  void dispose() {
    _scanAudio.dispose();
    _microCtrl?.dispose();
    _mediumCtrl?.dispose();
    _fullCtrl?.dispose();
    _cinematicTimer?.cancel();
    super.dispose();
  }

  // ── Phase-aware scan header (T1, M121) ────────────────────────────────────────

  Widget _buildScanHeader(ThemeData theme) {
    final progress = widget.progress;
    final processed = progress?.processed ?? 0;
    final countriesFound = progress?.countriesFound ?? 0;

    String headline;
    if (processed == 0) {
      headline = 'Discovering your world\u2026';
    } else if (countriesFound < 3 && processed < 5000) {
      headline = 'Discovering your world\u2026';
    } else if (processed < 15000) {
      headline = 'Building your travel story\u2026';
    } else {
      headline = 'Almost there\u2026';
    }

    final subtitleParts = <String>[];
    if (countriesFound > 0) {
      subtitleParts.add(
        '$countriesFound ${countriesFound == 1 ? 'country' : 'countries'} found',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: null,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitleParts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Extract ISO codes for the globe (which only needs codes).
    final liveNewCodes = widget.liveNewEntries.map((e) => e.isoCode).toList();
    final existingCodes = widget.existingEntries.map((e) => e.isoCode).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Emotional phase header — only during active scan (T1, M121).
            if (widget.isScanning) _buildScanHeader(theme),
            // Live stats bar — countries · continents · heritage (T3, M122/M123).
            _ScanStatsBar(
              liveNewEntries: widget.liveNewEntries,
              existingEntries: widget.existingEntries,
              liveHeritageCount: widget.liveHeritageCount,
              liveTripCount: widget.liveTripCount,
              visible: widget.isScanning,
            ),
            // Globe — flexible hero (T2, M121).
            Flexible(
              flex: 55,
              child: _ScanGlobeWidget(
                key: _globeKey,
                liveNewCodes: liveNewCodes,
                existingCodes: existingCodes,
                heritageSites: widget.liveHeritageSites,
              ),
            ),
            const SizedBox(height: 8),
            // Discovery feed — replaces split panel (T3/T4, M121).
            Flexible(
              flex: 45,
              child: _DiscoveryFeed(
                liveNewEntries: widget.liveNewEntries,
                existingEntries: widget.existingEntries,
                reduceMotion: reduceMotion,
              ),
            ),
          ],
        ),

        // Confetti — three priority tiers (M122, ADR-169). Skip when reduce-motion enabled.
        if (!reduceMotion) ...[
          if (_microCtrl != null)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _microCtrl!,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.25,
                numberOfParticles: 4,
                gravity: 0.35,
                shouldLoop: false,
                createParticlePath: _drawStar,
                colors: _confettiColors,
              ),
            ),
          if (_mediumCtrl != null)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _mediumCtrl!,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.4,
                numberOfParticles: 10,
                gravity: 0.3,
                shouldLoop: false,
                createParticlePath: _drawStar,
                colors: _confettiColors,
              ),
            ),
          if (_fullCtrl != null)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _fullCtrl!,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.55,
                numberOfParticles: 18,
                gravity: 0.25,
                shouldLoop: false,
                createParticlePath: _drawStar,
                colors: _confettiColors,
              ),
            ),
        ],
        // First-country cinematic overlay (T5, M121).
        if (_showCinematic && _cinematicEntry != null)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _cinematicOpacity,
              duration: const Duration(milliseconds: 400),
              child: _FirstCountryCinematic(entry: _cinematicEntry!),
            ),
          ),
      ],
    );
  }
}

// ── Live scan stats bar (T3, M122/M123) ───────────────────────────────────────

/// Single-line stats row shown only while scanning.
///
/// Format: "14/244 countries · 3/7 continents [· 7/1,157 heritage sites]"
///
/// Fades in when [visible] is true, fades out when false.
class _ScanStatsBar extends StatelessWidget {
  const _ScanStatsBar({
    required this.liveNewEntries,
    required this.existingEntries,
    required this.liveHeritageCount,
    required this.visible,
    this.liveTripCount = 0,
  });

  final List<_DiscoveryEntry> liveNewEntries;
  final List<_DiscoveryEntry> existingEntries;
  final int liveHeritageCount;
  final bool visible;
  final int liveTripCount;

  static const int _totalCountries = 244;
  static const int _totalContinents = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntries = [...existingEntries, ...liveNewEntries];
    final countriesCount = allEntries.length;
    final continentsCount =
        allEntries
            .map((e) => kCountryContinent[e.isoCode])
            .whereType<String>()
            .toSet()
            .length;
    final totalHeritage = WorldHeritageLookupService.totalSiteCount;

    final parts = <String>[
      '$countriesCount/$_totalCountries countries',
      '$continentsCount/$_totalContinents continents',
      if (liveHeritageCount > 0 && totalHeritage > 0)
        '$liveHeritageCount/${_fmtN(totalHeritage)} heritage',
      if (liveTripCount > 0)
        '$liveTripCount ${liveTripCount == 1 ? 'trip' : 'trips'}',
    ];

    final showProgress = liveHeritageCount > 0 && totalHeritage > 0;
    final heritageProgress =
        showProgress ? liveHeritageCount / totalHeritage : 0.0;

    return AnimatedOpacity(
      opacity: visible && countriesCount > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              parts.join(' \u00b7 '),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            if (showProgress) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: heritageProgress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder:
                      (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        backgroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.12,
                        ),
                        color: Colors.amber[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format integer with comma thousands separator (e.g. 1157 → "1,157").
  static String _fmtN(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

// ── Discovery toast banner (M121 — enhanced with contextual year) ─────────────

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
    super.key,
    required this.liveNewCodes,
    this.existingCodes = const [],
    this.heritageSites = const [],
  });
  final List<String> liveNewCodes;

  /// ISO codes already known before this scan. Pre-populate the globe without
  /// triggering travel animations (ADR-130).
  final List<String> existingCodes;

  /// UNESCO sites discovered this scan — used for colour-coded dots and
  /// tap-to-tooltip (M126/M128).
  final List<VisitedHeritageSite> heritageSites;

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

  // Gold pulse animation for heritage site dots (M126). Distinct timing from _pulseCtrl.
  late final AnimationController _heritagePulseCtrl;

  // Projection at the start of the last travel animation.
  GlobeProjection _fromProjection = const GlobeProjection(scale: 1.0);
  // Target projection for the current travel animation.
  GlobeProjection _toProjection = const GlobeProjection(scale: 1.0);

  // ISO code of the country currently highlighted (newest).
  String? _highlightedCode;

  // Tap-tooltip state for heritage dots (M128).
  String? _tooltipName;
  String? _tooltipCategory;
  Timer? _tooltipTimer;

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
    _heritagePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  /// Triggers a single extra heritage pulse amplitude to mark a P4 major milestone (M130, T6).
  void triggerMilestonePulse() {
    _heritagePulseCtrl.forward(from: 0.0);
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
    _heritagePulseCtrl.dispose();
    _tooltipTimer?.cancel();
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
    if (_highlightedCode != null && _highlightedCode!.isNotEmpty) {
      visualStates[_highlightedCode!] = CountryVisualState.newlyDiscovered;
    }

    // Split heritage sites by category for colour-coded dots (M128).
    final culturalCoords = <(double, double)>[];
    final naturalCoords = <(double, double)>[];
    for (final s in widget.heritageSites) {
      final coord = (s.latitude, s.longitude);
      if (s.category == 'natural') {
        naturalCoords.add(coord);
      } else {
        // 'cultural' and 'mixed' → amber.
        culturalCoords.add(coord);
      }
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_spinCtrl, _pulseCtrl, _heritagePulseCtrl]),
      builder: (context, _) {
        final isIdle =
            (_travelCtrl == null || !_travelCtrl!.isAnimating) &&
            (_zoomOutCtrl == null || !_zoomOutCtrl!.isAnimating);
        final displayProjection =
            (isIdle && !reduceMotion)
                ? GlobeProjection(
                  rotLat: _projection.rotLat,
                  rotLng: _projection.rotLng + _spinCtrl.value * 0.3,
                  scale: _projection.scale,
                )
                : _projection;
        final pulseValue = reduceMotion ? 0.0 : _pulseCtrl.value;
        final heritagePulseValue =
            reduceMotion ? 0.0 : _heritagePulseCtrl.value;

        return Stack(
          children: [
            GestureDetector(
              onTapUp:
                  (details) =>
                      _handleGlobeTap(details.localPosition, displayProjection),
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
                    culturalSiteCoords: culturalCoords,
                    naturalSiteCoords: naturalCoords,
                    heritagePulseValue: heritagePulseValue,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (_tooltipName != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: IgnorePointer(
                  child: _HeritageTooltip(
                    name: _tooltipName!,
                    category: _tooltipCategory ?? '',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Hit-tests [tapPos] against visible heritage dots. Shows tooltip for the
  /// nearest site within 24 px; auto-dismisses after 3 s.
  void _handleGlobeTap(Offset tapPos, GlobeProjection proj) {
    if (widget.heritageSites.isEmpty) return;

    // We need the render box size to call projection.project.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;

    VisitedHeritageSite? nearest;
    double nearestDist = 24.0; // px threshold

    for (final site in widget.heritageSites) {
      final pt = proj.project(site.latitude, site.longitude, size);
      if (pt == null) continue;
      final d = (pt - tapPos).distance;
      if (d < nearestDist) {
        nearestDist = d;
        nearest = site;
      }
    }

    if (nearest == null) {
      setState(() {
        _tooltipName = null;
        _tooltipCategory = null;
      });
      return;
    }

    _tooltipTimer?.cancel();
    setState(() {
      _tooltipName = nearest!.name;
      _tooltipCategory = nearest.category;
    });
    _tooltipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted)
        setState(() {
          _tooltipName = null;
          _tooltipCategory = null;
        });
    });
  }
}

// ── Heritage dot tooltip (M128) ───────────────────────────────────────────────

/// Semi-transparent pill shown at the bottom of the globe when the user taps
/// a heritage dot. Auto-dismissed after 3 seconds.
class _HeritageTooltip extends StatelessWidget {
  const _HeritageTooltip({required this.name, required this.category});

  final String name;
  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel =
        category == 'natural'
            ? 'Natural'
            : category == 'mixed'
            ? 'Mixed'
            : 'Cultural';
    final categoryColor =
        category == 'natural' ? Colors.green[400]! : Colors.amber[400]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined, size: 14, color: categoryColor),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'UNESCO $categoryLabel Heritage Site',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: categoryColor,
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

// ── Discovery feed (M121 — replaces split panel; M122 — compact chip rows) ─────

/// Vertical list of compact discovery chip rows, newest-first.
///
/// Existing countries (pre-scan) appear immediately as muted rows.
/// New discoveries slide in from the top as they are found (newest-first prepend).
class _DiscoveryFeed extends StatefulWidget {
  const _DiscoveryFeed({
    required this.liveNewEntries,
    required this.existingEntries,
    required this.reduceMotion,
  });

  final List<_DiscoveryEntry> liveNewEntries;
  final List<_DiscoveryEntry> existingEntries;
  final bool reduceMotion;

  @override
  State<_DiscoveryFeed> createState() => _DiscoveryFeedState();
}

class _DiscoveryFeedState extends State<_DiscoveryFeed> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_DiscoveryFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to top to show newest chip when a new entry arrives.
    if (widget.liveNewEntries.length > oldWidget.liveNewEntries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients &&
            _scrollCtrl.position.minScrollExtent == 0) {
          _scrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Newest-first: live new entries reversed, then existing entries reversed.
    final newReversed = widget.liveNewEntries.reversed.toList();
    final existingReversed = widget.existingEntries.reversed.toList();
    final allItems = [...newReversed, ...existingReversed];

    if (allItems.isEmpty) {
      return Center(
        child: Text(
          'Countries will appear here\u2026',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      );
    }

    final newestCode =
        widget.liveNewEntries.isNotEmpty
            ? widget.liveNewEntries.last.isoCode
            : null;
    final newCodes = widget.liveNewEntries.map((e) => e.isoCode).toSet();

    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: allItems.length,
      itemExtent: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      itemBuilder: (context, index) {
        final entry = allItems[index];
        final isNew = newCodes.contains(entry.isoCode);
        return _DiscoveryChip(
          key: ValueKey(entry.isoCode),
          entry: entry,
          isNew: isNew,
          isNewest: entry.isoCode == newestCode,
          reduceMotion: widget.reduceMotion,
        );
      },
    );
  }
}

// ── Discovery chip (M122 — compact row replacing M121 card) ───────────────────

class _DiscoveryChip extends StatefulWidget {
  const _DiscoveryChip({
    super.key,
    required this.entry,
    required this.isNew,
    required this.isNewest,
    required this.reduceMotion,
  });

  final _DiscoveryEntry entry;
  final bool isNew;
  final bool isNewest;
  final bool reduceMotion;

  @override
  State<_DiscoveryChip> createState() => _DiscoveryChipState();
}

class _DiscoveryChipState extends State<_DiscoveryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration:
          widget.reduceMotion || !widget.isNew
              ? Duration.zero
              : const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    // Slide in from above (newest-first list, new items prepend at top).
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
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
    final theme = Theme.of(context);
    final entry = widget.entry;
    final flag = _flagEmoji(entry.isoCode);
    final name = kCountryNames[entry.isoCode] ?? entry.isoCode;
    final textColor =
        widget.isNew
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    final chip = Row(
      children: [
        // Left accent bar for newest entry.
        if (widget.isNewest)
          Container(
            width: 2,
            height: 24,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          )
        else
          const SizedBox(width: 8),
        // Flag.
        Text(flag, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        // Country name.
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        // Year label (if known).
        if (entry.firstSeenYear != null) ...[
          const SizedBox(width: 4),
          Text(
            _yearLabel(entry.firstSeenYear!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor.withValues(alpha: widget.isNew ? 0.7 : 0.6),
            ),
          ),
        ],
        // Heritage badge.
        if (entry.heritageSiteNames.isNotEmpty) ...[
          const SizedBox(width: 4),
          const Text('🏛', style: TextStyle(fontSize: 10)),
        ],
        // Photo count.
        if (entry.photoCount > 0) ...[
          const SizedBox(width: 6),
          Text(
            '${entry.photoCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor.withValues(alpha: widget.isNew ? 0.55 : 0.4),
            ),
          ),
          const SizedBox(width: 4),
        ] else
          const SizedBox(width: 8),
      ],
    );

    if (!widget.isNew || widget.reduceMotion) return chip;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: chip),
    );
  }

  static String _yearLabel(int year) {
    final now = DateTime.now().year;
    if (year == now) return 'This year';
    return 'Since $year';
  }
}

// ── First-country cinematic overlay (M121) ────────────────────────────────────

class _FirstCountryCinematic extends StatelessWidget {
  const _FirstCountryCinematic({required this.entry});

  final _DiscoveryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = _flagEmoji(entry.isoCode);
    final name = kCountryNames[entry.isoCode] ?? entry.isoCode;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome to your world.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(flag, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 5-pointed star particle path for confetti.
Path _drawStar(Size size) {
  const n = 5;
  final cx = size.width / 2;
  final cy = size.height / 2;
  final outer = size.width / 2;
  final inner = outer * 0.4;
  final path = Path();
  for (var i = 0; i < n * 2; i++) {
    final r = i.isEven ? outer : inner;
    final angle = (i * math.pi / n) - math.pi / 2;
    final x = cx + r * math.cos(angle);
    final y = cy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your travel story is waiting.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Scan my photos" to discover the countries hidden in your photo library.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos never leave your device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResultsHint extends StatelessWidget {
  const _EmptyResultsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No travel photos found yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure Location is enabled on your camera and try scanning again — '
              'or add countries manually using Review & Edit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
