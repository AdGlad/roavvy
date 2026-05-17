import 'dart:math' as math;

import 'package:shared_models/shared_models.dart';

import '../map/country_centroids.dart';

/// Replay mode for the cinematic globe replay (M108).
enum TravelReplayMode {
  /// Every trip ever recorded, sorted chronologically.
  allTime,

  /// Only trips from the current calendar year.
  year,

  /// Only trips from a specific [TripRecord.tripId] group (reserved; UI
  /// currently shows allTime and year only).
  trip,
}

// ── Overlay events (M110) ─────────────────────────────────────────────────────

/// A precomputed event shown as an overlay during the replay hold phase.
///
/// Sealed — only [ReplayAchievementEvent] and [ReplayStatEvent] exist.
/// Events are shown in list order, one at a time, with a bell-curve
/// fade-in/hold/fade-out animation (1 600 ms per event).
sealed class ReplayOverlayEvent {
  const ReplayOverlayEvent();
}

/// A travel stat shown after arriving at a country (M110).
///
/// Examples: label="Countries" value="12", label="Photos" value="246".
class ReplayStatEvent extends ReplayOverlayEvent {
  const ReplayStatEvent({required this.label, required this.value});

  /// Human-readable stat name (e.g. "Countries", "Photos", "Days").
  final String label;

  /// Formatted stat value (e.g. "12", "246", "42").
  final String value;
}

/// An achievement reveal moment triggered by arriving at a country (M110).
///
/// Only shows achievements that are already unlocked — no new business logic.
class ReplayAchievementEvent extends ReplayOverlayEvent {
  const ReplayAchievementEvent({
    required this.achievementId,
    required this.title,
    required this.subtitle,
  });

  final String achievementId;

  /// Short title (e.g. "Europe Explorer").
  final String title;

  /// One-line description (e.g. "5 countries in Europe").
  final String subtitle;
}

// ── TravelLeg ─────────────────────────────────────────────────────────────────

