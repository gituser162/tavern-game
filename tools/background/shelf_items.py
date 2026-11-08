"""Stock on the shelves under the counter (run from gen_bg6.py, which defines the palette, the light and MULT).
Every storage compartment is a grid of 8x8 cells on two levels (the middle shelf and the floor plank). Every item has a
shape in cells (GameData.ITEM_SIZES) and a sprite that fills exactly that box. The sprites are NOT lit: the game lights
them with shelf_light.png (the very light of the background) wherever they lie, so a moved bottle still matches the wall.
Output (env SHELF_OUT = folder of the Godot project):
  assets/objects/shelf_items.png  - atlas with one unlit sprite per item
  assets/objects/shelf_light.png  - light of the background (MULT / LIGHT_SCALE), 320x180
  scripts/shelf_layout.gd         - CELL, LIGHT_SCALE, ORIGINS {place: [top-left of each level grid]}, SPRITES {item: Rect2i}
"""
import os

CELL = 8
LIGHT_SCALE = 1.5
LEVEL_BOTTOMS = (SHELF, UY1 - 4)     # first row under each level = the plank's top
# place id: (x0, x1 of the compartment, cols, rows) - must match GameData.STORAGES
SHELF_PLACES = {
    "cellar": (3, 74, 8, 3),
    "pantry": (78, 150, 8, 3),
    "chest": (154, 226, 8, 3),
    "cabinet": (230, 296, 8, 3),
}
# item: (w, h) in cells - must match GameData.ITEM_SIZES
SIZES = {
    "ale": (2, 2), "mead": (2, 1), "wine": (1, 2),
    "bread": (1, 1), "chicken": (2, 1), "stew": (2, 2),
    "heal_potion": (1, 1), "antidote": (1, 2), "strength_potion": (2, 2),
    "shield": (2, 2), "chainmail": (2, 3), "axe": (1, 3),
    "fire_scroll": (2, 1), "moon_amulet": (1, 2), "sapphire_ring": (1, 1),
}


class Layer:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), np.float32)
        self.a = np.zeros((H, W), bool)

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.rgb[y, x] = hx(c)
            self.a[y, x] = True

    def rect(self, x0, y0, x1, y1, c):
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                self.px(xx, yy, c)

    def h(self, x0, x1, y, c):
        self.rect(x0, y, x1, y + 1, c)

    def v(self, x, y0, y1, c):
        self.rect(x, y0, x + 1, y1, c)

    def disc(self, cx, cy, r, c):
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r + r * 0.6:
                    self.px(cx + xx, cy + yy, c)

    def outline(self):
        """Dark 1px outline around everything drawn (like the painted props)."""
        a = self.a.copy()
        edge = np.zeros_like(a)
        edge[1:, :] |= a[:-1, :]; edge[:-1, :] |= a[1:, :]; edge[:, 1:] |= a[:, :-1]; edge[:, :-1] |= a[:, 1:]
        edge &= ~a
        self.rgb[edge] = hx(OUT)
        self.a |= edge




# ---------- sprites: f(L, cx, b) draws the item centred on cx, standing on row b (b = bottom of the box - 1) ----------

def s_ale(L, cx, b):          # small barrel of ale with iron hoops and a tap (2x2)
    x0 = cx - 4
    for yy in range(b - 10, b + 1):
        bulge = 1 if b - 8 <= yy <= b - 2 else 0
        L.h(x0 - bulge, x0 + 9 + bulge, yy, "6a4426")
        L.px(x0 - bulge, yy, "8a6038"); L.px(x0 + 8 + bulge, yy, "4a2e1c")
    for xx in (x0 + 2, x0 + 5):
        L.v(xx, b - 9, b, "5a3820")
    for yy in (b - 8, b - 2):
        L.h(x0 - 1, x0 + 10, yy, "55555c")
    L.h(x0, x0 + 9, b - 10, "8a6038")
    L.px(cx, b - 5, BRASS); L.px(cx, b - 4, BRASS_HI)


