"""Composes the background music: "Paint Party", a cozy but upbeat loop.

Kalimba melody, electric-piano chords, a bouncy bass and soft swung drums in
F major at 104 BPM — relaxed, but with enough groove that it doesn't lull
anyone to sleep. The loop wraps its own reverb tail so it repeats seamlessly.

    python3 tool/compose_music.py -o assets/music/paint_party.mp3
    python3 tool/compose_music.py -o /tmp/faster.mp3 --bpm 112

Needs NumPy, and `lame` or `ffmpeg` on PATH to encode the MP3.
"""
import argparse
import shutil
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
SWING = 0.58  # where the off-beat 8th lands within a beat (0.5 = straight)

# Chords as (root pitch class, intervals). Rootless "3-5-7-9" voicings keep the
# keys warm and out of the bass's way.
CHORDS = {
    "Fmaj7": (5, [4, 7, 11, 14]),
    "F6": (5, [4, 7, 9, 14]),
    "Dm7": (2, [3, 7, 10, 14]),
    "Gm7": (7, [3, 7, 10, 14]),
    "C7": (0, [4, 7, 10, 14]),
    "C7sus4": (0, [5, 7, 10, 14]),
    "Am7": (9, [3, 7, 10, 14]),
    "Bbmaj7": (10, [4, 7, 11, 14]),
}

INTRO = [["Fmaj7"], ["Dm7"], ["Gm7"], ["C7"]]
VERSE = [["Fmaj7"], ["Dm7"], ["Gm7"], ["C7"], ["Fmaj7"], ["Dm7"], ["Gm7", "C7"], ["F6"]]
CHORUS = [["Bbmaj7"], ["C7"], ["Am7"], ["Dm7"], ["Gm7"], ["C7"], ["Bbmaj7"], ["C7sus4"]]
BRIDGE = [["Dm7"], ["Am7"], ["Bbmaj7"], ["Fmaj7"], ["Gm7"], ["Am7"], ["Bbmaj7"], ["C7"]]

# Melodies: one list per bar of (start in 8ths, length in 8ths, MIDI note).
MELODY_VERSE = [
    [(0, 1, 72), (1, 1, 77), (2, 2, 81), (4, 1, 79), (5, 1, 77), (6, 2, 76)],
    [(0, 2, 77), (2, 1, 74), (3, 1, 77), (4, 3, 81)],
    [(0, 2, 82), (2, 1, 81), (3, 1, 79), (4, 2, 77), (6, 2, 74)],
    [(0, 1, 76), (1, 1, 77), (2, 2, 79), (4, 2, 72), (6, 1, 76), (7, 1, 79)],
    [(0, 3, 81), (3, 1, 79), (4, 1, 81), (5, 3, 84)],
    [(0, 2, 86), (2, 1, 84), (3, 1, 81), (4, 2, 77), (6, 2, 81)],
    [(0, 1, 79), (1, 1, 81), (2, 2, 82), (4, 1, 76), (5, 1, 79), (6, 1, 82), (7, 1, 79)],
    [(0, 3, 77), (3, 1, 74), (4, 3, 72)],
]
MELODY_CHORUS = [
    [(0, 2, 86), (2, 1, 84), (3, 1, 81), (4, 4, 77)],
    [(0, 2, 79), (2, 1, 81), (3, 1, 82), (4, 3, 84)],
    [(0, 1, 76), (1, 1, 79), (2, 2, 81), (4, 2, 84), (6, 2, 81)],
    [(0, 3, 77), (3, 1, 76), (4, 2, 74), (6, 1, 77), (7, 1, 81)],
    [(0, 2, 82), (2, 1, 81), (3, 1, 79), (4, 2, 86), (6, 2, 82)],
    [(0, 3, 84), (3, 1, 82), (4, 2, 79), (6, 2, 76)],
    [(0, 1, 77), (1, 1, 79), (2, 2, 81), (4, 1, 77), (5, 1, 74), (6, 2, 77)],
    [(0, 3, 79), (3, 1, 77), (4, 4, 79)],
]
MELODY_BRIDGE = [
    [(0, 4, 81), (4, 4, 77)],
    [(0, 4, 76), (4, 4, 84)],
    [(0, 4, 86), (4, 4, 81)],
    [(0, 6, 84)],
    [(0, 4, 82), (4, 4, 86)],
    [(0, 4, 84), (4, 4, 81)],
    [(0, 2, 77), (2, 2, 81), (4, 4, 86)],
    [(0, 2, 84), (2, 2, 82), (4, 2, 79), (6, 2, 76)],
]

