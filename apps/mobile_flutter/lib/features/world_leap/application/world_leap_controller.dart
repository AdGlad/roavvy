// lib/features/world_leap/application/world_leap_controller.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

import '../domain/models/world_leap_failure_reason.dart';
import '../domain/models/world_leap_launch.dart';
import '../domain/models/world_leap_run.dart';
import '../domain/services/world_leap_country_service.dart';
import '../domain/services/world_leap_geo_service.dart';
import '../domain/services/world_leap_scoring_service.dart';
import '../world_leap_config.dart';
import '../data/repositories/world_leap_run_repository.dart';
import 'world_leap_daily_service.dart';
import 'world_leap_state.dart';

// ── Country lookup typedef ────────────────────────────────────────────────────

/// Function signature for looking up a country at a given lat/lon.
/// Returns `({code, name})` or `null` if over water/unrecognised territory.
typedef CountryLookupFn = ({String code, String name})? Function(
    double lat, double lon);

// ── Country data (centroid + name) ────────────────────────────────────────────

/// Approximate centroids + display names for countries used as game targets
/// and launch origins. Covers all inhabited continents with good variety.
const Map<String, ({double lat, double lon, String name})> _countryData = {
  'AF': (lat: 33.9391, lon: 67.7100, name: 'Afghanistan'),
  'AL': (lat: 41.1533, lon: 20.1683, name: 'Albania'),
  'DZ': (lat: 28.0339, lon: 1.6596, name: 'Algeria'),
  'AO': (lat: -11.2027, lon: 17.8739, name: 'Angola'),
  'AR': (lat: -38.4161, lon: -63.6167, name: 'Argentina'),
  'AM': (lat: 40.0691, lon: 45.0382, name: 'Armenia'),
  'AU': (lat: -25.2744, lon: 133.7751, name: 'Australia'),
  'AT': (lat: 47.5162, lon: 14.5501, name: 'Austria'),
  'AZ': (lat: 40.1431, lon: 47.5769, name: 'Azerbaijan'),
  'BD': (lat: 23.6850, lon: 90.3563, name: 'Bangladesh'),
  'BE': (lat: 50.5039, lon: 4.4699, name: 'Belgium'),
  'BO': (lat: -16.2902, lon: -63.5887, name: 'Bolivia'),
  'BA': (lat: 43.9159, lon: 17.6791, name: 'Bosnia'),
  'BR': (lat: -14.2350, lon: -51.9253, name: 'Brazil'),
  'BG': (lat: 42.7339, lon: 25.4858, name: 'Bulgaria'),
  'KH': (lat: 12.5657, lon: 104.9910, name: 'Cambodia'),
  'CM': (lat: 3.8480, lon: 11.5021, name: 'Cameroon'),
  'CA': (lat: 56.1304, lon: -106.3468, name: 'Canada'),
  'CL': (lat: -35.6751, lon: -71.5430, name: 'Chile'),
  'CN': (lat: 35.8617, lon: 104.1954, name: 'China'),
  'CO': (lat: 4.5709, lon: -74.2973, name: 'Colombia'),
  'CD': (lat: -4.0383, lon: 21.7587, name: 'DR Congo'),
  'HR': (lat: 45.1000, lon: 15.2000, name: 'Croatia'),
  'CU': (lat: 21.5218, lon: -77.7812, name: 'Cuba'),
  'CZ': (lat: 49.8175, lon: 15.4730, name: 'Czech Republic'),
  'DK': (lat: 56.2639, lon: 9.5018, name: 'Denmark'),
  'EC': (lat: -1.8312, lon: -78.1834, name: 'Ecuador'),
  'EG': (lat: 26.8206, lon: 30.8025, name: 'Egypt'),
  'ET': (lat: 9.1450, lon: 40.4897, name: 'Ethiopia'),
  'FI': (lat: 61.9241, lon: 25.7482, name: 'Finland'),
  'FR': (lat: 46.2276, lon: 2.2137, name: 'France'),
  'DE': (lat: 51.1657, lon: 10.4515, name: 'Germany'),
  'GH': (lat: 7.9465, lon: -1.0232, name: 'Ghana'),
  'GR': (lat: 39.0742, lon: 21.8243, name: 'Greece'),
  'GT': (lat: 15.7835, lon: -90.2308, name: 'Guatemala'),
  'GB': (lat: 55.3781, lon: -3.4360, name: 'United Kingdom'),
  'HU': (lat: 47.1625, lon: 19.5033, name: 'Hungary'),
  'IN': (lat: 20.5937, lon: 78.9629, name: 'India'),
  'ID': (lat: -0.7893, lon: 113.9213, name: 'Indonesia'),
  'IR': (lat: 32.4279, lon: 53.6880, name: 'Iran'),
  'IQ': (lat: 33.2232, lon: 43.6793, name: 'Iraq'),
  'IE': (lat: 53.1424, lon: -7.6921, name: 'Ireland'),
  'IL': (lat: 31.0461, lon: 34.8516, name: 'Israel'),
  'IT': (lat: 41.8719, lon: 12.5674, name: 'Italy'),
  'JP': (lat: 36.2048, lon: 138.2529, name: 'Japan'),
  'JO': (lat: 30.5852, lon: 36.2384, name: 'Jordan'),
  'KZ': (lat: 48.0196, lon: 66.9237, name: 'Kazakhstan'),
  'KE': (lat: -0.0236, lon: 37.9062, name: 'Kenya'),
  'KR': (lat: 35.9078, lon: 127.7669, name: 'South Korea'),
  'KW': (lat: 29.3117, lon: 47.4818, name: 'Kuwait'),
  'LA': (lat: 19.8563, lon: 102.4955, name: 'Laos'),
  'LY': (lat: 26.3351, lon: 17.2283, name: 'Libya'),
  'MY': (lat: 4.2105, lon: 101.9758, name: 'Malaysia'),
  'MX': (lat: 23.6345, lon: -102.5528, name: 'Mexico'),
  'MA': (lat: 31.7917, lon: -7.0926, name: 'Morocco'),
  'MZ': (lat: -18.6657, lon: 35.5296, name: 'Mozambique'),
  'MM': (lat: 21.9162, lon: 95.9560, name: 'Myanmar'),
  'NP': (lat: 28.3949, lon: 84.1240, name: 'Nepal'),
  'NL': (lat: 52.1326, lon: 5.2913, name: 'Netherlands'),
  'NZ': (lat: -40.9006, lon: 174.8860, name: 'New Zealand'),
  'NI': (lat: 12.8654, lon: -85.2072, name: 'Nicaragua'),
  'NG': (lat: 9.0820, lon: 8.6753, name: 'Nigeria'),
  'NO': (lat: 60.4720, lon: 8.4689, name: 'Norway'),
  'OM': (lat: 21.5129, lon: 55.9233, name: 'Oman'),
  'PK': (lat: 30.3753, lon: 69.3451, name: 'Pakistan'),
  'PA': (lat: 8.5380, lon: -80.7821, name: 'Panama'),
  'PY': (lat: -23.4425, lon: -58.4438, name: 'Paraguay'),
  'PE': (lat: -9.1900, lon: -75.0152, name: 'Peru'),
  'PH': (lat: 12.8797, lon: 121.7740, name: 'Philippines'),
  'PL': (lat: 51.9194, lon: 19.1451, name: 'Poland'),
  'PT': (lat: 39.3999, lon: -8.2245, name: 'Portugal'),
  'QA': (lat: 25.3548, lon: 51.1839, name: 'Qatar'),
  'RO': (lat: 45.9432, lon: 24.9668, name: 'Romania'),
  'RU': (lat: 61.5240, lon: 105.3188, name: 'Russia'),
  'SA': (lat: 23.8859, lon: 45.0792, name: 'Saudi Arabia'),
  'SN': (lat: 14.4974, lon: -14.4524, name: 'Senegal'),
  'RS': (lat: 44.0165, lon: 21.0059, name: 'Serbia'),
  'ZA': (lat: -30.5595, lon: 22.9375, name: 'South Africa'),
  'ES': (lat: 40.4637, lon: -3.7492, name: 'Spain'),
  'LK': (lat: 7.8731, lon: 80.7718, name: 'Sri Lanka'),
  'SD': (lat: 12.8628, lon: 30.2176, name: 'Sudan'),
  'SE': (lat: 60.1282, lon: 18.6435, name: 'Sweden'),
  'CH': (lat: 46.8182, lon: 8.2275, name: 'Switzerland'),
  'SY': (lat: 34.8021, lon: 38.9968, name: 'Syria'),
  'TW': (lat: 23.5937, lon: 120.9605, name: 'Taiwan'),
  'TZ': (lat: -6.3690, lon: 34.8888, name: 'Tanzania'),
  'TH': (lat: 15.8700, lon: 100.9925, name: 'Thailand'),
  'TN': (lat: 33.8869, lon: 9.5375, name: 'Tunisia'),
  'TR': (lat: 38.9637, lon: 35.2433, name: 'Turkey'),
  'UA': (lat: 48.3794, lon: 31.1656, name: 'Ukraine'),
  'AE': (lat: 23.4241, lon: 53.8478, name: 'UAE'),
  'US': (lat: 37.0902, lon: -95.7129, name: 'United States'),
  'UY': (lat: -32.5228, lon: -55.7658, name: 'Uruguay'),
  'UZ': (lat: 41.3775, lon: 64.5853, name: 'Uzbekistan'),
  'VE': (lat: 6.4238, lon: -66.5897, name: 'Venezuela'),
  'VN': (lat: 14.0583, lon: 108.2772, name: 'Vietnam'),
  'YE': (lat: 15.5527, lon: 48.5164, name: 'Yemen'),
  'ZM': (lat: -13.1339, lon: 27.8493, name: 'Zambia'),
  'ZW': (lat: -19.0154, lon: 29.1549, name: 'Zimbabwe'),
};

