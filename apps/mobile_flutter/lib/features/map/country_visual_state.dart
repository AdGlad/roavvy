import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

// ── Enum ──────────────────────────────────────────────────────────────────────

/// Visual state of a country polygon on the world map (M22 / ADR-066).
///
/// Priority (highest to lowest): [newlyDiscovered] > [reviewed] > [visited] > [unvisited].
/// [target] is reserved for M23 (region progress chips); rendered as [visited] for now.
enum CountryVisualState { unvisited, visited, reviewed, newlyDiscovered, target }

// ── RecentDiscoveriesNotifier ─────────────────────────────────────────────────

/// Tracks ISO-3166-1 alpha-2 codes discovered in the last 24 hours.
///
/// Persisted to SharedPreferences under [_kPrefsKey] as a JSON list of
/// `{isoCode, discoveredAt}` entries (ADR-067). Entries older than 24 h are
/// silently dropped on load.
///
/// All mutating methods are safe to call with `unawaited()`.
class RecentDiscoveriesNotifier extends StateNotifier<Set<String>> {
  RecentDiscoveriesNotifier() : super({}) {
    _readyCompleter = Completer<void>();
    _loadFromPrefs().then((_) => _readyCompleter.complete()).catchError((Object _) {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
  }

  static const _kPrefsKey = 'recent_discoveries_v1';

  SharedPreferences? _prefs;

  late final Completer<void> _readyCompleter;

  /// Completes when the initial SharedPreferences load has finished.
  /// Useful in tests to await the async constructor body.
  Future<void> get ready => _readyCompleter.future;

  /// isoCode → UTC timestamp of discovery; kept in sync with [state].
  final Map<String, DateTime> _entries = {};

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kPrefsKey);
    if (raw == null) return;

    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }

    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    for (final entry in list.cast<Map<String, dynamic>>()) {
      final isoCode = entry['isoCode'] as String?;
      final raw = entry['discoveredAt'] as String?;
      if (isoCode == null || raw == null) continue;
      final discoveredAt = DateTime.tryParse(raw);
      if (discoveredAt == null) continue;
      if (discoveredAt.isAfter(cutoff)) {
        _entries[isoCode] = discoveredAt;
      }
    }

    if (!mounted) return;
    state = _entries.keys.toSet();
  }

  /// Marks [isoCode] as recently discovered and persists to SharedPreferences.
  Future<void> add(String isoCode) async {
    _entries[isoCode] = DateTime.now().toUtc();
    if (mounted) state = _entries.keys.toSet();
    _prefs ??= await SharedPreferences.getInstance();
    unawaited(_persist());
  }

  /// Adds all [isoCodes] at once.
  Future<void> addAll(Iterable<String> isoCodes) async {
    final now = DateTime.now().toUtc();
    for (final code in isoCodes) {
      _entries[code] = now;
    }
    if (mounted) state = _entries.keys.toSet();
    _prefs ??= await SharedPreferences.getInstance();
    unawaited(_persist());
  }

  /// Clears all recent discoveries and removes the SharedPreferences key.
  Future<void> clear() async {
    _entries.clear();
    if (mounted) state = {};
    _prefs ??= await SharedPreferences.getInstance();
    unawaited(_prefs!.remove(_kPrefsKey));
  }

  Future<void> _persist() async {
    final list = _entries.entries
        .map((e) => {
              'isoCode': e.key,
              'discoveredAt': e.value.toIso8601String(),
            })
        .toList();
    await _prefs!.setString(_kPrefsKey, jsonEncode(list));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Tracks ISO codes discovered in the last 24 h, persisted across restarts (ADR-067).
final recentDiscoveriesProvider =
    StateNotifierProvider<RecentDiscoveriesNotifier, Set<String>>(
  (ref) => RecentDiscoveriesNotifier(),
);

/// Derived map of isoCode → [CountryVisualState] for all visited countries.
///
/// Unvisited countries are absent from the map (default [CountryVisualState.unvisited]).
/// When [yearFilterProvider] is active, derives states from [filteredEffectiveVisitsProvider]
/// instead of [effectiveVisitsProvider]. [recentDiscoveriesProvider] (newlyDiscovered state)
/// is always overlaid on top regardless of the year filter. (ADR-076)
final countryVisualStatesProvider = Provider<Map<String, CountryVisualState>>((ref) {
  final yearFilter = ref.watch(yearFilterProvider);
  final recentCodes = ref.watch(recentDiscoveriesProvider);

  // Always watch both async providers to maintain dependency tracking.
  final allVisitsAsync = ref.watch(effectiveVisitsProvider);
  final filteredVisitsAsync = ref.watch(filteredEffectiveVisitsProvider);

  final List<EffectiveVisitedCountry> visits;
  if (yearFilter == null) {
    visits = allVisitsAsync.valueOrNull ?? const <EffectiveVisitedCountry>[];
  } else {
    visits = filteredVisitsAsync.valueOrNull ?? const <EffectiveVisitedCountry>[];
  }

  final result = <String, CountryVisualState>{};

  for (final visit in visits) {
    final code = visit.countryCode;
    if (recentCodes.contains(code)) {
      result[code] = CountryVisualState.newlyDiscovered;
    } else if (_isSingleDayVisit(visit)) {
      result[code] = CountryVisualState.reviewed;
    } else {
      result[code] = CountryVisualState.visited;
    }
  }

  return result;
});

/// Per-country [CountryVisualState] lookup, derived from [countryVisualStatesProvider].
final countryVisualStateProvider =
    Provider.family<CountryVisualState, String>((ref, isoCode) {
  return ref.watch(countryVisualStatesProvider)[isoCode] ??
      CountryVisualState.unvisited;
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns true when [firstSeen] and [lastSeen] fall on the same calendar day
/// (UTC), indicating a single-visit country with a narrow date range.
bool _isSingleDayVisit(EffectiveVisitedCountry visit) {
  final first = visit.firstSeen;
  final last = visit.lastSeen;
  if (first == null || last == null) return false;
  return first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
}