rng = np.random.default_rng(7)


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def times(seconds):
    return np.arange(int(SR * seconds)) / SR


def release(t, end, length):
    return np.clip(1 - (t - end) / length, 0, 1)


# --- Instruments: each returns a mono note including its tail ---------------

def kalimba(f, dur):
    t = times(dur + 0.6)
    tone = (np.sin(2 * np.pi * f * t)
            + 0.12 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 5)
            + 0.30 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 25))  # metal tine "tink"
    return tone * (1 - np.exp(-t * 600)) * np.exp(-t * 3.2) * release(t, dur + 0.2, 0.4)


def epiano(f, dur):
    t = times(dur + 0.35)
    index = 1.4 * np.exp(-t * 4) + 0.25  # bright attack mellowing out, like a Rhodes
    tone = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    g = f * 1.003  # slightly detuned second voice for warmth
    tone += 0.5 * np.sin(2 * np.pi * g * t + index * np.sin(2 * np.pi * g * t))
    tremolo = 1 + 0.08 * np.sin(2 * np.pi * 4.5 * t)
    return tone * tremolo * (1 - np.exp(-t * 300)) * np.exp(-t * 1.4) * release(t, dur, 0.25) / 1.5


def bass(f, dur):
    t = times(dur + 0.1)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.08 * np.sin(6 * np.pi * f * t)
    return tone * (1 - np.exp(-t * 200)) * np.exp(-t * 1.8) * release(t, dur, 0.08)


def glock(f, _dur):
    t = times(1.4)
    tone = (np.sin(2 * np.pi * f * t)
            + 0.35 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 6)
            + 0.15 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 12))
    return tone * (1 - np.exp(-t * 900)) * np.exp(-t * 3.2)


def band_noise(n, lo, hi):
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spectrum[(freqs < lo) | (freqs > hi)] = 0
    y = np.fft.irfft(spectrum, n)
    return y / np.abs(y).max()


def kick():
    t = times(0.35)
    pitch = 48 + 70 * np.exp(-t * 35)
    return np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-t * 9) * (1 - np.exp(-t * 2000))


def snare():
    t = times(0.25)
    return 0.7 * band_noise(len(t), 1200, 7000) * np.exp(-t * 24) + 0.4 * np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)


def hat(open_hat=False):
    t = times(0.3 if open_hat else 0.1)
    return band_noise(len(t), 6000, 15000) * np.exp(-t * (14 if open_hat else 70))


# --- Arrangement -------------------------------------------------------------