/// Returns the centroid for [countryCode], or (0.0, 0.0) if unknown.
({double lat, double lon}) _centroidFor(String countryCode) {
  final d = _countryData[countryCode];
  return d != null ? (lat: d.lat, lon: d.lon) : (lat: 0.0, lon: 0.0);
}

// ── Controller ────────────────────────────────────────────────────────────────

class WorldLeapController extends ChangeNotifier {
  WorldLeapController({
    required String userId,
    required String date,
    required IWorldLeapDailyService dailyService,
    required IWorldLeapRunRepository repository,
    required WorldLeapGeoService geo,
    required WorldLeapCountryService countryService,
    required WorldLeapScoringService scoring,
    bool beginnerMode = false,
    CountryLookupFn? countryLookup,
  })  : _userId = userId,
        _date = date,
        _dailyService = dailyService,
        _repository = repository,
        _geo = geo,
        _countryService = countryService,
        _scoring = scoring,
        _countryLookup = countryLookup,
        _beginnerMode = beginnerMode;

  /// When true, releasing the slingshot freezes the aim for review instead of
  /// firing immediately — [SlingshotWidget] calls [confirmAim] instead of
  /// [launch] on release, and the screen shows a separate FIRE button.
  /// Initialised from the lobby's choice, but changeable at any time via
  /// [setBeginnerMode] — e.g. a toggle in the game screen itself, between
  /// shots.
  bool _beginnerMode;
  bool get beginnerMode => _beginnerMode;

