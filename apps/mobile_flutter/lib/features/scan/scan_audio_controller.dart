import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'scan_tone_generator.dart';

// ── ScanAudioController ────────────────────────────────────────────────────────

/// Manages audio playback during a live photo scan.
///
/// Mirrors [ReplayAudioController]: synthesises WAV bytes in Dart via
/// [ScanToneGenerator] and plays them with [BytesSource] — no on-disk
/// asset files, no iOS file-URL resolution.
///
/// One dedicated [AudioPlayer] per sound slot so overlapping events (e.g.
/// country discovery while a previous tone is still ringing) play correctly.
class ScanAudioController {
  ScanAudioController()
      : _country = AudioPlayer(),
        _continent = AudioPlayer(),
        _heritage = AudioPlayer(),
        _milestone = AudioPlayer() {
    for (final p in _allPlayers) {
      p.setReleaseMode(ReleaseMode.stop).ignore();
    }
  }

  final AudioPlayer _country;
  final AudioPlayer _continent;
  final AudioPlayer _heritage;
  final AudioPlayer _milestone;

  Uint8List? _countryBytes;
  Uint8List? _continentBytes;
  Uint8List? _heritageBytes;
  Uint8List? _milestoneBytes;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates all tones and warms up players so first playback has no latency.
  /// Safe to call multiple times (generation is idempotent).
  Future<void> preload() async {
    _countryBytes  ??= ScanToneGenerator.countryDiscovery();
    _continentBytes ??= ScanToneGenerator.continentDiscovery();
    _heritageBytes  ??= ScanToneGenerator.heritageDiscovery();
    _milestoneBytes ??= ScanToneGenerator.majorMilestone();

    await Future.wait([
      _warmUp(_country,   _countryBytes!),
      _warmUp(_continent, _continentBytes!),
      _warmUp(_heritage,  _heritageBytes!),
      _warmUp(_milestone, _milestoneBytes!),
    ]);
  }

  /// Plays the country-discovery ping.
  void playCountryDiscovery() => _play(_country, _countryBytes);

  /// Plays the continent-discovery chime.
  void playContinentDiscovery() => _play(_continent, _continentBytes);

  /// Plays the heritage-discovery bell.
  void playHeritageDiscovery() => _play(_heritage, _heritageBytes);

  /// Plays the major-milestone chord.
  void playMajorMilestone() => _play(_milestone, _milestoneBytes);

  void dispose() {
    for (final p in _allPlayers) {
      p.dispose();
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  List<AudioPlayer> get _allPlayers => [_country, _continent, _heritage, _milestone];

  Future<void> _warmUp(AudioPlayer player, Uint8List bytes) async {
    try {
      await player.setSource(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      developer.log('ScanAudio: warm-up failed: $e');
    }
  }

  void _play(AudioPlayer player, Uint8List? bytes) {
    if (bytes == null) return;
    try {
      player.play(BytesSource(bytes, mimeType: 'audio/wav')).ignore();
    } catch (e) {
      developer.log('ScanAudio: play failed: $e');
    }
  }
}