class Song:
    def __init__(self, bpm):
        self.beat = 60 / bpm
        self.bar = 4 * self.beat
        self.events = []  # (start seconds, mono samples, gain, pan, reverb send)
        self.bars = 0

    def at(self, bar, eighth):
        """Start time of an 8th note, swung, with a little human looseness."""
        beat, off = divmod(eighth, 2)
        t = (self.bars + bar) * self.bar + (beat + (SWING if off else 0)) * self.beat
        return max(0.0, t + rng.normal(0, 0.004))

    def eighths(self, n):
        return n * self.beat / 2

    def add(self, t, samples, gain, pan=0.0, send=0.0):
        self.events.append((t, samples, gain * rng.uniform(0.92, 1.0), pan, send))

    def section(self, chords, melody=None, drums="full", keys="comp", glock_double=False, sparkle=False):
        for b, bar_chords in enumerate(chords):
            halves = bar_chords if len(bar_chords) == 2 else bar_chords * 2
            nxt = chords[(b + 1) % len(chords)][0]
            for h, name in enumerate(halves):
                self._keys(b, h, name, keys, bar_chords)
                self._bass(b, h, name, nxt if h == 1 else halves[1])
            if melody:
                for start, length, note in melody[b]:
                    self.add(self.at(b, start), kalimba(hz(note), self.eighths(length)), 0.30, 0.2, 0.25)
                    if glock_double and start % 2 == 0:
                        self.add(self.at(b, start), glock(hz(note + 12), 0), 0.07, 0.45, 0.3)
            if sparkle and b % 4 == 3:
                for i, note in enumerate(voicing(bar_chords[-1])[1:]):
                    self.add(self.at(b, 5 + i), glock(hz(note + 24), 0), 0.08, 0.5, 0.35)
            self._drums(b, drums, last=b == len(chords) - 1)
        self.bars += len(chords)

    def _keys(self, b, h, name, style, bar_chords):
        notes = voicing(name)
        base = 4 * h
        if style == "comp":
            # Syncopated comping; with one chord per bar the second half answers the first.
            hits = [(0, 1.5, 0.20), (3, 1, 0.15)] if h == 0 else [(2, 2, 0.17)]
            if len(bar_chords) == 2:
                hits = [(0, 1.5, 0.20), (3, 1, 0.15)]
            for start, length, gain in hits:
                for n in notes:
                    self.add(self.at(b, base + start), epiano(hz(n), self.eighths(length)), gain, -0.25, 0.2)
        elif style == "arp":
            for i, idx in enumerate([0, 1, 2, 3]):
                self.add(self.at(b, base + i), epiano(hz(notes[idx]), self.eighths(1.6)), 0.16, -0.25, 0.25)
        elif style == "pad":
            if h == 0:
                for n in notes:
                    self.add(self.at(b, 0), epiano(hz(n), self.eighths(7)), 0.13, -0.25, 0.3)
                for i, idx in enumerate([0, 1, 2, 3, 2, 1, 2, 3]):
                    self.add(self.at(b, i), kalimba(hz(notes[idx] + 12), self.eighths(1)), 0.11, 0.35, 0.3)

    def _bass(self, b, h, name, next_name):
        root = bass_root(name)
        nxt = bass_root(next_name)
        base = 4 * h
        pattern = [(0, 1.5, root, 0.42), (3, 1, root + 7, 0.30)] if h == 0 else \
                  [(0, 1.5, root, 0.40), (3, 1, nxt - 1, 0.30)]  # chromatic walk-up into the next chord
        for start, length, note, gain in pattern:
            self.add(self.at(b, base + start), bass(hz(note), self.eighths(length)), gain)

    def _drums(self, b, style, last):
        if style == "none":
            return
        if style in ("full", "light"):
            for e in range(8):
                self.add(self.at(b, e), hat(open_hat=(e == 7 and b % 2 == 1)), 0.05 if e % 2 == 0 else 0.07, 0.3)
        if style == "full":
            for e in (0, 5):
                self.add(self.at(b, e), kick(), 0.55)
            for e in (2, 6):
                self.add(self.at(b, e), snare(), 0.20, -0.05, 0.15)
        elif style == "light":
            for e in (0, 4):
                self.add(self.at(b, e), kick(), 0.45)
            if last:  # little fill to lift back into the verse
                for i, e in enumerate((4, 5, 6, 7)):
                    self.add(self.at(b, e), snare(), 0.08 + 0.04 * i, -0.05, 0.15)
        elif style == "shaker":
            for e in range(8):
                self.add(self.at(b, e), hat(), 0.04 if e % 2 == 0 else 0.06, 0.3)
            self.add(self.at(b, 0), kick(), 0.30)


def voicing(name):
    """Chord tones placed around middle C, as close to E4 on average as possible."""
    root, intervals = CHORDS[name]
    best = None
    for low in range(root + 36, root + 72, 12):
        notes = [low + i for i in intervals]
        score = abs(sum(notes) / len(notes) - 63)
        if best is None or score < best[0]:
            best = (score, notes)
    return best[1]


