import 'dart:math' as math;
import 'dart:typed_data';

/// Generates synthesised audio cues for the live scan screen in memory.
///
/// Mirrors [ReplayToneGenerator] — all output is 44 100 Hz, 16-bit signed,
/// mono PCM in a RIFF/WAV container, played via [BytesSource] so no on-disk
/// asset files or iOS file-URL resolution are involved.
///
/// Sound designs:
/// | Slot               | Design                                        |
/// |--------------------|-----------------------------------------------|
/// | countryDiscovery   | C6 bell ping, 0.40 s — quick and bright       |
/// | continentDiscovery | G5 → C6 two-note chime, 0.60 s — distinctive |
/// | heritageDiscovery  | A4 resonant bell + harmonics, 0.80 s — deep  |
/// | majorMilestone     | C major chord swell, 1.00 s — celebratory    |
class ScanToneGenerator {
  const ScanToneGenerator._();

  static const int _sr = 44100;
  static const double _vol = 0.70;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Bright C6 ping — fires on every new country discovery.
  static Uint8List countryDiscovery() => _wav(_bell(1046.50, 0.40));

  /// G5 → C6 two-note chime — fires on first country in a new continent.
  static Uint8List continentDiscovery() =>
      _wav(_twoNoteChime(784.0, 1046.50, 0.60));

  /// Deep A4 resonant bell — fires on UNESCO World Heritage Site discovery.
  static Uint8List heritageDiscovery() => _wav(_bell(440.0, 0.80));

  /// C major chord swell — fires when crossing 10, 25, or 50 countries.
  static Uint8List majorMilestone() => _wav(_chordSwell());

  // ── Synthesis ──────────────────────────────────────────────────────────────

  /// Bell: fundamental + two harmonics with exponential decay.
  static List<int> _bell(double freq, double dur) {
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = math.exp(-t * 5.0);
      final s =
          (math.sin(2 * math.pi * freq * t) * 0.55 +
              math.sin(2 * math.pi * freq * 2.0 * t) * 0.25 +
              math.sin(2 * math.pi * freq * 3.01 * t) * 0.10) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Two-note chime: [freq1] for first half, [freq2] for second half.
  static List<int> _twoNoteChime(double freq1, double freq2, double dur) {
    final n = (dur * _sr).round();
    final half = n ~/ 2;
    return List.generate(n, (i) {
      final freq = i < half ? freq1 : freq2;
      final localT = (i < half ? i : i - half) / _sr;
      final env = math.exp(-localT * 6.0);
      final s = math.sin(2 * math.pi * freq * i / _sr) * env * _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// C major chord (C5 + E5 + G5 + C6) with attack swell and exponential decay.
  static List<int> _chordSwell() {
    const dur = 1.00;
    const freqs = [523.25, 659.25, 783.99, 1046.50];
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      // 50 ms attack, then decay.
      final env = t < 0.05 ? t / 0.05 : math.exp(-(t - 0.05) * 3.5);
      double s = 0;
      for (final f in freqs) {
        s += math.sin(2 * math.pi * f * t) / freqs.length;
      }
      return (s * env * _vol * 32767).round().clamp(-32767, 32767);
    });
  }

  // ── WAV encoding ───────────────────────────────────────────────────────────

  static Uint8List _wav(List<int> samples) {
    final dataBytes = samples.length * 2;
    final buf = ByteData(44 + dataBytes);

    void ascii(int off, String s) {
      for (var k = 0; k < s.length; k++) {
        buf.setUint8(off + k, s.codeUnitAt(k));
      }
    }

    ascii(0, 'RIFF');
    buf.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, 1, Endian.little); // mono
    buf.setUint32(24, _sr, Endian.little); // sample rate
    buf.setUint32(28, _sr * 2, Endian.little); // byte rate
    buf.setUint16(32, 2, Endian.little); // block align
    buf.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    buf.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buf.buffer.asUint8List();
  }
}