  /// Switches beginner/classic mode mid-game. Safe to call at any time; only
  /// affects the NEXT release (an in-progress drag keeps whatever mode was
  /// active when it started, read fresh by [SlingshotWidget] on each build).
  void setBeginnerMode(bool value) {
    if (_beginnerMode == value) return;
    _beginnerMode = value;
    notifyListeners();
  }

  /// True once the player has released at least one aim in beginner mode
  /// (via [confirmAim]) and it hasn't been fired yet. Drives the FIRE
  /// button's visibility directly and explicitly — deliberately NOT inferred
  /// from bearing/power thresholds, which dip transiently while the player is
  /// mid-drag adjusting an already-confirmed aim and would otherwise make the
  /// button flicker. Persists across any number of re-aim drags until
  /// [launch] fires or a fresh turn begins.
  bool _hasConfirmedAim = false;
  bool get hasConfirmedAim => _hasConfirmedAim;

  /// Notifier for aim-only updates (bearing/power) that fire at pointer-move
  /// frequency (~60Hz). Widgets that only care about game state transitions
  /// should listen to this controller via [addListener]; widgets that need
  /// the trajectory preview (WorldLeapMapWidget) listen to [aimNotifier].
  final aimNotifier = ValueNotifier<({double bearingDeg, double power})?>(null);

