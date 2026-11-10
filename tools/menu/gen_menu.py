"""Pixel-art pieces of the main menu, same palette and light (upper left) as the tavern background.
- menu_sign.png: hanging tavern signboard 136x44 (bg pixels) with two chains; the title is written over it by the game.
- plank*.png: menu button plank 32x12 bg px, saved 4x bigger (128x48) so it is used as a 9-slice
  StyleBoxTexture (margins 16 px) and still looks like the 4x-scaled background.
Run: python3 gen_menu.py <project>/assets/ui"""
import os
import random
import sys
from PIL import Image


def c(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


OUT = c("1a0f0a")
WOOD = [c("a07448"), c("8a6038"), c("6a4426"), c("553420"), c("3e2616")]   # light -> dark
SEAM = c("2e1c10")
IRON = [c("9a9aa4"), c("6a6a72"), c("4a4a52"), c("2c2c32")]
BRASS = [c("f0d070"), c("c8a040"), c("8a6a22")]


def sign():
    W, H = 136, 44
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = im.load()
    rnd = random.Random(7)

    def put(x, y, col):
        if 0 <= x < W and 0 <= y < H:
            p[x, y] = col
    # chains from the top edge down to the board
    for cx in (22, W - 23):
        for y in range(0, 10):
            if y % 3 == 0:
                put(cx - 1, y, IRON[1]); put(cx + 1, y, IRON[2]); put(cx, y, IRON[3])
            else:
                put(cx, y, IRON[0] if y % 3 == 1 else IRON[1])
        # ring on the board
        for dx, dy, col in ((-1, 9, IRON[1]), (1, 9, IRON[2]), (-1, 10, IRON[2]), (1, 10, IRON[3]), (0, 11, IRON[2])):
            put(cx + dx, dy, col)
    # board: rows 10..43, 4 horizontal planks
    x0, x1, y0, y1 = 2, W - 3, 11, H - 2
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            plank = (y - y0) // 8
            row = (y - y0) % 8
            shade = 0 if row == 0 else (1 if row < 3 else (2 if row < 6 else 3))
            if (x * 7 + y * 13 + plank * 5) % 23 == 0:
                shade = min(4, shade + 1)
            put(x, y, WOOD[shade])
        if (y - y0) % 8 == 7:
            for x in range(x0, x1 + 1):
                put(x, y, SEAM if rnd.random() > 0.12 else WOOD[3])
    # wood grain streaks
    for _ in range(40):
        gx = rnd.randint(x0 + 3, x1 - 12)
        gy = rnd.randint(y0 + 1, y1 - 1)
        if (gy - y0) % 8 in (0, 7):
            continue
        for x in range(gx, gx + rnd.randint(4, 11)):
            put(x, gy, WOOD[3])
    # dark outline, cut corners
    for x in range(x0, x1 + 1):
        put(x, y0 - 1, OUT); put(x, y1 + 1, OUT)
    for y in range(y0, y1 + 1):
        put(x0 - 1, y, OUT); put(x1 + 1, y, OUT)
    # inner bevel: light top/left, dark bottom/right
    for x in range(x0, x1 + 1):
        put(x, y0, WOOD[0]); put(x, y1, WOOD[4])
    for y in range(y0, y1 + 1):
        put(x0, y, WOOD[1]); put(x1, y, WOOD[4])
    # iron corner brackets with brass nails
    for (bx, by, sx, sy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        for i in range(7):
            put(bx + sx * i, by, IRON[1 if sy > 0 else 2])
            put(bx, by + sy * i, IRON[1 if sx > 0 else 2])
            put(bx + sx * i, by + sy, IRON[2])
            put(bx + sx, by + sy * i, IRON[2])
        put(bx + sx * 3, by + sy * 1, BRASS[0]); put(bx + sx * 1, by + sy * 3, BRASS[1])
    # brass nails holding the chain rings
    for cx in (22, W - 23):
        put(cx, y0 + 1, BRASS[0]); put(cx + 1, y0 + 1, BRASS[2])
    return im


def plank(kind):
    W, H = 32, 12
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = im.load()
    pal = {
        "normal": WOOD,
        "hover": [c("b88a58"), c("a07448"), c("8a6038"), c("6a4426"), c("4a2e1c")],
        "pressed": [c("6a4426"), c("553420"), c("4a2e1c"), c("3e2616"), c("2e1c10")],
        "disabled": [c("5e5048"), c("524640"), c("463c36"), c("3a322c"), c("2c2622")],
    }[kind]
    for y in range(H):
        for x in range(W):
            if (x in (0, W - 1) and y in (0, H - 1)):
                continue
            if x in (0, W - 1) or y in (0, H - 1):
                p[x, y] = OUT
                continue
            row = y - 1
            shade = 0 if row == 0 else (1 if row < 4 else (2 if row < 8 else 3))
            if y == H - 2 or x == W - 2:
                shade = 4
            if x == 1 and y < H - 2:
                shade = min(shade, 1)
            if kind == "pressed" and row == 0:
                shade = 3
            p[x, y] = pal[shade]
    # grain only in the middle (stretched part), so the 9-slice looks right
    for (gx, gy, n) in ((6, 4, 9), (14, 7, 10), (5, 8, 6), (20, 3, 6)):
        for x in range(gx, gx + n):
            if 4 <= x < W - 4:
                p[x, gy] = pal[3]
    # brass nails at both ends
    if kind != "disabled":
        for nx in (2, W - 3):
            p[nx, 5] = BRASS[0] if kind != "pressed" else BRASS[1]
            p[nx, 6] = BRASS[2]
    return im.resize((W * 4, H * 4), Image.NEAREST)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sign().save(os.path.join(out, "menu_sign.png"))
    for k in ("normal", "hover", "pressed", "disabled"):
        plank(k).save(os.path.join(out, "plank_%s.png" % k))
    print("ok")
