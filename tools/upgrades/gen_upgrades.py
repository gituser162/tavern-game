"""Pixel-art props that show the tavern upgrades in the room (320x180 background, lit from the fire / upper left).
Run: python3 gen_upgrades.py <project>   -> writes <project>/assets/objects/upg_*.png
  upg_kitchen_1/2.png  20x30  cauldron hanging in the fireplace (main.gd KITCHEN_RECT)
  upg_alchemy_1/2.png  10x20  flask / small alembic on the counter left of the mortar (ALCHEMY_UPG_RECT)
  upg_rooms_1/2.png    16x16  key rack on the wall: 2 / 4 room keys (ROOMS_RECT)
The keg variants are made by tools/background/gen_keg.py <out> <level>."""
import os
import sys
from PIL import Image

OUT_DIR = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "assets/objects")


def c(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


OUTLINE = c("1a0f0a")


class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.im.load()

    def px(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c(col) if isinstance(col, str) else col

    def rect(self, x0, y0, x1, y1, col):      # x1, y1 exclusive
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.px(x, y, col)

    def outline(self, skip=()):
        a = [[self.p[x, y][3] > 0 for x in range(self.w)] for y in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                if a[y][x] or (x, y) in skip:
                    continue
                if any(0 <= x + dx < self.w and 0 <= y + dy < self.h and a[y + dy][x + dx]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.p[x, y] = OUTLINE

    def save(self, name):
        path = os.path.join(OUT_DIR, name)
        self.im.save(path)
        print("saved", path)


IRON = ["6a6a72", "4e4e56", "38383e", "26262a"]       # light -> dark
COPPER = ["c8854a", "a06432", "744420", "4a2a12"]
BRASS = ["f0d070", "c8a040", "8a6a22"]


# ---------- kitchen: a cauldron on a chain over the fire ----------
def kitchen(level):
    s = Spr(20, 30)
    metal = IRON if level == 1 else COPPER
    # chain from the hood down to the handle
    for y in range(0, 14):
        s.px(10, y, IRON[1] if y % 2 else IRON[2])
        if y % 2 == 0:
            s.px(9, y, IRON[2])
    # bail handle
    for x in range(4, 16):
        s.px(x, 14, IRON[1])
    s.px(3, 15, IRON[1]); s.px(16, 15, IRON[1]); s.px(3, 16, IRON[2]); s.px(16, 16, IRON[2])
    # pot body: rows 16..27, widest in the middle; firelight from below-right
    widths = [6, 7, 7, 8, 8, 8, 8, 7, 7, 6, 5, 4]
    for i, hw in enumerate(widths):
        y = 16 + i
        for x in range(10 - hw, 10 + hw):
            shade = 1
            if x < 10 - hw + 2:
                shade = 2
            if i >= 8:
                shade = 2 if x < 10 else 1
            if x >= 10 + hw - 2 and i >= 3:
                shade = 0          # glow of the fire on the right side
            s.px(x, y, metal[shade])
    s.rect(4, 16, 16, 17, metal[3])                    # rim shadow
    s.rect(5, 15, 15, 16, metal[0])                    # rim
    # stew inside / steam
    s.rect(6, 15, 14, 16, "7a3e22" if level == 1 else "8a5a2a")
    s.px(8, 15, "a85a2a"); s.px(11, 15, "6a8a3a")
    if level == 2:
        s.px(12, 15, "c8a050")
        # ladle sticking out on the right
        for i in range(5):
            s.px(13 + i, 14 - i, "8a6a42")
        s.px(18, 9, "6a4426")
        # rivets band
        for x in range(4, 16, 3):
            s.px(x, 19, BRASS[1])
    # little legs / glowing bottom
    s.px(7, 28, metal[2]); s.px(12, 28, metal[2])
    s.outline(skip={(x, y) for y in range(0, 14) for x in range(7, 13)})
    # steam wisps (no outline, translucent)
    st = (200, 190, 175, 110)
    for x, y in ((8, 12), (7, 11), (8, 10), (12, 11), (13, 10), (12, 9)) + (((10, 8), (9, 7), (10, 6)) if level == 2 else ()):
        s.px(x, y, st)
    return s


# ---------- alchemy station: flask (1) / flask on a burner with a coil (2) ----------
def alchemy(level):
    s = Spr(10, 20)
    if level == 1:
        # round flask of green liquid standing on the counter (bottom row 19)
        for y, (l, r) in zip(range(13, 20), ((1, 1), (2, 2), (3, 3), (3, 3), (3, 3), (2, 2), (1, 1))):
            for x in range(5 - l, 5 + r):
                s.px(x, y, "3e8a4a" if y >= 15 else "9ab8b0")
        s.px(3, 15, "8ae09a"); s.px(3, 16, "8ae09a"); s.px(6, 17, "2e6a3a")
        s.rect(4, 9, 6, 13, "9aaaaa"); s.px(4, 10, "c8d8d8")
        s.rect(4, 7, 6, 9, "8a6a42")
        s.outline()
    else:
        # tripod and a tiny blue flame
        s.px(2, 19, "4a4a52"); s.px(7, 19, "4a4a52"); s.px(3, 18, "4a4a52"); s.px(6, 18, "4a4a52")
        s.rect(2, 17, 8, 18, "5a5a64")
        s.px(4, 18, "5aa0f0"); s.px(5, 18, "9ad0ff"); s.px(5, 19, "3a70d0"); s.px(4, 19, "3a70d0")
        # flask with glowing liquid
        for y, (l, r) in zip(range(11, 17), ((1, 1), (2, 2), (3, 3), (3, 3), (2, 2), (1, 1))):
            for x in range(5 - l, 5 + r):
                s.px(x, y, "c84a8a" if y >= 13 else "aab8c0")
        s.px(3, 13, "f08ac8"); s.px(6, 15, "8a2a5a")
        s.rect(4, 6, 6, 11, "9aaaaa")
        # coiled tube going up and to the right, a drop at its end
        for x, y in ((6, 6), (7, 5), (8, 4), (8, 3), (7, 2), (6, 2), (6, 1)):
            s.px(x, y, "b8c8c8")
        s.px(4, 6, "c8d8d8")
        s.outline()
        s.px(5, 0, (240, 160, 210, 255))
    return s


# ---------- rooms: a key rack with 2 / 4 keys ----------
def rooms(level):
    s = Spr(16, 16)
    # plaque
    s.rect(1, 2, 15, 9, "5a3a22")
    s.rect(1, 2, 15, 3, "7a5232")
    s.rect(1, 8, 15, 9, "3e2616")
    s.px(2, 4, "3e2616"); s.px(13, 4, "3e2616")     # nails
    s.px(8, 0, IRON[1]); s.px(7, 1, IRON[1]); s.px(9, 1, IRON[1])   # hanging string
    # carved "rooms" mark: a little bed
    s.rect(6, 5, 11, 6, "a07448"); s.px(6, 4, "a07448"); s.px(10, 6, "a07448"); s.px(6, 6, "a07448")
    keys = [3, 12] if level == 1 else [3, 6, 10, 13]
    for i, kx in enumerate(keys):
        s.px(kx, 9, IRON[2])                         # hook
        col = BRASS if i % 2 == 0 else ["e0c890", "b0985a", "7a6a3a"]
        s.px(kx, 10, col[0]); s.px(kx - 1, 11, col[1]); s.px(kx + 1, 11, col[1]); s.px(kx, 12, col[1])   # ring
        s.px(kx, 13, col[1]); s.px(kx, 14, col[2]); s.px(kx + 1, 14, col[2])                             # blade
    s.outline()
    return s


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for lvl in (1, 2):
        kitchen(lvl).save("upg_kitchen_%d.png" % lvl)
        alchemy(lvl).save("upg_alchemy_%d.png" % lvl)
        rooms(lvl).save("upg_rooms_%d.png" % lvl)