  final String _userId;
  final String _date;
  final IWorldLeapDailyService _dailyService;
  final IWorldLeapRunRepository _repository;
  final WorldLeapGeoService _geo;
  final WorldLeapCountryService _countryService;
  final WorldLeapScoringService _scoring;
  final CountryLookupFn? _countryLookup;

  WorldLeapState _state = WorldLeapStateIdle();

  // ── Countdown timer state ────────────────────────────────────────────────

  Timer? _countdownTimer;
  int _timeRemaining = 0;

  // ── Combo streak state ───────────────────────────────────────────────────

  /// Consecutive successful target hits in this run (resets on miss/timeout).
  int _comboStreak = 0;

  /// Current combo streak (read by HUD / score panel via provider).
  int get comboStreak => _comboStreak;

  /// Seconds remaining in the current countdown. Updated every second.
  int get timeRemaining => _timeRemaining;

  /// Current time limit for a shot (decreases by 1 each success, min 5).
  int get timeLimitSeconds {
    final s = _state;
    if (s is WorldLeapStateAiming) return s.run.timeLimitSeconds;
    return WorldLeapConfig.countdownStartSeconds;
  }

  /// ISO code of the current target country. Stays populated through
  /// [WorldLeapStateLaunching] (not just [WorldLeapStateAiming]) so the map's
  /// target highlight remains visible for the whole flight, not just while
  /// aiming — the target isn't resolved (hit or missed) until landing.
  String? get targetCountryCode {
    final s = _state;
    return switch (s) {
      WorldLeapStateAiming(:final run) => run.targetCountryCode,
      WorldLeapStateLaunching(:final run) => run.targetCountryCode,
      _ => null,
    };
  }

  /// Display name of the current target country. See [targetCountryCode] for
  /// why this also stays populated during [WorldLeapStateLaunching].
  String? get targetCountryName {
    final s = _state;
    return switch (s) {
      WorldLeapStateAiming(:final run) => run.targetCountryName,
      WorldLeapStateLaunching(:final run) => run.targetCountryName,
      _ => null,
    };
  }

  /// Centroid coordinates of the target country, or null if no target set.
  ({double lat, double lon})? get targetLocation {
    final code = targetCountryCode;
    if (code == null) return null;
    final d = _countryData[code];
    if (d == null) return null;
    return (lat: d.lat, lon: d.lon);
  }

  /// Distance in km from current position to target centroid, or null if no target.
  double? get targetDistanceKm {
    final code = targetCountryCode;
    if (code == null) return null;
    final d = _countryData[code];
    if (d == null) return null;
    final origin = currentOrigin;
    return _geo.greatCircleDistanceKm(
      lat1: origin.lat, lon1: origin.lon,
      lat2: d.lat, lon2: d.lon,
    );
  }

  /// Compass bearing from current position to target centroid, or null if no target.
  double? get targetBearingDeg {
    final code = targetCountryCode;
    if (code == null) return null;
    final d = _countryData[code];
    if (d == null) return null;
    final origin = currentOrigin;
    return _geo.initialBearingDeg(
      lat1: origin.lat, lon1: origin.lon,
      lat2: d.lat, lon2: d.lon,
    );
  }

  WorldLeapState get state => _state;