/// A single travel leg between two countries.
///
/// [fromLat]/[fromLng] and [toLat]/[toLng] are the actual GPS coordinates of
/// the last photo in the departing trip and the first photo in the arriving
/// trip respectively (M109, ADR-157). When null, the replay engine falls back
/// to [kCountryCentroids] for visual positioning.
class TravelLeg {
  const TravelLeg({
    required this.fromCode,
    required this.toCode,
    required this.date,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  /// ISO 3166-1 alpha-2 departure country.
  final String fromCode;

  /// ISO 3166-1 alpha-2 arrival country.
  final String toCode;

  /// Date of travel (used for year-filter and display).
  final DateTime date;

  /// Actual GPS of the last photo in the departing trip segment. Null when
  /// the trip has no GPS data (manual trips, pre-v12 data, or no GPS photos).
  final double? fromLat;
  final double? fromLng;

  /// Actual GPS of the first photo in the arriving trip segment.
  final double? toLat;
  final double? toLng;

  /// True when this leg has explicit GPS coordinates for the departure point.
  bool get hasFromGps => fromLat != null && fromLng != null;

  /// True when this leg has explicit GPS coordinates for the arrival point.
  bool get hasToGps => toLat != null && toLng != null;

  @override
  String toString() => 'TravelLeg($fromCode→$toCode, ${date.year}, '
      'gps: ${hasFromGps ? "($fromLat,$fromLng)" : "centroid"}→'
      '${hasToGps ? "($toLat,$toLng)" : "centroid"})';
}

// ── TravelReplayScript ────────────────────────────────────────────────────────

/// An ordered list of [TravelLeg]s ready to replay on the globe.
///
/// [overlayEvents] is keyed by leg index — events fire after that leg's
/// hold phase in list order. [summaryStats] are shown on the end summary screen.
class TravelReplayScript {
  const TravelReplayScript({
    required this.legs,
    required this.mode,
    required this.label,
    this.overlayEvents = const {},
    this.summaryStats = const [],
    this.legPacing = const [],
  });

  final List<TravelLeg> legs;
  final TravelReplayMode mode;

  /// Human-readable label shown in the replay UI (e.g. "All-Time Travels").
  final String label;

  /// Per-leg overlay events, keyed by leg index (M110).
  ///
  /// Events fire after the hold phase of the leg at that index, in list order.
  /// At most 2 events per leg: 1 [ReplayAchievementEvent] + 1 [ReplayStatEvent].
  final Map<int, List<ReplayOverlayEvent>> overlayEvents;

  /// Stats shown on the end-of-replay summary screen (M110).
  final List<ReplayStatEvent> summaryStats;

  /// Per-leg cinematic pacing, precomputed by [ReplayPacingRules] (M111).
  ///
  /// When empty, [TravelReplayController] falls back to fixed constants.
  final List<LegPacing> legPacing;

  bool get isEmpty => legs.isEmpty;
}

// ── TravelReplayScriptBuilder ─────────────────────────────────────────────────

/// Converts a list of [TripRecord]s into a [TravelReplayScript].
///
/// Strategy: trips sorted by [TripRecord.startedOn]; consecutive records with
/// different [countryCode] form one leg. Duplicate `fromCode == toCode` legs
/// are dropped.
class TravelReplayScriptBuilder {
  const TravelReplayScriptBuilder._();

  static TravelReplayScript build({
    required List<TripRecord> trips,
    required TravelReplayMode mode,
    int? year,
  }) {
    final targetYear = year ?? DateTime.now().year;

    // Filter by mode.
    final filtered = switch (mode) {
      TravelReplayMode.allTime => trips,
      TravelReplayMode.year =>
        trips.where((t) => t.startedOn.year == targetYear).toList(),
      TravelReplayMode.trip => trips, // caller narrows by tripId if needed
    };

    // Sort chronologically.
    final sorted = filtered.toList()
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    // For year mode: if the user was already in a different country at the start
    // of the year (trip started before targetYear), seed the leg list with that
    // trip so the cross-year departure leg is captured.
    // e.g. AU stay started in 2025, first 2026 trip is JP → we get AU→JP as leg 0.
    if (mode == TravelReplayMode.year && sorted.isNotEmpty) {
      final allSorted = trips.toList()
        ..sort((a, b) => a.startedOn.compareTo(b.startedOn));
      final lastBefore = allSorted
          .where((t) => t.startedOn.year < targetYear)
          .lastOrNull;
      if (lastBefore != null &&
          lastBefore.countryCode != sorted.first.countryCode) {
        sorted.insert(0, lastBefore);
      }
    }

    // Build legs from consecutive country changes.
    // M109: use actual trip GPS endpoints — last GPS of departing trip as
    // departure point; first GPS of arriving trip as arrival point (ADR-157).
    final legs = <TravelLeg>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final from = sorted[i];
      final to = sorted[i + 1];
      if (from.countryCode == to.countryCode) continue;
      legs.add(TravelLeg(
        fromCode: from.countryCode,
        toCode: to.countryCode,
        date: to.startedOn,
        fromLat: from.lastLat,
        fromLng: from.lastLng,
        toLat: to.firstLat,
        toLng: to.firstLng,
      ));
    }

    final label = switch (mode) {
      TravelReplayMode.allTime => 'All-Time Travels',
      TravelReplayMode.year => '$targetYear Travels',
      TravelReplayMode.trip => 'Trip Replay',
    };

    return TravelReplayScript(legs: legs, mode: mode, label: label);
  }

  /// Per-leg duration in milliseconds, compressed for large scripts.
  static int legDurationMs(int legCount) {
    if (legCount <= 10) return 3500;
    if (legCount <= 30) return 2000;
    if (legCount <= 80) return 1200;
    return 700;
  }
}

// ── LegPacing (M111) ──────────────────────────────────────────────────────────

/// Cinematic timing parameters for a single replay leg.
///
/// Computed by [ReplayPacingRules] based on the great-circle arc distance
/// between departure and arrival. Longer arcs use slower, more dramatic timing;
/// shorter regional arcs are snappier.
class LegPacing {
  const LegPacing({
    required this.departureSettleMs,
    required this.departureHoldMs,
    required this.flightMs,
    required this.pulseMs,
    required this.holdMs,
    required this.peakScale,
    required this.scaleDipAmount,
  });

