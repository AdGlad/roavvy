import 'dart:convert';

import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the local visited-country list across app restarts.
///
/// Stores a JSON array under a single [SharedPreferences] key.
/// All writes are fire-and-forget from the UI layer's perspective —
/// [save] is async but callers can await it if they need confirmation.
///
/// This is the sole local persistence layer for the spike. A Drift database
/// table will replace it once sync and richer querying are required.
class VisitStore {
  static const _key = 'roavvy.visits.v1';

  /// Loads all persisted [CountryVisit] records.
  /// Returns an empty list if nothing has been saved yet.
  static Future<List<CountryVisit>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(CountryVisit.fromJson)
        .toList();
  }

  /// Persists [visits], replacing any previously saved list.
  static Future<void> save(List<CountryVisit> visits) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(visits.map((v) => v.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Removes all persisted visits. Useful for testing and user-initiated reset.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