  /// Returns the geographic origin of the next launch: the last landing point
  /// if any launches have occurred, otherwise the start country centroid.
  ({double lat, double lon}) get currentOrigin {
    final s = _state;
    final WorldLeapRun? run = switch (s) {
      WorldLeapStateAiming(:final run) => run,
      WorldLeapStateLaunching(:final run) => run,
      WorldLeapStateLanded(:final run) => run,
      _ => null,
    };
    if (run == null) return (lat: 20.0, lon: 0.0);
    if (run.launches.isNotEmpty) {
      final last = run.launches.last;
      return (lat: last.landingLat, lon: last.landingLon);
    }
    return _centroidFor(run.startCountryCode);
  }

  void _emit(WorldLeapState next) {
    _state = next;
    notifyListeners();
  }

  // ── Target country selection ────────────────────────────────────────────

  /// The geographic origin the NEXT launch will fly from for [run]: the last
  /// landing point if any launches have occurred, otherwise the start
  /// country centroid. Mirrors [currentOrigin] but reads an explicit [run]
  /// rather than [_state] — needed because [_pickTarget] is called with an
  /// already-updated run (the just-completed launch appended) before that
  /// run has been emitted as the new [_state].
  ({double lat, double lon}) _originForRun(WorldLeapRun run) {
    if (run.launches.isNotEmpty) {
      final last = run.launches.last;
      return (lat: last.landingLat, lon: last.landingLon);
    }
    return _centroidFor(run.startCountryCode);
  }

  /// Picks an eligible target country that has not been visited and is
  /// different from the current country, weighted toward nearby countries
  /// early in the run and progressively opening up to any distance as
  /// [WorldLeapConfig.progressiveDistanceRampLaunches] launches accumulate —
  /// so new players aren't asked to aim across the globe on their first shot.
  ///
  /// Uses a seeded RNG so the same run always gets the same sequence of
  /// targets.
  ({String code, String name})? _pickTarget(WorldLeapRun run) {
    final visited = run.visitedCountryCodes;
    final candidates = _countryData.entries
        .where((e) => !visited.contains(e.key))
        .toList();
    if (candidates.isEmpty) return null;

    final origin = _originForRun(run);
    final byDistance = [
      for (final e in candidates)
        (
          code: e.key,
          name: e.value.name,
          distanceKm: _geo.greatCircleDistanceKm(
            lat1: origin.lat, lon1: origin.lon,
            lat2: e.value.lat, lon2: e.value.lon,
          ),
        ),
    ]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final rampProgress = (run.launches.length /
            WorldLeapConfig.progressiveDistanceRampLaunches)
        .clamp(0.0, 1.0);
    final poolSize = max(
      WorldLeapConfig.progressiveMinCandidatePool,
      (byDistance.length * rampProgress).ceil(),
    ).clamp(1, byDistance.length);

    final seed = _date.hashCode ^ run.launches.length;
    final entry = byDistance[Random(seed).nextInt(poolSize)];
    return (code: entry.code, name: entry.name);
  }

  // ── Countdown timer ─────────────────────────────────────────────────────

