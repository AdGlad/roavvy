// lib/features/world_leap/presentation/audio/world_leap_audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/world_leap_state.dart';
import '../../domain/models/world_leap_failure_reason.dart';
import '../../world_leap_config.dart';

/// Audio service for World Leap game sounds and mute preference management.
///
/// Not a singleton — instantiate in the game screen and call [dispose] when
/// the screen is removed from the tree.
class WorldLeapAudioService {
  WorldLeapAudioService({AudioPlayer? player, AudioPlayer? windPlayer, SharedPreferences? prefs})
      : _player = player ?? AudioPlayer(),
        _windPlayer = windPlayer ?? AudioPlayer(),
        _prefs = prefs;

  final AudioPlayer _player;

  /// Separate player for the wind/whoosh sound so it can overlap the launch snap.
  final AudioPlayer _windPlayer;
  SharedPreferences? _prefs;

  bool _muted = false;
  bool get isMuted => _muted;

  // Throttle stretch sound to at most once per 400 ms.
  DateTime? _lastStretch;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Load the mute preference from SharedPreferences.
  /// Call this once before using play methods.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _muted = prefs.getBool(WorldLeapConfig.localMuteKey) ?? false;
  }

  // ── Mute control ───────────────────────────────────────────────────────────

  Future<void> setMuted(bool value) async {
    _muted = value;
    await _prefs?.setBool(WorldLeapConfig.localMuteKey, value);
  }

  Future<void> toggleMute() => setMuted(!_muted);

  // ── Play methods ───────────────────────────────────────────────────────────

  /// Plays the slingshot stretch creak.
  /// [power] is normalised 0.0–1.0; sound is debounced below 0.15 and
  /// throttled to at most once per 400 ms so it doesn't spam on every
  /// pointer-move event.
  Future<void> playStretch(double power) {
    if (power <= 0.15) return Future.value();
    final now = DateTime.now();
    if (_lastStretch != null &&
        now.difference(_lastStretch!) < const Duration(milliseconds: 400)) {
      return Future.value();
    }
    _lastStretch = now;
    return _play(WorldLeapConfig.soundStretch);
  }

  Future<void> playLaunch() async {
    // Play the rubber-band snap on the main player, wind whoosh simultaneously.
    await Future.wait([
      _play(WorldLeapConfig.soundLaunch),
      _playWind(WorldLeapConfig.soundWindFlight),
    ]);
  }

  Future<void> playWindFlight() => _playWind(WorldLeapConfig.soundWindFlight);
  Future<void> playImpact() => _play(WorldLeapConfig.soundImpact);
  Future<void> playMiss() => _play(WorldLeapConfig.soundMiss);
  Future<void> playTick() => _play(WorldLeapConfig.soundTick);
  Future<void> playTimeout() => _play(WorldLeapConfig.soundTimeout);
  Future<void> playFanfare() => _play(WorldLeapConfig.soundFanfare);
  Future<void> playGameOver() => _play(WorldLeapConfig.soundGameOver);

  Future<void> stop() => Future.wait([_player.stop(), _windPlayer.stop()]);

  Future<void> dispose() => Future.wait([_player.dispose(), _windPlayer.dispose()]);

  Future<void> _play(String asset) async {
    if (_muted) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Unsupported format or missing asset — ignore.
    }
  }

  Future<void> _playWind(String asset) async {
    if (_muted) return;
    try {
      await _windPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  // ── Controller listener helper ─────────────────────────────────────────────

  /// Plays the appropriate sound for the given [state].
  /// Call this from a WorldLeapController listener.
  Future<void> playForState(WorldLeapState state) => switch (state) {
    WorldLeapStateLaunching() => playLaunch(),
    WorldLeapStateLanded() => playImpact(),
    WorldLeapStateFailed(:final reason) =>
      reason == WorldLeapFailureReason.timeout ? playTimeout() : playMiss(),
    WorldLeapStateComplete() => _playCompletionSequence(),
    _ => Future.value(),
  };

  /// Plays fanfare then game-over sting 1.5 s later (non-blocking).
  Future<void> _playCompletionSequence() async {
    await playFanfare();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await playGameOver();
  }
}
