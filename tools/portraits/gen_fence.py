"""Portraits of the fence (shady dealer, customer type "fence") - same helpers and style as gen_set.py.
Usage: python3 gen_fence.py OUT_DIR"""
import sys, os
from gen_set import *

CLOAK = ((14, 12, 16), (34, 30, 38), (50, 46, 56), (74, 70, 82))


def dagger(p, x, y):
    p.shape(STEEL, lambda d: d.polygon([(x, y), (x + 3, y), (x + 2, y - 22), (x + 1, y - 24)], fill=1), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.rectangle([x - 4, y, x + 7, y + 2], fill=1), sh=0, hl=1)
    p.shape(DLEATH, lambda d: d.rectangle([x, y + 3, x + 3, y + 10], fill=1), sh=0, hl=1)


def purse(p, x, y):
    p.shape(LEATH, lambda d: d.ellipse([x - 9, y - 6, x + 9, y + 10], fill=1), sh=2, hl=1)
    p.line([(x - 4, y - 6), (x + 4, y - 6)], GOLD[2], 2)
    p.px(x - 2, y + 2, GOLD[3]); p.px(x + 3, y, GOLD[3])


def fence_m_01(p):
    sk = SKINS['tan']
    s = dict(g='m', skin='tan', hair='short', hair_c='black', beard='stubble', expr='sly', mouth='smirk',
             hat='hood', hood_c=CLOAK, scar=True, eye=(150, 120, 60))
    torso(p, 'm', CLOAK)
    neck(p, 'm', sk)
    vneck(p, sk, top=61, depth=70, half=5)
    p.line([(30, 64), (22, 128)], DLEATH[2], 2)
    p.line([(14, 104), (82, 104)], DLEATH[1], 3)
    head(p, s)
    # a dagger held low and a heavy purse on the palm
    p.hand(20, 100, sk)
    dagger(p, 18, 96)
    purse(p, 70, 106)
    p.hand(70, 112, sk)


def fence_f_01(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='red', expr='sly', mouth='smirk', freckles=True,
             hat='hood', hood_c=CLOAK, eye=(90, 150, 90))
    torso(p, 'f', CLOAK)
    p.shape(CRIMS, lambda d: d.polygon([(36, 62), (60, 62), (56, 72), (40, 72)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    p.line([(64, 66), (72, 128)], DLEATH[2], 2)
    head(p, s)
    # a ring offered between two fingers
    p.hand(66, 96, sk)
    p.shape(GOLD, lambda d: d.ellipse([62, 86, 72, 96], fill=1), sh=1, hl=1)
    p.shape(CYAN, lambda d: d.ellipse([65, 84, 69, 88], fill=1), sh=0, hl=1)
    p.glow(67, 86, 8, (150, 220, 255), 0.4)
    dagger(p, 24, 120)


CAST_FENCE = {'fence_m_01': fence_m_01, 'fence_f_01': fence_f_01}

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    for name in (sys.argv[2:] or list(CAST_FENCE)):
        p = Portrait()
        CAST_FENCE[name](p)
        p.save(os.path.join(out, name + '.png'))
    print('done')
