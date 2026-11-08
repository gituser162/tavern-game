"""Generates the looping music of «Втомлений Грифон»: tavern, forest, graveyard + fire crackle ambience.
Run: python3 gen_music.py <out_dir>   (writes <out_dir>/music/*.ogg)"""
import sys, numpy as np
from synth import *

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"

CH = {  # chord tones (midi) around octave 3
    "Dm": ["D3", "F3", "A3"], "C": ["C3", "E3", "G3"], "Am": ["A2", "C3", "E3"], "F": ["F2", "A2", "C3"],
    "G": ["G2", "B2", "D3"], "Em": ["E3", "G3", "B3"], "D": ["D3", "F#3", "A3"], "Bm": ["B2", "D3", "F#3"],
    "E": ["E3", "G#3", "B3"], "Bb": ["Bb2", "D3", "F3"],
}
CH = {k: [note_num(n) for n in v] for k, v in CH.items()}


# ---------- instruments ----------

def lead(m, dur, duty=0.25, vib=0.004):
    n = int(dur * SR)
    return pulse(midi(m), n, duty, vib=vib, vib_rate=5.5) * env(n, 0.004, 0.09, 0.55, min(0.06, dur * 0.3))


def flute(m, dur, vib=0.006):
    n = int(dur * SR)
    s = 0.7 * tri(midi(m), n, vib=vib, vib_rate=5.0, vib_delay=0.1) + 0.3 * sine(midi(m) * 2, n, vib=vib)
    s += 0.04 * noise(n) * env(n, 0.01, 0.05, 0.0, 0)  # breath
    return s * env(n, 0.035, 0.1, 0.8, min(0.09, dur * 0.4))


def pluck(m, dur, decay=0.16, duty=0.125):
    n = int(dur * SR)
    return pulse(midi(m), n, duty) * exp_env(n, decay) * env(n, 0.002, 0, 1, 0.02)


def bass(m, dur, decay=0.35):
    n = int(dur * SR)
    return tri4(midi(m), n) * (0.35 + 0.65 * exp_env(n, decay)) * env(n, 0.003, 0, 1, 0.03)


def kick(gain=1.0):
    n = int(0.16 * SR)
    f = 45 + 80 * np.exp(-np.arange(n) / SR / 0.03)
    return sine(f, n) * exp_env(n, 0.06) * gain


def frame_drum():
    n = int(0.2 * SR)
    return (0.8 * sine(95, n) + 0.5 * lowpass(noise(n), 900)) * exp_env(n, 0.06)


def tap(decay=0.025):
    n = int(0.08 * SR)
    return highpass(noise(n, 16000), 3000) * exp_env(n, decay)


def bell(m, dur=2.5, decay=1.1):
    n = int(dur * SR)
    f = midi(m)
    s = sum(a * sine(f * r, n) * exp_env(n, decay / (1 + i * 0.7))
            for i, (r, a) in enumerate([(1, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.18), (8.9, 0.08)]))
    return s * env(n, 0.002, 0, 1, 0.1)


def pad(chord, dur, cutoff=900):
    n = int(dur * SR)
    s = sum(saw(midi(m) * d, n) for m in chord for d in (0.997, 1.003))
    s = lowpass(s, cutoff, 1)
    return s * env(n, dur * 0.35, 0.1, 1.0, dur * 0.4)


def play_line(track, seq, unit, start, inst, gain, **kw):
    pos = start
    for m, d in parse(seq):
        if m is not None:
            track.add(pos, inst(m, d * unit * 0.98, **kw), gain)
        pos += d * unit
    return pos


# ---------- Tavern: D dorian jig, 6/8 ----------

