"""Music and sounds of the swamp, the lake and the port (same chiptune synth as gen_music.py / gen_sfx.py).
Run: python3 gen_places_audio.py <out_dir>   (writes <out_dir>/music/{swamp,lake,port}.ogg and
<out_dir>/sfx/{splash,cast,bite,catch,wisp}.wav; the other tracks and sounds are not touched)."""
import sys
import numpy as np
from synth import *
from gen_music import CH, lead, flute, pluck, bass, pad, bell, frame_drum, tap, kick, play_line
from gen_sfx import N, blip, ring, thump, swish, seq, lead_note

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
CH.update({k: [note_num(n) for n in v] for k, v in {
    "Gm": ["G2", "Bb2", "D3"], "Cm": ["C3", "Eb3", "G3"], "A": ["A2", "C#3", "E3"], "Bbm": ["Bb2", "Db3", "F3"],
}.items()})


# ---------- Swamp: D minor, slow and murky; frogs, bubbles, a lonely flute far away ----------

def swamp():
    q = 60 / 54
    bar = 4 * q
    chords = ["Dm", "Dm", "Bb", "A", "Dm", "Gm", "Bb", "A", "Gm", "Dm", "Bb", "A", "Dm", "Gm", "A", "Dm"]
    mel = ["r:2 A4:1 F4:1", "E4:3 r:1", "D4:2 F4:1 E4:1", "C#4:4", "r:2 D5:1 C5:1", "Bb4:2 G4:2", "F4:1 E4:1 D4:2", "E4:4",
           "r:2 G4:1 Bb4:1", "A4:3 F4:1", "D5:2 C5:1 Bb4:1", "A4:4", "r:2 F4:1 A4:1", "G4:2 Bb4:2", "A4:2 C#4:2", "D4:4"]
    tr = Track(len(chords) * bar)
    far = Track(len(chords) * bar)
    for i, ch in enumerate(chords):
        t0 = i * bar
        tr.add(t0, pad(CH[ch], bar * 1.1, 420), 0.07)
        tr.add(t0, bass(CH[ch][0] - 12, bar, 3.0), 0.30)
        tr.add(t0 + 2.5 * q, bass(CH[ch][0] - 12, q, 0.8), 0.12)
        play_line(far, mel[i], q, t0, flute, 0.22, vib=0.012)
        if i % 4 == 3:
            tr.add(t0 + 3 * q, bell(note_num("D3"), 3.0, 1.5), 0.10)
    n = tr.length
    t = np.arange(n) / SR
    # wet low wind
    tr.buf[:n] += lowpass(noise(n), 300, 1) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 11.0) ** 2) * 0.12
    # frogs: short low croaks in little groups
    for when in np.arange(1.0, len(chords) * bar - 2, 3.7) + rng.uniform(0, 1.2, int((len(chords) * bar - 3) / 3.7) + 1)[:len(np.arange(1.0, len(chords) * bar - 2, 3.7))]:
        f0 = rng.uniform(90, 140)
        for k in range(rng.integers(2, 4)):
            m = int(0.09 * SR)
            croak = pulse(f0 * (1 + 0.15 * np.sin(np.linspace(0, 9, m))), m, 0.3) * env(m, 0.005, 0.02, 0.7, 0.03)
            tr.add(when + k * 0.16, lowpass(croak, 900), 0.12)
    # bubbles rising from the mud
    for when in rng.uniform(0, len(chords) * bar - 1, 40):
        m = int(rng.uniform(0.03, 0.06) * SR)
        f0 = rng.uniform(200, 420)
        tr.add(when, sine(np.linspace(f0, f0 * 2.2, m), m) * env(m, 0.002, 0.01, 0.6, 0.01), 0.05)
    tr.buf += echo(lowpass(far.buf, 3500), q * 1.5, 0.5, 0.45, 6)
    return tr.looped()


# ---------- Lake: F major waltz, calm; lapping water ----------

