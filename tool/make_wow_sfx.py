#!/usr/bin/env python3
"""Makes assets/sfx/wow.wav: the slime's squeaky "wow!" for a high combo.

    python3 tool/make_wow_sfx.py

A small voice synthesizer, no samples: the harmonics of a rising-then-falling
pitch, each as loud as the mouth shape lets it through (formant peaks that
glide w -> ah -> w). Mono, 16-bit, 22050 Hz like the other sounds.
"""

import math
import os
import struct
import wave

RATE = 22050
LENGTH = 0.56  # seconds

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/sfx/wow.wav")


def smooth(a, b, x):
    """a..b along x in 0..1, eased in and out."""
    x = min(1.0, max(0.0, x))
    return a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * x))


def pitch(p):
    """The voice's pitch at p (0..1): up on "wo", down on "ow", a little wobble."""
    if p < 0.38:
        f = smooth(520, 780, p / 0.38)
    else:
        f = smooth(780, 470, (p - 0.38) / 0.62)
    return f * (1 + 0.025 * math.sin(2 * math.pi * 7 * p * LENGTH) * min(1.0, p * 3))


def mouth(p):
    """How open the mouth is: closed (w), open (ah) at about a third, closed."""
    return math.sin(math.pi * min(1.0, p / 0.92)) ** 0.9


def formants(m):
    """(frequency, bandwidth, gain) of the voice's resonances for openness m."""
    return [
        (300 + 520 * m, 90, 1.0),  # F1: 300 (w) .. 820 (ah)
        (760 + 560 * m, 120, 0.55),  # F2: 760 .. 1320
        (2900 + 200 * m, 220, 0.18),  # F3, a bit of brightness
    ]


def envelope(f, m):
    peaks = sum(g / (1 + ((f - c) / b) ** 2) for c, b, g in formants(m))
    return peaks + 0.02


def loudness(t):
    attack, release = 0.03, 0.14
    a = min(1.0, t / attack)
    r = min(1.0, (LENGTH - t) / release)
    return a * max(0.0, r) ** 1.5


def main():
    n = int(RATE * LENGTH)
    phases = [0.0] * 16
    out = []
    for i in range(n):
        t = i / RATE
        p = t / LENGTH
        f0, m = pitch(p), mouth(p)
        sample = 0.0
        for k in range(1, len(phases) + 1):
            f = k * f0
            if f > RATE * 0.45:
                break
            phases[k - 1] += 2 * math.pi * f / RATE
            sample += envelope(f, m) / math.sqrt(k) * math.sin(phases[k - 1])
        out.append(sample * loudness(t) * (0.45 + 0.55 * m))

    peak = max(abs(s) for s in out) or 1.0
    frames = b"".join(struct.pack("<h", int(32767 * 0.85 * s / peak)) for s in out)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"wrote {os.path.relpath(OUT, ROOT)} ({LENGTH:.2f}s)")


if __name__ == "__main__":
    main()
