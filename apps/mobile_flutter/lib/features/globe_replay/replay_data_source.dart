import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'travel_replay_engine.dart';

// ── ReplayEvent sealed hierarchy ──────────────────────────────────────────────

/// Abstract event emitted by a [ReplayDataSource].
///
/// Sealed — only the concrete subtypes in this file exist.
sealed class ReplayEvent {
  const ReplayEvent();
}

/// Emitted when the scan (or historical script) crosses a calendar year
/// boundary. The controller shows a year banner overlay before the next leg.
class YearStartedEvent extends ReplayEvent {
  const YearStartedEvent({required this.year});
  final int year;
}

/// A country-to-country transition — maps directly to a [TravelLeg].
class CountryDiscoveredEvent extends ReplayEvent {
  const CountryDiscoveredEvent({
    required this.fromCode,
    required this.toCode,
    required this.date,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.isFirstVisit = false,
  });
  final String fromCode;
  final String toCode;
  final DateTime date;
  final double? fromLat, fromLng, toLat, toLng;
  /// True when this is the first time [toCode] is visited in this replay.
  /// Drives the flag-reveal + confetti discovery animation (M133).
  final bool isFirstVisit;
}

/// A UNESCO heritage site discovered in the currently active country.
/// Queued as an overlay event for the active or next [CountryDiscoveredEvent].
class HeritageSiteDiscoveredEvent extends ReplayEvent {
  const HeritageSiteDiscoveredEvent({
    required this.countryCode,
    required this.siteName,
    required this.siteType,
  });
  final String countryCode;
  final String siteName;

  /// UNESCO category: 'cultural', 'natural', 'mixed', or null.
  final String? siteType;
}

/// An achievement unlocked during the active or next [CountryDiscoveredEvent].
class AchievementUnlockedEvent extends ReplayEvent {
  const AchievementUnlockedEvent({
    required this.achievementId,
    required this.title,
    required this.subtitle,
    this.countryCode, // null = global, attach to next leg
  });
  final String achievementId;
  final String title;
  final String subtitle;
  final String? countryCode;
}

/// Scan engine progress update — drives the "Scanning live…" indicator.
class ScanProgressUpdatedEvent extends ReplayEvent {
  const ScanProgressUpdatedEvent({required this.processedCount});
  final int processedCount;
}

/// Signals the scan engine has finished. After this arrives and the queue
/// drains, [LiveScanReplayController] transitions to completed.
class ScanCompletedEvent extends ReplayEvent {
  const ScanCompletedEvent();
}

// ── ReplayDataSource interface ─────────────────────────────────────────────────

/// Abstract data source consumed by [LiveScanReplayController].
///
/// Implementations notify listeners when new events become available so
/// the controller can resume after a waiting pause.
abstract interface class ReplayDataSource implements Listenable {
  /// True if at least one event is ready to dequeue.
  bool get hasNextEvent;

  /// True when no further events will ever arrive (scan complete + queue empty,
  /// or historical script fully consumed).
  bool get isExhausted;

  /// Returns and removes the next event. Returns null if [hasNextEvent] is false.
  ReplayEvent? dequeue();
}

// ── HistoricalReplayDataSource ─────────────────────────────────────────────────

/// Wraps a pre-built [TravelReplayScript] as a [ReplayDataSource].
///
/// Converts legs to [CountryDiscoveredEvent]s and per-leg overlay events
/// to [HeritageSiteDiscoveredEvent] / [AchievementUnlockedEvent], inserting
/// a [YearStartedEvent] whenever the leg year changes.
///
/// [isExhausted] becomes true as soon as all events have been dequeued.
class HistoricalReplayDataSource extends ChangeNotifier
    implements ReplayDataSource {
  HistoricalReplayDataSource(TravelReplayScript script) {
    _buildQueue(script);
  }

  final Queue<ReplayEvent> _queue = Queue();

  void _buildQueue(TravelReplayScript script) {
    int? lastYear;
    for (var i = 0; i < script.legs.length; i++) {
      final leg = script.legs[i];
      // Year banner before first leg of each new calendar year.
      if (lastYear == null || leg.date.year != lastYear) {
        _queue.add(YearStartedEvent(year: leg.date.year));
        lastYear = leg.date.year;
      }
      _queue.add(CountryDiscoveredEvent(
        fromCode: leg.fromCode,
        toCode: leg.toCode,
        date: leg.date,
        fromLat: leg.fromLat,
        fromLng: leg.fromLng,
        toLat: leg.toLat,
        toLng: leg.toLng,
        isFirstVisit: leg.isFirstVisit,
      ));
      // Per-leg overlay events (heritage, achievements).
      for (final oe in script.overlayEvents[i] ?? const []) {
        switch (oe) {
          case ReplayHeritageEvent e:
            _queue.add(HeritageSiteDiscoveredEvent(
              countryCode: leg.toCode,
              siteName: e.siteName,
              siteType: e.siteType,
            ));
          case ReplayAchievementEvent e:
            _queue.add(AchievementUnlockedEvent(
              achievementId: e.achievementId,
              title: e.title,
              subtitle: e.subtitle,
              countryCode: leg.toCode,
            ));
          case ReplayStatEvent _:
            break; // stat events not surfaced through this interface
        }
      }
    }
  }

  @override
  bool get hasNextEvent => _queue.isNotEmpty;

  @override
  bool get isExhausted => _queue.isEmpty;

  @override
  ReplayEvent? dequeue() {
    if (_queue.isEmpty) return null;
    final ev = _queue.removeFirst();
    if (_queue.isEmpty) notifyListeners(); // signal exhaustion
    return ev;
  }
}