def tavern():
    e = 60 / (66 * 3)          # one eighth
    bar = 6 * e
    A = ["A4:2 F4:1 D4:2 F4:1", "G4:2 E4:1 C4:2 E4:1", "F4:1 G4:1 A4:1 D5:2 A4:1", "C5:2 A4:1 E4:3",
         "A4:2 F4:1 D4:2 F4:1", "G4:2 E4:1 C4:1 D4:1 E4:1", "F4:1 A4:1 C5:1 A4:2 G4:1", "E4:2 C4:1 D4:3"]
    B = ["C5:2 A4:1 F4:2 A4:1", "G4:2 E4:1 G4:1 A4:1 B4:1", "C5:1 D5:1 C5:1 A4:2 F4:1", "G4:2 B4:1 D5:3",
         "C5:2 A4:1 F4:1 G4:1 A4:1", "G4:2 E4:1 C4:2 E4:1", "E4:1 F4:1 G4:1 A4:1 C5:1 E5:1", "D5:3 r:3"]
    chA = ["Dm", "C", "Dm", "Am", "Dm", "C", "F", "C"]
    chB = ["F", "C", "Dm", "G", "F", "C", "Am", "Dm"]
    bars = A + B + A + B
    chords = chA + chB + chA + chB
    tr = Track(len(bars) * bar)
    mel = Track(len(bars) * bar)
    for i, (line, ch) in enumerate(zip(bars, chords)):
        t0 = i * bar
        second_pass = i >= 16
        if second_pass:   # second time round the tune is played by the "flute", an octave up in B
            play_line(mel, line, e, t0, flute, 0.30 if i < 24 else 0.26)
            if i >= 24:
                play_line(mel, " ".join(f"{tok.split(':')[0]}:{tok.split(':')[1]}" for tok in line.split()), e, t0, lead, 0.09, duty=0.5)
        else:
            play_line(mel, line, e, t0, lead, 0.20)
        root = CH[ch][0]
        tr.add(t0, bass(root - 12, bar * 0.48), 0.42)
        tr.add(t0 + 3 * e, bass(CH[ch][2] - 12, bar * 0.48), 0.36)
        for k in (1, 2, 4, 5):
            s = sum(pluck(m + 12, e * 0.95, 0.09) for m in CH[ch])
            tr.add(t0 + k * e, s, 0.055 if k in (1, 4) else 0.04)
        tr.add(t0, frame_drum(), 0.32)
        tr.add(t0 + 3 * e, frame_drum(), 0.22)
        for k in (1, 2, 4, 5):
            tr.add(t0 + k * e, tap(), 0.05 if k in (2, 5) else 0.03)
        if i % 8 == 7:  # little fill at the end of each phrase
            tr.add(t0 + 4 * e, frame_drum(), 0.15)
            tr.add(t0 + 5 * e, frame_drum(), 0.18)
    tr.buf += echo(lowpass(mel.buf, 6000), e * 1.5, 0.3, 0.18)
    return tr.looped()


# ---------- Forest: G major, calm 4/4 arpeggios ----------

def forest():
    q = 60 / 80
    bar = 4 * q
    s16 = q / 4
    chords = ["G", "Em", "C", "D", "G", "Em", "C", "D", "C", "D", "Bm", "Em", "C", "D", "G", "G"]
    mel = ["D5:2 B4:1 A4:1", "G4:3 E4:1", "E4:2 G4:1 A4:1", "A4:4", "B4:2 D5:1 E5:1", "D5:2 B4:2",
           "C5:1 B4:1 A4:1 G4:1", "A4:3 r:1", "E5:2 D5:1 C5:1", "D5:2 A4:2", "B4:1 A4:1 F#4:2", "G4:3 B4:1",
           "C5:2 B4:1 A4:1", "B4:1 A4:1 F#4:1 A4:1", "G4:4", "r:4"]
    tr = Track(len(chords) * bar)
    lead_tr = Track(len(chords) * bar)
    pattern = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 2, 1]
    for i, ch in enumerate(chords):
        t0 = i * bar
        tones = CH[ch] + [CH[ch][0] + 12, CH[ch][1] + 12]
        for k, p in enumerate(pattern):
            tr.add(t0 + k * s16, pluck(tones[p] + 12, s16 * 2.5, 0.22, duty=0.25), 0.05)
        tr.add(t0, bass(CH[ch][0] - 12, bar * 1.04, 1.2), 0.34)
        tr.add(t0, pad(CH[ch], bar * 1.05, 700), 0.035)
        play_line(lead_tr, mel[i], q, t0, flute, 0.30)
    # birds: little chirps here and there
    for when in (1.3, 9.7, 17.2, 26.1, 33.4, 41.0):
        n = int(0.09 * SR)
        for j in range(rng.integers(2, 4)):
            f0 = rng.uniform(2800, 3600)
            fsw = f0 * (1 + 0.5 * np.sin(np.linspace(0, np.pi, n)))
            tr.add(when + j * 0.12, sine(fsw, n) * env(n, 0.01, 0.02, 0.6, 0.03), 0.05)
    tr.buf += echo(lead_tr.buf, q * 0.75, 0.35, 0.25)
    return tr.looped()


