"""Generates the sound effects of «Втомлений Грифон». Run: python3 gen_sfx.py <out_dir> (writes <out_dir>/sfx/*.wav)"""
import sys, numpy as np
from synth import *

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"


def N(s):
    return midi(note_num(s))


def seq(notes, step, inst, overlap=1.0):
    """Notes one after another; returns one signal."""
    parts = []
    total = int((step * (len(notes) - 1) + step * overlap * 4) * SR)
    out = np.zeros(total)
    for i, n in enumerate(notes):
        s = inst(n)
        a = int(i * step * SR)
        out[a:a + len(s)] += s[:max(0, total - a)]
    return out


def blip(f, dur, duty=0.5, decay=0.05):
    n = int(dur * SR)
    return pulse(f, n, duty) * exp_env(n, decay) * env(n, 0.001, 0, 1, 0.005)


def ring(f, dur=0.5, decay=0.15):
    n = int(dur * SR)
    return (sine(f, n) + 0.4 * sine(f * 2.01, n) + 0.2 * pulse(f, n, 0.25) * 0.5) * exp_env(n, decay) * env(n, 0.001, 0, 1, 0.01)


def bell(f, dur=2.2, decay=0.8):
    n = int(dur * SR)
    s = sum(a * sine(f * r, n) * exp_env(n, decay / (1 + i * 0.6))
            for i, (r, a) in enumerate([(1, 1.0), (2.0, 0.6), (2.76, 0.4), (5.4, 0.25), (8.9, 0.12)]))
    hit = highpass(noise(int(0.01 * SR)), 3000) * 0.4
    s[:len(hit)] += hit
    return s * env(n, 0.001, 0, 1, 0.1)


def thump(f0=110, f1=45, dur=0.2, decay=0.05, nz=0.5):
    n = int(dur * SR)
    f = f1 + (f0 - f1) * np.exp(-np.arange(n) / SR / 0.025)
    return (sine(f, n) + nz * lowpass(noise(n), 1200)) * exp_env(n, decay)


def swish(dur=0.22, lo=1500, hi=6000):
    n = int(dur * SR)
    x = highpass(lowpass(noise(n), hi), lo)
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    return x * shape


