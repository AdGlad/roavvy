import 'package:shared_preferences/shared_preferences.dart';

/// Persists the highest XP level for which the [LevelUpSheet] has been shown.
///
/// Backed by [SharedPreferences] key `level_up_shown_v1`.
/// Default value is 1 (the starting level — no sheet shown for level 1).
class LevelUpRepository {
  static const _key = 'level_up_shown_v1';

  /// Returns the last level for which the level-up sheet was shown.
  /// Returns 1 (the starting level) when the key is absent.
  Future<int> getLastShownLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 1;
  }

  /// Records [level] as shown. Idempotent — calling multiple times with the
  /// same value has no additional effect.
  Future<void> markShown(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level);
  }
}
