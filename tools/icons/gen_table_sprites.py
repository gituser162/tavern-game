"""Top-down pixel sprites of the crafting ingredients for the alchemy table and the kitchen table (2026-11-10).
The stations are drawn in logical pixels (200x104, scaled x3..x4), so every sprite is drawn 1:1 in a 16x16 cell,
lit from the top left like the rest of the table, with a dark outline. The camera looks straight down: things lie
on the table on their side (fish, roots), round things are discs, jars and vials show their lids.

Usage: python3 gen_table_sprites.py <project dir> [preview.png]
  -> writes assets/objects/table_ingredients.png (one row of 16x16 cells, order = ORDER below; the same order
     is BrewStation.TABLE_SPRITES in scripts/brew_station.gd).
"""
import math
import os
import random
import sys

from PIL import Image

CELL = 16
OUT = (26, 15, 10)          # C_OUT of the stations
ORDER = ["herbs", "bones", "crystal", "burdock", "mandrake", "glow_mushroom", "berries", "grave_dust",
         "ether_essence", "swamp_moss", "lake_weed", "toad", "nightshade", "wisp_jar", "chicken", "bread",
         "perch", "pike", "crayfish", "spices"]


def C(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Sprite:
    def __init__(self):
        self.px = {}            # (x, y) -> (r, g, b, a)
        self.glow = []          # (x, y, colour, alpha) drawn under, never outlined

    def put(self, x, y, col, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < CELL and 0 <= y < CELL:
            c = C(col) if isinstance(col, str) else col
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def get(self, x, y):
        return self.px.get((x, y))

    def disc(self, cx, cy, rx, ry, cols, light=(-0.6, -0.8), rim=True):
        """Filled ellipse shaded from the light: cols = [lit .. dark]."""
        n = len(cols)
        got = set()
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x - cx) / max(0.5, rx)
                dy = (y - cy) / max(0.5, ry)
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                dot = dx * light[0] + dy * light[1]
                k = (1.0 - dot) * 0.5
                if rim and d > 0.6:
                    k += 0.15
                self.put(x, y, cols[max(0, min(n - 1, int(k * n)))])
                got.add((x, y))
        return got

    def edge(self, pts, col):
        """Darkens the pixels of `pts` on its border (to tell overlapping things apart)."""
        for (x, y) in pts:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in pts:
                    self.put(x, y, col)
                    break

    def line(self, x0, y0, x1, y1, col, w=1):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            t = i / max(1, steps)
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for oy in range(w):
                for ox in range(w):
                    self.put(x + ox - (w - 1) / 2, y + oy - (w - 1) / 2, col)

    def thick(self, pts, cols, w):
        """A shaded rod along the points: the lit side up-left. cols = [lit, mid, dark]."""
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            nx, ny = -(y1 - y0), (x1 - x0)
            ln = math.hypot(nx, ny) or 1
            nx, ny = nx / ln, ny / ln
            if nx * -0.6 + ny * -0.8 < 0:
                nx, ny = -nx, -ny
            for i in range(steps + 1):
                t = i / steps
                x = x0 + (x1 - x0) * t
                y = y0 + (y1 - y0) * t
                for k in range(-w, w + 1):
                    s = k / max(1, w)
                    col = cols[0] if s > 0.5 else (cols[1] if s > -0.4 else cols[2])
                    self.put(x + nx * k * 0.5, y + ny * k * 0.5, col)

    def outline(self):
        add = {}
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.px and 0 <= p[0] < CELL and 0 <= p[1] < CELL:
                    add[p] = OUT + (255,)
        self.px.update(add)

    def image(self):
        im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        for (x, y, col, a) in self.glow:
            if 0 <= x < CELL and 0 <= y < CELL:
                c = C(col) if isinstance(col, str) else col
                im.putpixel((x, y), (c[0], c[1], c[2], a))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def leaf(s, cx, cy, ang, ln, wd, cols):
    """A pointed leaf from (cx, cy) along `ang`: lit half, dark half, a vein."""
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx
    for i in range(int(ln * 3) + 1):
        t = i / (ln * 3)
        w = wd * math.sin(math.pi * min(1.0, t * 1.1))
        x = cx + dx * ln * t
        y = cy + dy * ln * t
        for k in range(-int(w * 2), int(w * 2) + 1):
            o = k / 2.0
            lit = (nx * o) * -0.6 + (ny * o) * -0.8 > 0
            col = cols[0] if lit else cols[1]
            if abs(o) > w - 0.6 and not lit:
                col = cols[2]
            s.put(x + nx * o, y + ny * o, col)
    s.line(cx + dx, cy + dy, cx + dx * ln * 0.75, cy + dy * ln * 0.75, cols[2])


# ---------- the ingredients ----------

def herbs():
    s = Sprite()
    g = [C("8ac45a"), C("5a9a3a"), C("2e5a20")]
    g2 = [C("a8d870"), C("6aaa44"), C("2e5a20")]
    # Two sprigs tied with twine at the bottom, leaves in pairs along the stems.
    for (x0, y0, x1, y1), cols in (((7, 14, 4, 3), g), ((8, 14, 12, 2), g2)):
        s.line(x0, y0, x1, y1, "3a6a28")
        for t in (0.35, 0.6, 0.85):
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            base = math.atan2(y1 - y0, x1 - x0)
            leaf(s, x, y, base - 1.0, 3.6, 1.5, cols)
            leaf(s, x, y, base + 1.0, 3.6, 1.5, cols)
        leaf(s, x1, y1, math.atan2(y1 - y0, x1 - x0), 2.5, 1.2, cols)
    s.line(6, 12, 9, 12, "d8b878")
    s.put(10, 13, "d8b878")
    return s


def bones():
    s = Sprite()
    c = [C("f0e6cc"), C("d8c8a4"), C("a8987a")]
    s.thick([(4, 11), (11, 4)], c, 2)
    for (x, y) in ((3, 11), (4, 12), (11, 3), (12, 4)):
        s.disc(x, y, 1.6, 1.6, c)
    s.put(6, 8, "fff8e8")
    s.put(7, 7, "fff8e8")
    return s


def shard(s, x0, y0, x1, y1, w):
    """A crystal prism lying on the table from (x0, y0) to its pointed tip (x1, y1): three facet bands."""
    ln = math.hypot(x1 - x0, y1 - y0)
    dx, dy = (x1 - x0) / ln, (y1 - y0) / ln
    nx, ny = -dy, dx
    if nx * -0.6 + ny * -0.8 < 0:
        nx, ny = -nx, -ny
    for i in range(int(ln * 3) + 1):
        t = i / (ln * 3)
        ww = w if t < 0.7 else w * (1 - (t - 0.7) / 0.3)
        for k in range(-int(ww * 2), int(ww * 2) + 1):
            o = k / 2.0
            band = o / max(0.5, w)
            col = "e0f8ff" if band > 0.35 else ("8ad0f0" if band > -0.3 else "3a78b8")
            s.put(x0 + dx * ln * t + nx * o, y0 + dy * ln * t + ny * o, col)
    s.line(x0 + dx * 2 + nx * w * 0.5, y0 + dy * 2 + ny * w * 0.5, x0 + dx * ln * 0.7 + nx * w * 0.5, y0 + dy * ln * 0.7 + ny * w * 0.5, "f8ffff")


def crystal():
    s = Sprite()
    shard(s, 3, 13, 12, 2, 2.6)
    shard(s, 4, 11, 1, 5, 1.6)
    shard(s, 9, 13, 14, 9, 1.6)
    return s


def burdock():
    s = Sprite()
    # A long tapering root: thick crown with leaf stubs at the top right, thin tail at the bottom left.
    pts = [(12.5, 3.5), (10, 6), (7, 9), (4.5, 12), (2.5, 14)]
    for (xa, ya), (xb, yb), w in zip(pts, pts[1:], (2, 2, 1, 1)):
        s.thick([(xa, ya), (xb, yb)], [C("b8925e"), C("8a6438"), C("5a3c20")], w)
    for (x, y) in ((9, 7), (7, 10), (11, 5)):
        s.put(x, y, "5a3c20")
        s.put(x - 1, y - 1, "d0aa74")
    for (x0, y0, x1, y1) in ((8, 9, 9, 11), (6, 10, 4, 9), (5, 12, 6, 14)):
        s.line(x0, y0, x1, y1, "7a5430")
    s.line(13, 3, 14, 1, "6a8a3a")
    s.line(12, 3, 11, 1, "6a8a3a")
    return s


def mandrake():
    s = Sprite()
    c = [C("f0d8a0"), C("d8b478"), C("a8844a")]
    # A pale little body with legs, a green tuft on the head and a grumpy face.
    s.disc(8, 9, 3.4, 3.8, c)
    s.line(6, 12, 4, 14, "c8a468")
    s.line(10, 12, 12, 14, "c8a468")
    s.line(5, 9, 3, 10, "c8a468")
    s.line(11, 9, 13, 10, "c8a468")
    g = [C("8ac45a"), C("5a9a3a"), C("3a6a28")]
    leaf(s, 8, 6, -2.0, 4, 1.5, g)
    leaf(s, 8, 6, -1.2, 5, 1.5, g)
    leaf(s, 8, 6, -0.6, 3.5, 1.3, g)
    s.put(7, 8, "3a2414")
    s.put(9, 8, "3a2414")
    s.line(7, 10, 9, 10, "8a5a34")
    return s


def glow_mushroom():
    s = Sprite()
    for x in range(CELL):
        for y in range(CELL):
            d = math.hypot(x - 8, y - 8)
            if d < 8:
                s.glow.append((x, y, "6ae0f0", int(70 * (1 - d / 8))))
    cap = [C("b8f4ff"), C("6ad0e8"), C("3a90b0")]
    for cx, cy, r in ((4.5, 10.5, 2.6), (11, 12, 2.3), (8.5, 6.5, 4.4)):
        s.edge(s.disc(cx, cy, r, r, cap), "1e5a78")
    for (x, y) in ((8, 6), (10, 8), (4, 10), (11, 12), (9, 5)):
        s.put(x, y, "f0ffff")
    return s


def berries():
    s = Sprite()
    leaf(s, 9, 7, -0.7, 5, 1.8, [C("8ac45a"), C("5a9a3a"), C("3a6a28")])
    b = [C("8aa8f0"), C("4a5ab8"), C("2a2a78")]
    for cx, cy in ((6, 7), (9, 9), (5, 11), (8, 12), (11, 12)):
        s.edge(s.disc(cx, cy, 2.0, 2.0, b), "1a1a50")
        s.put(cx - 1, cy - 1, "d0e0ff")
    return s


def pouch(cols, string, spill):
    s = Sprite()
    s.disc(8, 9, 5.2, 4.8, cols)
    # Gathered neck in the middle with the string around it.
    s.disc(8, 8, 2.0, 1.6, [cols[1], cols[2], cols[3]])
    for a in range(0, 360, 45):
        r = math.radians(a)
        s.put(8 + math.cos(r) * 3, 8 + math.sin(r) * 2.6, cols[2])
    s.line(6, 8, 10, 8, string)
    s.line(10, 8, 12, 5, string)
    s.put(12, 4, string)
    for (x, y) in spill:
        s.put(x, y, cols[0])
    return s


def grave_dust():
    s = pouch([C("b8b0a0"), C("9a9282"), C("78705e"), C("54503e")], "4a3a2a", [])
    for (x, y) in ((2, 13), (3, 14), (4, 13), (2, 14)):
        s.put(x, y, "8a8a80")
    s.put(7, 11, "c8c0b0")
    return s


def ether_essence():
    s = Sprite()
    for x in range(CELL):
        for y in range(CELL):
            d = math.hypot(x - 8, y - 8)
            if 5 < d < 8:
                s.glow.append((x, y, "8ae0ff", int(60 * (1 - (d - 5) / 3))))
    # A round vial from above: the glass rim, the violet-blue essence, the cork in the neck.
    s.disc(8, 8, 5.5, 5.5, [C("a8d8e8"), C("6a90b8"), C("3a5080")])
    s.disc(8, 8, 4.2, 4.2, [C("a080f0"), C("6a50c8"), C("3a2a88")], rim=False)
    for (x, y) in ((6, 9), (10, 7), (9, 10), (6, 6)):
        s.put(x, y, "e0d8ff")
    s.disc(8, 8, 1.8, 1.8, [C("d0a870"), C("a87a48"), C("7a5430")])
    s.put(4, 6, "f0ffff")
    s.put(5, 5, "f0ffff")
    return s


def swamp_moss():
    s = Sprite()
    rnd = random.Random(7)
    g = [C("9ab85a"), C("6a8a3a"), C("4a6428"), C("34481c")]
    for cx, cy, r in ((7, 8, 4.5), (10, 10, 3.6), (5, 11, 2.8), (10, 6, 2.6)):
        s.disc(cx, cy, r, r * 0.9, g)
    for k in range(18):
        x, y = rnd.randint(3, 13), rnd.randint(4, 13)
        if s.get(x, y):
            s.put(x, y, rnd.choice(["b8d070", "34481c", "8aa04a"]))
    return s


def lake_weed():
    s = Sprite()
    for x0, ph, col in ((4, 0.0, "4a8a3a"), (7, 1.5, "6aa84a"), (10, 3.0, "3a7030"), (12, 4.2, "5a9a40")):
        prev = None
        for y in range(2, 15):
            x = x0 + math.sin(y * 0.7 + ph) * 1.4
            if prev:
                s.line(prev[0], prev[1], x, y, col)
            prev = (x, y)
        s.put(x0 + math.sin(2 * 0.7 + ph) * 1.4, 2, "8ac860")
    return s


def toad():
    s = Sprite()
    g = [C("a8d060"), C("7aa840"), C("4e7a2a"), C("34541c")]
    # Legs splayed out, the back with warts, two bulging eyes at the front.
    for (x0, y0, x1, y1) in ((5, 10, 2, 13), (11, 10, 14, 13), (5, 7, 3, 5), (11, 7, 13, 5)):
        s.line(x0, y0, x1, y1, "5a8a30", 2)
    s.disc(8, 9, 4.2, 4.6, g)
    s.disc(6, 5, 1.6, 1.6, g)
    s.disc(10, 5, 1.6, 1.6, g)
    s.put(6, 5, "1a1208")
    s.put(10, 5, "1a1208")
    s.put(5, 4, "f0f0c0")
    s.put(9, 4, "f0f0c0")
    for (x, y) in ((7, 9), (9, 11), (10, 8), (6, 11)):
        s.put(x, y, "4e7a2a")
    s.put(7, 8, "c8e890")
    return s


def nightshade():
    s = Sprite()
    s.line(3, 14, 11, 4, "3a5a28")
    g = [C("6a9a48"), C("4a7a30"), C("2a4a1c")]
    leaf(s, 6, 11, 2.6, 4, 1.6, g)
    leaf(s, 8, 8, -0.2, 4, 1.6, g)
    # The violet star flower and two black berries.
    for a in range(5):
        r = math.radians(a * 72 - 90)
        s.disc(11 + math.cos(r) * 2, 4 + math.sin(r) * 2, 1.2, 1.2, [C("c890f0"), C("9050c8"), C("5a2a88")])
    s.put(11, 4, "f2d050")
    for cx, cy in ((4, 8), (5, 6)):
        s.disc(cx, cy, 1.4, 1.4, [C("5a5068"), C("2a2030"), C("100810")])
        s.put(cx - 1, cy - 1, "c0b8d0")
    return s


def wisp_jar():
    s = Sprite()
    for x in range(CELL):
        for y in range(CELL):
            d = math.hypot(x - 8, y - 8)
            if d < 8:
                s.glow.append((x, y, "b8f0ff", int(90 * (1 - d / 8))))
    # A jar from above: thick glass rim, the light inside, the cork lid tied with string.
    s.disc(8, 8, 6.2, 6.2, [C("d8f0f8"), C("98c0d0"), C("6890a0")])
    s.disc(8, 8, 4.8, 4.8, [C("f0ffff"), C("a8e8ff"), C("68b8e0")], rim=False)
    s.disc(8, 8, 3.0, 3.0, [C("d0a870"), C("a87a48"), C("7a5430")])
    s.line(5, 8, 11, 8, "6a4a2a")
    for (x, y) in ((3, 6), (12, 11), (4, 11), (13, 5)):
        s.put(x, y, "ffffff")
    return s


def chicken():
    s = Sprite()
    c = [C("f8d088"), C("e0a050"), C("b8742e"), C("80461c")]
    leg = [C("f0b868"), C("c88238"), C("8a5222")]
    # Roast bird from above: drumsticks first (under the body), then the round breast, wing tips.
    for sx in (-1, 1):
        s.edge(s.disc(8 + sx * 4.2, 11.5, 2.2, 2.6, leg), "6a3a18")
        s.line(8 + sx * 5.5, 13.5, 8 + sx * 6.5, 15, "f0e8d8")
    s.edge(s.disc(8, 7.5, 5.2, 4.6, c), "6a3a18")
    s.line(8, 4, 8, 10, "c88238")
    s.line(5, 6, 6, 5, "fff0c0")
    s.put(9.5, 5.5, "fff0c0")
    return s


def bread():
    s = Sprite()
    c = [C("c08a50"), C("9a6a38"), C("74502a"), C("54381c")]
    s.disc(8, 8, 6.2, 4.6, c)
    # Score marks across the crust, flour dusting.
    for k in (-3, 0, 3):
        s.line(8 + k - 1, 6, 8 + k + 1, 10, "5a3a1c")
        s.put(8 + k - 1, 6, "d8b078")
    for (x, y) in ((5, 6), (10, 5), (12, 8), (4, 9)):
        s.put(x, y, "e8d8b8")
    return s


def fish(body, belly, dark, fin, ln, spots=None, stripes=False):
    s = Sprite()
    cy = 8
    x0 = 8 - ln / 2
    for i in range(int(ln * 2) + 1):
        t = i / (ln * 2)
        x = x0 + ln * t
        w = 2.8 * math.sin(math.pi * min(1.0, 0.15 + t * 0.95)) + 0.3
        for y in range(int(cy - w), int(cy + w) + 1):
            k = (y - (cy - w)) / max(1, 2 * w)
            col = body if k < 0.55 else belly
            if k < 0.2:
                col = dark
            s.put(x, y, col)
    # Tail (right), fins, the eye at the head (left).
    tx = x0 + ln
    for k in range(4):
        s.line(tx, cy, tx + 3, cy - 3 + k * 2, fin)
    s.line(x0 + ln * 0.45, cy - 3, x0 + ln * 0.65, cy - 4, fin)
    s.put(x0 + ln * 0.35, cy + 2, fin)
    s.put(x0 + 1.5, cy - 1, "1a1208")
    s.put(x0 + 1, cy - 1, "f0f0e0")
    s.line(x0, cy + 0.5, x0 + 1, cy + 0.5, dark)
    if stripes:
        for k in range(3):
            x = x0 + ln * (0.35 + 0.17 * k)
            s.line(x, cy - 2, x + 0.5, cy + 1, dark)
    for (x, y) in spots or []:
        s.put(x, y, "e8e0a0")
    return s


def perch():
    return fish("a8b848", "e8e0a8", "4a6a28", "e05a30", 10, stripes=True)


def pike():
    return fish("6a8a48", "c8d0a0", "3a5a2a", "8a7a3a", 13, spots=[(4, 7), (7, 6), (9, 8), (11, 7), (6, 9)])


def crayfish():
    s = Sprite()
    r = [C("f08050"), C("c84a2a"), C("8a2a18")]
    # Head at the top with claws forward, the segmented tail down.
    s.disc(8, 6, 2.6, 2.4, r)
    for k in range(4):
        s.disc(8, 9 + k * 1.5, 2.2 - k * 0.3, 1.0, r)
        s.line(6.5 + k * 0.3, 9.5 + k * 1.5, 9.5 - k * 0.3, 9.5 + k * 1.5, "8a2a18")
    s.line(7, 15, 9, 15, "c84a2a")
    for sx in (-1, 1):
        s.line(8 + sx * 2, 5, 8 + sx * 4, 3, "c84a2a")
        s.disc(8 + sx * 4.5, 2, 1.5, 1.4, r)
        s.line(8 + sx * 2, 8, 8 + sx * 4, 10, "c84a2a")
        s.line(8 + sx * 1, 4, 8 + sx * 3, 0, "e08060")
    s.put(7, 5, "1a1208")
    s.put(9, 5, "1a1208")
    return s


def spices():
    s = Sprite()
    # An open paper twist with red-orange spice, a star anise beside it.
    s.disc(7, 8, 5.0, 4.6, [C("e8dcc0"), C("d0c09c"), C("a89874"), C("80704e")])
    s.disc(7, 8, 3.2, 2.8, [C("f0a040"), C("d06a28"), C("a03a18")], rim=False)
    for (x, y) in ((6, 7), (8, 9), (7, 8)):
        s.put(x, y, "f8d070")
    for a in range(8):
        rr = math.radians(a * 45)
        ln = 2.4 if a % 2 == 0 else 1.2
        s.line(13, 13, 13 + math.cos(rr) * ln, 13 + math.sin(rr) * ln, "7a3a1a")
    s.put(13, 13, "c87a3a")
    return s


def main():
    proj = sys.argv[1]
    sheet = Image.new("RGBA", (CELL * len(ORDER), CELL), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        s = globals()[name]()
        s.outline()
        sheet.paste(s.image(), (i * CELL, 0))
    path = os.path.join(proj, "assets", "objects", "table_ingredients.png")
    sheet.save(path)
    print("wrote", path)
    if len(sys.argv) > 2:
        bg = Image.new("RGBA", sheet.size, (61, 38, 20, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(sys.argv[2])


if __name__ == "__main__":
    main()
