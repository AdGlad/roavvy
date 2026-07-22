"""
Generate classic 8-bit arcade sound effects for World Leap.
All sounds use square/pulse waves with ADSR envelopes — authentic retro feel.
Outputs WAV files; caller should convert to MP3 with ffmpeg.
"""

import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), '../../apps/mobile_flutter/assets/audio')
os.makedirs(OUT_DIR, exist_ok=True)

# ── Core synthesis primitives ─────────────────────────────────────────────────

def square(freq, t, duty=0.5):
    if freq <= 0:
        return 0.0
    return 1.0 if (t * freq) % 1.0 < duty else -1.0

def triangle(freq, t):
    if freq <= 0:
        return 0.0
    p = (t * freq) % 1.0
    return (2.0 * p - 1.0) if p < 0.5 else (3.0 - 2.0 * p - 1.0) * -1 + 0.0

def adsr(t, dur, a=0.01, d=0.05, s=0.7, r=0.05):
    if t < a:
        return t / a if a > 0 else 1.0
    elif t < a + d:
        return 1.0 - (1.0 - s) * (t - a) / d if d > 0 else s
    elif t < dur - r:
        return s
    elif t < dur:
        return s * (1.0 - (t - (dur - r)) / r) if r > 0 else 0.0
    return 0.0

