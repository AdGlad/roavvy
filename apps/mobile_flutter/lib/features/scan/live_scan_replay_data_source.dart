import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../globe_replay/replay_data_source.dart';

/// Live data source fed by [_ScanScreenState] during an active photo scan.
///
/// The scan engine calls [addEvent] after each batch. Events are buffered in
/// [_queue] and sorted by [CountryDiscoveredEvent.date] before being consumed
/// so that out-of-order batch arrivals are replayed chronologically.
///
/// [markScanComplete] appends [ScanCompletedEvent] and notifies listeners.
/// After that point no further events can be added.
class LiveScanReplayDataSource extends ChangeNotifier
    implements ReplayDataSource {
  final Queue<ReplayEvent> _queue = Queue();
  bool _scanComplete = false;

  // Pending overlay events (heritage, achievements) not yet attached to a leg.
  // Keyed by countryCode; flushed as overlay events for the next matching leg.
  final Map<String, List<ReplayEvent>> _pendingOverlays = {};

  /// Called by [_ScanScreenState] after each batch.
  ///
  /// [CountryDiscoveredEvent]s are inserted in date order (chronological).
  /// Overlay events are queued immediately after the matching country event.
  void addEvent(ReplayEvent event) {
    assert(!_scanComplete, 'addEvent called after markScanComplete');
    if (event is CountryDiscoveredEvent) {
      final list = _queue.toList();
      final idx = _insertionIndexFor(event.date, list);
      list.insert(idx, event);
      // Re-attach pending overlays for this country immediately after the leg.
      final overlays = _pendingOverlays.remove(event.toCode) ?? [];
      var insertAfter = idx + 1;
      for (final o in overlays) {
        list.insert(insertAfter, o);
        insertAfter++;
      }
      _queue
        ..clear()
        ..addAll(list);
    } else if (event is HeritageSiteDiscoveredEvent) {
      _pendingOverlays.putIfAbsent(event.countryCode, () => []).add(event);
    } else if (event is AchievementUnlockedEvent) {
      final code = event.countryCode;
      if (code != null) {
        _pendingOverlays.putIfAbsent(code, () => []).add(event);
      } else {
        _queue.addLast(event); // global: show after current position
      }
    } else if (event is YearStartedEvent) {
      _insertYearBannerFor(event);
    } else if (event is ScanProgressUpdatedEvent) {
      _queue.addLast(event);
    }
    notifyListeners();
  }

  /// Signals scan completion. Flushes any remaining pending overlays then
  /// appends [ScanCompletedEvent]. No further [addEvent] calls after this.
  void markScanComplete() {
    _scanComplete = true;
    // Flush any pending overlays not yet matched to a leg.
    for (final overlays in _pendingOverlays.values) {
      _queue.addAll(overlays);
    }
    _pendingOverlays.clear();
    _queue.addLast(const ScanCompletedEvent());
    notifyListeners();
  }

  @override
  bool get hasNextEvent => _queue.isNotEmpty;

  @override
  bool get isExhausted => _queue.isEmpty && _scanComplete;

  @override
  ReplayEvent? dequeue() {
    if (_queue.isEmpty) return null;
    final ev = _queue.removeFirst();
    notifyListeners();
    return ev;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the index at which to insert a [CountryDiscoveredEvent] with
  /// [date], placing it before the first existing [CountryDiscoveredEvent]
  /// that has a later date (maintains chronological order).
  int _insertionIndexFor(DateTime date, List<ReplayEvent> list) {
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is CountryDiscoveredEvent && e.date.isAfter(date)) {
        return i;
      }
    }
    return list.length;
  }

  /// Inserts a [YearStartedEvent] before the first [CountryDiscoveredEvent]
  /// that has the matching year, if not already present.
  void _insertYearBannerFor(YearStartedEvent event) {
    final list = _queue.toList();
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is CountryDiscoveredEvent && e.date.year == event.year) {
        // Skip if a year banner is already immediately before this leg.
        if (i > 0 && list[i - 1] is YearStartedEvent) return;
        list.insert(i, event);
        _queue
          ..clear()
          ..addAll(list);
        return;
      }
    }
    // No matching leg found yet — append so it precedes future legs.
    _queue.addLast(event);
  }
}
