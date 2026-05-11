import 'package:audioplayers/audioplayers.dart';

// ── ReplayAudioController (M111) ──────────────────────────────────────────────

/// Manages cinematic audio playback during the travel replay (M111).
///
/// Wraps [audioplayers] with 5 dedicated [AudioPlayer] instances — one per
/// sound slot — so overlapping audio is handled correctly (e.g. a travel
/// whoosh can finish while an arrival chime starts).
///
/// Call [preload] once before [TravelReplayController.play]; set [isMuted]
/// to suppress all audio without stopping the replay.
///
/// ## Placeholder assets
/// The 5 audio asset files ship as placeholder copies of `celebration.mp3`
/// for the initial M111 release. Replace the files under `assets/audio/`
/// with final cinematic audio without any code changes:
///
/// | Slot | Asset path | When played |
/// |------|-----------|-------------|
/// | travelShort | `audio/replay_travel_short.mp3` | flight start, short arc (<20°) |
/// | travelLong  | `audio/replay_travel_long.mp3`  | flight start, long/medium arc (≥20°) |
/// | arrival     | `audio/replay_arrival.mp3`      | pulse phase start |
/// | achievement | `audio/replay_achievement.mp3`  | achievement overlay reveal |
/// | end         | `audio/replay_end.mp3`          | replay complete |
class ReplayAudioController {
  ReplayAudioController()
      : _travelShort = AudioPlayer(),
        _travelLong = AudioPlayer(),
        _arrival = AudioPlayer(),
        _achievement = AudioPlayer(),
        _end = AudioPlayer();

  final AudioPlayer _travelShort;
  final AudioPlayer _travelLong;
  final AudioPlayer _arrival;
  final AudioPlayer _achievement;
  final AudioPlayer _end;

  /// When true, all [play*] methods are no-ops. Audio already in progress is
  /// stopped. Toggle from the mute button in [GlobeReplayWidget].
  bool isMuted = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Warms up all audio players so the first playback has minimal latency.
  ///
  /// Loads each asset into the audio system without audible playback.
  /// Call this before [TravelReplayController.play].
  Future<void> preload() async {
    await Future.wait([
      _warmUp(_travelShort, 'audio/replay_travel_short.mp3'),
      _warmUp(_travelLong,  'audio/replay_travel_long.mp3'),
      _warmUp(_arrival,     'audio/replay_arrival.mp3'),
      _warmUp(_achievement, 'audio/replay_achievement.mp3'),
      _warmUp(_end,         'audio/replay_end.mp3'),
    ]);
  }

  /// Plays a travel movement sound appropriate to [arcDistanceDeg].
  ///
  /// Short arcs (<20°) use a snappier whoosh; longer arcs use a more sweeping
  /// version.
  void playTravelMovement(double arcDistanceDeg) {
    if (isMuted) return;
    _play(arcDistanceDeg < 20.0 ? _travelShort : _travelLong,
        arcDistanceDeg < 20.0
            ? 'audio/replay_travel_short.mp3'
            : 'audio/replay_travel_long.mp3');
  }

  /// Plays the arrival chime (when the arc completes and the pulse fires).
  void playArrival() {
    if (isMuted) return;
    _play(_arrival, 'audio/replay_arrival.mp3');
  }

  /// Plays the achievement swell (when an achievement overlay is revealed).
  void playAchievement() {
    if (isMuted) return;
    _play(_achievement, 'audio/replay_achievement.mp3');
  }

  /// Plays the cinematic end cue (when the replay completes).
  void playReplayEnd() {
    if (isMuted) return;
    _play(_end, 'audio/replay_end.mp3');
  }

  /// Stops all currently active audio immediately.
  void stopAll() {
    for (final p in _allPlayers) {
      p.stop().ignore();
    }
  }

  void dispose() {
    for (final p in _allPlayers) {
      p.dispose();
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  List<AudioPlayer> get _allPlayers =>
      [_travelShort, _travelLong, _arrival, _achievement, _end];

  /// Preloads a single player by playing and immediately stopping.
  Future<void> _warmUp(AudioPlayer player, String assetPath) async {
    try {
      await player.setSourceAsset(assetPath);
    } catch (_) {
      // Silently suppressed — missing asset or audio unavailable in test.
    }
  }

  /// Plays an asset on [player], stopping any current playback first.
  void _play(AudioPlayer player, String assetPath) {
    try {
      player.play(AssetSource(assetPath)).ignore();
    } catch (_) {
      // Silently suppressed — audio is non-critical.
    }
  }
}
