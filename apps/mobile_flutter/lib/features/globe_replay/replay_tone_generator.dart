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

  /// Gold chime for UNESCO heritage reveals — 880 Hz + 1100 Hz overtone (≈ 0.60 s).
  static Uint8List heritage() => _wav(_heritageChime());

  /// Rising two-note for year transitions — C5 (523 Hz) → G5 (784 Hz) (≈ 0.40 s).
  static Uint8List yearTransition() => _wav(_yearRise());

  /// Rich discovery chime when the flag appears over a first-visit country (≈ 1.0 s).
  static Uint8List discovery() => _wav(_discoveryChime());

  /// Soft collection pop when the flag joins the row (≈ 0.35 s).
  static Uint8List collection() => _wav(_collectionPop());

  // ── Challenge audio ─────────────────────────────────────────────────────────

  /// Clue reveal chime — pitch rises with [clueNumber] (1–5) to build tension.
  /// Clue 1 = low/calm; Clue 5 = high/urgent.
  static Uint8List challengeClue(int n) {
    const freqs = [293.66, 349.23, 415.30, 523.25, 659.25]; // D4→F4→Ab4→C5→E5
    final freq = freqs[(n - 1).clamp(0, 4)];
    return _wav(_bell(freq, 0.45));
  }

  /// Short dissonant buzz for a wrong guess.
  static Uint8List challengeWrong() => _wav(_buzzWrong());

  /// Joyful ascending fanfare for a solved challenge.
  static Uint8List challengeSolve() => _wav(_fanfare());

  /// Descending minor arpeggio for a failed challenge.
  static Uint8List challengeFail() => _wav(_failDescend());

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

  /// Gold chime: 880 Hz fundamental + 1100 Hz overtone, exponential decay, 0.60 s.
  static List<int> _heritageChime() {
    const dur = 0.60;
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = math.exp(-t * 5.5);
      final s = (
            math.sin(2 * math.pi * 880.0 * t) * 0.55 +
            math.sin(2 * math.pi * 1100.0 * t) * 0.30 +
            math.sin(2 * math.pi * 1760.0 * t) * 0.10
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Rising two-note: C5 (523 Hz) then G5 (784 Hz), 0.20 s each, 0.40 s total.
  static List<int> _yearRise() {
    const freqs = [523.25, 783.99];
    const noteSec = 0.18;
    const total = noteSec * 2 + 0.04; // small tail
    final n = (total * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final ni = (t / noteSec).floor().clamp(0, freqs.length - 1);
      final freq = freqs[ni];
      final nt = t - ni * noteSec;
      final env = nt < 0.01 ? nt / 0.01 : math.exp(-(nt - 0.01) * 8.0);
      final s = math.sin(2 * math.pi * freq * t) * env * _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Three ascending notes E5→G5→C6 with warm harmonic overtones.
  static List<int> _discoveryChime() {
    const freqs = [659.25, 783.99, 1046.50];
    const noteSec = 0.28;
    const tail = 0.18;
    final n = ((noteSec * freqs.length + tail) * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final ni = (t / noteSec).floor().clamp(0, freqs.length - 1);
      final freq = freqs[ni];
      final nt = t - ni * noteSec;
      final env = nt < 0.015 ? nt / 0.015 : math.exp(-(nt - 0.015) * 4.5);
      final s = (
            math.sin(2 * math.pi * freq * t) * 0.60 +
            math.sin(2 * math.pi * freq * 2.0 * t) * 0.25 +
            math.sin(2 * math.pi * freq * 3.0 * t) * 0.10
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Gentle two-frequency pop with quick attack and soft decay.
  static List<int> _collectionPop() {
    const dur = 0.35;
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = t < 0.008 ? t / 0.008 : math.exp(-(t - 0.008) * 9.0);
      final s = (
            math.sin(2 * math.pi * 660.0 * t) * 0.55 +
            math.sin(2 * math.pi * 990.0 * t) * 0.35 +
            math.sin(2 * math.pi * 1320.0 * t) * 0.08
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Short dissonant buzz (220 Hz + 233 Hz minor 2nd) — wrong-guess feedback.
  static List<int> _buzzWrong() {
    const dur = 0.18;
    final n = (dur * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = t < 0.006 ? t / 0.006 : math.exp(-(t - 0.006) * 12.0);
      final s = (
            math.sin(2 * math.pi * 220.0 * t) * 0.55 +
            math.sin(2 * math.pi * 233.0 * t) * 0.45
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
    });
  }

  /// Descending minor arpeggio C5→G4→Eb4→C4 — challenge-failed fanfare.
  static List<int> _failDescend() {
    const freqs = [523.25, 392.00, 311.13, 261.63]; // C5 G4 Eb4 C4
    const noteSec = 0.18;
    final total = noteSec * freqs.length + 0.12;
    final n = (total * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final ni = (t / noteSec).floor().clamp(0, freqs.length - 1);
      final freq = freqs[ni];
      final nt = t - ni * noteSec;
      final env = nt < 0.012 ? nt / 0.012 : math.exp(-(nt - 0.012) * 6.0);
      final s = (
            math.sin(2 * math.pi * freq * t) * 0.60 +
            math.sin(2 * math.pi * freq * 2.0 * t) * 0.25 +
            math.sin(2 * math.pi * freq * 3.0 * t) * 0.10
          ) *
          env *
          _vol;
      return (s * 32767).round().clamp(-32767, 32767);
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