# ---------- Graveyard: A minor, slow, bells over a drone ----------

def graveyard():
    q = 60 / 60
    bar = 4 * q
    chords = ["Am", "Am", "F", "F", "Dm", "Dm", "E", "E", "Am", "Am", "Bb", "F", "Dm", "E", "Am", "E"]
    mel = ["E5:3 C5:1", "B4:4", "A4:3 C5:1", "F4:4", "D5:2 C5:1 A4:1", "F4:4", "G#4:2 B4:2", "E4:4",
           "A4:1 C5:1 E5:2", "D5:2 C5:2", "D5:3 F5:1", "C5:4", "A4:2 F4:1 D4:1", "G#4:2 E4:2", "A4:4", "r:4"]
    tr = Track(len(chords) * bar)
    bells = Track(len(chords) * bar)
    for i, ch in enumerate(chords):
        t0 = i * bar
        tr.add(t0, pad(CH[ch], bar * 1.1, 500), 0.06)
        tr.add(t0, bass(CH[ch][0] - 12, bar, 2.5), 0.30)
        if i % 2 == 0:
            tr.add(t0 + 2 * q, bass(CH[ch][0] - 12, bar * 0.5, 1.5), 0.15)
        pos = t0
        for m, d in parse(mel[i]):
            if m is not None:
                bells.add(pos, bell(m, 3.0, 1.0), 0.16)
            pos += d * q
        if i % 4 == 3:   # distant toll
            tr.add(t0 + 3 * q, bell(note_num("A2"), 4.0, 2.0), 0.18)
    # cold wind: slow swelling filtered noise
    n = tr.length
    wind = lowpass(noise(n), 500, 1) * (0.5 + 0.5 * np.sin(2 * np.pi * np.arange(n) / SR / 13.0) ** 2)
    tr.buf[:n] += wind * 0.10
    tr.buf += echo(bells.buf, 0.6, 0.45, 0.35, 6)
    return tr.looped()


# ---------- Fire crackle ambience ----------

def fire():
    secs = 12.0
    tr = Track(secs)
    n = tr.length
    hiss = lowpass(highpass(noise(n), 400), 2500) * 0.05
    rumble = lowpass(noise(n), 160, 1) * 0.35
    tr.buf[:n] += hiss + rumble
    for _ in range(int(secs * 9)):
        when = rng.uniform(0, secs)
        m = int(rng.uniform(0.003, 0.02) * SR)
        c = highpass(noise(m), rng.uniform(1500, 5000)) * exp_env(m, rng.uniform(0.002, 0.008))
        tr.add(when, c, rng.uniform(0.15, 0.6))
    for _ in range(6):   # bigger pops
        when = rng.uniform(0, secs)
        m = int(0.05 * SR)
        tr.add(when, lowpass(noise(m), 3000) * exp_env(m, 0.012), 0.7)
    return tr.looped()


if __name__ == "__main__":
    for name, fn, peak in [("tavern", tavern, 0.8), ("forest", forest, 0.8), ("graveyard", graveyard, 0.8), ("fire", fire, 0.7)]:
        x = fn()
        write_ogg(f"{OUT}/music/{name}.ogg", x, peak)
        print(name, round(len(x) / SR, 1), "s")
