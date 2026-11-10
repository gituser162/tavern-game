"""Pixel-art market background, 320x180 (x4 = 1280x720), same style as tavern.png / forest.png.
market.png - town market square on a sunny morning: timber houses, a well, striped stall awnings,
bunting, cobblestones, crates/sacks/baskets in the foreground corners.
The middle of the picture is calm (cobbles) because the item cards are drawn over it.
Usage: python gen_market.py <out_dir>   (needs gen_locations.py next to it for the Canvas class)
"""
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_locations import Canvas, hx, W, H, XX, YY, BAYER  # noqa: E402

OUT = "1a0f0a"
GROUND = 92


def house(cv, x0, x1, base, top, wall, roof, rng):
    """Timber-framed town house with a pitched roof."""
    cv.rect(x0, top, x1, base, wall)
    # timber frame
    beam = "4a3020"
    cv.rect(x0, top, x0 + 2, base, beam)
    cv.rect(x1 - 2, top, x1, base, beam)
    mid = (top + base) // 2
    cv.hline(x0, x1, mid, beam)
    cv.hline(x0, x1, top, beam)
    for bx in range(x0 + 10, x1 - 6, 12):
        cv.vline(bx, top, base, beam)
        # diagonal braces in the upper floor
        for t in range(mid - top):
            cv.px(bx + 1 + t * 5 // max(1, mid - top), top + t, beam)
    # windows
    for wx in range(x0 + 4, x1 - 8, 12):
        for wy in (top + 4, mid + 4):
            if wy + 7 > base - 2:
                continue
            cv.rect(wx, wy, wx + 5, wy + 6, "2a2a3a")
            cv.rect(wx + 1, wy + 1, wx + 4, wy + 5, "6a8aa8")
            cv.px(wx + 1, wy + 1, "b8d0e0")
            cv.vline(wx + 2, wy + 1, wy + 5, "3a3040")
            cv.hline(wx - 1, wx + 6, wy + 6, "5a3a24")  # sill
            if rng.random() < 0.5:  # flower box
                cv.hline(wx, wx + 5, wy + 7, "5a3a24")
                for fx in range(wx, wx + 5, 2):
                    cv.px(fx, wy + 6, rng.choice(["c84a4a", "e8c050", "d070a0"]))
    # roof
    h = (x1 - x0) // 2 + 2
    rt = top - h // 2
    for y in range(rt, top + 1):
        t = (y - rt) / max(1, top - rt)
        half = int(t * (x1 - x0 + 8) / 2)
        cx = (x0 + x1) // 2
        cv.hline(cx - half, cx + half, y, roof)
        if y % 3 == 0:
            cv.hline(cx - half + 1, cx + half - 1, y, np.array(hx(roof)) * 0.8)
    cv.hline((x0 + x1) // 2 - (x1 - x0 + 8) // 2, (x0 + x1) // 2 + (x1 - x0 + 8) // 2, top, "3a2418")
    # chimney
    if rng.random() < 0.7:
        chx = x0 + (x1 - x0) * 2 // 3
        cv.rect(chx, rt + 2, chx + 4, rt + 10, "6a5a50")
        cv.hline(chx - 1, chx + 5, rt + 2, "4a4038")


def awning(cv, x0, x1, y, depth, c1, c2):
    """Striped stall awning seen from the front, with a scalloped edge."""
    for yy in range(y, y + depth):
        for x in range(x0, x1):
            col = c1 if ((x - x0) // 5) % 2 == 0 else c2
            shade = 0.82 + 0.18 * (yy - y) / max(1, depth - 1)
            cv.img[yy, x] = hx(col) * shade
    for x in range(x0, x1):
        k = (x - x0) % 5
        drop = 2 if k in (1, 2, 3) else 1
        col = c1 if ((x - x0) // 5) % 2 == 0 else c2
        for d in range(drop):
            cv.px(x, y + depth + d, np.array(hx(col)) * 0.75)
    cv.hline(x0, x1, y, "3a2418")


# Stalls, one per category the market sells. Rects (bg px) are copied to main.gd MARKET_STALLS.
STALLS = [
    # cat, x0, x1, awning colours, goods
    ("food", 6, 62, ("c84a3a", "e8dcc0"), ["bread", "cheese", "apples", "bread"]),
    ("drink", 69, 125, ("b8862e", "e8d8a0"), ["mugs", "bottles", "mugs"]),
    ("resource", 132, 188, ("4a8a4a", "e0e8b0"), ["herbs", "mandrake", "crystals", "herbs"]),
    ("gear", 195, 251, ("3a5a8a", "c8ccd0"), ["swords", "shields", "helmet"]),
    ("magic", 258, 314, ("6a3a8a", "e8c050"), ["scrolls", "orb", "amulet", "potions"]),
]
AWNING_Y = 58
SIGN_Y = 45
STALL_TOP = 43    # top of the clickable rect (sign included)
STALL_BOTTOM = 112


def sign(cv, cx, y, cat):
    """Hanging wooden sign with a tiny picture of what the stall sells."""
    cv.vline(cx - 4, y - 3, y, "3a2418")
    cv.vline(cx + 4, y - 3, y, "3a2418")
    cv.rect(cx - 7, y, cx + 8, y + 11, "7a5430")
    cv.hline(cx - 7, cx + 8, y, "9a6e40")
    cv.hline(cx - 7, cx + 8, y + 10, "3a2418")
    cv.vline(cx - 7, y, y + 11, "3a2418")
    cv.vline(cx + 7, y, y + 11, "3a2418")
    x, yy = cx - 4, y + 2
    pics = {
        "food": ["..####..", ".#oooo#.", "#oooooo#", "#oooooo#", "########", "........"],
        "drink": ["#####...", "#ffff##.", "#oooo#.#", "#oooo#.#", "#oooo##.", "#####..."],
        "resource": ["....##..", "...###..", "..####..", ".####...", ".##.....", "#......."],
        "gear": [".......#", "......#.", ".....#..", "#..##...", ".##.....", "#.#....."],
        "magic": ["...#....", "...#....", "#######.", "..###...", ".##.##..", ".#...#.."],
    }
    cols = {"food": {"#": "6a3a18", "o": "e0a050"}, "drink": {"#": "4a3020", "o": "e8b048", "f": "f4f0e4"},
            "resource": {"#": "5ab048"}, "gear": {"#": "d0d8e0"}, "magic": {"#": "f0d060"}}
    for j, row in enumerate(pics[cat]):
        for i, ch in enumerate(row):
            if ch != ".":
                cv.px(x + i, yy + j, cols[cat].get(ch, "ffffff"))


def goods_item(cv, g, x, ctop, rng):
    """Draws one pile of goods standing on the counter at x; returns its width."""
    if g == "apples":
        cv.rect(x, ctop - 3, x + 7, ctop, "8a6a42")
        for ax in range(x, x + 7, 2):
            cv.px(ax, ctop - 4, rng.choice(["c83a2e", "d85a3a", "a8c048"]))
            cv.px(ax + 1, ctop - 4, "e86a4a")
        return 9
    if g == "bread":
        cv.ellipse(x + 3, ctop - 2, 3.5, 2, "c08a48")
        cv.hline(x + 1, x + 5, ctop - 3, "d8a860")
        return 8
    if g == "cheese":
        cv.ellipse(x + 3, ctop - 2, 3.5, 2.2, "e8c050")
        cv.px(x + 2, ctop - 2, "c8a030")
        cv.px(x + 4, ctop - 3, "c8a030")
        return 8
    if g == "mugs":
        for bx in range(x, x + 8, 4):
            cv.rect(bx, ctop - 4, bx + 3, ctop, "8a6038")
            cv.hline(bx, bx + 3, ctop - 5, "f4f0e4")
            cv.px(bx + 3, ctop - 3, "5a3a20")
        return 10
    if g == "bottles":
        for bx in range(x, x + 6, 2):
            col = rng.choice(["3a6a3a", "6a3a5a", "4a5a8a"])
            cv.rect(bx, ctop - 5, bx + 2, ctop, col)
            cv.px(bx, ctop - 6, col)
            cv.px(bx, ctop - 5, "b8d0c0")
        return 8
    if g == "herbs":
        for bx in range(x, x + 7, 2):
            cv.vline(bx, ctop - 5, ctop, "4a7a2a")
            cv.px(bx - 1, ctop - 4, "6aa83a")
            cv.px(bx + 1, ctop - 3, "6aa83a")
        return 9
    if g == "mandrake":
        cv.ellipse(x + 3, ctop - 2, 2.5, 2, "b89060")
        cv.vline(x + 3, ctop - 6, ctop - 3, "5ab048")
        cv.px(x + 2, ctop - 6, "5ab048")
        cv.px(x + 4, ctop - 6, "5ab048")
        return 8
    if g == "crystals":
        for bx, h in [(x, 4), (x + 2, 6), (x + 4, 3)]:
            cv.rect(bx, ctop - h, bx + 2, ctop, "8ab8e8")
            cv.px(bx, ctop - h, "e0f0ff")
        return 8
    if g == "swords":
        for bx in range(x, x + 6, 3):
            cv.vline(bx, ctop - 9, ctop - 2, "b8c0c8")
            cv.hline(bx - 1, bx + 2, ctop - 2, "8a6a3a")
            cv.vline(bx, ctop - 2, ctop, "5a3a24")
        return 8
    if g == "shields":
        cv.ellipse(x + 4, ctop - 4, 3.5, 4, "8a5a30")
        cv.ellipse(x + 4, ctop - 4, 1.5, 1.5, "c8ccd0")
        return 10
    if g == "helmet":
        cv.ellipse(x + 3, ctop - 2, 3.5, 3, "a8b0b8")
        cv.hline(x, x + 7, ctop - 1, "6a7078")
        cv.px(x + 2, ctop - 4, "e0e8f0")
        return 9
    if g == "scrolls":
        for i in range(2):
            cv.rect(x + i * 4, ctop - 3, x + i * 4 + 3, ctop, "e8dcb0")
            cv.hline(x + i * 4, x + i * 4 + 3, ctop - 2, "c84a3a")
        return 9
    if g == "orb":
        cv.rect(x + 1, ctop - 1, x + 6, ctop, "5a3a20")
        cv.ellipse(x + 3, ctop - 4, 2.5, 2.5, "8a62d0")
        cv.px(x + 2, ctop - 5, "e0d0ff")
        return 8
    if g == "amulet":
        cv.vline(x + 1, ctop - 6, ctop - 2, "e8c050")
        cv.vline(x + 5, ctop - 6, ctop - 2, "e8c050")
        cv.hline(x + 1, x + 6, ctop - 6, "e8c050")
        cv.rect(x + 2, ctop - 2, x + 5, ctop, "4ac8e8")
        return 8
    if g == "potions":
        for bx in range(x, x + 8, 3):
            col = rng.choice(["c84a8a", "4ac8a8", "a8e050", "e8a040"])
            cv.ellipse(bx + 1, ctop - 2, 1.5, 1.6, col)
            cv.px(bx + 1, ctop - 4, "c8c0b0")
            cv.px(bx, ctop - 3, "ffffff")
        return 9
    return 4


def hanging(cv, cat, hx_, y, rng):
    """Things hung under the awning, matching the stall."""
    cv.vline(hx_, y, y + 3, "3a2418")
    y += 3
    if cat == "food":
        cv.rect(hx_ - 1, y, hx_ + 1, y + 6, rng.choice(["a85a3a", "8a3a2a"]))
    elif cat == "drink":
        cv.rect(hx_ - 1, y, hx_ + 2, y + 4, "8a6038")
        cv.hline(hx_ - 1, hx_ + 2, y, "f4f0e4")
    elif cat == "resource":
        cv.rect(hx_ - 1, y, hx_ + 2, y + 5, "5a8a3a")
        cv.px(hx_, y + 5, "3a6a2a")
    elif cat == "gear":
        cv.vline(hx_, y, y + 7, "c8d0d8")
        cv.hline(hx_ - 1, hx_ + 2, y + 1, "8a6a3a")
    else:
        cv.rect(hx_ - 1, y, hx_ + 2, y + 4, "e8b048")
        cv.px(hx_, y + 1, "fff0b0")


def stall(cv, cat, x0, x1, colours, goods, rng):
    """Market stall: sign, awning on two poles, a wooden counter with goods of its category."""
    y = AWNING_Y
    ctop = GROUND + 4
    cv.rect(x0 + 1, y, x0 + 3, ctop + 12, "4a3020")
    cv.rect(x1 - 3, y, x1 - 1, ctop + 12, "4a3020")
    cv.rect(x0 + 3, y + 8, x1 - 3, ctop, "3a2a22")  # back cloth in shadow
    # shelf on the back cloth with more goods
    cv.hline(x0 + 4, x1 - 4, ctop - 12, "5a3a20")
    x = x0 + 6
    k = 0
    while x < x1 - 12:
        x += goods_item(cv, goods[(k + 1) % len(goods)], x, ctop - 12, rng) + 1
        k += 1
    awning(cv, x0 - 2, x1 + 2, y, 8, colours[0], colours[1])
    for hx_ in range(x0 + 7, x1 - 4, 9):
        hanging(cv, cat, hx_, y + 9, rng)
    sign(cv, (x0 + x1) // 2, SIGN_Y, cat)
    # counter
    cv.rect(x0, ctop, x1, ctop + 12, "6a4628")
    cv.hline(x0, x1, ctop, "8a6038")
    cv.hline(x0, x1, ctop + 11, "3a2418")
    for px_ in range(x0 + 6, x1, 9):
        cv.vline(px_, ctop + 1, ctop + 11, "52341e")
    x = x0 + 3
    k = 0
    while x < x1 - 8:
        x += goods_item(cv, goods[k % len(goods)], x, ctop, rng) + 1
        k += 1


def crate(cv, x, y, w, h):
    cv.rect(x, y, x + w, y + h, "7a5430")
    cv.rect(x, y, x + w, y + 1, "9a6e40")
    cv.rect(x, y + h - 1, x + w, y + h, "3a2418")
    cv.vline(x, y, y + h, "3a2418")
    cv.vline(x + w - 1, y, y + h, "3a2418")
    for yy in range(y + 3, y + h - 1, 4):
        cv.hline(x + 1, x + w - 1, yy, "5a3a20")
    for t in range(min(w, h) - 2):
        cv.px(x + 1 + t * (w - 2) // max(1, h - 2), y + 1 + t, "5a3a20")


def sack(cv, x, y, r, col):
    cv.ellipse(x, y, r, r * 0.9, col)
    cv.ellipse(x - 1, y - 1, r * 0.6, r * 0.5, np.array(hx(col)) * 1.12)
    cv.rect(x - 2, y - r - 2, x + 2, y - r + 1, col)
    cv.hline(x - 2, x + 2, y - r + 1, "4a3020")
    cv.hline(x - r + 1, x + r - 1, int(y + r * 0.9), "3a2418")


def basket(cv, x, y, w, fruit):
    cv.rect(x, y, x + w, y + 6, "9a7040")
    for xx in range(x, x + w, 2):
        cv.vline(xx, y, y + 6, "7a5430")
    cv.hline(x, x + w, y, "b8884a")
    cv.hline(x, x + w, y + 6, "3a2418")
    for xx in range(x + 1, x + w - 1):
        cv.px(xx, y - 1, fruit[xx % len(fruit)])
        if xx % 2:
            cv.px(xx, y - 2, fruit[(xx + 1) % len(fruit)])


def market(path):
    cv = Canvas(37)
    rng = cv.rng
    # morning sky
    cv.gradient(0, GROUND, "a8d0e8", "e8d8b0", 7)
    # clouds
    for cx, cy, s in [(40, 16, 1.0), (150, 10, 1.3), (262, 20, 0.9)]:
        for dx, dy, rx, ry in [(0, 0, 12, 4), (8, -3, 8, 4), (-8, 1, 7, 3), (14, 1, 6, 3)]:
            cv.ellipse(cx + dx * s, cy + dy * s, rx * s, ry * s, "f4f0e4")
        cv.hline(int(cx - 14 * s), int(cx + 18 * s), int(cy + 3 * s), "d8dce0")
    # far roofs / castle silhouette
    far = "9aa8b8"
    for x in range(0, W, 1):
        h = 8 + int(4 * math.sin(x * 0.13) + 3 * math.sin(x * 0.041 + 1))
        cv.vline(x, 52 - h, 60, far)
    cv.rect(146, 22, 156, 52, far)  # tower
    for x in range(146, 157, 3):
        cv.rect(x, 19, x + 2, 22, far)
    cv.rect(150, 10, 151, 19, "7a8898")
    cv.rect(151, 10, 156, 13, "c84a4a")  # flag
    # town houses behind the square
    walls = ["d8c8a8", "c8b898", "e0d0b0", "cfc0a0", "d0b8a0"]
    roofs = ["8a3a2a", "6a4a3a", "9a4a2e", "5a5a6a", "7a3a2a"]
    x = -6
    i = 0
    while x < W:
        w = rng.randrange(34, 48)
        top = rng.randrange(44, 56)
        house(cv, x, x + w, GROUND, top, walls[i % 5], roofs[(i * 2) % 5], rng)
        x += w + rng.randrange(0, 3)
        i += 1
    # cobblestone square: rows get taller towards the viewer, each stone has its own tint
    cv.rect(0, GROUND, W, H, "4a4238")
    y = GROUND + 1
    r = 0
    while y < H:
        t = (y - GROUND) / (H - GROUND)
        rh = 2 + int(t * 6)
        sw = 5 + int(t * 12)
        x = -rng.randrange(0, sw)
        while x < W:
            w = sw + rng.randrange(-1, 2) * (1 + int(t * 2))
            base = hx(rng.choice(["8a8070", "827868", "948a78", "7a7264", "8e8272"])) * (0.85 + 0.2 * t)
            cv.rect(x + 1, y, x + w, y + rh, base)
            cv.hline(x + 2, x + w - 1, y, base * 1.16)
            if rh > 3:
                cv.hline(x + 1, x + w, y + rh - 1, base * 0.8)
                cv.px(x + 1, y, "4a4238")
                cv.px(x + w - 1, y, "4a4238")
            x += w
        y += rh + 1
        r += 1
    # a lighter worn path to the well
    for y in range(GROUND, H):
        t = (y - GROUND) / (H - GROUND)
        hw = 16 + 70 * t
        m = (np.abs(XX[y] - 160) < hw)
        cv.img[y, m] *= 1.06
    # five stalls, one per category
    for cat, x0, x1, colours, goods in STALLS:
        stall(cv, cat, x0, x1, colours, goods, rng)
    # bunting across the top
    for (ax, ay), (bx, by) in [((0, 30), (110, 36)), ((110, 36), (210, 34)), ((210, 34), (320, 28))]:
        n = bx - ax
        for k in range(n):
            t = k / n
            x = ax + k
            y = ay + (by - ay) * t + 6 * math.sin(math.pi * t)
            cv.px(x, int(y), "4a3020")
            if k % 7 == 2:
                col = ["c84a3a", "e8c050", "3a6aa8", "4a8a4a", "e8dcc0"][(x // 7) % 5]
                for d in range(4):
                    cv.hline(x - 2 + d // 2, x + 3 - d // 2, int(y) + 1 + d, col)
    # people silhouettes in the back (small, muted)
    for px_, col in [(66, "5a4a6a"), (129, "6a4a3a"), (192, "4a5a4a"), (255, "7a5a3a")]:
        py = GROUND + 2
        cv.rect(px_ - 2, py - 10, px_ + 2, py, col)
        cv.ellipse(px_, py - 12, 1.8, 2, "c8a080")
        cv.hline(px_ - 2, px_ + 2, py - 14, np.array(hx(col)) * 0.8)
    # pigeons
    for px_, py in [(110, 132), (114, 134), (226, 140)]:
        cv.rect(px_, py, px_ + 3, py + 2, "8a8a90")
        cv.px(px_ + 3, py - 1, "6a6a70")
        cv.px(px_ + 4, py - 1, "e8a040")
    # foreground: crates, sacks, barrels and baskets in the corners
    crate(cv, 4, 140, 22, 18)
    crate(cv, 10, 124, 16, 16)
    sack(cv, 36, 160, 9, "b8a070")
    sack(cv, 50, 166, 8, "a89060")
    basket(cv, 60, 160, 14, ["c83a2e", "e86a4a", "a8c048"])
    basket(cv, 24, 166, 12, ["e8c050", "d8a030"])
    crate(cv, 292, 136, 24, 20)
    crate(cv, 270, 150, 18, 16)
    sack(cv, 262, 168, 9, "b8a070")
    basket(cv, 240, 164, 14, ["6a3a8a", "8a4aa8"])
    basket(cv, 300, 124, 12, ["c8a048", "e8c060"])
    # barrels
    for bx, by in [(84, 150), (230, 146)]:
        cv.rect(bx, by, bx + 14, by + 20, "6a4426")
        for yy in (by + 3, by + 16):
            cv.hline(bx, bx + 14, yy, "3a3a3a")
        cv.vline(bx + 3, by, by + 20, "7a5430")
        cv.vline(bx + 10, by, by + 20, "52341e")
        cv.hline(bx, bx + 14, by, "8a6038")
    # sunlight from the upper left
    sun = np.clip(1 - ((XX - 40) ** 2 / 260 ** 2 + (YY + 20) ** 2 / 220 ** 2), 0, 1)
    cv.light(sun, 0.12, 4)
    # vignette
    v = 1 - 0.35 * np.clip(((XX - W / 2) / (W / 2)) ** 2 + ((YY - H * 0.55) / (H * 0.7)) ** 2 - 0.25, 0, 1)
    cv.img *= v[..., None]
    cv.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    market(os.path.join(out, "market.png"))
