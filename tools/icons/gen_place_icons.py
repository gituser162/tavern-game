"""32x32 pixel-art icons for the swamp / lake items (same style as assets/icons/glow_mushroom.png:
dark outline around solid shapes, 2-3 tone shading, light from the top-left).
Usage: python3 gen_place_icons.py <project dir>   -> writes assets/icons/{toad,wisp_jar,lake_weed,crayfish,perch,pike}.png
"""
import math
import os
import sys
from PIL import Image

W = 32
OUT = (22, 30, 38, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Icon:
    def __init__(self):
        self.body = {}
        self.glow = []   # (cx, cy, r, colour, strength)
        self.sparks = []

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < W:
            self.body[(x, y)] = C(c) if isinstance(c, str) else c

    def ellipse(self, cx, cy, rx, ry, cols, shade=True):
        """Filled ellipse; cols = (light, mid, dark): light top-left, dark bottom-right."""
        for y in range(W):
            for x in range(W):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    if not shade:
                        self.put(x, y, cols[1])
                        continue
                    k = dx * 0.6 + dy * 0.8
                    self.put(x, y, cols[0] if k < -0.45 else cols[2] if k > 0.45 else cols[1])

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, c)

    def save(self, path):
        img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        px = img.load()
        for cx, cy, r, col, strength in self.glow:
            for y in range(W):
                for x in range(W):
                    a = max(0.0, 1 - math.hypot(x - cx, y - cy) / r) ** 2 * strength
                    if a > 5:
                        old = px[x, y]
                        px[x, y] = col[:3] + (min(255, old[3] + int(a)),)
        for (x, y) in list(self.body):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in self.body and 0 <= q[0] < W and 0 <= q[1] < W:
                    px[q] = OUT
        for (x, y), c in self.body.items():
            px[x, y] = c
        for x, y, c in self.sparks:
            px[x, y] = C(c)
        img.save(path)


def toad():
    i = Icon()
    G = (C("9ac050"), C("6a9a34"), C("4a7024"))
    i.ellipse(16, 20, 11, 7.5, G)                        # body
    i.ellipse(16, 23.5, 8, 3.2, (C("e8d878"), C("d8c060"), C("b89a40")))  # yellow belly
    for ex in (10, 22):                                    # eye bumps
        i.ellipse(ex, 13, 3.6, 3.4, G)
        i.put(ex, 12, "f0e070"); i.put(ex + 1, 12, "f0e070"); i.put(ex, 13, "1a1a10"); i.put(ex + 1, 13, "1a1a10")
    for x0, s in ((5, 1), (27, -1)):                       # front feet
        i.rect(min(x0, x0 + 3 * s), 26, max(x0, x0 + 3 * s) + 1, 28, "5a8a2a")
    for wx, wy in ((12, 18), (19, 17), (16, 21), (23, 21), (9, 21)):   # warts
        i.put(wx, wy, "4a6a22")
    i.rect(12, 16, 21, 17, "3a5a1a")  # mouth line
    return i


def wisp_jar():
    i = Icon()
    i.glow.append((16, 18, 15, C("7af0ff"), 150))
    glass = (C("c8e8f0"), C("8ab8c8"), C("5a8898"))
    i.ellipse(16, 20, 9, 9.5, glass)                      # jar
    i.rect(11, 6, 21, 11, "8ab8c8")                       # neck
    i.rect(10, 4, 22, 7, "8a6a40"); i.rect(10, 4, 22, 5, "b08a54")   # cork
    i.rect(9, 8, 23, 9, "a8a8b0")                         # rim/string
    i.ellipse(16, 20, 5.2, 5.4, (C("e8ffff"), C("8af0ff"), C("3ab0e0")))   # the wisp
    i.ellipse(15, 19, 2.2, 2.2, (C("ffffff"), C("ffffff"), C("e8ffff")), shade=False)
    for x, y in ((11, 15), (12, 14)):                     # glass shine
        i.put(x, y, "f0ffff")
    i.sparks += [(4, 10, "e8ffff"), (27, 7, "e8ffff"), (28, 24, "b0f8ff"), (5, 27, "b0f8ff")]
    return i