  void _startCountdown(int limitSeconds) {
    _countdownTimer?.cancel();
    _timeRemaining = limitSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeRemaining <= 1) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        _handleTimeout();
      } else {
        _timeRemaining--;
        // Notify without changing _state so listeners (e.g. HUD) can redraw
        // the countdown without triggering audio/analytics for Aiming.
        notifyListeners();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _handleTimeout() async {
    final current = _state;
    if (current is! WorldLeapStateAiming) return;
    _comboStreak = 0;
    final run = current.run;
    final failed = run.copyWith(
      isComplete: true,
      failureReason: WorldLeapFailureReason.timeout,
      completedAt: DateTime.now(),
    );
    try {
      await _repository.saveRunLocal(failed);
    } catch (_) {}
    unawaited(_repository.syncRunToFirestore(failed).catchError((_) {}));
    _emit(WorldLeapStateFailed(run: failed, reason: WorldLeapFailureReason.timeout));
  }

  /// Returns true if [landing] is within [WorldLeapConfig.landingToleranceKm]
  /// of [targetCode]'s centroid — accepted even when the reverse-geocoded
  /// country differs (e.g. landing just over a border).
  bool _isWithinLandingTolerance(
      ({double lat, double lon}) landing, String targetCode) {
    final centroid = _countryData[targetCode];
    if (centroid == null) return false;
    final dist = _geo.greatCircleDistanceKm(
      lat1: landing.lat, lon1: landing.lon,
      lat2: centroid.lat, lon2: centroid.lon,
    );
    return dist <= WorldLeapConfig.landingToleranceKm;
  }

  /// Looks up a country using injected [_countryLookup] (for tests) or the
  /// real [WorldLeapCountryService] (in production).
  ({String code, String name})? _lookupCountry(double lat, double lon) {
    if (_countryLookup != null) return _countryLookup(lat, lon);
    return _countryService.countryAt(lat, lon);
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called once on screen entry: loads run or creates new one.
  Future<void> initialize() async {
    _cancelCountdown();
    _emit(WorldLeapStateLoading());

    try {
      final hasRun = await _dailyService.hasExistingRun(_userId, _date);

      if (hasRun) {
        final run = await _repository.loadRun(_userId, _date);
        if (run == null) {
          _emit(WorldLeapStateError(message: 'Failed to load existing run.'));
          return;
        }
        if (run.isComplete) {
          _emit(WorldLeapStateLocked(run: run));
        } else {
          final readyRun = _ensureTarget(run);
          _emit(WorldLeapStateAiming(run: readyRun));
          _startCountdown(readyRun.timeLimitSeconds);
        }
        return;
      }

      // No existing run — fetch start country and create new run.
      final startCountry = await _dailyService.getStartCountry(_date);
      if (startCountry == null) {
        _emit(WorldLeapStateError(
            message: 'No daily configuration found for $_date.'));
        return;
      }

      var run = WorldLeapRun(
        id: WorldLeapRun.documentId(_userId, _date),
        userId: _userId,
        date: _date,
        startCountryCode: startCountry.code,
        startCountryName: startCountry.name,
      );
      run = _ensureTarget(run);

      await _repository.saveRunLocal(run);
      unawaited(_repository.syncRunToFirestore(run).catchError((_) {}));
      _emit(WorldLeapStateAiming(run: run));
      _startCountdown(run.timeLimitSeconds);
    } catch (e) {
      _emit(WorldLeapStateError(message: 'Initialization error: $e'));
    }
  }

  /// Ensures [run] has a target country assigned. Picks one if missing.
  WorldLeapRun _ensureTarget(WorldLeapRun run) {
    if (run.targetCountryCode != null) return run;
    final target = _pickTarget(run);
    if (target == null) return run;
    return run.copyWith(
      targetCountryCode: target.code,
      targetCountryName: target.name,
    );
  }

  /// Player begins pulling the slingshot.
  void startAiming() {
    final current = _state;
    if (current is WorldLeapStateAiming) {
      _emit(WorldLeapStateAiming(
        run: current.run,
        bearingDeg: current.bearingDeg,
        power: current.power,
      ));
    }
  }

  /// Gesture updates bearing (0–360°) and power (0.0–1.0).
  ///
  /// Updates internal state and [aimNotifier] WITHOUT calling notifyListeners().
  /// This prevents 60Hz rebuilds of HUD, Quokka, and the full game Stack.
  /// Only WorldLeapMapWidget (which listens to [aimNotifier]) rebuilds.
  void updateAim({required double bearingDeg, required double power}) {
    final current = _state;
    if (current is! WorldLeapStateAiming) return;

    final clampedPower = power.clamp(0.0, 1.0);
    // Update state silently so launch() reads current bearing/power.
    _state = WorldLeapStateAiming(
      run: current.run,
      bearingDeg: bearingDeg,
      power: clampedPower,
    );
    aimNotifier.value = (bearingDeg: bearingDeg, power: clampedPower);
  }

  /// Beginner mode: called when the player releases the drag WITHOUT firing,
  /// so the frozen aim can be reviewed before committing. [updateAim] already
  /// stored the bearing/power in [_state] without notifying (to avoid 60Hz
  /// rebuilds); this just triggers the one rebuild needed to show the FIRE
  /// button and "on target" hint at their final values. Does not advance
  /// game state — [launch] is still required to actually fire.
  void confirmAim() {
    if (_state is! WorldLeapStateAiming) return;
    _hasConfirmedAim = true;
    notifyListeners();
  }

  /// Player releases — starts the launch sequence.
  Future<void> launch() async {
    final current = _state;
    if (current is! WorldLeapStateAiming) return;

    _hasConfirmedAim = false;
    _cancelCountdown();
    aimNotifier.value = null;

    final run = current.run;
    final bearingDeg = current.bearingDeg ?? 0.0;
    final power = (current.power ?? 0.0).clamp(0.0, 1.0);

    _emit(WorldLeapStateLaunching(
      run: run,
      bearingDeg: bearingDeg,
      power: power,
    ));

    // Compute distance from power, clamped to valid range.
    final rawDistance = power * WorldLeapConfig.maxLaunchDistanceKm;
    final distanceKm = rawDistance.clamp(
      WorldLeapConfig.minLaunchDistanceKm,
      WorldLeapConfig.maxLaunchDistanceKm,
    );

    // Determine launch origin: last landing or country centroid.
    final ({double lat, double lon}) origin;
    if (run.launches.isNotEmpty) {
      final last = run.launches.last;
      origin = (lat: last.landingLat, lon: last.landingLon);
    } else {
      origin = _centroidFor(run.startCountryCode);
    }

    // Compute destination.
    final dest = _geo.destinationPoint(
      startLat: origin.lat,
      startLon: origin.lon,
      bearingDeg: bearingDeg,
      distanceKm: distanceKm,
    );

    // Lookup destination country.
    final destCountry = _lookupCountry(dest.lat, dest.lon);

    // ── Determine outcome synchronously, then animate ────────────────────────
    // All outcome paths (success and failure) wait for the full animation
    // duration so the flight arc is always visible before the result shows.

    // ── Failure cases ───────────────────────────────────────────────────────

    Future<void> failWith(WorldLeapFailureReason reason) async {
      _comboStreak = 0;
      final failed = run.copyWith(
        isComplete: true,
        failureReason: reason,
        completedAt: DateTime.now(),
      );
      // Only the local save + the fixed animation hold-time block the state
      // transition — Firestore sync is fire-and-forget so a slow connection
      // never delays showing the result (offline-first, CLAUDE.md rule 4).
      try {
        await Future.wait([
          _repository.saveRunLocal(failed),
          Future.delayed(
              const Duration(milliseconds: WorldLeapConfig.launchAnimationMs)),
        ]);
      } catch (_) {}
      unawaited(_repository.syncRunToFirestore(failed).catchError((_) {}));
      _emit(WorldLeapStateFailed(run: failed, reason: reason));
    }

    if (destCountry == null) {
      await failWith(WorldLeapFailureReason.water);
      return;
    }

    if (destCountry.code == run.currentCountryCode) {
      await failWith(WorldLeapFailureReason.sameCountry);
      return;
    }

    // ── Check target hit ─────────────────────────────────────────────────────

    final targetCode = run.targetCountryCode;
    if (targetCode != null) {
      final bool isHit = destCountry.code == targetCode ||
          _isWithinLandingTolerance(dest, targetCode);
      if (!isHit) {
        await failWith(WorldLeapFailureReason.wrongCountry);
        return;
      }
    }

    // ── Success ─────────────────────────────────────────────────────────────

    final destContinent = kCountryContinent[destCountry.code];
    final isNewContinent =
        destContinent != null && !run.visitedContinents.contains(destContinent);

    _comboStreak++;
    final scoreBreakdown = _scoring.computeScore(
      distanceKm: distanceKm,
      landingLat: dest.lat,
      landingLon: dest.lon,
      isNewContinent: isNewContinent,
      timeRemaining: _timeRemaining,
      comboStreak: _comboStreak,
    );

    final newLaunch = WorldLeapLaunch(
      launchNumber: run.launches.length + 1,
      fromCountryCode: run.currentCountryCode,
      fromCountryName: run.currentCountryName,
      toCountryCode: destCountry.code,
      toCountryName: destCountry.name,
      bearing: bearingDeg,
      power: power,
      distanceKm: distanceKm,
      landingLat: dest.lat,
      landingLon: dest.lon,
      scoreBreakdown: scoreBreakdown,
      timestamp: DateTime.now(),
      newContinent: isNewContinent,
    );

    // Compute next target + reduced time limit for the next shot.
    final nextTimeLimit = (run.timeLimitSeconds - 1)
        .clamp(WorldLeapConfig.countdownMinSeconds, WorldLeapConfig.countdownStartSeconds);

    var updatedRun = run.copyWith(
      launches: [...run.launches, newLaunch],
      totalScore: run.totalScore + scoreBreakdown.total,
      timeLimitSeconds: nextTimeLimit,
      clearTarget: true, // cleared so _ensureTarget picks a fresh one
    );
    // Assign next target (must not include the country we just landed in).
    updatedRun = _ensureTarget(updatedRun);

    // Only the local save + the fixed animation hold-time block the state
    // transition — Firestore sync is fire-and-forget so a slow or flaky
    // connection never delays the next shot. This was the "aim doesn't
    // respond for a few seconds after a hit" bug: awaiting the Firestore
    // write here meant network latency directly held up returning to
    // Aiming (offline-first, CLAUDE.md hard rule 4).
    try {
      await Future.wait([
        _repository.saveRunLocal(updatedRun),
        Future.delayed(
            const Duration(milliseconds: WorldLeapConfig.launchAnimationMs)),
      ]);
    } catch (e) {
      _emit(WorldLeapStateError(message: 'Failed to save run: $e'));
      return;
    }
    unawaited(_repository.syncRunToFirestore(updatedRun).catchError((_) {}));
    _emit(WorldLeapStateLanded(run: updatedRun, lastLaunch: newLaunch));
  }

  /// Called after score panel animation completes.
  void dismissScorePanel() {
    final current = _state;
    if (current is! WorldLeapStateLanded) return;

    final run = current.run;
    _emit(WorldLeapStateAiming(run: run));
    _startCountdown(run.timeLimitSeconds);
  }

  /// Resets today's run so the player can play again.
  /// Deletes from both local cache and Firestore, then re-initializes.
  Future<void> resetRun() async {
    _cancelCountdown();
    _comboStreak = 0;
    _hasConfirmedAim = false;
    try {
      await _repository.deleteRun(_userId, _date);
    } catch (_) {
      // Firestore delete failed — clear local cache at minimum so
      // initialize() won't load the stale completed run from cache.
      await _repository.clearLocalRun();
    }
    await initialize();
  }

  @override
  void dispose() {
    _cancelCountdown();
    aimNotifier.dispose();
    super.dispose();
  }

  /// Player taps "End Game" button early.
  Future<void> endRun() async {
    final current = _state;
    final WorldLeapRun run;

    if (current is WorldLeapStateAiming) {
      aimNotifier.value = null;
      run = current.run;
    } else if (current is WorldLeapStateLanded) {
      run = current.run;
    } else {
      return;
    }

    final completed = run.copyWith(
      isComplete: true,
      completedAt: DateTime.now(),
    );

    await _repository.saveRunLocal(completed);
    unawaited(_repository.syncRunToFirestore(completed).catchError((_) {}));
    _emit(WorldLeapStateComplete(run: completed));
  }

  /// Returns true if [lat]/[lon] falls within the current source country.
  /// Used by the map widget to hit-test whether a touch starts on the country.
  bool isInCurrentCountry(double lat, double lon) {
    final s = _state;
    if (s is! WorldLeapStateAiming) return false;
    final result = _lookupCountry(lat, lon);
    return result?.code == s.run.currentCountryCode;
  }
}
