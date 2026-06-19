// lib/features/world_leap/application/world_leap_daily_service.dart
//
// Offline-first daily start-country service.
//
// Resolution order for getStartCountry():
//   1. SharedPreferences local cache (instant, works offline)
//   2. Firestore `world_leap_daily/{date}` document (set by admin tooling)
//   3. Deterministic fallback — derived from the date string so the same date
//      always produces the same starting country, even with no network.
//
// Resolution order for hasExistingRun():
//   1. SharedPreferences local run cache (avoids a network round-trip)
//   2. Firestore presence check

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/world_leap_run.dart';
import '../world_leap_config.dart';

// ── Fallback start-country pool ───────────────────────────────────────────────
//
// Curated selection of geographically varied countries used when no Firestore
// document exists for the day. Must never be empty.

const _kStartPool = <({String code, String name})>[
  (code: 'AU', name: 'Australia'),
  (code: 'BR', name: 'Brazil'),
  (code: 'CA', name: 'Canada'),
  (code: 'CN', name: 'China'),
  (code: 'EG', name: 'Egypt'),
  (code: 'ET', name: 'Ethiopia'),
  (code: 'FR', name: 'France'),
  (code: 'DE', name: 'Germany'),
  (code: 'GH', name: 'Ghana'),
  (code: 'IN', name: 'India'),
  (code: 'ID', name: 'Indonesia'),
  (code: 'JP', name: 'Japan'),
  (code: 'KE', name: 'Kenya'),
  (code: 'MA', name: 'Morocco'),
  (code: 'MX', name: 'Mexico'),
  (code: 'NG', name: 'Nigeria'),
  (code: 'NZ', name: 'New Zealand'),
  (code: 'PE', name: 'Peru'),
  (code: 'PH', name: 'Philippines'),
  (code: 'PL', name: 'Poland'),
  (code: 'PT', name: 'Portugal'),
  (code: 'RU', name: 'Russia'),
  (code: 'SA', name: 'Saudi Arabia'),
  (code: 'ZA', name: 'South Africa'),
  (code: 'KR', name: 'South Korea'),
  (code: 'ES', name: 'Spain'),
  (code: 'SE', name: 'Sweden'),
  (code: 'TZ', name: 'Tanzania'),
  (code: 'TH', name: 'Thailand'),
  (code: 'TR', name: 'Turkey'),
  (code: 'UA', name: 'Ukraine'),
  (code: 'GB', name: 'United Kingdom'),
  (code: 'US', name: 'United States'),
  (code: 'VN', name: 'Vietnam'),
  (code: 'AR', name: 'Argentina'),
];

/// Returns a deterministic start country for [date] (format "YYYY-MM-DD").
/// The same date always produces the same country on every device.
({String code, String name}) _deterministicStart(String date) {
  // Fold all char-code values with a prime multiplier for good distribution.
  final hash = date.codeUnits.fold(0, (int acc, int c) => acc * 31 + c);
  final idx = hash.abs() % _kStartPool.length;
  return _kStartPool[idx];
}

// ── Interface ─────────────────────────────────────────────────────────────────

abstract class IWorldLeapDailyService {
  /// Returns the start country for [date] (ISO date string "YYYY-MM-DD").
  /// Never returns null — falls back to deterministic generation if needed.
  Future<({String code, String name})?> getStartCountry(String date);

  /// Returns true if [userId] already has a run for [date].
  Future<bool> hasExistingRun(String userId, String date);
}

// ── Implementation ────────────────────────────────────────────────────────────

class WorldLeapFirestoreDailyService implements IWorldLeapDailyService {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  WorldLeapFirestoreDailyService(FirebaseFirestore firestore, SharedPreferences prefs)
      : _firestore = firestore,
        _prefs = prefs;

  // SharedPreferences key for cached start country: "wl_daily_YYYY-MM-DD"
  String _dailyKey(String date) => 'wl_daily_$date';

  @override
  Future<({String code, String name})?> getStartCountry(String date) async {
    // ── 1. Local cache ────────────────────────────────────────────────────────
    final cached = _prefs.getString(_dailyKey(date));
    if (cached != null) {
      final parts = cached.split('|');
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return (code: parts[0], name: parts[1]);
      }
    }

    // ── 2. Firestore ──────────────────────────────────────────────────────────
    try {
      final doc = await _firestore
          .collection(WorldLeapConfig.dailyCollection)
          .doc(date)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final code = data['countryCode'] as String?;
        final name = data['countryName'] as String?;
        if (code != null && name != null) {
          final country = (code: code, name: name);
          await _cacheDaily(date, country);
          return country;
        }
      }
    } catch (_) {
      // Offline or permission error — fall through to deterministic fallback.
    }

    // ── 3. Deterministic fallback ─────────────────────────────────────────────
    final country = _deterministicStart(date);
    await _cacheDaily(date, country);
    return country;
  }

  Future<void> _cacheDaily(
      String date, ({String code, String name}) country) async {
    await _prefs.setString(_dailyKey(date), '${country.code}|${country.name}');
  }

  @override
  Future<bool> hasExistingRun(String userId, String date) async {
    // ── 1. Local cache ────────────────────────────────────────────────────────
    final cached = _prefs.getString(WorldLeapConfig.localRunKey);
    if (cached != null) {
      try {
        final run =
            WorldLeapRun.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        if (run.userId == userId && run.date == date) return true;
      } catch (_) {
        // Corrupt cache — fall through.
      }
    }

    // ── 2. Firestore ──────────────────────────────────────────────────────────
    try {
      final docId = '${userId}_$date';
      final doc = await _firestore
          .collection(WorldLeapConfig.runsCollection)
          .doc(docId)
          .get();
      return doc.exists;
    } catch (_) {
      // Offline — no local run found above, so treat as no existing run.
      return false;
    }
  }
}
