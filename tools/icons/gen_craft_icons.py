"""32x32 pixel-art icons for the side-effect potions (2026-11-09), same style as gen_place_icons.py.
Usage: python3 gen_craft_icons.py <project dir>   -> writes assets/icons/{murky_brew,sleep_draught}.png
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_place_icons import Icon, C  # noqa: E402


def flask(i, body, neck_col="a8b0b0"):
    i.ellipse(16, 21, 9, 8.5, body)                    # round belly
    i.rect(13, 8, 19, 14, neck_col)                    # neck
    i.rect(14, 8, 15, 13, "d8e0e0")                    # neck shine
    i.rect(12, 5, 20, 9, "8a6a40"); i.rect(12, 5, 20, 6, "b08a54")   # cork
    for x, y in ((11, 17), (12, 16)):                  # glass shine
        i.put(x, y, "e8f0f0")


def murky_brew():
    i = Icon()
    flask(i, (C("8a7a5a"), C("6a5a42"), C("4a3e2e")))
    for x, y in ((14, 22), (18, 19), (20, 24), (12, 25)):   # dregs
        i.put(x, y, "3a3024")
    i.put(17, 23, "9a8a68"); i.put(13, 20, "9a8a68")
    for x, y in ((10, 3), (22, 2), (24, 5)):               # bad smell puffs
        i.put(x, y, "7a8a5a")
    i.put(23, 3, "7a8a5a")
    return i


def sleep_draught():
    i = Icon()
    flask(i, (C("b8a8e0"), C("8a7ab0"), C("5a4a80")))
    i.ellipse(16, 22, 4, 3.5, (C("d8d0f8"), C("c0b0f0"), C("9a8ad0")), shade=False)
    # "z z" drifting up
    for (x0, y0) in ((21, 5), (26, 0)):
        for k in range(4):
            i.sparks.append((x0 + k, y0, "e8e0ff"))
            i.sparks.append((x0 + k, y0 + 3, "e8e0ff"))
        i.sparks.append((x0 + 2, y0 + 1, "e8e0ff"))
        i.sparks.append((x0 + 1, y0 + 2, "e8e0ff"))
    return i


if __name__ == "__main__":
    out = os.path.join(sys.argv[1], "assets/icons")
    for name, fn in (("murky_brew", murky_brew), ("sleep_draught", sleep_draught)):
        fn().save(os.path.join(out, name + ".png"))
        print("wrote", name)
