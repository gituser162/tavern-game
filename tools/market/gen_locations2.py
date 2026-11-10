"""Pixel-art backgrounds 320x180 for the swamp, the lake and the port (same style and helpers as gen_locations.py).
swamp.png - a rotten bog at dusk: water, mossy hummocks (the resource spots), dead trees with hanging moss, fog.
lake.png  - a calm lake on a bright day: hills across the water, a sandy shore, reeds, a wooden pier with a rod.
port.png  - a river harbour at sunset: a moored merchant ship, a quay with crates, the foreign merchant's stall (left)
            and the smuggler in the shadow of the warehouse (right).
Spots / clickable places must match GameData.LOCATIONS (spots, fishing, people).
Usage: python gen_locations2.py <out_dir>
"""
import math
import sys
import numpy as np

from gen_locations import Canvas, W, H, BAYER, XX, YY, hx


def dither_add(cv, field, amount, col=(1.0, 1.0, 1.0), steps=3):
    q = np.floor(np.clip(field, 0, 1) * steps + BAYER[YY % 4, XX % 4]) / steps
    cv.img += (q * amount)[..., None] * np.array(col)


def vignette(cv, cx=0.5, cy=0.55, k=0.35):
    v = 1 - k * np.clip(((XX - W * cx) / (W / 2)) ** 2 + ((YY - H * cy) / (H * 0.7)) ** 2 - 0.25, 0, 1)
    cv.img *= v[..., None]


