import 'dart:math' as math;
import 'dart:typed_data';

/// Generates synthesised audio cues for the globe replay in memory.
///
/// All output is 44 100 Hz, 16-bit signed, mono PCM wrapped in a RIFF/WAV
/// container so [audioplayers] can play it via [BytesSource] without any
/// on-disk asset files.
///
/// Sound designs:
/// | Slot           | Design                                              |
/// |----------------|-----------------------------------------------------|
/// | shortWhoosh    | band-limited noise burst + rising sine, 0.25 s      |
/// | longWhoosh     | slower noise sweep + rising sine, 0.55 s            |
/// | arrival        | bell: 880 Hz + harmonics, exponential decay, 0.7 s  |
/// | achievement    | ascending arpeggio C5–E5–G5–C6, 0.60 s             |
/// | replayEnd      | arpeggio then sustained major chord, 1.2 s          |
class ReplayToneGenerator {
  const ReplayToneGenerator._();

  static const int _sr = 44100;        // sample rate
  static const double _vol = 0.70;     // master volume (avoids clipping)

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Short whoosh: flight < 20° arc (≈ 0.25 s).
  static Uint8List shortWhoosh() => _wav(_whoosh(0.25, loFreq: 250, hiFreq: 900));

  /// Long whoosh: flight ≥ 20° arc (≈ 0.55 s).
  static Uint8List longWhoosh() => _wav(_whoosh(0.55, loFreq: 120, hiFreq: 550));

  /// Bell chime for arrival (≈ 0.70 s).
  static Uint8List arrival() => _wav(_bell(880.0, 0.70));

  /// Ascending arpeggio for achievement reveal (≈ 0.60 s).
  static Uint8List achievement() => _wav(_arpeggio());

  /// Arpeggio + chord fanfare for replay complete (≈ 1.20 s).
  static Uint8List replayEnd() => _wav(_fanfare());

  // ── Synthesis ──────────────────────────────────────────────────────────────

  /// Band-limited noise burst with a rising sine tone.
  ///
  /// The noise is low-pass smoothed (running average) to give a "rush of air"
  /// character. A rising sine adds pitch definition so the ear reads it as
  /// motion rather than static.
  static List<int> _whoosh(
    double dur, {
    required double loFreq,
    required double hiFreq,
  }) {
    final n = (dur * _sr).round();
    final rng = math.Random(7); // fixed seed → deterministic bytes
    var prev = 0.0;
    const smooth = 0.12; // low-pass coefficient

    return List.generate(n, (i) {
      final t = i / n; // normalised 0→1

      // Trapezoid envelope: 10 % attack, 70 % sustain, 20 % release.
      final env = t < 0.10
          ? t / 0.10
          : t > 0.80
              ? (1.0 - t) / 0.20
              : 1.0;

      // Smoothed white noise (approximates air-rush).
      final white = rng.nextDouble() * 2 - 1;
      prev = prev + smooth * (white - prev);

      // Rising sine adds pitch character.
      final freq = loFreq + (hiFreq - loFreq) * t;
      final tone = math.sin(2 * math.pi * freq * i / _sr) * 0.30;

      final s = (prev * 0.70 + tone) * env * _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Bell: fundamental + two harmonics with exponential decay.
  static List<int> _bell(double freq, double dur) {
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = math.exp(-t * 4.8);
      final s = (
            math.sin(2 * math.pi * freq * t) * 0.50 +
            math.sin(2 * math.pi * freq * 2.0 * t) * 0.25 +
            math.sin(2 * math.pi * freq * 3.01 * t) * 0.10
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Ascending arpeggio: C5 E5 G5 C6 — 0.14 s per note.
  static List<int> _arpeggio() {
    const freqs = [523.25, 659.25, 783.99, 1046.50];
    const noteSec = 0.14;
    final totalSec = noteSec * freqs.length + 0.12; // hold last note
    final n = (totalSec * _sr).round();

    return List.generate(n, (i) {
      final t = i / _sr;
      final ni = (t / noteSec).floor().clamp(0, freqs.length - 1);
      final freq = freqs[ni];
      final nt = t - ni * noteSec;
      final env =
          nt < 0.01 ? nt / 0.01 : math.exp(-(nt - 0.01) * 9.0);
      final s = math.sin(2 * math.pi * freq * t) * env * _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Arpeggio (0.6 s) → sustained major chord (0.6 s).
  static List<int> _fanfare() {
    const freqs = [523.25, 659.25, 783.99, 1046.50];
    const arpSec = 0.60;
    const chordSec = 0.60;
    const total = arpSec + chordSec;
    final n = (total * _sr).round();
    // noteSec = arpSec / freqs.length = 0.60 / 4
    const noteSec = 0.15;

    return List.generate(n, (i) {
      final t = i / _sr;
      double s;

      if (t < arpSec) {
        final ni = (t / noteSec).floor().clamp(0, freqs.length - 1);
        final nt = t - ni * noteSec;
        final env =
            nt < 0.01 ? nt / 0.01 : math.exp(-(nt - 0.01) * 4.0);
        s = math.sin(2 * math.pi * freqs[ni] * t) * env;
      } else {
        final ct = t - arpSec;
        final env = math.exp(-ct * 2.5);
        s = 0;
        for (final f in freqs) {
          s += math.sin(2 * math.pi * f * t) / freqs.length;
        }
        s *= env;
      }
      return (s * _vol * 32767).round().clamp(-32767, 32767);
    });
  }

  // ── WAV encoding ───────────────────────────────────────────────────────────

  static Uint8List _wav(List<int> samples) {
    final dataBytes = samples.length * 2; // 16-bit = 2 bytes/sample
    final buf = ByteData(44 + dataBytes);

    void ascii(int off, String s) {
      for (var k = 0; k < s.length; k++) {
        buf.setUint8(off + k, s.codeUnitAt(k));
      }
    }

    // RIFF header.
    ascii(0, 'RIFF');
    buf.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');

    // fmt chunk.
    ascii(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);       // chunk size
    buf.setUint16(20, 1, Endian.little);         // PCM
    buf.setUint16(22, 1, Endian.little);         // mono
    buf.setUint32(24, _sr, Endian.little);       // sample rate
    buf.setUint32(28, _sr * 2, Endian.little);   // byte rate
    buf.setUint16(32, 2, Endian.little);         // block align
    buf.setUint16(34, 16, Endian.little);        // bits per sample

    // data chunk.
    ascii(36, 'data');
    buf.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buf.buffer.asUint8List();
  }
}