def lake():
    b = 60 / 96          # one beat (3/4)
    bar = 3 * b
    chords = ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Am", "Bb", "F", "Gm", "C", "F", "F"]
    mel = ["A4:2 C5:1", "G4:3", "F4:1 A4:1 D5:1", "D5:2 C5:1", "C5:2 A4:1", "G4:2 E4:1", "F4:1 G4:1 A4:1", "G4:3",
           "A4:2 F4:1", "E4:2 C4:1", "D4:1 F4:1 Bb4:1", "A4:3", "Bb4:2 G4:1", "E4:1 G4:1 C5:1", "A4:3", "F4:2 r:1"]
    tr = Track(len(chords) * bar)
    lead_tr = Track(len(chords) * bar)
    for i, ch in enumerate(chords):
        t0 = i * bar
        tr.add(t0, bass(CH[ch][0] - 12, bar * 0.9, 0.9), 0.36)
        for k in (1, 2):
            s = sum(pluck(m + 12, b * 0.9, 0.18, duty=0.25) for m in CH[ch])
            tr.add(t0 + k * b, s, 0.05)
        tr.add(t0, pad(CH[ch], bar * 1.05, 800), 0.025)
        play_line(lead_tr, mel[i], b, t0, flute, 0.28)
        if i >= 8:
            play_line(lead_tr, mel[i], b, t0 + b * 0.5, pluck, 0.04)
    n = tr.length
    t = np.arange(n) / SR
    lap = lowpass(highpass(noise(n), 200), 900) * (0.35 + 0.65 * np.clip(np.sin(2 * np.pi * t / 3.1), 0, 1) ** 3)
    tr.buf[:n] += lap * 0.12
    for when in (2.0, 13.5, 24.0, 31.7):   # a far bird
        m = int(0.12 * SR)
        f = np.linspace(2600, 1900, m)
        tr.add(when, sine(f, m) * env(m, 0.01, 0.03, 0.5, 0.04), 0.04)
        tr.add(when + 0.2, sine(f * 1.1, m) * env(m, 0.01, 0.03, 0.5, 0.04), 0.035)
    tr.buf += echo(lead_tr.buf, b * 0.75, 0.3, 0.25)
    return tr.looped()


# ---------- Port: A minor shanty in 6/8, accordion-ish lead, stomping drum, gulls ----------

def accordion(m, dur):
    n = int(dur * SR)
    f = midi(m)
    s = pulse(f, n, 0.5, vib=0.003, vib_rate=6.0) * 0.6 + pulse(f * 1.004, n, 0.35) * 0.4
    return lowpass(s, 3200) * env(n, 0.02, 0.06, 0.8, min(0.06, dur * 0.3))


def port():
    e = 60 / (100 * 3)
    bar = 6 * e
    A = ["E4:2 A4:1 A4:2 B4:1", "C5:2 B4:1 A4:3", "G4:2 C5:1 C5:2 D5:1", "E5:2 D5:1 C5:3",
         "E5:2 C5:1 D5:2 B4:1", "C5:2 A4:1 B4:2 G4:1", "A4:1 B4:1 C5:1 B4:2 G#4:1", "A4:6"]
    chA = ["Am", "Am", "C", "C", "Am", "F", "E", "Am"]
    B = ["A4:2 E5:1 E5:2 D5:1", "C5:2 D5:1 E5:3", "D5:2 C5:1 B4:2 G4:1", "C5:2 B4:1 A4:3",
         "E5:2 E5:1 D5:2 C5:1", "D5:2 B4:1 G4:3", "A4:2 C5:1 B4:2 G#4:1", "A4:3 r:3"]
    chB = ["Am", "C", "G", "Am", "C", "G", "E", "Am"]
    bars = A + B + A + B
    chords = chA + chB + chA + chB
    tr = Track(len(bars) * bar)
    mel = Track(len(bars) * bar)
    for i, (line, ch) in enumerate(zip(bars, chords)):
        t0 = i * bar
        play_line(mel, line, e, t0, accordion if i % 16 < 8 or i >= 24 else lead, 0.22)
        tr.add(t0, bass(CH[ch][0] - 12, bar * 0.45), 0.42)
        tr.add(t0 + 3 * e, bass(CH[ch][2] - 12, bar * 0.45), 0.34)
        for k in (1, 2, 4, 5):
            s = sum(pluck(m + 12, e * 0.9, 0.07, duty=0.5) for m in CH[ch])
            tr.add(t0 + k * e, s, 0.045)
        tr.add(t0, kick(1.0), 0.45)
        tr.add(t0 + 3 * e, frame_drum(), 0.30)
        for k in (2, 5):
            tr.add(t0 + k * e, tap(0.03), 0.06)
    n = tr.length
    t = np.arange(n) / SR
    tr.buf[:n] += lowpass(noise(n), 500, 1) * (0.4 + 0.6 * np.sin(2 * np.pi * t / 5.3) ** 2) * 0.07   # surf
    for when in (3.0, 15.0, 28.0, 41.0):   # gulls
        for k in range(2):
            m = int(0.25 * SR)
            f = 1500 + 500 * np.sin(np.linspace(0, np.pi, m))
            tr.add(when + k * 0.32, lowpass(saw(f, m), 2800) * env(m, 0.02, 0.05, 0.6, 0.08), 0.035)
    tr.buf += echo(mel.buf, e * 1.5, 0.25, 0.15)
    return tr.looped()


