import 'package:shared_models/shared_models.dart';

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
    var prevUnlocked = <String>{};
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
      ReplayStatEvent(label: 'Countries', value: '${legs.map((l) => l.toCode).toSet().length}'),
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