def person(cv, cx, feet, body, dark, skin="d8a880", head_col=None, hat=None, w=8, h=26):
    """Simple standing figure, feet at y=feet. body/dark: cloak colours. hat: (colour, kind)."""
    top = feet - h
    # cloak / robe (trapezoid)
    for y in range(top + 7, feet):
        t = (y - top - 7) / max(1, h - 7)
        half = int(w / 2 - 1 + t * 2)
        cv.hline(cx - half, cx + half + 1, y, body)
        cv.px(cx + half, y, dark); cv.px(cx - half, y, dark)
    cv.vline(cx, top + 12, feet, dark)
    # arms
    cv.rect(cx - w // 2 - 1, top + 9, cx - w // 2 + 1, top + 17, dark)
    cv.rect(cx + w // 2, top + 9, cx + w // 2 + 2, top + 17, dark)
    # head
    cv.rect(cx - 2, top + 2, cx + 3, top + 7, skin)
    cv.px(cx - 1, top + 4, "2a1a10"); cv.px(cx + 1, top + 4, "2a1a10")
    if head_col:
        cv.rect(cx - 3, top, cx + 4, top + 3, head_col)
    if hat:
        col, kind = hat
        if kind == "turban":
            cv.rect(cx - 3, top - 2, cx + 4, top + 2, col); cv.px(cx, top - 3, col); cv.px(cx + 1, top - 2, "f0d060")
        elif kind == "hood":
            cv.rect(cx - 3, top, cx + 4, top + 8, col); cv.rect(cx - 2, top + 3, cx + 3, top + 7, "120c10")
            cv.px(cx - 1, top + 5, "c8c070"); cv.px(cx + 1, top + 5, "c8c070")   # eyes in the hood
    cv.hline(cx - 3, cx + 4, feet, "1a120c")


# ======================================================================== SWAMP
SWAMP_SPOTS = [[30, 132], [52, 150], [78, 126], [96, 158], [130, 140], [150, 160], [176, 128], [204, 154],
               [230, 136], [262, 150], [288, 130], [118, 118], [244, 162], [22, 158]]


def swamp(path):
    cv = Canvas(31)
    rng = cv.rng
    GROUND = 92
    cv.gradient(0, GROUND, "2e3a3c", "8a9a76", 8)
    # sick moon behind haze
    cv.ellipse(70, 30, 9, 9, "c8d0a0"); cv.ellipse(73, 28, 3, 2, "b0b888")
    glow = np.clip(1 - np.hypot(XX - 70, YY - 30) / 34, 0, 1) * (np.hypot(XX - 70, YY - 30) > 9)
    dither_add(cv, glow, 14, (0.9, 1.0, 0.8))
    # far dead forest silhouettes
    for col, base, step, hmin, hmax in [("4a5a50", GROUND, 7, 18, 34), ("3a4840", GROUND + 1, 10, 12, 26)]:
        x = -3
        while x < W + 5:
            h = rng.randrange(hmin, hmax)
            cv.vline(x, base - h, base, col)
            cv.vline(x + 1, base - h + 2, base, col)
            for b in range(rng.randrange(1, 4)):
                by = base - h + rng.randrange(2, h // 2 + 3)
                ln = rng.randrange(2, 6)
                s = rng.choice([-1, 1])
                for t in range(ln):
                    cv.px(x + s * t, by - t // 2, col)
            x += step + rng.randrange(0, 6)
    # water everywhere below the horizon
    cv.gradient(GROUND, H, "3a4c40", "16221c", 6)
    # reflections of the sky / moon
    for _ in range(90):
        y = rng.randrange(GROUND + 2, H)
        x = rng.randrange(0, W)
        ln = rng.randrange(3, 12)
        cv.hline(x, x + ln, y, "4e6452" if y < 130 else "2c3e32")
    for y in range(GROUND + 3, 116, 4):
        w = max(2, 7 - (y - GROUND) // 5)
        cv.hline(70 - w + rng.randrange(-2, 2), 70 + w + rng.randrange(-2, 2), y, "6a7a5c")
    # duckweed patches on the water
    for _ in range(40):
        cx, cy = rng.randrange(0, W), rng.randrange(GROUND + 6, H)
        for _ in range(8):
            cv.px(cx + rng.randrange(-6, 6), cy + rng.randrange(-2, 2), rng.choice(["5a7a3a", "4a6a30", "6a8a40"]))
    # lily pads
    for lx, ly in [(110, 104), (160, 112), (196, 140), (60, 110), (300, 112), (176, 172), (70, 172)]:
        cv.ellipse(lx, ly, 4, 1.6, "4a7a34"); cv.px(lx + 2, ly, "2c3e32"); cv.px(lx - 2, ly - 1, "6a9a48")
    # hummocks (dry land: the resources lie on them)
    MOSS = ["5a6a34", "6a7a3c", "4a5a2c", "7a8a44"]
    for sx, sy in SWAMP_SPOTS:
        rx = 13 + rng.randrange(-1, 3)
        ry = 4.2 + (sy - GROUND) / 40
        cv.ellipse(sx, sy + 1, rx + 1, ry + 1.2, "1c2a20")            # wet dark rim
        cv.ellipse(sx, sy, rx, ry, "4a5a2e")
        cv.ellipse(sx - 2, sy - 1, rx * 0.7, ry * 0.6, "5e6e38")
        for _ in range(int(rx * 2.5)):
            x = sx + rng.randrange(-rx + 2, rx - 1)
            y = sy + rng.randrange(-int(ry) + 1, int(ry))
            cv.vline(x, y - rng.randrange(1, 4), y + 1, MOSS[rng.randrange(4)])
    # boardwalk planks across the bog (rotten)
    for k in range(9):
        x0 = 96 + k * 13
        y0 = 132 + int(6 * math.sin(k * 0.8))
        if k == 5:
            continue  # a missing plank
        cv.rect(x0, y0, x0 + 10, y0 + 3, "5a4630"); cv.hline(x0, x0 + 10, y0, "7a6040"); cv.hline(x0, x0 + 10, y0 + 3, "2a2016")
        cv.vline(x0 + 1, y0 + 3, y0 + 7, "2a2016")
    # cattails and reeds
    for _ in range(60):
        x = rng.randrange(0, W)
        y = rng.randrange(GROUND + 4, H)
        h = 6 + int((y - GROUND) / 8) + rng.randrange(0, 5)
        cv.vline(x, y - h, y, rng.choice(["5a6a34", "4a5a2c", "6a7a40"]))
        if rng.random() < 0.4:
            cv.rect(x, y - h, x + 2, y - h + 3 + h // 8, "5a3a22")
            cv.px(x, y - h - 1, "6a7a40")
    # twisted dead trees with hanging moss (left and right)
    def tree(tx, base, height, lean):
        for y in range(base - height, base):
            t = (base - y) / height
            x = tx + int(lean * t * t * 14)
            wdt = max(2, int(7 * (1 - t) + 2))
            cv.rect(x - wdt // 2, y, x + wdt // 2 + 1, y + 1, "2a2a22")
            cv.px(x - wdt // 2, y, "3a3a2e")
        cv.rect(tx - 7, base - 2, tx + 8, base + 1, "2a2a22")
        top_x = tx + int(lean * 14)
        for ang, ln in [(2.4, 22), (0.6, 24), (1.7, 14), (2.9, 16), (0.2, 16)]:
            for t in range(ln):
                x = top_x + math.cos(ang) * t
                y = base - height + 6 - math.sin(ang) * t * 0.6 + (t * t) / 60
                cv.rect(x, y, x + 2 - t // 12, y + 1, "2a2a22")
                if t % 4 == 2:   # hanging moss strands
                    ln2 = rng.randrange(3, 10)
                    for k in range(ln2):
                        cv.px(x + (k % 3 == 2), y + 1 + k, rng.choice(["5a6a4a", "6a7a56", "4a5a3e"]))
    tree(18, 118, 112, 0.6)
    tree(298, 114, 106, -0.7)
    tree(214, 100, 64, 0.3)
    # bones of an old boat sticking out of the water
    for k in range(5):
        x = 150 + k * 4
        cv.vline(x, 98 - (2 - abs(k - 2)) * 2, 104, "3a3226")
    cv.hline(148, 168, 104, "2a2418")
    # low fog bands
    fog = np.zeros((H, W), dtype=np.float32)
    for fy, amp, fr in [(100, 3, 0.04), (124, 5, 0.03), (150, 4, 0.05)]:
        center = fy + amp * np.sin(XX * fr + fy)
        fog += np.clip(1 - np.abs(YY - center) / 6, 0, 1) * (0.5 + 0.5 * np.sin(XX * fr * 1.9 + fy))
    q = np.floor(np.clip(fog, 0, 1) * 3 + BAYER[YY % 4, XX % 4]) / 3
    a = (q * 0.3)[..., None]
    cv.img = cv.img * (1 - a) + hx("9aac94") * a
    # a few fireflies / marsh lights
    for x, y in [(52, 104), (182, 98), (262, 120), (140, 152), (90, 140)]:
        cv.px(x, y, "c8f080"); cv.px(x + 1, y, "88b060")
    vignette(cv, 0.5, 0.5, 0.45)
    cv.save(path)


# ========================================================================= LAKE
LAKE_SPOTS = [[24, 150], [48, 158], [70, 146], [96, 160], [118, 152], [142, 158], [166, 148], [36, 140],
              [300, 156], [278, 150], [128, 144]]
FISHING_SPOT = (222, 118)


def lake(path):
    cv = Canvas(47)
    rng = cv.rng
    HORIZON = 72
    cv.gradient(0, HORIZON, "6aa8d8", "c8e4f0", 7)
    # clouds
    for cx, cy, s in [(60, 18, 1.0), (180, 28, 1.3), (276, 14, 0.9), (120, 40, 0.7)]:
        for k in range(6):
            cv.ellipse(cx + (k - 2.5) * 7 * s, cy + (k % 2) * 2, 8 * s, 4 * s, "eef6fa")
        cv.hline(int(cx - 20 * s), int(cx + 20 * s), int(cy + 4 * s), "d0e2ec")
    # far hills and forest across the lake
    for col, base, amp, fr, ph in [("7aa0a8", 62, 8, 0.025, 0.5), ("5a8a6a", 70, 6, 0.04, 1.7)]:
        for x in range(W):
            h = int(base - amp * math.sin(x * fr + ph) - amp * 0.5 * math.sin(x * fr * 2.7))
            cv.vline(x, h, HORIZON + 4, col)
    for x in range(-4, W + 4, 5):  # tree line: round crowns
        h = rng.randrange(3, 7)
        cv.ellipse(x, HORIZON - h + 3, 4 + rng.randrange(0, 2), h, rng.choice(["3e6a48", "4a7a52", "365e40"]))
    cv.rect(0, HORIZON, W, HORIZON + 3, "365e40")
    # water
    cv.gradient(HORIZON + 3, 140, "6aa0c0", "2e6a8a", 6)
    for _ in range(140):
        y = rng.randrange(HORIZON + 4, 138)
        x = rng.randrange(0, W)
        ln = rng.randrange(2, 4 + (y - HORIZON) // 6)
        cv.hline(x, x + ln, y, "a8d0e0" if rng.random() < 0.6 else "4a86a8")
    # reflection of the far forest
    for x in range(0, W, 2):
        cv.vline(x, HORIZON + 3, HORIZON + 3 + rng.randrange(2, 6), "4a7a6a")
    # shore: sand then grass (shore line ~ y 132)
    shore = [int(132 + 3 * math.sin(x * 0.05) + 2 * math.sin(x * 0.13)) for x in range(W)]
    for x in range(W):
        y0 = shore[x]
        for y in range(y0, H):
            t = (y - y0) / max(1, H - y0)
            if y < y0 + 3:
                col = hx("d8c890")                       # wet sand edge
            elif y < y0 + 8 + 2 * math.sin(x * 0.3):
                col = hx("e0d0a0") * (0.95 if (x + y) % 5 else 0.85)
            else:
                col = hx("6a9a44") * (1.0 - 0.3 * t)
            cv.img[y, x] = col
        cv.px(x, y0 - 1, "c8e0e8")                       # foam
    for _ in range(600):
        x = rng.randrange(0, W)
        y = rng.randrange(shore[x] + 9, H)
        cv.vline(x, y - 1 - rng.randrange(0, 2), y, rng.choice(["7aac50", "5a8a3a", "8abc5c"]))
    for _ in range(40):  # pebbles
        x = rng.randrange(0, W)
        cv.px(x, shore[x] + rng.randrange(3, 8), rng.choice(["a89a78", "8a8070"]))
    # reeds on the left in the shallow water
    for _ in range(40):
        x = rng.randrange(0, 60)
        y = shore[x] + rng.randrange(-4, 2)
        h = rng.randrange(8, 20)
        cv.vline(x, y - h, y, rng.choice(["5a8a3a", "4a7a30", "6a9a44"]))
        if rng.random() < 0.3:
            cv.rect(x, y - h, x + 2, y - h + 4, "6a4a2a")
    # pier from the bottom up into the lake (perspective: wider at the bottom)
    PX = 222
    for y in range(112, H):
        t = (y - 112) / (H - 112)
        half = int(12 + 16 * t)
        for x in range(PX - half, PX + half):
            plank = (y - 112) // (2 + int(3 * t))
            base = hx("8a6a44") if plank % 2 else hx("7a5c3a")
            cv.img[y, x] = base * (0.9 + 0.1 * math.sin(x * 1.3))
        cv.px(PX - half, y, "4a3420"); cv.px(PX + half - 1, y, "4a3420")
    cv.hline(PX - 12, PX + 12, 112, "a08058")
    for side in (-1, 1):  # posts in the water
        for k, (py, ph) in enumerate([(114, 8), (126, 10)]):
            x = PX + side * (13 + k * 3)
            cv.rect(x, py, x + 2, py + ph, "4a3420"); cv.px(x, py, "6a4a2a")
    # rowboat tied at the pier
    cv.ellipse(184, 122, 14, 3.5, "6a4428"); cv.ellipse(184, 121, 12, 2, "8a5e36"); cv.hline(174, 194, 121, "4a3018")
    cv.hline(193, PX - 12, 118, "c8b088")  # rope
    # rod leaning on a post at the end of the pier, bucket
    for t in range(30):
        cv.px(PX + 6 + t * 0.6, 112 - t, "5a3a20")
    for t in range(18):   # line
        cv.px(PX + 24 + t * 0.2, 83 + t * 2, "e8e8e0")
    cv.rect(PX - 9, 106, PX - 3, 112, "6a7a8a"); cv.hline(PX - 9, PX - 3, 106, "9aaab8")   # bucket
    # ripples near the pier end (fish!)
    for rx, ry in [(236, 100), (206, 96), (150, 104)]:
        cv.hline(rx - 3, rx + 4, ry, "c8e4f0"); cv.px(rx - 4, ry + 1, "c8e4f0"); cv.px(rx + 4, ry + 1, "c8e4f0")
    # sun glints
    glint = np.clip(1 - np.abs(XX - 160) / 60, 0, 1) * ((YY > HORIZON + 4) & (YY < 128))
    dither_add(cv, glint * (np.sin(XX * 1.7 + YY * 3.1) > 0.85), 40, (1.0, 1.0, 0.9), 2)
    vignette(cv, 0.5, 0.55, 0.3)
    cv.save(path)


# ========================================================================= PORT
def port(path):
    cv = Canvas(59)
    rng = cv.rng
    HORIZON = 70
    cv.gradient(0, HORIZON, "4a3a6a", "f0a060", 9)
    # sun setting at the horizon
    cv.ellipse(60, HORIZON - 2, 12, 12, "ffd890")
    glow = np.clip(1 - np.hypot(XX - 60, YY - HORIZON) / 60, 0, 1) * (YY < HORIZON)
    dither_add(cv, glow, 30, (1.0, 0.8, 0.5))
    # far coast and a distant ship
    for x in range(W):
        h = int(HORIZON - 4 - 3 * math.sin(x * 0.04 + 1) - 2 * math.sin(x * 0.11))
        if x > 150:
            cv.vline(x, h, HORIZON, "5a3a4a")
    # a distant ship sitting on the horizon (drawn after the sea, see below)
    # sea
    cv.gradient(HORIZON, 116, "c88a6a", "3a4a6a", 6)
    for _ in range(120):
        y = rng.randrange(HORIZON + 2, 114)
        x = rng.randrange(0, W)
        cv.hline(x, x + rng.randrange(2, 8), y, "f0c090" if abs(x - 60) < 30 and rng.random() < 0.7 else "5a6a8a")
    for y in range(HORIZON - 2, HORIZON + 2):          # distant ship: hull on the water line, mast, sail
        cv.hline(29 + (y - HORIZON + 2), 41 - (y - HORIZON + 2), y, "3a2a3a")
    cv.vline(35, HORIZON - 14, HORIZON - 2, "3a2a3a"); cv.rect(31, HORIZON - 12, 39, HORIZON - 5, "6a4a5a")
    cv.hline(28, 43, HORIZON + 2, "8a6a6a")               # its little reflection
    # the merchant ship (centre right): hull, masts, sails, flags
    HX0, HX1, HY = 128, 250, 104
    for y in range(80, HY):
        t = (y - 80) / (HY - 80)
        inset = int(t * t * 14)
        cv.hline(HX0 + inset, HX1 - inset + 6, y, "5a3a22" if (y // 4) % 2 else "4a2e1a")
    cv.hline(HX0, HX1 + 6, 80, "8a6a40"); cv.hline(HX0, HX1 + 6, 86, "c8a050")
    for wx in range(HX0 + 14, HX1 - 6, 14):   # portholes
        cv.rect(wx, 90, wx + 3, 93, "f0c070")
    cv.rect(HX1 - 10, 66, HX1 + 8, 80, "4a2e1a"); cv.hline(HX1 - 10, HX1 + 8, 66, "8a6a40")   # stern castle
    cv.rect(HX1 - 6, 70, HX1 - 2, 74, "f0c070")
    for mx, top, sw in [(160, 14, 26), (200, 20, 22), (234, 30, 16)]:
        cv.rect(mx, top, mx + 2, 80, "3a2416")
        for k, (y0, y1) in enumerate([(top + 6, top + 26), (top + 30, top + 52)]):
            if y1 > 78:
                continue
            for y in range(y0, y1):
                t = (y - y0) / (y1 - y0)
                half = int(sw / 2 * (0.8 + 0.25 * math.sin(t * math.pi)))
                for x in range(mx + 1 - half, mx + 1 + half):
                    stripe = ((x - mx) // 5) % 2 == 0 and k == 0 and mx == 160
                    cv.img[y, x] = hx("c84a3a" if stripe else "e8dcc0") * (0.85 + 0.15 * (1 - t))
            cv.hline(mx + 1 - sw // 2, mx + 1 + sw // 2, y0, "3a2416")
        cv.rect(mx + 2, top, mx + 9, top + 3, "e0b040")   # flag
    # quay: wooden planks in the foreground
    QY = 114
    cv.gradient(QY, H, "8a6a44", "4a3420", 5)
    for y in range(QY, H, 4):
        cv.hline(0, W, y, "3a2816")
    for y in range(QY, H, 4):
        off = 0 if (y // 4) % 2 else 9
        for x in range(off, W, 18):
            cv.vline(x, y, y + 4, "3a2816")
    cv.hline(0, W, QY, "a8885a")
    for x in range(6, W, 30):   # bollards
        cv.rect(x, QY - 4, x + 4, QY + 1, "3a3030"); cv.hline(x, x + 4, QY - 4, "5a5050")
    cv.hline(130, 170, QY - 2, "c8b088")   # mooring rope
    # crates and barrels
    def crate(x, y, w, h):
        cv.rect(x, y - h, x + w, y, "9a7444"); cv.rect(x + 1, y - h + 1, x + w - 1, y - 1, "b08a54")
        cv.hline(x, x + w, y - h // 2, "6a4a2a")
        for t in range(min(w, h)):
            cv.px(x + t * w // max(1, min(w, h)), y - 1 - t * h // max(1, min(w, h)), "6a4a2a")
        cv.hline(x - 1, x + w + 1, y, "2a1a10")
    def barrel(x, y):
        cv.rect(x, y - 11, x + 8, y, "7a4e28"); cv.vline(x, y - 11, y, "5a3618"); cv.vline(x + 7, y - 11, y, "5a3618")
        cv.hline(x, x + 8, y - 9, "3a3030"); cv.hline(x, x + 8, y - 3, "3a3030"); cv.hline(x + 1, x + 7, y - 11, "9a6a38")
        cv.hline(x - 1, x + 9, y, "2a1a10")
    crate(150, 132, 14, 12); crate(166, 132, 12, 10); crate(156, 120, 10, 9); barrel(182, 134); barrel(192, 136)
    crate(20, 150, 16, 14); barrel(40, 152); crate(290, 170, 18, 14)
    # merchant stall (left): striped awning on posts, a table with goods, carpet
    SX0, SX1 = 72, 130
    cv.rect(SX0, 86, SX0 + 2, 138, "4a3018"); cv.rect(SX1 - 2, 86, SX1, 138, "4a3018")
    for y in range(80, 92):
        for x in range(SX0 - 3, SX1 + 3):
            cv.img[y, x] = hx("c83a3a" if ((x - SX0) // 6) % 2 == 0 else "f0e0b0") * (0.85 if y > 88 else 1.0)
    for x in range(SX0 - 3, SX1 + 3, 6):
        cv.ellipse(x + 3, 92, 3, 1.5, "c83a3a" if ((x - SX0) // 6) % 2 == 0 else "f0e0b0")
    # the foreign merchant stands BEHIND the table: drawn first, the table and the goods cover his legs
    person(cv, 101, 126, "3a6aa0", "2a4a7a", skin="a8784a", hat=("f0e8d0", "turban"))
    cv.rect(SX0 + 2, 122, SX1 - 2, 128, "6a4428"); cv.hline(SX0 + 2, SX1 - 2, 122, "8a6038")   # table
    cv.rect(SX0 + 4, 128, SX0 + 6, 138, "4a3018"); cv.rect(SX1 - 6, 128, SX1 - 4, 138, "4a3018")
    for gx, col in [(76, "e0a030"), (82, "c84a2a"), (118, "a0d0e0"), (123, "6a3a7a")]:   # goods on the table
        cv.rect(gx, 117, gx + 4, 122, col); cv.px(gx + 1, 116, col)
    cv.ellipse(122, 120, 3, 2, "c8a050")
    for x in range(SX0 + 4, SX1 - 4):   # carpet hanging from the table
        for y in range(128, 134):
            cv.img[y, x] = hx("8a2a4a" if (x + y) % 6 < 3 else "c8a050")
    # warehouse on the right with a dark arch; the smuggler in its shadow
    cv.rect(236, 70, W, QY + 40, "4a3a30")
    for y in range(70, QY + 40, 5):
        cv.hline(236, W, y, "3a2c24")
        off = 0 if (y // 5) % 2 else 6
        for x in range(236 + off, W, 12):
            cv.vline(x, y, y + 5, "3a2c24")
    for i in range(10):
        cv.hline(232 + i, W, 70 - i, "5a3426" if i % 2 else "6a3e2c")   # roof edge
    cv.rect(244, 104, 272, 150, "120c0a"); cv.ellipse(258, 104, 14, 8, "120c0a")   # arch
    cv.rect(278, 96, 284, 104, "f0b050"); cv.rect(279, 104, 283, 106, "3a2a20")    # wall lantern
    lamp = np.clip(1 - np.hypot(XX - 281, YY - 100) / 26, 0, 1)
    dither_add(cv, lamp * ((XX > 236)), 22, (1.0, 0.7, 0.3))
    person(cv, 257, 146, "2a2430", "18141c", skin="6a5040", hat=("2a2430", "hood"))   # the smuggler
    # water between the quay and the ship has a gap at the far left: small boat
    cv.ellipse(18, 110, 12, 3, "5a3a22"); cv.hline(8, 28, 109, "8a6a40")
    # gulls
    for gx, gy in [(110, 30), (122, 24), (290, 40)]:
        cv.px(gx, gy, "f0f0f0"); cv.px(gx - 1, gy - 1, "f0f0f0"); cv.px(gx + 1, gy - 1, "f0f0f0")
        cv.px(gx - 2, gy - 1, "e0e0e0"); cv.px(gx + 2, gy - 1, "e0e0e0")
    vignette(cv, 0.5, 0.5, 0.3)
    cv.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    swamp(f"{out}/swamp.png")
    lake(f"{out}/lake.png")
    port(f"{out}/port.png")
    print("ok")
