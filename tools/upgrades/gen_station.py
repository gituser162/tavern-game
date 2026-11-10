"""Alchemy station on the counter (2026-11-10): one prop that is in the room from the start and grows with the
"Алхімічна станція" upgrade (it replaced the mortar + a separate flask, which looked like two stations).
Run: python3 gen_station.py <project>  -> <project>/assets/objects/alchemy_station_1/2/3.png, 42x28 (main.gd STATION_RECT)
  1: mortar + green flask (start)   2: mortar + flask on a burner with a coil   3: as 2 + a little rack of vials
Also writes shelf_locked_<place>.png / attic_locked.png: boards nailed over shelves and the attic ladder not built yet."""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_upgrades as G   # noqa: E402

PROJECT = sys.argv[1] if len(sys.argv) > 1 else "."
OBJ = os.path.join(PROJECT, "assets/objects")
W, H = 42, 28            # STATION_RECT = (24, 77, 42, 28) on the 320x180 background
MORTAR_AT = (7, 0)       # mortar.png (28x28) was at (31, 77)
FLASK_AT = (0, 3)        # upg_alchemy_N (10x20) was at (24, 80)


def rack():
    s = G.Spr(10, 20)
    # small wooden rack with two vials (blue, amber)
    s.rect(1, 18, 9, 20, "6a4426"); s.rect(1, 18, 9, 19, "8a6038")
    s.rect(1, 14, 2, 18, "5a3a22"); s.rect(8, 14, 9, 18, "5a3a22")
    s.rect(1, 14, 9, 15, "7a5232")
    for x, liquid, hi in ((3, "3a70d0", "9ad0ff"), (6, "d89a30", "f0d070")):
        s.rect(x, 11, x + 2, 18, "aab8c0")
        s.rect(x, 14, x + 2, 18, liquid)
        s.px(x, 14, hi)
        s.rect(x, 10, x + 2, 11, "8a6a42")
    s.outline()
    return s.im


def station(level):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    im.alpha_composite(Image.open(os.path.join(OBJ, "mortar.png")).convert("RGBA"), MORTAR_AT)
    im.alpha_composite(G.alchemy(1 if level == 1 else 2).im, FLASK_AT)
    if level == 3:
        im.alpha_composite(rack(), (32, 8))
    return im


def boards(w, h, bands):
    """Dark compartment with planks nailed across it. bands: list of (y, height, tilt) for every plank."""
    s = G.Spr(w, h)
    for y in range(h):
        for x in range(w):
            s.p[x, y] = (12, 7, 4, 150)
    for y0, th, tilt in bands:
        for x in range(1, w - 1):
            yy = y0 + round(tilt * (x - w / 2))
            for t in range(th):
                col = "6a4628" if t == 0 else ("2e1c10" if t == th - 1 else "4e321c")
                if (x * 7 + t * 3) % 11 == 0 and 0 < t < th - 1:
                    col = "3e2616"          # wood grain
                s.px(x, yy + t, col)
            s.px(x, yy - 1, G.OUTLINE); s.px(x, yy + th, G.OUTLINE)
        for nx in (3, w - 4):              # nails
            ny = y0 + round(tilt * (nx - w / 2)) + th // 2
            s.px(nx, ny, "8a8a92")
    return s.im


if __name__ == "__main__":
    for lvl in (1, 2, 3):
        station(lvl).save(os.path.join(OBJ, "alchemy_station_%d.png" % lvl))
        print("saved alchemy_station_%d.png" % lvl)
    # STORAGE_RECTS in main.gd (w, h); the shelves start at the counter top (y 104).
    for place, (w, h) in {"cellar": (71, 76), "pantry": (72, 76), "chest": (72, 76), "cabinet": (66, 76)}.items():
        boards(w, h, [(14, 6, 0.18), (44, 6, -0.15)]).save(os.path.join(OBJ, "shelf_locked_%s.png" % place))
    boards(20, 166, [(40, 5, 0.25), (70, 5, -0.25), (100, 5, 0.25)]).save(os.path.join(OBJ, "attic_locked.png"))
    print("saved locked overlays")
