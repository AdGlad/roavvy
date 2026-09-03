import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'procedural/procedural.dart';

/// Persists the user's design-preference profile locally. Abstracted so tests
/// can inject a fake.
abstract class PreferenceStore {
  Future<UserDesignPreferenceProfile> load();
  Future<void> save(UserDesignPreferenceProfile profile);
}

/// Default store — a single JSON blob in SharedPreferences. On-device only.
class SharedPrefsPreferenceStore implements PreferenceStore {
  static const _key = 'design_pref_profile_v1';

  @override
  Future<UserDesignPreferenceProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return UserDesignPreferenceProfile.neutral;
    try {
      return UserDesignPreferenceProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return UserDesignPreferenceProfile.neutral;
    }
  }

  @override
  Future<void> save(UserDesignPreferenceProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}

/// Holds the live preference profile and folds in behavioural signals. Loads
/// asynchronously (starts neutral); every recorded signal updates the profile
/// and persists it. This is the USER PREFERENCE side — kept separate from the
/// engine's intrinsic QUALITY score.
class PreferenceProfileNotifier
    extends StateNotifier<UserDesignPreferenceProfile> {
  PreferenceProfileNotifier(
    this._store, {
    PreferenceLearner learner = const PreferenceLearner(),
  }) : _learner = learner,
       super(UserDesignPreferenceProfile.neutral) {
    unawaited(_load());
  }

  final PreferenceStore _store;
  final PreferenceLearner _learner;

  Future<void> _load() async {
    final loaded = await _store.load();
    if (mounted) state = loaded;
  }

  /// Fold one behavioural [signal] about [recipe] into the profile + persist.
  void record(ProceduralDesignRecipe recipe, PreferenceSignal signal) {
    state = _learner.observe(state, recipe, signal);
    unawaited(_store.save(state));
  }
}

/// App-wide preference profile. Read the profile with `ref.watch`, record
/// signals with `ref.read(preferenceProfileProvider.notifier).record(...)`.
final preferenceProfileProvider = StateNotifierProvider<
  PreferenceProfileNotifier,
  UserDesignPreferenceProfile
>((ref) => PreferenceProfileNotifier(SharedPrefsPreferenceStore()));
