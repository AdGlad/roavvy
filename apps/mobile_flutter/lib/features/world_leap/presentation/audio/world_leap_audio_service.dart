// lib/features/world_leap/presentation/audio/world_leap_audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/world_leap_state.dart';
import '../../world_leap_config.dart';

/// Audio service for World Leap game sounds and mute preference management.
///
/// Not a singleton — instantiate in the game screen and call [dispose] when
/// the screen is removed from the tree.
class WorldLeapAudioService {
  WorldLeapAudioService({AudioPlayer? player, SharedPreferences? prefs})
      : _player = player ?? AudioPlayer(),
        _prefs = prefs;

  final AudioPlayer _player;
  SharedPreferences? _prefs;

  bool _muted = false;
  bool get isMuted => _muted;

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

  Future<void> playTension() => _play(WorldLeapConfig.soundTension);
  Future<void> playLaunch() => _play(WorldLeapConfig.soundLaunch);
  Future<void> playWind() => _play(WorldLeapConfig.soundWind);
  Future<void> playLand() => _play(WorldLeapConfig.soundLand);
  Future<void> playSplash() => _play(WorldLeapConfig.soundSplash);
  Future<void> playCelebrate() => _play(WorldLeapConfig.soundCelebrate);
  Future<void> playGameOver() => _play(WorldLeapConfig.soundGameOver);
  Future<void> playTick() => _play(WorldLeapConfig.soundTick);

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();

  Future<void> _play(String asset) async {
    if (_muted) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Asset may not exist yet (placeholder). Ignore.
    }
  }

  // ── Controller listener helper ─────────────────────────────────────────────

  /// Plays the appropriate sound for the given [state].
  /// Call this from a WorldLeapController listener.
  Future<void> playForState(WorldLeapState state) => switch (state) {
        WorldLeapStateLaunching() => playLaunch(),
        WorldLeapStateLanded() => playLand(),
        WorldLeapStateFailed() => playSplash(),
        WorldLeapStateComplete() => playCelebrate(),
        _ => Future.value(),
      };
}