def lake_weed():
    i = Icon()
    cols = ["4a8a3a", "5aa048", "3a6a2e", "6ab858"]
    for k, (x0, curl) in enumerate(((9, 1.0), (14, -1.2), (19, 0.8), (24, -0.9), (12, 0.5))):
        for t in range(22):
            y = 28 - t
            x = x0 + curl * 2.6 * math.sin(t * 0.32 + k)
            i.put(x, y, cols[k % 4]); i.put(x + 1, y, cols[(k + 1) % 4])
    i.ellipse(16, 28, 11, 2.5, (C("7a6a4a"), C("6a5a3a"), C("5a4a30")))   # wet sand
    for x, y in ((8, 9), (20, 7), (25, 12)):
        i.sparks.append((x, y, "b8e8f0"))   # drops
    return i


def crayfish():
    i = Icon()
    R = (C("e87050"), C("c84a2a"), C("8a2a1a"))
    for k in range(5):                                       # tail segments going down-right
        i.ellipse(17 + k * 1.6, 15 + k * 2.6, 4.5 - k * 0.5, 2.0, R)
    i.ellipse(24, 28, 3.6, 1.6, R)                           # tail fan
    i.ellipse(14, 11, 5.0, 4.0, R)                           # head/carapace
    for s in (-1, 1):                                        # claws
        bx = 14 + s * 7
        i.ellipse(bx, 6, 3.2, 3.6, R)
        i.put(bx + s, 3, "1a0a08"); i.put(bx + s, 4, "1a0a08")
        i.put(14 + s * 4, 8, "c84a2a"); i.put(14 + s * 5, 7, "c84a2a")
    for k in range(3):                                       # legs
        i.put(10 - k, 14 + k * 2, "8a2a1a"); i.put(20 + k, 13 + k * 2, "8a2a1a")
    i.put(12, 9, "1a0a08"); i.put(16, 9, "1a0a08")            # eyes
    for t in range(8):                                       # antennae
        i.put(11 - t, 8 - t * 0.6, "c84a2a"); i.put(17 + t * 0.3, 8 - t, "c84a2a")
    return i


def fish(i, cx, cy, length, height, body, belly, fin, stripes=0, spots=False, jaw=False):
    i.ellipse(cx, cy, length / 2, height / 2, body)
    i.ellipse(cx - 1, cy + height * 0.22, length * 0.38, height * 0.2, belly, shade=False)
    tx = cx + length / 2 - 1
    for t in range(6):                                    # tail
        for y in range(-t - 1, t + 2):
            i.put(tx + t, cy + y, fin)
    n = int(length * 0.4)
    for t in range(n):                                    # spiky dorsal fin, tallest at the front
        top = int(round(3 * (1 - t / n))) + (1 if t % 2 == 0 else 0)
        for k in range(1, top + 1):
            i.put(cx - length * 0.15 + t, cy - height / 2 + 1 - k, fin)
    for k in range(stripes):
        x = cx - length * 0.2 + k * length * 0.16
        for y in range(int(cy - height / 2 + 1), int(cy + height * 0.15)):
            i.put(x, y, body[2])
    if spots:
        for k in range(7):
            i.put(cx - length * 0.3 + (k * 5) % int(length * 0.7), cy - 2 + (k * 3) % 4, "d8d890")
    ex = cx - length / 2 + 3
    i.put(ex, cy - 1, "f0f0e0"); i.put(ex + 1, cy - 1, "1a1a10")
    if jaw:
        for t in range(4):
            i.put(cx - length / 2 - 1 - t * 0.3, cy + 1, body[1])
        i.put(cx - length / 2 + 1, cy + 1, "f0f0e0")


def perch():
    i = Icon()
    fish(i, 15, 16, 20, 11, (C("c8c060"), C("98a040"), C("4a5a24")), (C("f0e8b0"), C("e8d898"), C("e8d898")),
         C("e06a3a"), stripes=4)
    return i


def pike():
    i = Icon()
    fish(i, 14, 17, 25, 8, (C("8ab060"), C("5a8040"), C("3a5a2a")), (C("e8e8c0"), C("d8d8a8"), C("d8d8a8")),
         C("6a7a3a"), spots=True, jaw=True)
    return i


if __name__ == "__main__":
    out = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "assets/icons")
    for name, fn in (("toad", toad), ("wisp_jar", wisp_jar), ("lake_weed", lake_weed), ("crayfish", crayfish),
                     ("perch", perch), ("pike", pike)):
        fn().save(os.path.join(out, name + ".png"))
    print("ok")
