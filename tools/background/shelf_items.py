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
# place id: (x0, x1 of the compartment, cols, rows) - must match GameData.STORAGES (rows = GameData.SHELF_ROWS: the
# tallest grid; at the start the top row is closed until the "Полиці" upgrade)
SHELF_PLACES = {
    "cellar": (3, 74, 8, 4),
    "pantry": (78, 150, 8, 4),
    "chest": (154, 226, 8, 4),
    "cabinet": (230, 296, 8, 4),
}
# item: (w, h) in cells - must match GameData.ITEM_SIZES
SIZES = {
    "ale": (1, 1), "mead": (2, 1), "wine": (1, 2),
    "bread": (1, 1), "chicken": (2, 1), "stew": (2, 2),
    "heal_potion": (1, 2), "antidote": (1, 2), "strength_potion": (1, 2),
    "shield": (2, 2), "chainmail": (2, 3), "axe": (1, 3),
    "fire_scroll": (2, 1), "moon_amulet": (1, 2), "sapphire_ring": (1, 1),
    "herb_soup": (1, 1), "berry_pie": (2, 1), "forest_roast": (2, 1), "luck_elixir": (1, 2),
    "mushroom_soup": (1, 1), "berry_uzvar": (1, 2), "chicken_pie": (2, 1),
    # swamp, lake and port (2026-11-08)
    "swamp_draught": (1, 2), "poison": (1, 2), "wisp_elixir": (1, 2), "rum": (1, 2),
    "fish_soup": (1, 1), "baked_pike": (2, 1), "crayfish_fry": (2, 1),
    # side-effect potions (2026-11-09)
    "murky_brew": (1, 2), "sleep_draught": (1, 2),
    # resources (2026-11-10: shelves take any item, so resources lie on them too)
    "herbs": (1, 1), "berries": (1, 1), "burdock": (1, 1), "mandrake": (1, 1), "bones": (1, 1), "grave_dust": (1, 1),
    "ether_essence": (1, 1), "crystal": (1, 1), "glow_mushroom": (1, 1), "swamp_moss": (1, 1), "toad": (1, 1),
    "nightshade": (1, 1), "wisp_jar": (1, 1), "lake_weed": (1, 1), "crayfish": (1, 1), "perch": (1, 1), "pike": (1, 1),
    "spices": (1, 1),
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

def s_ale(L, cx, b):          # wooden tankard of dark ale with a foam head and an iron hoop (1x1)
    L.rect(cx - 2, b - 3, cx + 2, b + 1, "6a4426")
    L.v(cx - 2, b - 3, b + 1, "8a6038")
    L.h(cx - 2, cx + 2, b - 1, "55555c")
    L.v(cx + 2, b - 3, b, "4a2e1c")
    L.h(cx - 2, cx + 2, b - 4, "f0e8d0")
    L.px(cx - 1, b - 5, "f0e8d0"); L.px(cx, b - 5, "e0d8c0")


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


def s_heal(L, cx, b):         # round red flask with a long glass neck and a cork (1x2)
    for yy, (l, r) in zip(range(b - 6, b + 1), ((1, 0), (2, 1), (3, 2), (3, 2), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "a82a2a")
    L.v(cx + 2, b - 4, b, "7a1a1a")
    L.px(cx - 2, b - 4, "e87060"); L.px(cx - 2, b - 3, "e87060")
    L.rect(cx - 1, b - 10, cx + 1, b - 6, "9aaaaa")
    L.px(cx - 1, b - 9, "c8d8d8")
    L.rect(cx - 1, b - 12, cx + 1, b - 10, "8a6a42")


def s_antidote(L, cx, b):     # tall green vial (1x2)
    L.rect(cx - 2, b - 8, cx + 2, b + 1, "3a8a3a")
    L.v(cx - 1, b - 7, b, "7ac86a")
    L.rect(cx - 1, b - 11, cx + 1, b - 8, "9aaaaa")
    L.rect(cx - 1, b - 13, cx + 1, b - 11, "8a6a42")


def s_strength(L, cx, b):     # square orange bottle with a bull label (1x2)
    L.rect(cx - 3, b - 8, cx + 3, b + 1, "c8702a")
    L.v(cx - 3, b - 7, b, "f0a050")
    L.rect(cx - 1, b - 11, cx + 1, b - 8, "8a9a9a")
    L.rect(cx - 2, b - 13, cx + 2, b - 11, "8a6a42")
    L.rect(cx - 2, b - 6, cx + 2, b - 2, "e8dcc0")
    L.px(cx - 2, b - 5, "5a1e1e"); L.px(cx + 1, b - 5, "5a1e1e"); L.px(cx - 1, b - 4, "5a1e1e"); L.px(cx, b - 4, "5a1e1e")


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


def s_soup(L, cx, b):         # wooden bowl of green herb soup with a wisp of steam (1x1)
    L.h(cx - 3, cx + 3, b - 3, "4e7a2e")
    L.px(cx - 1, b - 3, "7aa84a"); L.px(cx + 1, b - 3, "c8a050")
    L.h(cx - 3, cx + 3, b - 2, "7a5232"); L.h(cx - 2, cx + 2, b - 1, "6a4426"); L.h(cx - 1, cx + 1, b, "553420")
    L.px(cx - 3, b - 2, "9a7048")
    L.px(cx, b - 4, "8a8478"); L.px(cx - 1, b - 5, "8a8478")


def s_pie(L, cx, b):          # berry pie with a lattice crust on a little plate (2x1)
    L.h(cx - 6, cx + 7, b, "b8b0a0")
    L.rect(cx - 5, b - 3, cx + 6, b, "c08a48")
    L.h(cx - 4, cx + 5, b - 4, "d8a058")
    for x in range(cx - 4, cx + 5):
        if (x - cx) % 2 == 0:
            L.px(x, b - 3, "5a2a6a")
            L.px(x + 1, b - 2, "7a3a8a")
    L.px(cx - 5, b - 1, "9a6a32"); L.px(cx + 5, b - 1, "9a6a32")


def s_roast(L, cx, b):        # forest roast: browned meat with roots on a wooden board (2x1)
    L.h(cx - 6, cx + 7, b, "6a4426"); L.px(cx + 6, b - 1, "6a4426")
    for yy, half in zip(range(b - 4, b), (2, 3, 4, 4)):
        L.h(cx - half - 1, cx + half, yy, "8a4a22")
        L.px(cx - half - 1, yy, "b0682e")
    L.px(cx - 1, b - 4, "c07a3a"); L.px(cx + 1, b - 3, "5a2e14")
    L.px(cx + 4, b - 2, "d8b878"); L.px(cx + 5, b - 2, "c8a060"); L.px(cx + 5, b - 1, "d8b878")
    L.px(cx - 2, b - 5, "5a8a3a"); L.px(cx - 3, b - 5, "6a9a3a")


def s_luck(L, cx, b):         # round golden elixir of luck with a sparkle and a wax-sealed cork (1x2)
    for yy, (l, r) in zip(range(b - 6, b + 1), ((1, 0), (2, 1), (3, 2), (3, 2), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "d0a028")
    L.v(cx + 2, b - 4, b, "9a7018")
    L.px(cx - 2, b - 4, "fff0a0"); L.px(cx, b - 3, "ffffff"); L.px(cx - 1, b - 2, "f8e070")
    L.rect(cx - 1, b - 10, cx + 1, b - 6, "9aaaaa")
    L.px(cx - 1, b - 9, "c8d8d8")
    L.rect(cx - 1, b - 12, cx + 1, b - 10, "2a5a9a")


def s_mushsoup(L, cx, b):     # wooden bowl of pale broth with glowing blue mushroom caps (1x1)
    L.h(cx - 3, cx + 3, b - 3, "b8b08a")
    L.px(cx - 2, b - 3, "5ab8e0"); L.px(cx + 1, b - 3, "8ad8f0"); L.px(cx, b - 4, "5ab8e0")
    L.h(cx - 3, cx + 3, b - 2, "7a5232"); L.h(cx - 2, cx + 2, b - 1, "6a4426"); L.h(cx - 1, cx + 1, b, "553420")
    L.px(cx - 3, b - 2, "9a7048")
    L.px(cx - 1, b - 5, "8a8478")


def s_uzvar(L, cx, b):        # clay jug of dark berry uzvar with a loop handle (1x2)
    for yy, l in zip(range(b - 7, b + 1), (1, 2, 3, 3, 3, 3, 2, 2)):
        L.h(cx - l, cx + 1 if l > 1 else cx, yy, "a0603a")
    L.v(cx, b - 5, b - 1, "7a4426")
    L.px(cx - 2, b - 5, "c8844e"); L.px(cx - 2, b - 4, "c8844e")
    L.rect(cx - 2, b - 10, cx, b - 7, "a0603a")
    L.h(cx - 2, cx + 1, b - 10, "b8704a")
    L.px(cx - 2, b - 10, "6a1a3a"); L.px(cx - 1, b - 10, "6a1a3a")
    L.v(cx + 2, b - 7, b - 3, "7a4426"); L.px(cx + 1, b - 7, "7a4426"); L.px(cx + 1, b - 3, "7a4426")


def s_chickenpie(L, cx, b):   # golden domed chicken pie with a crimped edge and a steam vent, on a plate (2x1)
    L.h(cx - 6, cx + 7, b, "b8b0a0")
    L.rect(cx - 5, b - 2, cx + 6, b, "b8783a")
    for x in range(cx - 5, cx + 6, 2):
        L.px(x, b - 2, "e0b060")
    L.h(cx - 4, cx + 5, b - 3, "d8a050")
    L.h(cx - 3, cx + 4, b - 4, "e8b860")
    L.px(cx, b - 4, "6a4426"); L.px(cx - 2, b - 4, "f8d888"); L.px(cx - 3, b - 3, "f8d888")
    L.px(cx + 1, b - 5, "8a8478")


def s_swampdraught(L, cx, b):  # squat murky-green flask with a cloth-tied neck (1x2)
    L.rect(cx - 3, b - 6, cx + 3, b + 1, "4a5a24")
    L.h(cx - 2, cx + 2, b - 7, "4a5a24")
    L.v(cx - 3, b - 5, b, "7a8a3a"); L.v(cx + 2, b - 5, b, "2e3a16")
    L.px(cx - 1, b - 3, "8a9a4a"); L.px(cx + 1, b - 1, "2e3a16")
    L.rect(cx - 1, b - 10, cx + 1, b - 7, "8a9a8a")
    L.rect(cx - 2, b - 11, cx + 2, b - 10, "8a7a5a"); L.px(cx + 1, b - 12, "8a7a5a")


def s_poison(L, cx, b):        # thin black vial with a skull mark and a purple wax seal (1x2)
    L.rect(cx - 2, b - 8, cx + 2, b + 1, "1e1a24")
    L.v(cx - 2, b - 7, b, "4a3a5a")
    L.px(cx - 1, b - 5, "d8d0c0"); L.px(cx, b - 5, "d8d0c0"); L.px(cx - 1, b - 4, "d8d0c0"); L.px(cx, b - 4, "d8d0c0")
    L.px(cx - 1, b - 3, "1e1a24"); L.px(cx, b - 3, "d8d0c0")
    L.rect(cx - 1, b - 11, cx + 1, b - 8, "6a6a7a")
    L.rect(cx - 1, b - 13, cx + 1, b - 11, "6a2a8a")


def s_wispelixir(L, cx, b):    # round flask with a glowing blue light inside (1x2)
    for yy, (l, r) in zip(range(b - 6, b + 1), ((1, 0), (2, 1), (3, 2), (3, 2), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "3a8ab8")
    L.v(cx + 2, b - 4, b, "2a5a8a")
    L.px(cx - 1, b - 3, "c8f8ff"); L.px(cx, b - 3, "ffffff"); L.px(cx, b - 4, "8af0ff"); L.px(cx - 1, b - 2, "8af0ff")
    L.rect(cx - 1, b - 10, cx + 1, b - 6, "9aaaaa")
    L.rect(cx - 1, b - 12, cx + 1, b - 10, "8a6a42")


def s_rum(L, cx, b):           # dark square bottle of rum with a red label and a long neck (1x2)
    L.rect(cx - 3, b - 7, cx + 3, b + 1, "3a2010")
    L.v(cx - 3, b - 6, b, "6a3a1a")
    L.rect(cx - 2, b - 5, cx + 2, b - 2, "c83a2a"); L.px(cx - 1, b - 4, "f0d060")
    L.rect(cx - 1, b - 11, cx + 1, b - 7, "3a2010")
    L.rect(cx - 1, b - 13, cx + 1, b - 11, "c8a868")


def s_fishsoup(L, cx, b):      # wooden bowl of golden fish soup with a fish tail and dill (1x1)
    L.h(cx - 3, cx + 3, b - 3, "d8b868")
    L.px(cx - 2, b - 3, "5a8a3a"); L.px(cx + 1, b - 3, "e8d8a8")
    L.px(cx + 1, b - 4, "8a9aa0"); L.px(cx + 2, b - 5, "8a9aa0")
    L.h(cx - 3, cx + 3, b - 2, "7a5232"); L.h(cx - 2, cx + 2, b - 1, "6a4426"); L.h(cx - 1, cx + 1, b, "553420")
    L.px(cx - 3, b - 2, "9a7048")


def s_bakedpike(L, cx, b):     # long baked pike on a plate with a lemon slice (2x1)
    L.h(cx - 6, cx + 7, b, "b8b0a0")
    for x in range(cx - 5, cx + 5):
        L.px(x, b - 1, "b8783a"); L.px(x, b - 2, "d8a058" if x % 2 else "c88a48")
    L.h(cx - 3, cx + 3, b - 3, "c88a48")
    L.px(cx - 6, b - 2, "a86a2a"); L.px(cx - 6, b - 1, "a86a2a")           # head
    L.px(cx - 5, b - 2, "1a1a10")
    L.px(cx + 5, b - 3, "a86a2a"); L.px(cx + 5, b - 1, "a86a2a"); L.px(cx + 6, b - 2, "a86a2a")   # tail
    L.px(cx + 1, b - 4, "f0e060"); L.px(cx - 1, b - 4, "5a8a3a")


def s_crayfish(L, cx, b):      # a heap of red boiled crayfish on a plate (2x1)
    L.h(cx - 6, cx + 7, b, "b8b0a0")
    for x0 in (cx - 5, cx - 1, cx + 3):
        L.h(x0, x0 + 3, b - 1, "c84a2a"); L.h(x0, x0 + 3, b - 2, "e06a40")
        L.px(x0 + 3, b - 2, "8a2a1a")
    L.h(cx - 3, cx + 2, b - 3, "c84a2a"); L.px(cx - 3, b - 4, "e06a40"); L.px(cx + 2, b - 4, "e06a40")
    L.px(cx + 1, b - 3, "5a8a3a"); L.px(cx - 5, b - 2, "f0d878")


def s_murky(L, cx, b):         # round flask of grey-brown sludge with dregs and a plain cork (1x2)
    for yy, (l, r) in zip(range(b - 6, b + 1), ((1, 0), (2, 1), (3, 2), (3, 2), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "6a5a42")
    L.v(cx + 2, b - 4, b, "4a3e2e"); L.px(cx - 2, b - 4, "8a7a5a")
    L.px(cx - 1, b - 1, "3a3024"); L.px(cx + 1, b - 2, "3a3024")
    L.rect(cx - 1, b - 10, cx + 1, b - 6, "9aa0a0")
    L.rect(cx - 1, b - 12, cx + 1, b - 10, "8a6a42")


def s_sleep(L, cx, b):         # round lavender flask with a pale swirl and a cork (1x2)
    for yy, (l, r) in zip(range(b - 6, b + 1), ((1, 0), (2, 1), (3, 2), (3, 2), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "8a7ab0")
    L.v(cx + 2, b - 4, b, "5a4a80"); L.px(cx - 2, b - 4, "b8a8e0")
    L.px(cx, b - 3, "d8d0f8"); L.px(cx - 1, b - 2, "d8d0f8")
    L.rect(cx - 1, b - 10, cx + 1, b - 6, "9aa0a0")
    L.rect(cx - 1, b - 12, cx + 1, b - 10, "8a6a42")


# ---------- resources, 1x1: drawn inside x cx-3..cx+2, rows b-5..b (the outline takes the cell's edge) ----------
def s_herbs(L, cx, b):        # bundle of green herbs tied with a string
    for x, top in ((cx - 2, b - 4), (cx - 1, b - 5), (cx, b - 5), (cx + 1, b - 4)):
        L.v(x, top, b + 1, "4e7a2e")
    L.px(cx - 1, b - 5, "7aa84a"); L.px(cx + 1, b - 4, "7aa84a"); L.px(cx - 3, b - 3, "4e7a2e"); L.px(cx + 2, b - 3, "6a9a3a")
    L.h(cx - 2, cx + 2, b - 1, "c8a868")


def s_berries(L, cx, b):      # little wooden bowl full of blueberries
    L.h(cx - 3, cx + 3, b - 2, "7a5232"); L.h(cx - 2, cx + 2, b - 1, "6a4426"); L.h(cx - 1, cx + 1, b, "553420")
    L.h(cx - 2, cx + 2, b - 3, "3a3a8a"); L.px(cx - 1, b - 4, "4a4aa8"); L.px(cx, b - 4, "2a2a6a")
    L.px(cx - 2, b - 3, "6a6ac8"); L.px(cx + 1, b - 3, "6a6ac8")


def s_burdock(L, cx, b):      # thick brown root lying down
    L.h(cx - 3, cx + 2, b - 1, "7a5230"); L.h(cx - 2, cx + 3, b, "5a3a20")
    L.px(cx - 3, b - 2, "9a7048"); L.px(cx + 2, b - 2, "4e7a2e"); L.px(cx + 2, b - 3, "4e7a2e")


def s_mandrake(L, cx, b):     # pale forked root with green leaves
    L.rect(cx - 1, b - 3, cx + 1, b, "d8c090"); L.px(cx - 2, b, "c0a878"); L.px(cx + 1, b, "c0a878")
    L.px(cx - 1, b - 2, "4a3020")
    L.px(cx - 2, b - 5, "4e7a2e"); L.px(cx - 1, b - 4, "6a9a3a"); L.px(cx, b - 4, "4e7a2e"); L.px(cx + 1, b - 5, "6a9a3a")


def s_bones(L, cx, b):        # two old bones on top of each other
    L.h(cx - 2, cx + 2, b, "d8d0b8"); L.px(cx - 3, b, "e8e0c8"); L.px(cx + 2, b, "e8e0c8"); L.px(cx - 3, b - 1, "c8c0a0")
    L.h(cx - 1, cx + 2, b - 2, "c8c0a0"); L.px(cx - 2, b - 3, "e8e0c8"); L.px(cx + 2, b - 3, "e8e0c8")


def s_gravedust(L, cx, b):    # small grey sack tied at the neck
    for yy, (l, r) in zip(range(b - 3, b + 1), ((2, 1), (3, 2), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "7a7a72")
    L.px(cx - 2, b - 2, "9a9a90"); L.v(cx + 2, b - 2, b, "5a5a54")
    L.h(cx - 1, cx + 1, b - 4, "5a4a38"); L.px(cx - 1, b - 5, "8a8a80"); L.px(cx, b - 5, "8a8a80")


def s_ether(L, cx, b):        # tiny vial of pale blue mist
    L.rect(cx - 2, b - 3, cx + 2, b + 1, "6ab8e8"); L.px(cx - 2, b - 3, "c8f0ff"); L.v(cx + 1, b - 2, b + 1, "3a80c0")
    L.rect(cx - 1, b - 5, cx + 1, b - 3, "8a6a42")


def s_crystal(L, cx, b):      # moon crystal standing upright
    L.v(cx - 1, b - 4, b + 1, "a8c8f0"); L.v(cx, b - 5, b + 1, "d8e8ff"); L.v(cx + 1, b - 3, b + 1, "6a8ac8")
    L.px(cx - 2, b - 1, "8aa8e0"); L.px(cx - 2, b, "8aa8e0"); L.px(cx + 2, b, "5a7ab0")


def s_glowmush(L, cx, b):     # two glowing blue mushrooms
    L.v(cx - 1, b - 2, b + 1, "d8d0c0"); L.h(cx - 3, cx + 1, b - 3, "4ab8f0"); L.px(cx - 2, b - 4, "8ae0ff"); L.px(cx - 1, b - 4, "4ab8f0")
    L.v(cx + 1, b - 1, b + 1, "d8d0c0"); L.h(cx, cx + 3, b - 2, "3a90d0"); L.px(cx + 1, b - 3, "8ae0ff")


def s_moss(L, cx, b):         # wet clump of grey-green moss
    L.h(cx - 3, cx + 3, b, "4a5a34"); L.h(cx - 3, cx + 2, b - 1, "6a7a4a"); L.h(cx - 2, cx + 2, b - 2, "7a8a5a")
    L.px(cx - 1, b - 3, "8a9a6a"); L.px(cx + 1, b - 3, "6a7a4a"); L.px(cx, b - 1, "9aaa7a")


def s_toad(L, cx, b):         # squat warty toad
    L.h(cx - 3, cx + 3, b, "5a6a2a"); L.h(cx - 2, cx + 3, b - 1, "6a7a32"); L.h(cx - 2, cx + 2, b - 2, "7a8a3a")
    L.px(cx - 2, b - 3, "8a9a42"); L.px(cx + 1, b - 3, "8a9a42"); L.px(cx - 2, b - 4, "e0c040"); L.px(cx + 1, b - 4, "e0c040")
    L.px(cx, b - 1, "d8c050")


def s_nightshade(L, cx, b):   # sprig of nightshade: purple flowers, black berries
    L.v(cx, b - 4, b + 1, "3e5a2a"); L.px(cx - 1, b - 2, "3e5a2a")
    L.px(cx - 1, b - 5, "8a4ab0"); L.px(cx + 1, b - 5, "8a4ab0"); L.px(cx, b - 5, "c8a040")
    L.px(cx - 2, b - 2, "1e1a24"); L.px(cx + 1, b - 1, "1e1a24"); L.px(cx + 2, b - 2, "2e2a34")


def s_wispjar(L, cx, b):      # jar with a glowing blue light, cloth over the lid
    L.rect(cx - 2, b - 3, cx + 2, b + 1, "506878"); L.px(cx - 1, b - 2, "9af0ff"); L.px(cx, b - 2, "6ad8f0")
    L.px(cx - 1, b - 1, "6ad8f0"); L.px(cx, b - 1, "3aa0c8")
    L.h(cx - 3, cx + 3, b - 4, "a08a5a"); L.px(cx - 1, b - 5, "c8b080")


def s_lakeweed(L, cx, b):     # wet heap of long green strands
    L.h(cx - 3, cx + 3, b, "2e5a3a"); L.h(cx - 2, cx + 2, b - 1, "3e7a4a")
    L.px(cx - 2, b - 2, "4a8a5a"); L.px(cx - 1, b - 3, "4a8a5a"); L.px(cx + 1, b - 2, "3e7a4a"); L.px(cx + 2, b - 3, "4a8a5a")
    L.px(cx, b - 4, "5a9a6a")


def s_crayfish(L, cx, b):     # red crayfish with its claws up
    L.h(cx - 2, cx + 3, b, "a83a22"); L.h(cx - 1, cx + 2, b - 1, "c84a2a")
    L.px(cx - 3, b - 2, "c84a2a"); L.px(cx - 3, b - 3, "e06a3a"); L.px(cx + 2, b - 2, "c84a2a"); L.px(cx + 2, b - 3, "e06a3a")
    L.px(cx, b - 2, "1a0f0a")


def s_perch(L, cx, b):        # striped perch lying on its side
    L.h(cx - 2, cx + 2, b - 1, "8a9a3a"); L.h(cx - 2, cx + 2, b, "c8b860")
    L.px(cx - 1, b - 2, "e06a3a"); L.px(cx, b - 2, "6a7a2a")
    L.px(cx - 1, b - 1, "3e4a1a"); L.px(cx + 1, b - 1, "3e4a1a")
    L.px(cx + 2, b - 1, "6a7a2a"); L.px(cx + 2, b, "6a7a2a"); L.px(cx - 3, b - 1, "1e1a14")


def s_pike(L, cx, b):         # long pike curled on the plank
    L.h(cx - 3, cx + 3, b, "6a7a4a"); L.h(cx - 3, cx + 2, b - 1, "8a9a5a")
    L.px(cx - 2, b - 1, "c8c890"); L.px(cx, b - 1, "c8c890"); L.px(cx + 2, b - 2, "6a7a4a"); L.px(cx + 2, b - 3, "6a7a4a")
    L.px(cx - 3, b - 1, "1e1a14")


def s_spices(L, cx, b):       # little cloth pouch of spices, open, with red and orange powder
    for yy, (l, r) in zip(range(b - 2, b + 1), ((2, 1), (3, 2), (2, 1))):
        L.h(cx - l, cx + r + 1, yy, "c8a070")
    L.px(cx - 2, b - 1, "e0c090"); L.v(cx + 2, b - 1, b + 1, "8a6a42")
    L.h(cx - 1, cx + 1, b - 3, "d06a2a"); L.px(cx, b - 4, "e0a030"); L.px(cx - 1, b - 4, "b83a1a")


SPRITE_FN = {
    "ale": s_ale, "mead": s_mead, "wine": s_wine,
    "bread": s_bread, "chicken": s_chicken, "stew": s_stew,
    "heal_potion": s_heal, "antidote": s_antidote, "strength_potion": s_strength,
    "shield": s_shield, "chainmail": s_chainmail, "axe": s_axe,
    "fire_scroll": s_scroll, "moon_amulet": s_amulet, "sapphire_ring": s_ring,
    "herb_soup": s_soup, "berry_pie": s_pie, "forest_roast": s_roast, "luck_elixir": s_luck,
    "mushroom_soup": s_mushsoup, "berry_uzvar": s_uzvar, "chicken_pie": s_chickenpie,
    "swamp_draught": s_swampdraught, "poison": s_poison, "wisp_elixir": s_wispelixir, "rum": s_rum,
    "fish_soup": s_fishsoup, "baked_pike": s_bakedpike, "crayfish_fry": s_crayfish,
    "murky_brew": s_murky, "sleep_draught": s_sleep,
    "herbs": s_herbs, "berries": s_berries, "burdock": s_burdock, "mandrake": s_mandrake, "bones": s_bones,
    "grave_dust": s_gravedust, "ether_essence": s_ether, "crystal": s_crystal, "glow_mushroom": s_glowmush,
    "swamp_moss": s_moss, "toad": s_toad, "nightshade": s_nightshade, "wisp_jar": s_wispjar, "lake_weed": s_lakeweed,
    "crayfish": s_crayfish, "perch": s_perch, "pike": s_pike, "spices": s_spices,
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
    demo = {"cellar": [("ale", 0, 0, 2), ("ale", 0, 1, 2), ("ale", 0, 2, 2), ("wine", 0, 4, 1), ("wine", 0, 5, 1), ("mead", 0, 6, 2), ("mead", 1, 0, 2), ("ale", 1, 2, 2)],
            "pantry": [("stew", 0, 0, 0), ("chicken", 0, 2, 1), ("bread", 0, 4, 1), ("bread", 0, 5, 1), ("chicken", 0, 6, 1), ("stew", 1, 0, 0)],
            "chest": [("chainmail", 0, 0, 0), ("shield", 0, 2, 1), ("axe", 0, 4, 0), ("amulet", 0, 5, 1), ("fire_scroll", 1, 0, 2), ("sapphire_ring", 1, 2, 1)],
            "cabinet": [("heal_potion", 0, 0, 1), ("antidote", 0, 1, 1), ("strength_potion", 0, 2, 1), ("heal_potion", 0, 3, 1), ("strength_potion", 0, 4, 1), ("antidote", 1, 0, 1)]}
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