  final int departureSettleMs;
  final int departureHoldMs;
  final int flightMs;
  final int pulseMs;
  final int holdMs;

  /// Globe zoom scale at arrival (peak). Larger for longer arcs.
  final double peakScale;

  /// Mid-flight scale reduction magnitude. Larger values create a greater
  /// sense of distance and height during the arc.
  final double scaleDipAmount;
}

// ── ReplayPacingRules (M111) ──────────────────────────────────────────────────

/// Computes cinematic [LegPacing] for each leg based on great-circle arc distance.
///
/// Classification:
/// - **short**  < 20° (e.g. France→Germany)
/// - **medium** 20–90° (e.g. UK→Thailand)
/// - **long**   > 90° (e.g. Australia→Europe)
///
/// For scripts with >30 legs, flight duration is further compressed proportionally
/// to preserve reasonable total replay time (uses [TravelReplayScriptBuilder.legDurationMs]
/// as the ceiling for very large scripts).
class ReplayPacingRules {
  const ReplayPacingRules._();

  // ── Pacing tables by distance class ────────────────────────────────────────

  static const _kShort = LegPacing(
    departureSettleMs: 500,
    departureHoldMs: 150,
    flightMs: 800,
    pulseMs: 250,
    holdMs: 150,
    peakScale: 1.8,
    scaleDipAmount: 0.2,
  );

  static const _kMedium = LegPacing(
    departureSettleMs: 700,
    departureHoldMs: 250,
    flightMs: 1800,
    pulseMs: 300,
    holdMs: 300,
    peakScale: 1.9,
    scaleDipAmount: 0.45,
  );

  static const _kLong = LegPacing(
    departureSettleMs: 900,
    departureHoldMs: 400,
    flightMs: 3000,
    pulseMs: 400,
    holdMs: 500,
    peakScale: 2.0,
    scaleDipAmount: 0.65,
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Great-circle arc distance in degrees between two lat/lng points.
  ///
  /// Uses the haversine formula; returns a value in [0, 180].
  static double arcDistanceDeg(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final lat1R = lat1 * math.pi / 180.0;
    final lat2R = lat2 * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1R) *
            math.cos(lat2R) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return c * 180.0 / math.pi;
  }

  /// Resolves the arc distance for a [TravelLeg], using explicit GPS when
  /// available and falling back to [kCountryCentroids].
  static double legArcDistance(TravelLeg leg) {
    double? fromLat = leg.fromLat;
    double? fromLng = leg.fromLng;
    double? toLat = leg.toLat;
    double? toLng = leg.toLng;

    if (fromLat == null || fromLng == null) {
      final c = kCountryCentroids[leg.fromCode];
      if (c != null) { fromLat = c.$1; fromLng = c.$2; }
    }
    if (toLat == null || toLng == null) {
      final c = kCountryCentroids[leg.toCode];
      if (c != null) { toLat = c.$1; toLng = c.$2; }
    }

    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      return 45.0; // safe medium fallback
    }
    return arcDistanceDeg(fromLat, fromLng, toLat, toLng);
  }

