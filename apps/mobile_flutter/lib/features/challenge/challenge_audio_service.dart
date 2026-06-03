import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../globe_replay/replay_tone_generator.dart';

// ── ChallengeAudioService ─────────────────────────────────────────────────────

/// Manages synthesised audio cues for the Daily Heritage Challenge.
///
/// Uses [ReplayToneGenerator] — no asset files needed. Tones are generated
/// once in [preload] and cached. Four dedicated [AudioPlayer] instances allow
/// overlapping sounds (e.g. clue reveal while previous note decays).
///
/// | Slot   | Sound                                    | Trigger              |
/// |--------|------------------------------------------|----------------------|
/// | clue   | Rising pitch per clue (D4→E5), 0.45 s   | Reveal Clue button   |
/// | wrong  | Dissonant buzz 220+233 Hz, 0.18 s        | Incorrect guess      |
/// | solve  | Ascending arpeggio + chord fanfare, 1.2s | Challenge solved     |
/// | fail   | Descending minor arpeggio, 0.84 s        | Challenge failed     |
class ChallengeAudioService {
  ChallengeAudioService()
    : _clue = AudioPlayer(),
      _wrong = AudioPlayer(),
      _solve = AudioPlayer(),
      _fail = AudioPlayer() {
    for (final p in _all) {
      p.setReleaseMode(ReleaseMode.stop).ignore();
    }
  }

  final AudioPlayer _clue;
  final AudioPlayer _wrong;
  final AudioPlayer _solve;
  final AudioPlayer _fail;

  // Pre-generated WAV bytes — one entry per clue number (index 0 = clue 1).
  final List<Uint8List?> _clueBytes = List.filled(5, null);
  Uint8List? _wrongBytes;
  Uint8List? _solveBytes;
  Uint8List? _failBytes;

  List<AudioPlayer> get _all => [_clue, _wrong, _solve, _fail];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Synthesises all tones. Call once before the screen is interactive.
  Future<void> preload() async {
    for (var i = 0; i < 5; i++) {
      _clueBytes[i] ??= ReplayToneGenerator.challengeClue(i + 1);
    }
    _wrongBytes ??= ReplayToneGenerator.challengeWrong();
    _solveBytes ??= ReplayToneGenerator.challengeSolve();
    _failBytes ??= ReplayToneGenerator.challengeFail();

    // Warm up with the first clue tone.
    await Future.wait([
      _warmUp(_clue, _clueBytes[0]!),
      _warmUp(_wrong, _wrongBytes!),
      _warmUp(_solve, _solveBytes!),
      _warmUp(_fail, _failBytes!),
    ]);
  }

  /// Plays the clue-reveal chime for clue [n] (1–5).
  void playClue(int n) {
    final bytes = _clueBytes[(n - 1).clamp(0, 4)];
    _play(_clue, bytes);
  }

  /// Plays the wrong-guess buzz.
  void playWrong() => _play(_wrong, _wrongBytes);

  /// Plays the solve fanfare.
  void playSolve() => _play(_solve, _solveBytes);

  /// Plays the failure descending arpeggio.
  void playFail() => _play(_fail, _failBytes);

  void dispose() {
    for (final p in _all) {
      p.dispose();
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _warmUp(AudioPlayer player, Uint8List bytes) async {
    try {
      await player.setSource(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      developer.log('ChallengeAudio: warm-up failed: $e');
    }
  }

  void _play(AudioPlayer player, Uint8List? bytes) {
    if (bytes == null) return;
    try {
      player.play(BytesSource(bytes, mimeType: 'audio/wav')).ignore();
    } catch (e) {
      developer.log('ChallengeAudio: play failed: $e');
    }
  }
}
