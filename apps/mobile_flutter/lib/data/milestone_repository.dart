import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Country count thresholds that trigger a [MilestoneCardSheet].
const List<int> kMilestoneThresholds = [5, 10, 25, 50, 100];

/// Persists which milestone thresholds have already been shown to the user,
/// so each milestone card appears exactly once.
///
/// Backed by [SharedPreferences] key `shown_milestones_v1` (JSON list of ints).
class MilestoneRepository {
  static const _key = 'shown_milestones_v1';

  /// Returns the set of thresholds that have already been shown.
  /// Returns an empty set if the key is absent.
  Future<Set<int>> getShownThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return {};
    final list = (jsonDecode(json) as List).cast<int>();
    return list.toSet();
  }

  /// Records [threshold] as shown. Idempotent — calling multiple times with
  /// the same value has no additional effect.
  Future<void> markShown(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getShownThresholds();
    current.add(threshold);
    await prefs.setString(_key, jsonEncode(current.toList()));
  }
}