def bass_root(name):
    root = CHORDS[name][0]
    return 40 + (root - 40) % 12  # E2..D#3


# --- Mixing --------------------------------------------------------------------

def comb(x, delay, gain):
    y = x.copy()
    for s in range(delay, len(y), delay):
        e = min(s + delay, len(y))
        y[s:e] += gain * y[s - delay:e - delay]
    return y


def allpass(x, delay, gain):
    y = np.zeros_like(x)
    for s in range(0, len(x), delay):
        e = min(s + delay, len(x))
        prev_x = x[s - delay:e - delay] if s >= delay else np.zeros(e - s)
        prev_y = y[s - delay:e - delay] if s >= delay else np.zeros(e - s)
        y[s:e] = -gain * x[s:e] + prev_x + gain * prev_y
    return y


def reverb(x):
    """Small Schroeder room, darkened so it adds warmth rather than wash."""
    wet = sum(comb(x, d, g) for d, g in ((1557, 0.80), (1617, 0.79), (1491, 0.81), (1422, 0.78))) / 4
    for d in (556, 225):
        wet = allpass(wet, d, 0.5)
    spectrum = np.fft.rfft(wet)
    freqs = np.fft.rfftfreq(len(wet), 1 / SR)
    spectrum *= 1 / (1 + (freqs / 4500) ** 2)
    return np.fft.irfft(spectrum, len(wet))


def render(song):
    length = int(song.bars * song.bar * SR)
    tail = int(2.5 * SR)
    dry = np.zeros((2, length + tail))
    send = np.zeros(length + tail)
    for t, samples, gain, pan, rev in song.events:
        s = int(t * SR)
        e = min(s + len(samples), dry.shape[1])
        chunk = samples[:e - s] * gain
        angle = (pan + 1) * np.pi / 4
        dry[0, s:e] += chunk * np.cos(angle)
        dry[1, s:e] += chunk * np.sin(angle)
        send[s:e] += chunk * rev
    wet = reverb(send)
    mix = dry + np.stack([wet, np.roll(wet, 331)]) * 0.9  # tiny offset widens the room
    # Wrap the tail onto the start so the loop is seamless.
    mix[:, :tail] += mix[:, length:]
    mix = mix[:, :length]
    mix /= np.abs(mix).max()
    mix = np.tanh(mix * 1.3) / np.tanh(1.3) * 0.89  # gentle glue, peaks at -1 dBFS
    return mix


def arrange(bpm):
    song = Song(bpm)
    song.section(INTRO, drums="shaker", keys="pad")
    song.section(VERSE, MELODY_VERSE)
    song.section(CHORUS, MELODY_CHORUS, sparkle=True)
    song.section(VERSE, MELODY_VERSE, glock_double=True)
    song.section(BRIDGE, MELODY_BRIDGE, drums="light", keys="arp")
    song.section(VERSE, MELODY_VERSE, sparkle=True)
    return song


def write_wav(path, mix):
    data = (mix.T * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def encode_mp3(wav, mp3):
    if shutil.which("lame"):
        subprocess.run(["lame", "--quiet", "-b", "128", wav, mp3], check=True)
    elif shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-b:a", "128k", mp3], check=True)
    else:
        raise SystemExit("Install lame or ffmpeg to encode MP3 (or use --wav).")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--output", required=True, help=".mp3 (or .wav) path")
    ap.add_argument("--bpm", type=float, default=104)
    args = ap.parse_args()

    song = arrange(args.bpm)
    mix = render(song)
    if args.output.endswith(".wav"):
        write_wav(args.output, mix)
    else:
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            write_wav(tmp.name, mix)
            encode_mp3(tmp.name, args.output)
    rms = 20 * np.log10(np.sqrt((mix ** 2).mean()))
    print(f"{args.output}: {song.bars} bars, {mix.shape[1] / SR:.1f}s, RMS {rms:.1f} dBFS")


if __name__ == "__main__":
    main()
