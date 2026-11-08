"""Tiny chiptune synth (numpy only) for «Втомлений Грифон». Shared by gen_music.py and gen_sfx.py."""
import numpy as np, wave, subprocess, os

SR = 32000
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_num(s):
    """'A4', 'F#4', 'Bb3' -> midi number."""
    n = NOTE[s[0]]
    i = 1
    while s[i] in "#b":
        n += 1 if s[i] == "#" else -1
        i += 1
    return n + 12 * (int(s[i:]) + 1)


def parse(seq):
    """'A4:2 F4:1 r:3' -> [(midi or None, length units)]."""
    out = []
    for tok in seq.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else note_num(n), float(d)))
    return out


def t(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.005, d=0.05, s=0.7, r=0.05, sr=SR):
    """ADSR envelope of n samples (release inside the length)."""
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    e = np.full(n, s, dtype=float)
    a_n = min(a_n, n)
    e[:a_n] = np.linspace(0, 1, a_n, endpoint=False) if a_n else e[:a_n]
    d_end = min(n, a_n + d_n)
    if d_end > a_n:
        e[a_n:d_end] = np.linspace(1, s, d_end - a_n)
    if r_n and n > r_n:
        e[-r_n:] *= np.linspace(1, 0, r_n)
    return e


def exp_env(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def phase(freq, n, vib=0.0, vib_rate=5.0, vib_delay=0.15):
    tt = np.arange(n) / SR
    f = np.full(n, float(freq)) if np.isscalar(freq) else freq
    if vib:
        depth = np.clip((tt - vib_delay) / 0.2, 0, 1) * vib
        f = f * (1 + depth * np.sin(2 * np.pi * vib_rate * tt))
    return np.cumsum(f) / SR


def pulse(freq, n, duty=0.5, **kw):
    p = phase(freq, n, **kw) % 1.0
    return np.where(p < duty, 1.0, -1.0)


def tri(freq, n, **kw):
    p = (phase(freq, n, **kw) + 0.75) % 1.0   # starts at 0, no click
    return 4 * np.abs(p - 0.5) - 1


def tri4(freq, n, **kw):
    """NES-like stepped triangle (16 steps)."""
    return np.round(tri(freq, n, **kw) * 8) / 8


def saw(freq, n, **kw):
    return 2 * (phase(freq, n, **kw) % 1.0) - 1


def sine(freq, n, **kw):
    return np.sin(2 * np.pi * phase(freq, n, **kw))


def noise(n, rate=SR):
    """Sample-and-hold white noise; lower rate = darker, more 'chippy'."""
    step = max(1, int(SR / rate))
    v = rng.uniform(-1, 1, n // step + 2)
    return np.repeat(v, step)[:n]


def lowpass(x, cutoff, order=2):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(X, len(x))


def highpass(x, cutoff, order=2):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 - 1 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(X, len(x))


class Track:
    """A buffer you add sounds into at given times."""

    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR * 6)
        self.length = int(seconds * SR)

    def add(self, start, sig, gain=1.0):
        i = int(start * SR)
        self.buf[i:i + len(sig)] += sig * gain

    def looped(self):
        """Fold the tail (reverb / release past the loop point) back onto the start."""
        out = self.buf[:self.length].copy()
        tail = self.buf[self.length:]
        out[:len(tail)] += tail
        return out


def echo(x, delay, fb=0.35, mix=0.3, taps=4):
    out = x.copy()
    d = int(delay * SR)
    for k in range(1, taps + 1):
        out[d * k:] += x[:len(x) - d * k] * mix * fb ** (k - 1)
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write_wav(path, x, peak=0.89):
    x = normalize(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x, peak=0.85):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x, peak)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)