def sfx():
    S = {}
    # UI
    S["click"] = blip(1400, 0.04, 0.25, 0.012) * 0.6
    # an item put down on a wooden shelf: short knock + a tiny clink
    S["shelf"] = thump(340, 170, 0.12, 0.025, 0.7) * 0.8 + np.pad(blip(2100, 0.03, 0.25, 0.008) * 0.25, (0, int(0.09 * SR)))
    S["open"] = seq([N("E5"), N("A5")], 0.045, lambda f: blip(f, 0.09, 0.25, 0.03)) * 0.6
    S["close"] = seq([N("A5"), N("E5")], 0.045, lambda f: blip(f, 0.09, 0.25, 0.03)) * 0.6
    S["page"] = swish(0.25, 1200, 7000)
    S["error"] = seq([N("E3"), N("C3")], 0.08, lambda f: blip(f, 0.12, 0.5, 0.06)) * 0.6
    # tavern
    S["bell"] = bell(N("A5"), 2.2, 0.9) + 0.5 * bell(N("A5") * 1.003, 2.2, 0.7)
    S["coin"] = seq([N("B5"), N("E6")], 0.07, lambda f: ring(f, 0.45, 0.12))
    S["buy"] = seq([N("E6"), N("B5"), N("G#6"), N("E6")], 0.055, lambda f: ring(f, 0.35, 0.08))
    S["visitor"] = seq([N("C6"), N("G6")], 0.09, lambda f: ring(f, 0.6, 0.2)) * 0.6   # door bell tinkle
    S["refuse"] = seq([N("D4"), N("C#4")], 0.12, lambda f: tri(f, int(0.2 * SR)) * env(int(0.2 * SR), 0.005, 0.05, 0.6, 0.06))
    S["angry"] = seq([N("F3"), N("C3")], 0.1, lambda f: blip(f, 0.18, 0.5, 0.08))
    # door: creak + thud
    n = int(0.55 * SR)
    f = 180 + 90 * np.sin(np.linspace(0, 3.4, n)) + 40 * np.sin(np.linspace(0, 40, n))
    creak = lowpass(saw(f, n) * (0.6 + 0.4 * pulse(23, n, 0.4)), 2200) * env(n, 0.05, 0.1, 0.8, 0.1)
    door = np.zeros(int(0.85 * SR)); door[:n] += creak * 0.35
    th = thump(130, 60, 0.3, 0.06, 0.6); door[int(0.5 * SR):int(0.5 * SR) + len(th)] += th
    S["door"] = door
    # locations
    S["gather"] = (lambda n: pulse(np.linspace(500, 1500, n), n, 0.25) * exp_env(n, 0.04))(int(0.1 * SR)) * 0.7 \
        + np.pad(swish(0.08, 2000, 7000) * 0.4, (0, int(0.02 * SR)))
    dig = np.zeros(int(0.9 * SR))
    for k in (0.0, 0.4):
        x = thump(90, 40, 0.25, 0.05, 1.2) + np.pad(swish(0.12, 400, 2500), (0, int(0.13 * SR)))[:int(0.25 * SR)] * 0.6
        dig[int(k * SR):int(k * SR) + len(x)] += x
    S["dig"] = dig
    S["grave_loot"] = seq([N("A4"), N("C5"), N("E5"), N("A5")], 0.07, lambda f: ring(f, 0.5, 0.15)) * 0.8
    S["expelled"] = np.concatenate([thump(70, 30, 0.35, 0.12, 1.5)]) + np.pad(
        seq([N("C4"), N("B3"), N("Bb3")], 0.09, lambda f: blip(f, 0.15, 0.5, 0.06)), (0, 0))[:int(0.35 * SR)]
    # rare find / magic event: sparkle
    sp = np.zeros(int(0.9 * SR))
    for i, m in enumerate(["E6", "B6", "G#6", "E7", "B6"]):
        s = sine(N(m), int(0.3 * SR)) * exp_env(int(0.3 * SR), 0.08)
        sp[int(i * 0.07 * SR):int(i * 0.07 * SR) + len(s)] += s
    S["magic"] = echo(sp, 0.09, 0.4, 0.4)
    # alchemy: bubbles
    br = np.zeros(int(1.1 * SR))
    for i in range(9):
        n = int(rng.uniform(0.03, 0.06) * SR)
        f0 = rng.uniform(300, 700)
        b = sine(np.linspace(f0, f0 * 2.6, n), n) * env(n, 0.002, 0.01, 0.7, 0.01)
        a = int((0.05 + i * 0.09 + rng.uniform(0, 0.04)) * SR)
        br[a:a + n] += b * rng.uniform(0.4, 0.9)
    tail = seq([N("C6"), N("E6"), N("G6")], 0.06, lambda f: ring(f, 0.4, 0.12))
    br[int(0.75 * SR):int(0.75 * SR) + len(tail)] += tail[:len(br) - int(0.75 * SR)] * 0.6
    S["brew"] = br
    # contracts and reputation
    S["contract"] = seq([N("G4"), N("C5")], 0.1, lambda f: lead_note(f, 0.25)) * 0.8   # hero takes a contract
    S["success"] = seq([N("C5"), N("E5"), N("G5"), N("C6")], 0.09, lambda f: lead_note(f, 0.35))
    S["fail"] = seq([N("G4"), N("E4"), N("C4"), N("B3")], 0.14, lambda f: tri(f, int(0.3 * SR)) * env(int(0.3 * SR), 0.005, 0.05, 0.7, 0.1))
    death = seq([N("A3"), N("F3"), N("D3")], 0.3, lambda f: tri(f, int(0.6 * SR)) * env(int(0.6 * SR), 0.01, 0.1, 0.6, 0.3))
    toll = bell(N("A3"), 2.0, 1.0)[:len(death)]
    death[:len(toll)] += 0.4 * toll
    S["death"] = death
    S["rank_up"] = seq([N("G4"), N("C5"), N("E5"), N("G5"), N("E5"), N("G5"), N("C6")], 0.08, lambda f: lead_note(f, 0.3))
    S["rank_down"] = seq([N("E5"), N("D#5"), N("D5"), N("C#5")], 0.12, lambda f: lead_note(f, 0.2, 0.5))
    # town / hall events
    S["event"] = seq([N("C5"), N("Eb5"), N("F#5"), N("A5")], 0.08, lambda f: ring(f, 0.6, 0.2)) * 0.8
    S["tax"] = seq([N("A5"), N("E5"), N("C5"), N("A4")], 0.06, lambda f: ring(f, 0.35, 0.1)) * 0.8
    S["fair"] = seq([N("C5"), N("G5"), N("E5"), N("C6"), N("G5"), N("C6")], 0.07, lambda f: lead_note(f, 0.18))
    brawl = np.zeros(int(0.9 * SR))
    for k in (0.0, 0.18, 0.45):
        x = thump(160, 60, 0.18, 0.04, 1.8)
        brawl[int(k * SR):int(k * SR) + len(x)] += x
    crash = highpass(noise(int(0.3 * SR)), 2500) * exp_env(int(0.3 * SR), 0.08)
    brawl[int(0.55 * SR):int(0.55 * SR) + len(crash)] += crash * 0.6
    S["brawl"] = brawl
    # end of game
    S["victory"] = victory()
    S["defeat"] = seq([N("C5"), N("G4"), N("Eb4"), N("D4"), N("C4")], 0.28,
                      lambda f: tri(f, int(0.7 * SR), vib=0.01) * env(int(0.7 * SR), 0.01, 0.1, 0.7, 0.3))
    return S


def lead_note(f, dur, duty=0.25):
    n = int(dur * SR)
    return pulse(f, n, duty, vib=0.004) * env(n, 0.003, 0.06, 0.6, min(0.08, dur * 0.4))


def victory():
    tune = "G4:1 C5:1 E5:1 G5:3 E5:1 G5:5"
    out = np.zeros(int(2.4 * SR))
    pos = 0.0
    u = 0.11
    for m, d in parse(tune):
        s = lead_note(midi(m), d * u * 1.1 + 0.05)
        a = int(pos * SR)
        out[a:a + len(s)] += s
        out[a:a + len(s)] += 0.5 * lead_note(midi(m - 12), d * u * 1.1 + 0.05, 0.5)
        pos += d * u
    b = bell(N("C6"), 1.4, 0.6)
    a = int(1.0 * SR)
    out[a:a + len(b)] += b * 0.4
    return out


if __name__ == "__main__":
    S = sfx()
    for name, x in S.items():
        x = np.asarray(x, dtype=float)
        x = np.concatenate([x, np.zeros(int(0.02 * SR))])
        write_wav(f"{OUT}/sfx/{name}.wav", x, 0.8)
    print(len(S), "sounds:", ", ".join(S))