def write_wav(path, samples):
    with wave.open(path, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            v = max(-32767, min(32767, int(s * 32767)))
            data += struct.pack('<h', v)
        wf.writeframes(bytes(data))
    print(f'  wrote {path}  ({len(samples)/SAMPLE_RATE*1000:.0f} ms)')

def silence(dur):
    return [0.0] * int(SAMPLE_RATE * dur)

# ── Sound generators ──────────────────────────────────────────────────────────

def make_stretch():
    """Rising 'charging' tone — slingshot pull."""
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(1)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / dur
        freq = 200 + 600 * (progress ** 1.5)   # non-linear rise → more tension
        amp = adsr(t, dur, a=0.005, d=0.06, s=0.55, r=0.04)
        # Mix square + slight pulse for richer texture
        s = square(freq, t, 0.5) * 0.7 + square(freq * 2, t, 0.25) * 0.3
        out.append(s * amp * 0.55)
    return out


def make_launch():
    """Sharp 'PEW!' — elastic snap release, Space Invaders style."""
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Fast ascending then rapid decay — classic shoot pew
        freq_env = 1200 * math.exp(-t * 12) + 180
        amp = math.exp(-t * 9) * 0.9
        s = square(freq_env, t, 0.5)
        out.append(s * amp)
    return out


def make_wind():
    """Electronic whoosh during projectile flight."""
    dur = 1.0
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(42)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Bell-curve amplitude: rises then falls (matches arc of flight)
        arc = math.sin(math.pi * t / dur)
        # Pitch rises then falls with arc
        freq = 120 + 320 * arc
        # Vibrato for texture
        vib = 1 + 0.04 * math.sin(2 * math.pi * 8 * t)
        s_sq = square(freq * vib, t, 0.4) * 0.35
        # Add noise layer for air rush feel
        s_noise = rng.uniform(-1, 1) * 0.65
        amp = arc * 0.45
        out.append((s_sq + s_noise) * amp)
    return out


def make_impact():
    """Satisfying 'BOOM!' — successful landing, classic arcade thud."""
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    rng = random.Random(7)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Punchy bass drop + high attack transient
        low_freq = 80 * math.exp(-t * 3) + 40
        high_freq = 800 * math.exp(-t * 20)
        low_amp = math.exp(-t * 4)
        high_amp = math.exp(-t * 18)
        noise_amp = math.exp(-t * 6) * 0.5
        # High-pitched attack click
        hi = square(high_freq, t) * high_amp * 0.4
        # Low boom
        lo = square(low_freq, t) * low_amp * 0.5
        # Noise burst
        nz = rng.uniform(-1, 1) * noise_amp
        out.append((hi + lo + nz) * 0.85)
    return out


def make_miss():
    """Classic 3-note descending fail — Pac-Man death flavour."""
    # Chromatic descend across minor intervals
    notes = [
        (523, 0.13),  # C5
        (415, 0.13),  # G#4
        (330, 0.22),  # E4 (hold slightly)
    ]
    out = []
    for freq, dur in notes:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            # Slight downward pitch slide on each note for droopy feel
            slide = freq * (1 - 0.08 * (t / dur))
            amp = adsr(t, dur, a=0.005, d=0.04, s=0.65, r=0.06)
            s = square(slide, t, 0.5) * 0.6 + square(slide * 0.5, t, 0.5) * 0.2
            out.append(s * amp * 0.65)
    return out


def make_tick():
    """Short blip — countdown timer beep."""
    freq = 1047  # C6 — clear and punchy
    dur = 0.07
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        amp = adsr(t, dur, a=0.003, d=0.01, s=0.8, r=0.01)
        out.append(square(freq, t) * amp * 0.5)
    return out


def make_timeout():
    """Rapid alarm descent — 5 blips dropping in pitch, urgent feel."""
    blip_freqs = [988, 831, 698, 587, 494]  # B5→B4 descend
    blip_dur = 0.09
    gap_dur = 0.025
    out = []
    for freq in blip_freqs:
        n = int(SAMPLE_RATE * blip_dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            amp = adsr(t, blip_dur, a=0.005, d=0.02, s=0.7, r=0.02)
            out.append(square(freq, t) * amp * 0.65)
        out += silence(gap_dur)
    return out


def make_fanfare():
    """
    8-bit victory jingle — Mario coin + power-up hybrid.
    C-E-G-C ascending arpeggio then triumphant held chord.
    """
    arp = [
        (523, 0.08),   # C5
        (659, 0.08),   # E5
        (784, 0.08),   # G5
        (1047, 0.08),  # C6
    ]
    final = [
        (784, 0.35),   # G5 — slight drop for resolution
        (1047, 0.35),  # C6 — together
    ]
    out = []
    for freq, dur in arp:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            amp = adsr(t, dur, a=0.005, d=0.02, s=0.85, r=0.01)
            out.append(square(freq, t, 0.5) * amp * 0.65)

    # Two-voice hold: sum and normalise to avoid clipping
    n_final = int(SAMPLE_RATE * 0.35)
    for i in range(n_final):
        t = i / SAMPLE_RATE
        amp = adsr(t, 0.35, a=0.01, d=0.04, s=0.75, r=0.08)
        v = sum(square(f, t, 0.5) for f, _ in final) / len(final)
        out.append(v * amp * 0.65)

    return out


def make_game_over():
    """
    Classic 8-bit game-over melody — dignified descending minor scale,
    longer and melancholic (think early Zelda / Bubble Bobble game over).
    """
    notes = [
        (392, 0.20),  # G4
        (370, 0.20),  # F#4
        (330, 0.20),  # E4
        (294, 0.20),  # D4
        (262, 0.20),  # C4
        (247, 0.20),  # B3
        (220, 0.20),  # A3
        (196, 0.55),  # G3 — final low hold
    ]
    out = []
    for freq, dur in notes:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            # Add sub-octave for weight
            sub = square(freq / 2, t, 0.5) * 0.2
            main = square(freq, t, 0.5) * 0.6
            amp = adsr(t, dur, a=0.008, d=0.06, s=0.70, r=0.08)
            out.append((main + sub) * amp * 0.75)
    return out


# ── Generate all sounds ───────────────────────────────────────────────────────

SOUNDS = {
    'wl_stretch':   make_stretch,
    'wl_launch':    make_launch,
    'wl_wind':      make_wind,
    'wl_impact':    make_impact,
    'wl_miss':      make_miss,
    'wl_tick':      make_tick,
    'wl_timeout':   make_timeout,
    'wl_fanfare':   make_fanfare,
    'wl_game_over': make_game_over,
}

print('Generating 8-bit arcade sounds...')
for name, fn in SOUNDS.items():
    path = os.path.join(OUT_DIR, f'{name}.wav')
    samples = fn()
    write_wav(path, samples)

print('Done.')