  /// Computes [LegPacing] for a single leg.
  ///
  /// [totalLegs] is used to apply a compression cap on flight duration for
  /// large scripts: the flight duration will not exceed the value returned by
  /// [TravelReplayScriptBuilder.legDurationMs].
  static LegPacing compute(TravelLeg leg, int totalLegs) {
    final dist = legArcDistance(leg);
    final base = dist < 20.0
        ? _kShort
        : dist < 90.0
            ? _kMedium
            : _kLong;

    // Apply flight compression for large scripts (>30 legs).
    final cap = TravelReplayScriptBuilder.legDurationMs(totalLegs);
    if (base.flightMs <= cap) return base;

    return LegPacing(
      departureSettleMs: base.departureSettleMs,
      departureHoldMs: base.departureHoldMs,
      flightMs: cap,
      pulseMs: base.pulseMs,
      holdMs: base.holdMs,
      peakScale: base.peakScale,
      scaleDipAmount: base.scaleDipAmount,
    );
  }

  /// Precomputes [LegPacing] for all legs in [script].
  ///
  /// Call once before replay starts; assign result to
  /// [TravelReplayScript.legPacing].
  static List<LegPacing> buildPacingList(TravelReplayScript script) {
    final totalLegs = script.legs.length;
    return [
      for (final leg in script.legs) compute(leg, totalLegs),
    ];
  }
}

// ── ReplayTimelineBuilder (M110) ──────────────────────────────────────────────

/// Precomputes achievement reveal and stat overlay events for a replay script.
///
/// This class is **pure**: no I/O, no side effects, deterministic output.
/// Call [build] once before replay starts; the result is stored on
/// [TravelReplayScript.overlayEvents] and [TravelReplayScript.summaryStats].
///
/// Achievement detection: walks legs chronologically, maintains a running
/// visited-country set, calls [AchievementEngine.evaluate] at each step, and
/// records when a threshold is first crossed. Only achievements present in
/// [unlockedIds] are shown — no new unlock logic is applied here.
///
/// Stat events: shown at every 5th leg and the final leg. Content is scope-
/// appropriate (countries + continents for allTime/year; days + photos for trip).
///
/// Cap: at most 1 achievement + 1 stat event per leg.
class ReplayTimelineBuilder {
  const ReplayTimelineBuilder._();

  static ({
    Map<int, List<ReplayOverlayEvent>> events,
    List<ReplayStatEvent> summary,
  }) build({
    required List<TravelLeg> legs,
    required List<TripRecord> allTrips,
    required Set<String> unlockedIds,
    required TravelReplayMode mode,
    int? year,
  }) {
    if (legs.isEmpty) return (events: const {}, summary: const []);

    // Sort trips chronologically (mirrors TravelReplayScriptBuilder order).
    final targetYear = year ?? DateTime.now().year;
    final scopedTrips = switch (mode) {
      TravelReplayMode.allTime => allTrips,
      TravelReplayMode.year =>
        allTrips.where((t) => t.startedOn.year == targetYear).toList(),
      TravelReplayMode.trip => allTrips,
    };
    final sortedTrips = scopedTrips.toList()
      ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

    // ── Achievement detection ─────────────────────────────────────────────────
    final events = <int, List<ReplayOverlayEvent>>{};

    // Pre-seed prevUnlocked with achievements already earned before this scope.
    // Without this, achievements like "First Trip" would appear during a year
    // replay even though they were actually unlocked in a prior year.
    var prevUnlocked = <String>{};
    if (mode == TravelReplayMode.year) {
      final preScope = allTrips
          .where((t) => t.startedOn.year < targetYear)
          .toList();
      if (preScope.isNotEmpty) {
        final preCodes = preScope.map((t) => t.countryCode).toSet();
        final preVisits = preCodes
            .map((c) => EffectiveVisitedCountry(
                  countryCode: c,
                  hasPhotoEvidence: true,
                ))
            .toList();
        prevUnlocked =
            AchievementEngine.evaluate(preVisits, tripCount: preScope.length);
      }
    }

    final seenCodes = <String>{};
    var seenTripCount = 0;

    void addEvent(int legIndex, ReplayOverlayEvent event) {
      events.putIfAbsent(legIndex, () => []).add(event);
    }

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];

