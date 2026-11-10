"""Pixel-art tavern background, 320x180 (x4 = 1280x720). v6: storages under the counter with EMPTY shelves; shelf_items.py draws the stock sprites.
View from behind the bar: the hall is in the back, the counter runs along the bottom.
Only rows ~14..114 are visible in game (top info panel and bottom storage panels cover the rest).
"""
import random
import sys
import numpy as np
from PIL import Image

W, H = 320, 180
rng = random.Random(7)
img = np.zeros((H, W, 3), dtype=np.float32)


def hx(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def rect(x0, y0, x1, y1, c):
    x0, x1 = max(0, x0), min(W, x1)
    y0, y1 = max(0, y0), min(H, y1)
    if x0 < x1 and y0 < y1:
        img[y0:y1, x0:x1] = hx(c) if isinstance(c, str) else c


def px(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y, x] = hx(c) if isinstance(c, str) else c


def hline(x0, x1, y, c):
    rect(x0, y, x1, y + 1, c)


def vline(x, y0, y1, c):
    rect(x, y0, x + 1, y1, c)


OUT = "1a0f0a"
WOOD = ["4a2e1c", "52331f", "45291a", "4e3020"]
WOOD_HI, WOOD_SEAM = "5e3c25", "2c1a10"
BEAM, BEAM_HI, BEAM_LO = "33200f", "4a2f19", "22150b"
STONE = ["5b5148", "655a50", "51483f", "5f554b"]
STONE_HI, STONE_SEAM = "766a5e", "2e2722"
BRASS, BRASS_HI = "b08a3e", "e0c070"

RAIL = 66      # chair rail between planks and stone
FLOOR_Y = 90   # hall floor line (behind the counter)
CTOP = 94      # counter top surface starts here

# ---------- back wall: planks ----------
y, row = 18, 0
while y < RAIL:
    h = 6
    x = -((row * 23) % 40)
    while x < W:
        w = rng.choice([34, 40, 46, 52])
        rect(x, y, x + w, y + h, WOOD[rng.randrange(4)])
        hline(x, x + w, y, WOOD_HI)
        vline(x, y, y + h, WOOD_SEAM)
        for _ in range(3):
            gx, gy = x + rng.randrange(2, max(3, w - 6)), y + rng.randrange(2, h - 1)
            hline(gx, gx + rng.randrange(3, 8), gy, "3f2617")
        if rng.random() < 0.25:
            kx = x + rng.randrange(4, max(5, w - 4))
            px(kx, y + 3, "2f1c11"); px(kx + 1, y + 3, "3a2214")
        x += w
    hline(0, W, y + h - 1, WOOD_SEAM)
    y += h
    row += 1
rect(0, RAIL, W, RAIL + 3, BEAM); hline(0, W, RAIL, BEAM_HI); hline(0, W, RAIL + 2, BEAM_LO)

# ---------- stone wainscot ----------
y, row = RAIL + 3, 0
while y < FLOOR_Y:
    h = 5 if row % 2 == 0 else 6
    x = -(row % 2) * 9
    while x < W:
        w = rng.choice([14, 16, 18, 20])
        rect(x, y, x + w, y + h, STONE[rng.randrange(4)])
        hline(x + 1, x + w - 1, y, STONE_HI)
        vline(x, y, y + h, STONE_SEAM)
        x += w
    hline(0, W, y + h - 1, STONE_SEAM)
    y += h
    row += 1
# hall floor (thin strip, the counter hides the rest)
rect(0, FLOOR_Y, W, CTOP, "3d2717"); hline(0, W, FLOOR_Y, "1e120a")
for x in range(0, W, 26):
    vline(x, FLOOR_Y, CTOP, "2a1a0e")

# ---------- ceiling, beam, posts ----------
rect(0, 0, W, 13, "24170d")
for x in range(0, W, 12):
    vline(x, 0, 13, "1c120a")
rect(0, 12, W, 18, BEAM); hline(0, W, 12, BEAM_HI); hline(0, W, 17, BEAM_LO)
for x0 in (0, 88, 216, 314):
    rect(x0, 12, x0 + 6, FLOOR_Y, BEAM)
    vline(x0, 12, FLOOR_Y, BEAM_LO); vline(x0 + 1, 12, FLOOR_Y, BEAM_HI); vline(x0 + 5, 12, FLOOR_Y, BEAM_LO)
    for yy in (22, 80):
        rect(x0, yy, x0 + 6, yy + 2, "2a2a2e"); px(x0 + 2, yy, "55555c")

# ---------- left: entrance door + barrels ----------
DX0, DX1, DY0 = 14, 44, 34
rect(DX0 - 3, DY0 - 2, DX1 + 3, FLOOR_Y, "5b5148")  # stone frame
for yy in range(DY0 - 2, FLOOR_Y, 5):
    hline(DX0 - 3, DX0, yy, STONE_SEAM); hline(DX1, DX1 + 3, yy, STONE_SEAM)
for i in range(6):  # arched top
    rect(DX0 + i, DY0 - 6 + i, DX1 - i, DY0, "5b5148")
rect(DX0, DY0, DX1, FLOOR_Y, "5a3a22")
for i in range(5):
    rect(DX0 + 1 + i, DY0 - 5 + i, DX1 - 1 - i, DY0, "5a3a22")
for x in range(DX0 + 6, DX1, 6):  # vertical boards
    vline(x, DY0 - 3, FLOOR_Y, "3a2414")
for x in range(DX0 + 1, DX1, 6):
    vline(x, DY0 - 2, FLOOR_Y, "6e4a2c")
for yy in (DY0 + 6, DY0 + 40):  # iron bands
    rect(DX0, yy, DX1, yy + 2, "2a2a2e")
    for x in range(DX0 + 2, DX1, 6):
        px(x, yy, "6a6a72")
px(DX1 - 6, DY0 + 26, "c9a24a"); px(DX1 - 7, DY0 + 27, "c9a24a"); px(DX1 - 5, DY0 + 27, "c9a24a"); px(DX1 - 6, DY0 + 28, "c9a24a")
# small barred window in the door
rect(DX0 + 10, DY0 + 12, DX1 - 10, DY0 + 20, "1b2440")
vline((DX0 + DX1) // 2, DY0 + 12, DY0 + 20, "2a2a2e")
# barrels


def barrel(x, y, w, h):
    rect(x, y, x + w, y + h, "6a4426")
    for i in range(w):  # rounded shading
        t = abs(i - w / 2) / (w / 2)
        c = "7e5430" if t < 0.4 else ("6a4426" if t < 0.75 else "4e3018")
        vline(x + i, y + 1, y + h - 1, c)
    hline(x + 1, x + w - 1, y, "8a6038"); hline(x + 1, x + w - 1, y + h - 1, "3a2414")
    for yy in (y + 2, y + h - 4):
        hline(x, x + w, yy, "3a3a3e"); hline(x, x + w, yy + 1, "55555c")
    vline(x - 1, y + 1, y + h - 1, OUT); vline(x + w, y + 1, y + h - 1, OUT)


barrel(52, 72, 14, 18)
barrel(68, 72, 14, 18)
rect(73, 82, 76, 84, BRASS); px(75, 84, BRASS)  # tap

# herb bundles hanging from the beam
HIDDEN_HERBS = (60, 76)  # removed for the contract board, but rng is still consumed so the rest stays the same
for hxp, col in ((101, "4f7a3a"), (110, "7a5a8a"), (200, "6a8a3a"), (209, "4f7a3a"), (60, "4f7a3a"), (76, "6a8a3a")):
    if hxp not in HIDDEN_HERBS:
        vline(hxp, 18, 22, "8a7050")
        rect(hxp - 1, 22, hxp + 2, 24, "8a5a30")
    for dy in range(7):
        w = 1 + dy // 2
        for dx in range(-w, w + 1):
            if rng.random() < 0.8:
                c = col if rng.random() < 0.7 else "38552a"
                if hxp not in HIDDEN_HERBS:
                    px(hxp + dx, 24 + dy, c)


# ---------- centre: fireplace with griffin shield ----------
FX0, FX1 = 122, 188
MANTLE = 46
y, row = 18, 0
while y < FLOOR_Y:
    h = 6
    narrow = y < MANTLE
    xs, xe = (FX0 + 6, FX1 - 6) if narrow else (FX0, FX1)
    x = xs - (row % 2) * 5
    while x < xe:
        w = rng.choice([10, 12, 14])
        x0, x1 = max(x, xs), min(x + w, xe)
        rect(x0, y, x1, y + h, STONE[rng.randrange(4)])
        hline(x0 + 1, x1 - 1, y, STONE_HI)
        vline(x0, y, y + h, STONE_SEAM)
        x += w
    hline(xs, xe, y + h - 1, STONE_SEAM)
    y += h
    row += 1
vline(FX0 + 6, 18, MANTLE, OUT); vline(FX1 - 7, 18, MANTLE, OUT)
vline(FX0, MANTLE, FLOOR_Y, OUT); vline(FX1 - 1, MANTLE, FLOOR_Y, OUT)
rect(FX0 - 4, MANTLE, FX1 + 4, MANTLE + 5, "5a3a22")
hline(FX0 - 4, FX1 + 4, MANTLE, "7a5232"); hline(FX0 - 4, FX1 + 4, MANTLE + 4, "22150b")
for cx in (FX0 + 2, FX1 - 4):
    rect(cx, MANTLE - 6, cx + 2, MANTLE, "e8dcc0"); px(cx, MANTLE - 7, "ffd36b"); px(cx + 1, MANTLE - 8, "fff0b0")
rect(FX0 + 10, MANTLE - 6, FX0 + 16, MANTLE, "8a5a3a"); hline(FX0 + 11, FX0 + 15, MANTLE - 7, "a07040")
rect(FX1 - 16, MANTLE - 4, FX1 - 11, MANTLE, "d8d0bc"); px(FX1 - 15, MANTLE - 2, OUT); px(FX1 - 13, MANTLE - 2, OUT)
OX0, OX1, OY0 = 134, 176, 60
rect(OX0, OY0, OX1, FLOOR_Y, "140a06")
for i in range(5):
    rect(OX0 + i, OY0 - 5 + i, OX1 - i, OY0, "140a06")
for i in range(6):
    hline(OX0 - 1 + i, OX1 + 1 - i, OY0 - 6 + i, "3a332c")
for yy in range(OY0, FLOOR_Y, 4):
    hline(OX0 + 2, OX1 - 2, yy, "22140c")
FB = FLOOR_Y - 3  # fire base
rect(OX0 + 5, FB, OX1 - 5, FB + 3, "4a2a16"); hline(OX0 + 5, OX1 - 5, FB, "6a3e20")
# Flames: argv[2] = animation phase 0..1 (looping); no argv[2] = empty hearth (static background).
FIRE_T = float(sys.argv[2]) if len(sys.argv) > 2 else None
_static_sparks = [(rng.randrange(OX0 + 6, OX1 - 6), rng.randrange(OY0 + 2, FB - 10), rng.choice(["ff9a3c", "ffd36b"])) for _ in range(12)]
if FIRE_T is not None:
    A = 2 * np.pi * FIRE_T
    frng = random.Random(1234)
    ph = [frng.uniform(0, 6.28) for _ in range(64)]
    for col, hgt in [("8a2a1a", 20), ("e0582a", 15), ("ff9a3c", 11), ("ffd36b", 6), ("fff3c0", 3)]:
        for fx in range(OX0 + 7, OX1 - 7):
            i = fx - OX0
            d = abs(fx - (OX0 + OX1) / 2) / ((OX1 - OX0) / 2 - 7)
            wob = (0.72 + 0.22 * abs(np.sin(fx * 0.9 + A))
                   + 0.12 * np.sin(2 * A + ph[i])
                   + 0.08 * np.sin(3 * A + fx * 0.5 + ph[i + 20]))
            top = int(FB - hgt * (1 - d ** 1.6) * wob)
            if top < FB:
                rect(fx, top, fx + 1, FB, col)
    # flame tongues breaking off and rising
    for k in range(5):
        p = (FIRE_T * 2 + k / 5) % 1.0
        tx = int(OX0 + 12 + (k * 7 + 3) % 19 + round(np.sin(A + k) * 1))
        ty = int(FB - 16 - p * 9)
        if p < 0.6:
            px(tx, ty, "ff9a3c" if p < 0.3 else "e0582a")
            if p < 0.3:
                px(tx, ty + 1, "e0582a")
    # sparks drifting up
    for k in range(9):
        sp = 1 + k % 2
        p = (FIRE_T * sp + k / 9) % 1.0
        sx = int(OX0 + 9 + (k * 11) % 25 + round(2 * np.sin(A * sp + k * 1.7)))
        sy = int(FB - 12 - p * (FB - 12 - OY0 - 1))
        px(sx, sy, "ffd36b" if p < 0.5 else "ff9a3c")
else:
    # glowing embers on the logs only
    for fx in range(OX0 + 7, OX1 - 7, 3):
        px(fx, FB - 1, "e0582a")
rect(FX0 - 4, FLOOR_Y - 1, FX1 + 4, FLOOR_Y + 3, "6b6157"); hline(FX0 - 4, FX1 + 4, FLOOR_Y - 1, "857a6e")

SX, SY = 155, 22
for yy in range(22):
    half = 11 if yy < 12 else int(11 * (1 - ((yy - 12) / 10) ** 1.5))
    hline(SX - half, SX + half + 1, SY + yy, "7a1e1e")
    px(SX - half, SY + yy, BRASS); px(SX + half, SY + yy, BRASS)
hline(SX - 11, SX + 12, SY, BRASS_HI)
vline(SX, SY + 1, SY + 21, "5a1414")
GRIFFIN = ["....##......", "...###...#..", "..####..##..", ".#####.###..", "..##########",
           "...########.", "...#######..", "..###..##...", "..#....#...."]
for gy, r in enumerate(GRIFFIN):
    for gx, ch in enumerate(r):
        if ch == "#":
            px(SX - 6 + gx, SY + 5 + gy, "e0b84a")
px(SX - 3, SY + 6, OUT)
for i in range(-14, 15):
    px(SX + i, SY + 11 + int(i * 0.55), "a8acb4"); px(SX + i, SY + 11 - int(i * 0.55), "a8acb4")
for sx in (-14, 14):
    rect(SX + sx - 1, SY + 3, SX + sx + 2, SY + 5, "6b4a2a")

# ---------- right: night window + quest board ----------
WX0, WY0, WX1, WY1 = 238, 24, 296, 56
rect(WX0 - 3, WY0 - 3, WX1 + 3, WY1 + 4, BEAM); hline(WX0 - 3, WX1 + 3, WY0 - 3, BEAM_HI)
for yy in range(WY0, WY1):
    t = (yy - WY0) / (WY1 - WY0)
    rect(WX0, yy, WX1, yy + 1, hx("141c38") * (1 - t) + hx("2a3a66") * t)
for _ in range(20):
    px(rng.randrange(WX0, WX1), rng.randrange(WY0, WY1 - 8), rng.choice(["e8e4c8", "9aa4c8"]))
for dy in range(-5, 6):
    for dx in range(-5, 6):
        if dx * dx + dy * dy <= 25 and (dx - 2) ** 2 + (dy + 1) ** 2 > 16:
            px(280 + dx, 33 + dy, "efe8c4")
for xx in range(WX0, WX1):
    hh = int(5 + 3 * np.sin(xx * 0.15) + 2 * np.sin(xx * 0.37))
    rect(xx, WY1 - hh, xx + 1, WY1, "121a2c")
vline((WX0 + WX1) // 2, WY0, WY1, BEAM); hline(WX0, WX1, (WY0 + WY1) // 2, BEAM)
rect(WX0 - 5, WY1 + 1, WX1 + 5, WY1 + 4, "5a3a22"); hline(WX0 - 5, WX1 + 5, WY1 + 1, "7a5232")
# (the old quest board under the window moved to the left wall, see "contract board")


# ---------- lanterns ----------
def lantern(x, y):
    vline(x, 18, y, "3a3a3e")
    rect(x - 3, y, x + 4, y + 9, "2a2a2e")
    rect(x - 2, y + 3, x + 3, y + 8, "ffcf6a"); rect(x - 1, y + 4, x + 2, y + 7, "fff0b8")
    vline(x, y + 2, y + 9, "2a2a2e")
    rect(x - 2, y + 9, x + 3, y + 10, "2a2a2e")


lantern(48, 22)
lantern(229, 22)

# ---------- foreground: the bar counter ----------
# top surface (seen slightly from above), thick front edge, panelled front.
rect(0, CTOP, W, CTOP + 7, "7a5232")
hline(0, W, CTOP, "a87a4a")          # far edge catches the light
hline(0, W, CTOP + 1, "8e6238")
for yy in (CTOP + 3, CTOP + 5):      # boards along the counter
    hline(0, W, yy, "6a4428")
x = 0
while x < W:  # board joints, staggered
    vline(x, CTOP + 1, CTOP + 3, "5a3820"); vline(x + 31, CTOP + 3, CTOP + 5, "5a3820"); vline(x + 13, CTOP + 5, CTOP + 7, "5a3820")
    x += rng.choice([52, 60, 68])
for _ in range(40):  # wear and scratches
    sx, sy = rng.randrange(W), rng.randrange(CTOP + 2, CTOP + 7)
    hline(sx, sx + rng.randrange(2, 5), sy, rng.choice(["8a5e36", "6e4a2a"]))
rect(0, CTOP + 7, W, CTOP + 10, "4a2e1c"); hline(0, W, CTOP + 7, "2c1a10"); hline(0, W, CTOP + 9, "22150b")
# (keeper side under the counter: open shelving, drawn in its own section below)

# things on the counter (left part; the mortar sprite stands at x~30..58)
CT = CTOP + 5  # where objects stand
# candle in a brass holder
rect(19, CT - 8, 21, CT - 1, "e8dcc0"); px(19, CT - 9, "ffd36b"); px(20, CT - 10, "fff0b0"); px(20, CT - 9, "ffd36b")
rect(17, CT - 1, 24, CT + 1, BRASS); hline(17, 24, CT - 1, BRASS_HI)
# mug of ale
rect(66, CT - 6, 71, CT + 1, "7a5432"); hline(66, 71, CT - 6, "a0764a"); vline(66, CT - 5, CT + 1, "8e6440")
vline(71, CT - 5, CT, "5a3a22"); px(72, CT - 4, "5a3a22"); px(72, CT - 2, "5a3a22"); vline(73, CT - 4, CT - 1, "5a3a22")
hline(66, 71, CT - 7, "e8e0cc"); px(67, CT - 8, "e8e0cc")
# small potion bottle
rect(77, CT - 5, 81, CT + 1, "8f2a2a"); px(78, CT - 4, "c44a3e"); rect(78, CT - 8, 80, CT - 5, "8f2a2a"); px(78, CT - 9, "6b4a2a"); px(79, CT - 9, "6b4a2a")
# a few coins
for cx, cy in ((84, CT), (86, CT), (85, CT - 1)):
    hline(cx, cx + 2, cy, "e0b84a")
# rag and mugs further along (behind the client panel)
rect(128, CT - 1, 146, CT + 1, "b8ac90"); hline(130, 144, CT - 1, "d0c4a8")
for mx in (196, 204):
    rect(mx, CT - 5, mx + 5, CT + 1, "7a5432"); hline(mx, mx + 5, CT - 5, "a0764a")

# ---------- left wall: contract board (empty; the game pins one note per contract on it) ----------
# Frame BX0..BX1 x BY0..BY1, cork inside (BX0+2..BX1-2, BY0+2..BY1-2). main.gd/contract_board.gd use these numbers.
BX0, BY0, BX1, BY1 = 54, 28, 87, 66
brng = random.Random(11)  # own rng so the board does not reshuffle the rest of the picture
vline(BX0 + 6, 18, BY0 - 4, "8a7050"); vline(BX1 - 7, 18, BY0 - 4, "8a7050")   # hanging cords
rect(BX0 - 1, BY0 - 1, BX1 + 1, BY1 + 2, OUT)                                    # shadow/outline
rect(BX0, BY0, BX1, BY1, "5a3a22")
hline(BX0, BX1, BY0, "7a5232"); vline(BX0, BY0, BY1, "6e4a2c")
hline(BX0, BX1, BY1 - 1, "2c1a10"); vline(BX1 - 1, BY0, BY1, "3a2414")
CORK = ["8a6a42", "7e6038", "94744a", "806440"]
for yy in range(BY0 + 2, BY1 - 2):
    for xx in range(BX0 + 2, BX1 - 2):
        px(xx, yy, CORK[brng.randrange(4)] if brng.random() < 0.55 else "8a6a42")
hline(BX0 + 2, BX1 - 2, BY0 + 2, "6a4e30"); vline(BX0 + 2, BY0 + 2, BY1 - 2, "6e5232")  # inner shadow
for nx in (BX0 + 6, BX1 - 7):                                                      # nails
    px(nx, BY0 + 1, "9a9aa2"); px(nx, BY0, "c8c8d0")
# small header plank with a crossed-swords mark
rect(BX0 + 9, BY0 - 4, BX1 - 9, BY0 + 1, "6a4426"); hline(BX0 + 9, BX1 - 9, BY0 - 4, "8a6038"); hline(BX0 + 9, BX1 - 9, BY0, "3a2414")
cx = (BX0 + BX1) // 2
for i in range(4):
    px(cx - 2 + i, BY0 - 3 + i * 3 // 4, "b8bcc4"); px(cx + 1 - i, BY0 - 3 + i * 3 // 4, "b8bcc4")
px(cx - 2, BY0 - 1, BRASS); px(cx + 1, BY0 - 1, BRASS)

# ---------- keeper side: open shelving under the counter = the storages ----------
# Compartments (bg px, x0..x1 inclusive-exclusive): main.gd uses the same numbers (STORAGE_RECTS).
#   Погріб 3..74, Комора 78..150, Скриня 154..226, Шафа 230..296; Горище = ladder 300..319 up to the ceiling hatch.
urng = random.Random(23)  # own rng: the hall above stays pixel-identical
UY0, UY1 = CTOP + 10, H          # 104..180
SHELF = 140                      # middle shelf plank top
POSTS = [(0, 3), (74, 78), (150, 154), (226, 230), (296, 300)]
BACK = ["2a190d", "2e1b0f", "27170c", "2c1a0e"]
# back boards (vertical planks)
x = 0
while x < W:
    w = urng.choice([7, 8, 9])
    rect(x, UY0, x + w, UY1, BACK[urng.randrange(4)])
    vline(x, UY0, UY1, "1e110a")
    for _ in range(2):
        gy = urng.randrange(UY0 + 2, UY1 - 4)
        vline(x + urng.randrange(2, w - 1), gy, gy + urng.randrange(3, 7), "24150b")
    x += w
# underside of the counter top (thick beam) + its shadow
rect(0, UY0, W, UY0 + 3, "3a2414"); hline(0, W, UY0 + 3, "1a0f0a")
# posts
for p0, p1 in POSTS:
    rect(p0, UY0, p1, UY1, "4a2e1c")
    vline(p0, UY0, UY1, "5e3c25"); vline(p1 - 1, UY0, UY1, "2c1a10")
    for yy in (UY0 + 6, SHELF + 8, UY1 - 8):
        px(p0 + (p1 - p0) // 2, yy, "6a6a72")
# shelf plank + floor


def plank(x0, x1, y):
    rect(x0, y, x1, y + 4, "5a3a22"); hline(x0, x1, y, "7a5232"); hline(x0, x1, y + 3, "2c1a10")
    hline(x0, x1, y + 4, "1a0f0a")


for (a, _), (_, b) in zip(POSTS[1:], POSTS[:-1]):
    plank(b, a, SHELF)
rect(0, UY1 - 4, W, UY1, "3d2717"); hline(0, W, UY1 - 4, "5a3a22")
ST = SHELF        # objects on the shelf stand on y = ST - 1
FL = UY1 - 4      # objects on the floor stand on y = FL - 1


def disc(cx, cy, r, c, ring=None, ring_c=None):
    for yy in range(-r, r + 1):
        for xx in range(-r, r + 1):
            d2 = xx * xx + yy * yy
            if d2 <= r * r:
                px(cx + xx, cy + yy, c)
                if ring is not None and d2 >= (r - ring) ** 2:
                    px(cx + xx, cy + yy, ring_c)


def bottle(x, base, body, h=15, neck=5, w=4):
    rect(x, base - h, x + w, base, body)
    vline(x, base - h, base, OUT); vline(x + w, base - h + 1, base, OUT)
    hx_ = hx(body)
    vline(x + 1, base - h + 1, base - 2, np.clip(hx_ * 1.6 + 20, 0, 255))
    rect(x + 1, base - h - neck, x + w - 1, base - h, body)
    rect(x + 1, base - h - neck - 2, x + w - 1, base - h - neck, "8a6a42")


# --- Shelves are empty: the game draws the real stock on them (SHELF_* below -> shelf_items.png).
# a few cobwebs in the upper corners so the empty compartments do not look unfinished
for cx_, dir_ in ((4, 1), (73, -1), (155, 1), (295, -1)):
    for k in range(5):
        px(cx_ + dir_ * k, UY0 + 4 + k // 2, "5a4a3e")
        px(cx_ + dir_ * (k // 2), UY0 + 4 + k, "5a4a3e")
    px(cx_ + dir_ * 2, UY0 + 6, "6a5a4c")

# --- 5. Горище (resources): ladder from the keeper's floor up through a hatch in the ceiling
rect(299, 0, W, 13, "120a06")                                  # dark hatch opening
hline(297, W, 12, BEAM_HI); rect(297, 12, W, 14, BEAM)
for lx in (301, 315):                                          # rails
    rect(lx, 0, lx + 3, H, "7a5232")
    vline(lx, 0, H, "9a6a40"); vline(lx + 2, 0, H, "4a2e1c")
for ry in range(4, H, 9):                                      # rungs
    rect(303, ry, 315, ry + 2, "8a6038"); hline(303, 315, ry + 2, "3a2414")
# a sack of herbs peeking out of the hatch
rect(303, 6, 312, 12, "8a7454"); hline(303, 312, 6, "b8a07a")
for k in range(3):
    px(305 + k * 3, 5, "4f7a3a"); px(306 + k * 3, 4, "6a8a3a")

# ---------- counter top, right side: service bell and the ledger ----------
# bell (main.gd BELL_RECT)
BLX = 249
rect(BLX - 6, CT - 1, BLX + 7, CT + 1, "4a2e1c"); hline(BLX - 6, BLX + 7, CT - 1, "6e4a2c")   # wooden base
for yy in range(8):
    half = [2, 3, 4, 4, 5, 5, 5, 6][yy]
    hline(BLX - half, BLX + half + 1, CT - 9 + yy, BRASS)
    px(BLX - half, CT - 9 + yy, OUT); px(BLX + half, CT - 9 + yy, OUT)
    px(BLX + half - 1, CT - 9 + yy, "8a6a2e")
hline(BLX - 2, BLX + 3, CT - 10, OUT)
hline(BLX - 6, BLX + 7, CT - 1, "8a6a2e"); hline(BLX - 6, BLX + 7, CT - 2, "c8a050")
rect(BLX, CT - 13, BLX + 1, CT - 10, "3a3a3e"); hline(BLX - 1, BLX + 2, CT - 13, BRASS_HI)   # plunger
vline(BLX - 2, CT - 8, CT - 4, "fff0b0"); px(BLX - 1, CT - 8, "fff0b0")    # shine
# ledger book (main.gd BOOK_RECT): thick closed book, slightly from above
BKX0, BKX1 = 262, 283
rect(BKX0, CT - 5, BKX1, CT + 1, "6a1e1e")                       # cover
hline(BKX0, BKX1, CT - 5, "8a2e2a")
rect(BKX0 + 1, CT - 1, BKX1 - 1, CT + 1, "e8dcc0"); hline(BKX0 + 1, BKX1 - 1, CT, "c8bca0")    # pages
vline(BKX0, CT - 5, CT + 1, "3a1010")
for cx_ in (BKX0 + 1, BKX1 - 3):                                 # brass corners
    rect(cx_, CT - 5, cx_ + 2, CT - 3, BRASS)
rect(BKX0 + 8, CT - 4, BKX0 + 13, CT - 2, BRASS_HI)              # title plate
vline(BKX0 + 16, CT - 5, CT + 3, "c8a03a"); px(BKX0 + 16, CT + 3, "a8802a")  # bookmark ribbon
# inkwell + quill
rect(287, CT - 3, 292, CT + 1, "1e1e2a"); hline(287, 292, CT - 3, "3a3a4a")
for k in range(7):
    px(289 + k // 2, CT - 4 - k, "e8e0d0")
px(292, CT - 11, "c8c0b0")

UNDER_LIGHTS = [
    (38, 122, 40, 0.28), (114, 122, 40, 0.28), (190, 122, 40, 0.28), (262, 122, 40, 0.28),
    (38, 160, 36, 0.18), (114, 160, 36, 0.18), (190, 160, 36, 0.18), (262, 160, 36, 0.18),
    (255, CT - 6, 26, 0.2),
]

# ---------- lighting ----------
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
light = np.full((H, W), 0.48, dtype=np.float32)
for lx, ly, r, s in [
    (155, 78, 72, 0.85),   # fireplace
    (48, 28, 55, 0.55),    # lantern left
    (229, 28, 55, 0.45),   # lantern right
    (20, CT - 8, 34, 0.45),  # candle on the counter
    (124, 40, 18, 0.25), (186, 40, 18, 0.25),
] + UNDER_LIGHTS:
    d = np.sqrt((xx - lx) ** 2 + ((yy - ly) * 1.15) ** 2) / r
    light += s * np.clip(1 - d, 0, 1) ** 1.6
light *= 1 - 0.35 * np.clip((18 - yy) / 18, 0, 1)
# counter front face falls into shadow
light *= 1 - 0.18 * np.clip((yy - (CTOP + 8)) / 10, 0, 1)
light = np.clip(light, 0, 1.35)
bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16
q = np.floor(light * 8 + bayer[yy.astype(int) % 4, xx.astype(int) % 4]) / 8
tint = np.stack([q, q * 0.93, q * 0.80], axis=-1)
warm = np.clip(q - 0.6, 0, 1)[..., None] * np.array([0.10, 0.04, -0.02])
out = img * (tint + warm)
emissive = np.zeros((H, W), bool)
for c in ("ffcf6a", "fff0b8", "ffd36b", "fff3c0", "ff9a3c", "e0582a", "fff0b0", "efe8c4", "e8e4c8"):
    emissive |= np.all(np.abs(img - hx(c)) < 1, axis=-1)
out[emissive] = img[emissive]
out[WY0:WY1, WX0:WX1] = np.maximum(out[WY0:WY1, WX0:WX1], img[WY0:WY1, WX0:WX1] * 0.9)
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").save(sys.argv[1])
print("saved", sys.argv[1])
MULT = tint + warm
exec(open(__file__.replace("gen_bg6.py", "shelf_items.py"), encoding="utf-8").read())