# ---------- Sound effects ----------

def sfx():
    S = {}
    # splash: a plop and a short spray
    n = int(0.45 * SR)
    sp = np.zeros(n)
    m = int(0.12 * SR)
    sp[:m] += sine(np.linspace(520, 160, m), m) * exp_env(m, 0.04) * 0.8
    spray = lowpass(highpass(noise(n), 800), 5000) * exp_env(n, 0.09)
    sp += spray * 0.5
    S["splash"] = sp
    # cast: a swish of the rod and the reel clicking out
    c = np.zeros(int(0.6 * SR))
    w = swish(0.22, 900, 5000)
    c[:len(w)] += w
    for k in range(7):
        b = blip(2400, 0.015, 0.5, 0.004) * 0.35
        a = int((0.2 + k * 0.035) * SR)
        c[a:a + len(b)] += b
    S["cast"] = c
    # bite: two quick plops and an alert blip
    bt = np.zeros(int(0.45 * SR))
    for k, f in enumerate((700, 560)):
        m = int(0.07 * SR)
        x = sine(np.linspace(f, f * 0.4, m), m) * exp_env(m, 0.025)
        a = int(k * 0.09 * SR)
        bt[a:a + m] += x * 0.7
    al = seq([N("A5"), N("E6")], 0.05, lambda f: blip(f, 0.08, 0.25, 0.03)) * 0.5
    a = int(0.2 * SR)
    bt[a:a + len(al)] += al[:len(bt) - a]
    S["bite"] = bt
    # catch: splash out of the water and a happy arpeggio
    ct = np.zeros(int(1.0 * SR))
    ct[:len(sp)] += sp * 0.6
    arp = seq([N("C5"), N("E5"), N("G5"), N("C6")], 0.07, lambda f: lead_note(f, 0.22))
    a = int(0.25 * SR)
    ct[a:a + len(arp)] += arp[:len(ct) - a] * 0.8
    S["catch"] = ct
    # wisp caught: an eerie glassy shimmer
    ws = np.zeros(int(1.4 * SR))
    for i, m_ in enumerate(["E6", "G#6", "D#7", "B6", "E7"]):
        x = sine(N(m_), int(0.6 * SR), vib=0.01) * exp_env(int(0.6 * SR), 0.2)
        a = int(i * 0.1 * SR)
        ws[a:a + len(x)] += x * 0.5
    S["wisp"] = echo(ws, 0.13, 0.5, 0.5)
    return S


if __name__ == "__main__":
    for name, fn in [("swamp", swamp), ("lake", lake), ("port", port)]:
        x = fn()
        write_ogg(f"{OUT}/music/{name}.ogg", x, 0.8)
        print(name, round(len(x) / SR, 1), "s")
    for name, x in sfx().items():
        x = np.concatenate([np.asarray(x, dtype=float), np.zeros(int(0.02 * SR))])
        write_wav(f"{OUT}/sfx/{name}.wav", x, 0.8)
    print("sfx ok")
