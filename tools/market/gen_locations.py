"""Pixel-art location backgrounds, 320x180 (x4 = 1280x720), same style as tavern.png.
forest.png  - morning forest glade with a path; resources lie on the grass (spots in game_data.gd).
graveyard.png - abandoned hill graveyard at dusk, moon, crypt, tombstones and fog.
Usage: python gen_locations.py <out_dir>
In game the top bar covers rows ~0..11 and the bottom bar rows ~165..180.
"""
import math
import random
import sys
import numpy as np
from PIL import Image

W, H = 320, 180
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16
YY, XX = np.mgrid[0:H, 0:W]


def hx(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


class Canvas:
    def __init__(self, seed):
        self.img = np.zeros((H, W, 3), dtype=np.float32)
        self.rng = random.Random(seed)

    def c(self, col):
        return hx(col) if isinstance(col, str) else col

    def rect(self, x0, y0, x1, y1, col):
        x0, x1 = max(0, int(x0)), min(W, int(x1))
        y0, y1 = max(0, int(y0)), min(H, int(y1))
        if x0 < x1 and y0 < y1:
            self.img[y0:y1, x0:x1] = self.c(col)

    def px(self, x, y, col):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.img[y, x] = self.c(col)

    def hline(self, x0, x1, y, col):
        self.rect(x0, y, x1, y + 1, col)

    def vline(self, x, y0, y1, col):
        self.rect(x, y0, x + 1, y1, col)

    def ellipse(self, cx, cy, rx, ry, col):
        m = ((XX - cx) / max(rx, 0.5)) ** 2 + ((YY - cy) / max(ry, 0.5)) ** 2 <= 1.0
        self.img[m] = self.c(col)

    def mask(self, m, col):
        self.img[m] = self.c(col)

    def gradient(self, y0, y1, top, bottom, steps=8):
        """Vertical gradient with ordered dithering, quantized to `steps` bands."""
        a, b = self.c(top), self.c(bottom)
        for y in range(max(0, y0), min(H, y1)):
            t = (y - y0) / max(1, (y1 - y0 - 1))
            for x in range(W):
                q = math.floor(t * steps + BAYER[y % 4, x % 4]) / steps
                q = min(1.0, max(0.0, q))
                self.img[y, x] = a + (b - a) * q

    def light(self, field, strength=0.35, steps=6):
        """Multiply by a dithered light field (0..1 -> dark..bright)."""
        q = np.floor(field * steps + BAYER[YY % 4, XX % 4]) / steps
        q = np.clip(q, 0, 1)
        self.img *= (1 - strength + strength * 2 * q)[..., None]

    def save(self, path):
        Image.fromarray(np.clip(self.img, 0, 255).astype(np.uint8)).save(path)


# ====================================================================== FOREST
def forest(path):
    cv = Canvas(11)
    rng = cv.rng
    GROUND = 100
    # sky behind the canopy: pale morning light
    cv.gradient(0, GROUND, "c9dca0", "7fa66a", 7)
    # far tree line (misty)
    for layer, (col, base, hmin, hmax, step) in enumerate([
            ("8fb47c", GROUND, 30, 55, 9), ("6f9a62", GROUND, 22, 46, 12), ("557f4e", GROUND + 2, 14, 34, 16)]):
        x = -rng.randrange(0, 8)
        while x < W + 10:
            h = rng.randrange(hmin, hmax)
            w = rng.randrange(step, step + 8)
            # conifer-ish silhouette
            for yy in range(h):
                half = int((yy / h) * w / 2) + 1
                cv.hline(x - half, x + half, base - h + yy, col)
            x += step + rng.randrange(0, 6)
    # mid trunks
    TRUNK = ["4a3524", "543c28", "3f2d1e"]
    for tx in [38, 92, 150, 214, 262, 300]:
        w = rng.randrange(6, 10)
        top = 0
        bot = GROUND + rng.randrange(2, 6)
        cv.rect(tx, top, tx + w, bot, TRUNK[rng.randrange(3)])
        cv.vline(tx, top, bot, "2e2116")
        cv.vline(tx + w - 2, top, bot, "6a503a")
        for _ in range(10):
            yy = rng.randrange(top, bot)
            cv.hline(tx + 1, tx + rng.randrange(2, w - 1), yy, "35261a")
        # roots
        cv.rect(tx - 2, bot - 2, tx + w + 2, bot, TRUNK[0])
    # canopy across the top
    LEAF = ["2f5a2e", "386a35", "437a3c", "264b27", "4f8a45"]
    for _ in range(120):
        cx, cy = rng.randrange(-10, W + 10), rng.randrange(-8, 34)
        cv.ellipse(cx, cy, rng.randrange(8, 20), rng.randrange(5, 11), LEAF[rng.randrange(4)])
    for _ in range(260):
        cx, cy = rng.randrange(0, W), rng.randrange(0, 40)
        cv.ellipse(cx, cy, rng.randrange(1, 4), rng.randrange(1, 3), LEAF[rng.choice([2, 4])])
    # ground
    cv.gradient(GROUND, H, "5f8c3c", "34552a", 6)
    # dirt path from bottom centre to the back
    for y in range(GROUND, H):
        t = (y - GROUND) / (H - GROUND)
        cx = 168 + 24 * math.sin(t * 2.6 + 0.4) - 10 * t
        hw = 6 + 46 * t ** 1.3
        x0, x1 = int(cx - hw), int(cx + hw)
        for x in range(max(0, x0), min(W, x1)):
            k = 0.5 + 0.5 * math.sin(x * 0.7 + y * 1.3)
            base = hx("8a6a44") if (x + y) % 7 else hx("7a5c3a")
            cv.img[y, x] = base * (0.92 + 0.08 * k) * (0.85 + 0.25 * t)
        # path edge pebbles
        if rng.random() < 0.5:
            cv.px(x0, y, "6e5236"); cv.px(x1 - 1, y, "6e5236")
    for _ in range(70):
        y = rng.randrange(GROUND + 6, H)
        cv.px(rng.randrange(120, 240), y, "a08458")
    # grass tufts
    for _ in range(900):
        x, y = rng.randrange(0, W), rng.randrange(GROUND, H)
        col = cv.img[y, x]
        if col[0] > 110 and col[1] < 120:  # skip the path
            continue
        h = 1 + int((y - GROUND) / 18) + rng.randrange(0, 2)
        g = rng.choice(["79a84a", "4c7a33", "8cbc58", "3e6a2c"])
        cv.vline(x, y - h, y, g)
    # light rays from the canopy
    ray = np.zeros((H, W), dtype=np.float32)
    for rx in [60, 130, 205, 255]:
        d = np.abs((XX - rx) - (YY * 0.45))
        ray += np.clip(1 - d / 10, 0, 1) * np.clip((YY - 20) / 60, 0, 1) * np.clip((140 - YY) / 60, 0, 1)
    q = np.floor(np.clip(ray, 0, 1) * 3 + BAYER[YY % 4, XX % 4]) / 3
    cv.img += (q * 26)[..., None] * np.array([1.0, 1.0, 0.7])
    # bushes (sides)
    BUSH = ["2c5527", "376833", "264a22"]
    for bx, by, r in [(14, 120, 18), (44, 128, 14), (300, 118, 20), (276, 130, 13), (96, 108, 10), (236, 108, 11)]:
        for _ in range(16):
            cv.ellipse(bx + rng.randrange(-r, r), by + rng.randrange(-r // 2, r // 3), rng.randrange(r // 3, r // 2 + 2), rng.randrange(r // 4, r // 3 + 2), BUSH[rng.randrange(3)])
        for _ in range(12):
            cv.px(bx + rng.randrange(-r, r), by + rng.randrange(-r // 2, r // 3), "4f8a45")
        if rng.random() < 0.6:
            for _ in range(4):
                cv.px(bx + rng.randrange(-r + 2, r - 2), by + rng.randrange(-r // 3, r // 4), "a23a4a")
    # fallen log (back right)
    cv.rect(238, 112, 286, 119, "5a4029"); cv.hline(238, 286, 112, "735438"); cv.hline(238, 286, 118, "3a2a1b")
    cv.ellipse(286, 115, 3, 4, "8a6a48"); cv.ellipse(286, 115, 1.5, 2, "6a4e34")
    for x in range(242, 284, 7):
        cv.px(x, 114, "4a3322")
    cv.px(250, 111, "c84a3a"); cv.px(251, 111, "c84a3a"); cv.px(250, 112, "e8e0d0")  # tiny mushroom
    # rocks
    for rx, ry, r in [(70, 150, 7), (112, 118, 4), (258, 156, 8), (204, 128, 3)]:
        cv.ellipse(rx, ry, r, r * 0.6, "6e6e64"); cv.ellipse(rx - 1, ry - 1, r * 0.6, r * 0.35, "8a8a7e")
        cv.hline(rx - r + 1, rx + r - 1, int(ry + r * 0.6), "3a4a2a")
    # mushrooms near the left trunk
    for mx, my in [(30, 140), (35, 142), (238, 140)]:
        cv.rect(mx, my - 2, mx + 1, my + 1, "e8dcc0")
        cv.hline(mx - 2, mx + 3, my - 3, "b8402e"); cv.hline(mx - 1, mx + 2, my - 4, "c85a3e"); cv.px(mx - 1, my - 3, "f0e0d0")
    # foreground trunks at the edges
    for tx, w in [(-6, 18), (306, 20)]:
        cv.rect(tx, 0, tx + w, H, "3a2a1b")
        cv.vline(tx + w - 1 if tx < 0 else tx, 0, H, "584030")
        for _ in range(40):
            yy = rng.randrange(0, H)
            cv.hline(tx + 2, tx + w - 2, yy, "2c2015")
    # ferns in the corners
    for fx, fy, s in [(22, 170, 1), (60, 176, 1), (298, 172, -1), (262, 178, -1)]:
        for i in range(6):
            ang = -2.6 + i * 0.35
            for t in range(14):
                x = fx + s * int(math.cos(ang) * t * 1.2)
                y = fy + int(math.sin(ang) * t * 0.9) + t * t // 40
                cv.px(x, y, "3f7a34" if t % 3 else "5c9a44")
    # vignette
    v = 1 - 0.35 * np.clip(((XX - W / 2) / (W / 2)) ** 2 + ((YY - H * 0.55) / (H * 0.7)) ** 2 - 0.25, 0, 1)
    cv.img *= v[..., None]
    cv.save(path)


# =================================================================== GRAVEYARD
def graveyard(path):
    cv = Canvas(23)
    rng = cv.rng
    GROUND = 98
    cv.gradient(0, GROUND, "2a2140", "8a6a7a", 8)
    # stars
    for _ in range(50):
        x, y = rng.randrange(0, W), rng.randrange(0, 60)
        cv.px(x, y, rng.choice(["c8c0e0", "9a92b8", "e8e4f0"]))
    # moon
    cv.ellipse(252, 30, 13, 13, "e8e2c8"); cv.ellipse(256, 26, 4, 3, "d0c8aa"); cv.ellipse(246, 34, 3, 2, "d0c8aa")
    glow = np.clip(1 - np.hypot(XX - 252, YY - 30) / 40, 0, 1) * (np.hypot(XX - 252, YY - 30) > 13)
    cv.img += (np.floor(glow * 3 + BAYER[YY % 4, XX % 4]) / 3 * 18)[..., None]
    # distant hills
    for col, base, amp, fr, ph in [("3a3150", 70, 10, 0.02, 0.3), ("2c2640", 84, 8, 0.035, 2.0)]:
        for x in range(W):
            h = int(base - amp * math.sin(x * fr + ph) - amp * 0.4 * math.sin(x * fr * 3.1))
            cv.vline(x, h, GROUND, col)
    # crypt on the hill (centre-left)
    CX = 110
    cv.rect(CX - 22, 58, CX + 22, GROUND, "3e3a4a")
    for y in range(58, GROUND, 5):
        cv.hline(CX - 22, CX + 22, y, "2e2a38")
        off = 0 if (y // 5) % 2 else 5
        for x in range(CX - 22 + off, CX + 22, 10):
            cv.vline(x, y, y + 5, "2e2a38")
    for i in range(14):  # roof
        cv.hline(CX - 26 + i * 2, CX + 26 - i * 2, 57 - i, "2a2636" if i % 3 else "35303f")
    cv.rect(CX - 2, 32, CX + 1, 44, "4a4658"); cv.rect(CX - 5, 35, CX + 4, 37, "4a4658")  # cross
    cv.rect(CX - 7, 72, CX + 7, GROUND, "15121c"); cv.ellipse(CX, 72, 7, 5, "15121c")  # door
    cv.vline(CX, 70, GROUND, "26222e")
    cv.rect(CX - 18, 66, CX - 13, 74, "e0b860"); cv.rect(CX + 13, 66, CX + 18, 74, "6a5a3a")  # windows (one lit)
    # dead tree (right)
    def branch(x, y, ang, length, w):
        for t in range(length):
            xx = x + math.cos(ang) * t
            yy = y - math.sin(ang) * t
            cv.rect(xx, yy, xx + max(1, w), yy + 1, "1c1824")
        if length > 5:
            ex, ey = x + math.cos(ang) * length, y - math.sin(ang) * length
            branch(ex, ey, ang + rng.uniform(0.3, 0.7), int(length * 0.65), w - 1)
            branch(ex, ey, ang - rng.uniform(0.3, 0.7), int(length * 0.6), w - 1)
    cv.rect(272, 60, 279, 112, "1c1824")
    branch(275, 64, 1.9, 22, 4); branch(276, 70, 0.8, 20, 3); branch(274, 80, 2.5, 14, 2)
    # ground
    cv.gradient(GROUND, H, "3a4a36", "1e281e", 6)
    for _ in range(700):
        x, y = rng.randrange(0, W), rng.randrange(GROUND, H)
        h = 1 + int((y - GROUND) / 22) + rng.randrange(0, 2)
        cv.vline(x, y - h, y, rng.choice(["4a5c42", "2c3a2a", "56684a", "263224"]))
    # path to the crypt
    for y in range(GROUND, H):
        t = (y - GROUND) / (H - GROUND)
        cx = CX + 30 * t ** 1.5 + 6 * math.sin(t * 5)
        hw = 7 + 30 * t
        for x in range(max(0, int(cx - hw)), min(W, int(cx + hw))):
            cv.img[y, x] = hx("4e4650") * (0.85 + 0.2 * t) * (0.94 if (x * 3 + y) % 5 else 0.82)
    # iron fence along the back
    for x in range(0, W, 6):
        if CX - 30 < x < CX + 30:
            continue
        cv.vline(x, 88, 102, "14111a"); cv.px(x, 87, "2a2632")
    cv.hline(0, CX - 30, 91, "14111a"); cv.hline(CX + 30, W, 91, "14111a")
    cv.hline(0, CX - 30, 99, "14111a"); cv.hline(CX + 30, W, 99, "14111a")

    STONE, STONE_HI, STONE_LO = "6a6676", "8a8698", "45424f"

    def tomb(x, y, w, h, kind):
        if kind == "round":
            cv.rect(x, y - h + w // 2, x + w, y, STONE); cv.ellipse(x + w / 2 - 0.5, y - h + w // 2, w / 2, w / 2, STONE)
            cv.vline(x, y - h + w // 2, y, STONE_HI)
        elif kind == "cross":
            cv.rect(x + w // 2 - 1, y - h, x + w // 2 + 2, y, STONE); cv.rect(x, y - h + 3, x + w, y - h + 6, STONE)
            cv.vline(x + w // 2 - 1, y - h, y, STONE_HI)
        else:  # slab with pointed top, leaning
            for i in range(h):
                lean = i // 6
                cv.hline(x + lean, x + w + lean, y - i, STONE if i < h - 2 else STONE_HI)
            cv.vline(x, y - h, y, STONE_HI)
        cv.hline(x - 1, x + w + 1, y, STONE_LO); cv.hline(x - 2, x + w + 2, y + 1, "1e1a24")
        # moss and cracks
        for _ in range(3):
            cv.px(x + rng.randrange(0, w), y - rng.randrange(1, 4), "4a6a44")
        if kind != "cross" and rng.random() < 0.7:
            cx = x + rng.randrange(1, w - 1)
            for k in range(rng.randrange(2, 5)):
                cv.px(cx + (k % 2), y - h + 4 + k, STONE_LO)
        # engraving
        if kind == "round" and w >= 9:
            cv.hline(x + 2, x + w - 2, y - h + w // 2 + 2, STONE_LO); cv.hline(x + 3, x + w - 3, y - h + w // 2 + 4, STONE_LO)

    for x, y, w, h, k in [(18, 112, 10, 15, "round"), (52, 108, 9, 16, "cross"), (182, 110, 10, 14, "round"),
                          (214, 106, 8, 15, "cross"), (238, 116, 12, 13, "slab"), (300, 112, 10, 16, "round"),
                          (8, 150, 14, 20, "round"), (70, 136, 12, 18, "slab"), (224, 146, 13, 20, "cross"),
                          (292, 158, 14, 22, "round"), (150, 122, 9, 12, "round")]:
        tomb(x, y, w, h, k)
    # open grave mound
    cv.ellipse(176, 160, 18, 5, "3a3028"); cv.ellipse(176, 159, 14, 3, "4a3e32"); cv.ellipse(176, 160, 9, 2.5, "15121a")
    # candles at a grave
    for cx_ in [232, 238]:
        cv.rect(cx_, 143, cx_ + 2, 147, "d8d0b8"); cv.px(cx_, 142, "ffd070"); cv.px(cx_ + 1, 141, "ffb040")
    # fog bands
    fog = np.zeros((H, W), dtype=np.float32)
    for fy, amp, fr in [(104, 4, 0.05), (128, 5, 0.03), (152, 4, 0.045)]:
        center = fy + amp * np.sin(XX * fr + fy)
        fog += np.clip(1 - np.abs(YY - center) / 7, 0, 1) * (0.5 + 0.5 * np.sin(XX * fr * 2.3 + fy))
    q = np.floor(np.clip(fog, 0, 1) * 3 + BAYER[YY % 4, XX % 4]) / 3
    fogcol = hx("a8a8c8")
    a = (q * 0.35)[..., None]
    cv.img = cv.img * (1 - a) + fogcol * a
    # moonlight from the right, vignette
    v = 1 - 0.4 * np.clip(((XX - W * 0.6) / (W / 2)) ** 2 + ((YY - H * 0.45) / (H * 0.7)) ** 2 - 0.2, 0, 1)
    cv.img *= v[..., None]
    cv.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    forest(f"{out}/forest.png")
    graveyard(f"{out}/graveyard.png")
    print("ok")