def s_mead(L, cx, b):         # drinking horn of mead lying on a little rest (2x1)
    L.h(cx - 4, cx + 4, b, "5a3a22")
    for i in range(12):           # horn from the wide mouth (left) to the tip (right)
        x = cx - 6 + i
        th = max(1, 4 - i // 3)
        top = b - 1 - th - (1 if i > 8 else 0)
        L.v(x, top, top + th, "d8c8a0" if i < 9 else "8a6a42")
    L.v(cx - 6, b - 5, b - 1, BRASS); L.px(cx - 5, b - 5, "f0c050"); L.px(cx - 5, b - 4, "e0a030")


def s_wine(L, cx, b):         # slim bottle of elven wine with a green label (1x2)
    L.rect(cx - 2, b - 8, cx + 3, b + 1, "5a1e3a")
    L.v(cx - 1, b - 7, b, "8a3a5a")
    L.rect(cx - 1, b - 11, cx + 2, b - 8, "4a1830")
    L.rect(cx - 1, b - 13, cx + 2, b - 11, "c8a868")
    L.rect(cx - 2, b - 5, cx + 3, b - 2, "4a8a5a"); L.px(cx, b - 4, BRASS_HI)


def s_bread(L, cx, b):        # round rye loaf (1x1)
    for yy, half in zip(range(b - 3, b + 1), (1, 2, 2, 2)):
        L.h(cx - half, cx + half + 1, yy, "8a5a2e")
        L.px(cx + half, yy, "5a3a1a")
    L.px(cx - 1, b - 3, "a87440"); L.px(cx, b - 3, "a87440")
    L.px(cx - 1, b - 1, "5a3a1a"); L.px(cx + 1, b - 2, "5a3a1a")


def s_chicken(L, cx, b):      # roast chicken on a plate (2x1)
    L.h(cx - 5, cx + 6, b, "b8b0a0")
    for yy, half in zip(range(b - 4, b), (2, 3, 4, 4)):
        L.h(cx - half, cx + half + 1, yy, "c07a32")
        L.px(cx - half, yy, "e0a050")
    L.px(cx + 4, b - 4, "c07a32"); L.px(cx + 5, b - 5, "e8e0d0"); L.px(cx + 6, b - 5, "e8e0d0")
    L.px(cx - 4, b - 4, "c07a32"); L.px(cx - 5, b - 5, "e8e0d0")


def s_stew(L, cx, b):         # iron pot of venison stew (2x2)
    for yy in range(b - 6, b + 1):
        half = [5, 5, 5, 5, 4, 4, 3][yy - (b - 6)]
        L.h(cx - half, cx + half + 1, yy, "3a3a42")
        L.px(cx - half + 1, yy, "5a5a64")
    L.h(cx - 5, cx + 6, b - 7, "4a4a52")
    L.h(cx - 4, cx + 5, b - 7, "7a3e22"); L.px(cx - 1, b - 7, "a85a2a"); L.px(cx + 2, b - 7, "6a8a3a")
    L.px(cx - 6, b - 5, "3a3a42"); L.px(cx + 6, b - 5, "3a3a42")
    L.px(cx - 1, b - 9, "6a5a50"); L.px(cx + 1, b - 10, "6a5a50")


def s_heal(L, cx, b):         # small round red flask (1x1)
    for yy, half in zip(range(b - 3, b + 1), (1, 2, 2, 1)):
        L.h(cx - half, cx + half + 1, yy, "a82a2a")
    L.px(cx - 1, b - 2, "e87060")
    L.px(cx, b - 4, "8a9a9a"); L.px(cx, b - 5, "8a6a42")


def s_antidote(L, cx, b):     # tall green vial (1x2)
    L.rect(cx - 2, b - 8, cx + 2, b + 1, "3a8a3a")
    L.v(cx - 1, b - 7, b, "7ac86a")
    L.rect(cx - 1, b - 11, cx + 1, b - 8, "9aaaaa")
    L.rect(cx - 1, b - 13, cx + 1, b - 11, "8a6a42")


def s_strength(L, cx, b):     # big square orange bottle with a bull label (2x2)
    L.rect(cx - 4, b - 8, cx + 5, b + 1, "c8702a")
    L.v(cx - 3, b - 7, b, "f0a050")
    L.rect(cx - 1, b - 11, cx + 2, b - 8, "8a9a9a")
    L.rect(cx - 2, b - 13, cx + 3, b - 11, "8a6a42")
    L.rect(cx - 2, b - 6, cx + 3, b - 2, "e8dcc0"); L.px(cx - 1, b - 5, "5a1e1e"); L.px(cx + 1, b - 5, "5a1e1e"); L.px(cx, b - 4, "5a1e1e")


def s_shield(L, cx, b):       # round oak shield standing on its edge (2x2)
    r = 6
    cy = b - r
    for yy in range(-r, r + 1):
        for xx in range(-r, r + 1):
            d2 = xx * xx + yy * yy
            if d2 <= r * r + 3:
                c = "8a5a2e" if (xx + 7) // 3 % 2 == 0 else "7a4e26"
                if d2 >= (r - 1) ** 2:
                    c = "55555c"
                L.px(cx + xx, cy + yy, c)
    L.disc(cx, cy, 1, "8a8e96"); L.px(cx - 1, cy - 1, "c8ccd4")


def s_chainmail(L, cx, b):    # chainmail shirt on a wooden stand (2x3)
    L.v(cx, b - 5, b + 1, "5a3a22"); L.h(cx - 4, cx + 5, b, "5a3a22")
    L.h(cx - 6, cx + 7, b - 20, "5a3a22"); L.v(cx, b - 21, b - 19, "5a3a22")
    for yy in range(b - 19, b - 4):
        half = 6 if yy < b - 13 else 4
        for xx in range(cx - half, cx + half + 1):
            L.px(xx, yy, "9a9ea6" if (xx + yy) % 2 == 0 else "6a6e76")
    L.h(cx - 2, cx + 3, b - 19, "3a3a42")
    L.h(cx - 4, cx + 5, b - 5, "8a6a42")


def s_axe(L, cx, b):          # battle axe standing upright on its haft (1x3)
    cx -= 1
    L.v(cx, b - 20, b + 1, "6a4426"); L.px(cx, b - 21, "55555c")
    for yy in range(b - 20, b - 12):
        w_ = [1, 2, 3, 3, 3, 3, 2, 1][yy - (b - 20)]
        L.h(cx + 1, cx + 1 + w_, yy, "9a9ea6")
        L.px(cx + w_, yy, "d8dce4")
    L.rect(cx - 2, b - 18, cx, b - 15, "7a7e86")


def s_scroll(L, cx, b):       # rolled scroll of fire with a red seal (2x1)
    L.rect(cx - 5, b - 3, cx + 6, b + 1, "e8d8b0")
    L.h(cx - 5, cx + 6, b - 3, "f0e4c4")
    L.v(cx - 6, b - 2, b, "a8987a"); L.v(cx + 6, b - 2, b, "a8987a")
    L.rect(cx - 1, b - 2, cx + 2, b + 1, "c83a1a"); L.px(cx, b - 3, "f07a2a"); L.px(cx, b - 4, "e0582a")


def s_amulet(L, cx, b):       # silver crescent amulet on a little stand (1x2)
    L.h(cx - 2, cx + 3, b, "4a2e1c"); L.v(cx, b - 12, b, "4a2e1c"); L.h(cx - 2, cx + 3, b - 12, "4a2e1c")
    L.px(cx - 2, b - 11, BRASS); L.px(cx - 2, b - 10, BRASS); L.px(cx + 2, b - 11, BRASS); L.px(cx + 2, b - 10, BRASS)
    L.px(cx - 1, b - 9, BRASS); L.px(cx + 1, b - 9, BRASS)
    for yy, xs in ((-7, (-2, 1, 2)), (-6, (-2, 2)), (-5, (-1, 0, 1))):
        for dx in xs:
            L.px(cx + dx, b + yy, "d8dce8")
    L.px(cx, b - 7, "8ab8f0")


def s_ring(L, cx, b):         # sapphire ring on a velvet cushion (1x1)
    L.h(cx - 2, cx + 3, b, "6a2a6a"); L.h(cx - 2, cx + 3, b - 1, "8a3a8a")
    L.px(cx - 1, b - 2, BRASS); L.px(cx + 1, b - 2, BRASS); L.px(cx - 1, b - 3, BRASS); L.px(cx + 1, b - 3, BRASS)
    L.px(cx, b - 4, "3a6ae0")


SPRITE_FN = {
    "ale": s_ale, "mead": s_mead, "wine": s_wine,
    "bread": s_bread, "chicken": s_chicken, "stew": s_stew,
    "heal_potion": s_heal, "antidote": s_antidote, "strength_potion": s_strength,
    "shield": s_shield, "chainmail": s_chainmail, "axe": s_axe,
    "fire_scroll": s_scroll, "moon_amulet": s_amulet, "sapphire_ring": s_ring,
}


def bake(item):
    """Unlit sprite exactly filling its w x h cell box (transparent around the drawing)."""
    w, h = SIZES[item]
    L = Layer()
    bx, by = 40, 40                       # draw somewhere in the empty layer, then cut the box out
    SPRITE_FN[item](L, bx + w * CELL // 2, by + h * CELL - 2)
    L.outline()
    box = (slice(by, by + h * CELL), slice(bx, bx + w * CELL))
    ys, xs = np.nonzero(L.a)
    assert ys.min() >= by and ys.max() < by + h * CELL and xs.min() >= bx and xs.max() < bx + w * CELL, \
        (item, xs.min() - bx, xs.max() - bx, ys.min() - by, ys.max() - by)
    rgb = np.clip(L.rgb[box], 0, 255).astype(np.uint8)
    alpha = (L.a[box] * 255).astype(np.uint8)
    return np.dstack([rgb, alpha])


def origins(place):
    x0, x1, cols, rows = SHELF_PLACES[place]
    gx = x0 + (x1 - x0 - cols * CELL) // 2
    return [(gx, bottom - rows * CELL) for bottom in LEVEL_BOTTOMS]


SHELF_OUT = os.environ.get("SHELF_OUT")
if SHELF_OUT:
    sprites = [(item, bake(item)) for item in SIZES]
    AW, x_, y_, row_h = 128, 0, 0, 0
    placed = []
    for item, rgba in sprites:
        h_, w_ = rgba.shape[:2]
        if x_ + w_ > AW:
            x_, y_, row_h = 0, y_ + row_h + 1, 0
        placed.append((item, x_, y_, w_, h_))
        x_ += w_ + 1
        row_h = max(row_h, h_)
    atlas = np.zeros((y_ + row_h + 1, AW, 4), np.uint8)
    for (item, ax, ay, w_, h_), (_, rgba) in zip(placed, sprites):
        atlas[ay:ay + h_, ax:ax + w_] = rgba
    Image.fromarray(atlas, "RGBA").save(os.path.join(SHELF_OUT, "assets/objects/shelf_items.png"))
    lm = np.clip(MULT / LIGHT_SCALE * 255, 0, 255).astype(np.uint8)
    Image.fromarray(lm, "RGB").save(os.path.join(SHELF_OUT, "assets/objects/shelf_light.png"))
    lines = [
        "extends RefCounted",
        "## GENERATED by tools/background/gen_bg6.py + shelf_items.py - do not edit by hand.",
        "## Shelves under the counter as puzzle grids: every storage place has two levels (middle shelf, floor plank),",
        "## each a grid of CELL x CELL bg pixels starting at ORIGINS[place][level]. Sprites are unlit; the game multiplies",
        "## them by LIGHT (x LIGHT_SCALE) at the spot where they lie.",
        "",
        "const CELL := %d" % CELL,
        "const LIGHT_SCALE := %.2f" % LIGHT_SCALE,
        'const ATLAS := "res://assets/objects/shelf_items.png"',
        'const LIGHT := "res://assets/objects/shelf_light.png"',
        "",
        "## place id -> [top-left of the grid on the middle shelf, on the floor plank] (bg px)",
        "const ORIGINS := {",
    ]
    for place in SHELF_PLACES:
        lines.append('\t"%s": [%s],' % (place, ", ".join("Vector2i(%d, %d)" % o for o in origins(place))))
    lines += ["}", "", "## item id -> its sprite in ATLAS (size = item cells x CELL)", "const SPRITES := {"]
    for item, ax, ay, w_, h_ in placed:
        lines.append('\t"%s": Rect2i(%d, %d, %d, %d),' % (item, ax, ay, w_, h_))
    lines += ["}", ""]
    open(os.path.join(SHELF_OUT, "scripts/shelf_layout.gd"), "w", encoding="utf-8").write("\n".join(lines))
    # preview: every compartment filled with its items (lit like in the game)
    prev = np.clip(out, 0, 255).astype(np.float32)
    demo = {"cellar": [("ale", 0, 0, 0), ("ale", 0, 2, 0), ("wine", 0, 4, 0), ("wine", 0, 5, 0), ("mead", 0, 6, 1), ("mead", 1, 0, 1), ("ale", 1, 2, 0)],
            "pantry": [("stew", 0, 0, 0), ("chicken", 0, 2, 1), ("bread", 0, 4, 1), ("bread", 0, 5, 1), ("chicken", 0, 6, 1), ("stew", 1, 0, 0)],
            "chest": [("chainmail", 0, 0, 0), ("shield", 0, 2, 1), ("axe", 0, 4, 0), ("amulet", 0, 5, 1), ("fire_scroll", 1, 0, 2), ("sapphire_ring", 1, 2, 1)],
            "cabinet": [("heal_potion", 0, 0, 1), ("antidote", 0, 1, 0), ("strength_potion", 0, 2, 0), ("heal_potion", 0, 4, 1), ("antidote", 1, 0, 0)]}
    spr = dict(sprites)
    spr["amulet"] = spr["moon_amulet"]
    for place, lst in demo.items():
        org = origins(place)
        for item, lvl, cx_, cy_ in lst:
            rgba = spr[item]
            h_, w_ = rgba.shape[:2]
            X, Y = org[lvl][0] + cx_ * CELL, org[lvl][1] + cy_ * CELL
            m = rgba[..., 3] > 0
            lit = rgba[..., :3].astype(np.float32) * MULT[Y:Y + h_, X:X + w_]
            prev[Y:Y + h_, X:X + w_][m] = lit[m]
    Image.fromarray(np.clip(prev, 0, 255).astype(np.uint8), "RGB").resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(SHELF_OUT, "shelf_preview.png"))
    print("shelf sprites:", len(sprites), "atlas", atlas.shape)