      // Build running visit list up to and including this leg's arrival.
      seenCodes.add(leg.toCode);
      // Find the trip that corresponds to arriving in toCode on leg.date.
      final matchedTrip = sortedTrips.where((t) =>
          t.countryCode == leg.toCode &&
          !t.startedOn.isAfter(leg.date.add(const Duration(days: 1)))).lastOrNull;
      if (matchedTrip != null) seenTripCount++;

      final runningVisits = seenCodes
          .map((code) => EffectiveVisitedCountry(
                countryCode: code,
                hasPhotoEvidence: true,
              ))
          .toList();

      final nowUnlocked = AchievementEngine.evaluate(
        runningVisits,
        tripCount: seenTripCount,
      );
      final newlyUnlocked = nowUnlocked.difference(prevUnlocked);
      prevUnlocked = nowUnlocked;

      // Achievement event: pick the most significant newly unlocked achievement
      // (prefer higher progressTarget). Only include if in user's unlockedIds.
      final showable = kAchievements
          .where((a) => newlyUnlocked.contains(a.id) && unlockedIds.contains(a.id))
          .toList()
        ..sort((a, b) => b.progressTarget.compareTo(a.progressTarget));

      if (showable.isNotEmpty) {
        final a = showable.first;
        addEvent(i, ReplayAchievementEvent(
          achievementId: a.id,
          title: a.title,
          subtitle: a.description,
        ));
      }

      // Stat event: every 5th leg (0-indexed: legs 4, 9, 14…) and final leg.
      final isFinalLeg = i == legs.length - 1;
      final isStatLeg = (i + 1) % 5 == 0 || isFinalLeg;
      if (isStatLeg) {
        final statEvent = _buildStatEvent(
          mode: mode,
          seenCodes: Set.of(seenCodes),
          legs: legs,
          upToIndex: i,
          sortedTrips: sortedTrips,
        );
        addEvent(i, statEvent);
      }
    }

    // ── Summary stats ─────────────────────────────────────────────────────────
    final allSeenCodes = legs.map((l) => l.toCode).toSet()
      ..addAll(legs.map((l) => l.fromCode));
    final continents = allSeenCodes
        .map((c) => kCountryContinent[c])
        .whereType<String>()
        .toSet();
    final totalPhotos = scopedTrips.fold(0, (sum, t) => sum + t.photoCount);
    final totalDays = scopedTrips.fold(0, (sum, t) =>
        sum + t.endedOn.difference(t.startedOn).inDays + 1);

    final summary = [
      ReplayStatEvent(label: 'Countries', value: '${allSeenCodes.length}'),
      ReplayStatEvent(label: 'Continents', value: '${continents.length}'),
      ReplayStatEvent(label: 'Photos', value: '$totalPhotos'),
      ReplayStatEvent(label: 'Days', value: '$totalDays'),
    ];

    return (events: events, summary: summary);
  }

  static ReplayStatEvent _buildStatEvent({
    required TravelReplayMode mode,
    required Set<String> seenCodes,
    required List<TravelLeg> legs,
    required int upToIndex,
    required List<TripRecord> sortedTrips,
  }) {
    switch (mode) {
      case TravelReplayMode.trip:
        // Trip mode: show days travelled so far.
        final tripsInWindow = sortedTrips
            .where((t) => !t.startedOn.isAfter(legs[upToIndex].date))
            .toList();
        final days = tripsInWindow.fold(0, (sum, t) =>
            sum + t.endedOn.difference(t.startedOn).inDays + 1);
        return ReplayStatEvent(label: 'Days', value: '$days');

      case TravelReplayMode.year:
      case TravelReplayMode.allTime:
        // Year / all-time: show countries visited so far.
        final countryCount = seenCodes.length;
        return ReplayStatEvent(label: 'Countries', value: '$countryCount');
    }
  }
}
