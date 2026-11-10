"""Second wave of portraits (variants 02/03) - brings the set to 34.
Uses the helpers from gen_set.py. Usage: python3 gen_set2.py OUT_DIR"""
import sys, os
from gen_set import *


def staff(p, x, top, bottom=128, pal=WOOD):
    p.shape(pal, lambda d: d.rectangle([x, top, x + 3, bottom], fill=1), sh=1, hl=1)


def round_shield(p, box, face=WOOD, rim=STEEL):
    x0, y0, x1, y1 = box
    p.shape(face, lambda d: d.ellipse(box, fill=1), sh=3, hl=2)
    for x in range(x0 + 6, x1 - 2, 6):
        p.line([(x, y0 + 2), (x, y1 - 2)], face[1])
    p.layer(p.mask(lambda d: d.ellipse(box, fill=1)) & ~p.mask(lambda d: d.ellipse([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=1)), rim, sh=1, hl=1)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    p.shape(rim, lambda d: d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=1), sh=1, hl=2)


def plate(p, build, pal=STEEL):
    torso(p, build, pal)
    p.shape(pal, lambda d: (d.ellipse([0, 58, 34, 92], fill=1), d.ellipse([62, 58, 96, 92], fill=1)), sh=3, hl=2)
    for x0 in (6, 68):
        p.line([(x0, 72), (x0 + 22, 72)], pal[0]); p.line([(x0 + 2, 80), (x0 + 20, 80)], pal[0])
    p.line([(48, 72), (48, 128)], pal[3])


def crystal(p, cx, cy, pal=CYAN, glow=(150, 220, 255), r=6):
    p.shape(pal, lambda d: d.polygon([(cx, cy - r - 4), (cx + r, cy), (cx, cy + r + 4), (cx - r, cy)], fill=1), sh=2, hl=2)
    p.glow(cx, cy, r * 3 + 4, glow, 0.5)


# ---------------- civilians ----------------
def peasant_m_02(p):
    sk = SKINS['light']
    s = dict(g='m', skin='light', hair='bald', hair_c='grey', beard='short', expr='kind', mouth='smile', old=True)
    # pitchfork behind
    staff(p, 14, 10)
    p.shape(STEEL, lambda d: (d.rectangle([6, 6, 26, 9], fill=1), d.rectangle([6, -4, 8, 8], fill=1),
                              d.rectangle([14, -4, 17, 8], fill=1), d.rectangle([24, -4, 26, 8], fill=1)), sh=0, hl=1)
    torso(p, 'm', LINEN)
    neck(p, 'm', sk)
    vneck(p, sk, top=61, depth=72, half=6)
    p.line([(30, 62), (30, 128)], LEATH[2], 3); p.line([(66, 62), (66, 128)], LEATH[2], 3)
    p.shape(BURLAP, lambda d: d.polygon([(20, 100), (76, 100), (80, 128), (16, 128)], fill=1), sh=2, hl=1)
    head(p, s)
    p.hand(12, 72, sk)


def peasant_f_02(p):
    sk = SKINS['dark']
    s = dict(g='f', skin='dark', hair='curly', hair_c='black', expr='happy', mouth='smile', eye=(60, 40, 30))
    torso(p, 'f', SHAWL)
    p.shape(WHITE, lambda d: d.polygon([(40, 62), (56, 62), (55, 70), (41, 70)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=69, half=5)
    p.shape(LINEN, lambda d: d.polygon([(32, 84), (64, 84), (68, 128), (28, 128)], fill=1), sh=2, hl=1)
    head(p, s)
    # a loaf of bread
    p.shape(WOOD, lambda d: d.ellipse([24, 94, 72, 114], fill=1), sh=3, hl=2)
    for x in (34, 44, 54, 62):
        p.line([(x, 98), (x + 4, 106)], STRAW[2])
    p.hand(18, 102, sk); p.hand(68, 102, sk)


def reveler_m_02(p):
    sk = SKINS['light']
    s = dict(g='m', skin='light', hair='spiky', hair_c='blond', beard='stubble', expr='happy', mouth='grin', blush=True, red_nose=True)
    torso(p, 'm', RED)
    p.shape(WHITE, lambda d: d.polygon([(38, 61), (58, 61), (54, 100), (42, 100)], fill=1), sh=2, hl=1)
    neck(p, 'm', sk)
    vneck(p, sk, top=61, depth=78, half=8)
    p.line([(37, 61), (40, 128)], GOLD[2], 2); p.line([(59, 61), (56, 128)], GOLD[2], 2)
    p.line([(14, 112), (82, 112)], LEATH[1], 3)
    head(p, s)
    # two mugs: one in each raised hand, the left one only
    p.shape(RED, lambda d: d.polygon([(12, 74), (28, 70), (24, 128), (10, 128)], fill=1), sh=2, hl=1)
    p.hand(18, 60, sk, w=12, h=10)
    p.shape(WOOD, lambda d: d.ellipse([8, 44, 18, 58], fill=1), sh=1, hl=0)
    p.shape(WOOD, lambda d: d.rectangle([16, 38, 32, 64], fill=1), sh=2, hl=2)
    for y in (42, 58):
        p.line([(16, y), (32, y)], STEEL[1], 2)
    p.shape(WHITE, lambda d: (d.ellipse([14, 32, 34, 42], fill=1), d.ellipse([30, 34, 36, 46], fill=1)), sh=1, hl=1)
    p.hand(18, 56, sk, w=12, h=8)


def reveler_f_02(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='blond', expr='happy', mouth='smile', blush=True, eye=(70, 110, 170))
    torso(p, 'f', BLUE)
    p.shape(WHITE, lambda d: (d.ellipse([16, 62, 36, 86], fill=1), d.ellipse([60, 62, 80, 86], fill=1)), sh=2, hl=2)
    neck(p, 'f', sk)
    p.shape(sk, lambda d: d.polygon([(36, 63), (60, 63), (56, 76), (40, 76)], fill=1), sh=1, hl=0)
    p.shape(WHITE, lambda d: d.polygon([(36, 74), (60, 74), (58, 78), (38, 78)], fill=1), sh=0, hl=0)
    for y in range(82, 124, 6):
        p.line([(44, y), (52, y + 4)], WHITE[2]); p.line([(52, y), (44, y + 4)], WHITE[2])
    head(p, s)
    # beer mug held at the chest
    p.shape(WOOD, lambda d: d.ellipse([70, 92, 80, 108], fill=1), sh=1, hl=0)
    p.shape(WOOD, lambda d: d.rectangle([54, 88, 72, 116], fill=1), sh=2, hl=2)
    for y in (92, 110):
        p.line([(54, y), (72, y)], STEEL[1], 2)
    p.shape(WHITE, lambda d: d.ellipse([52, 82, 74, 92], fill=1), sh=1, hl=1)
    p.hand(48, 100, sk)


def herbalist_f_03(p):
    sk = SKINS['dark']
    s = dict(g='f', skin='dark', hair='long', hair_c='black', expr='kind', mouth='smile', hat='hood', hood_c=GREEN, eye=(60, 90, 40))
    torso(p, 'f', GREEN)
    p.shape(LINEN, lambda d: d.polygon([(40, 63), (56, 63), (52, 128), (44, 128)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    # satchel with herbs, viewer-right
    p.line([(30, 64), (70, 110)], LEATH[2], 3)
    p.shape(LEATH, lambda d: d.rectangle([58, 102, 84, 126], fill=1), sh=2, hl=2)
    p.shape(LEATH, lambda d: d.polygon([(58, 102), (84, 102), (82, 112), (60, 112)], fill=1), sh=1, hl=1)
    for i, x in enumerate((62, 68, 74, 80)):
        p.shape((GREEN, FGREEN, YELLOW, GREEN)[i], lambda d, x=x: d.ellipse([x - 3, 92, x + 3, 102], fill=1), sh=1, hl=1)
    head(p, s)
    # small vial
    p.shape(CYAN, lambda d: d.ellipse([26, 100, 38, 114], fill=1), sh=2, hl=2)
    p.shape(WOOD, lambda d: d.rectangle([30, 94, 34, 100], fill=1), sh=0, hl=0)
    p.hand(22, 108, sk)


def merchant_m_02(p):
    sk = SKINS['mid']
    s = dict(g='m', skin='mid', race='dwarf', hair='bald', hair_c='grey', beard='long', expr='sly', mouth='smile', old=True)
    p.shape(CRIMS, lambda d: d.polygon(TORSO['w'], fill=1), sh=4, hl=3)
    neck(p, 'w', sk)
    p.shape(FUR, lambda d: d.ellipse([20, 56, 76, 82], fill=1), sh=3, hl=2)
    p.shape(sk, lambda d: d.ellipse([38, 56, 58, 70], fill=1), sh=2, hl=0)
    p.shape(GOLD, lambda d: d.rectangle([46, 84, 50, 128], fill=1), sh=0, hl=1)
    head(p, s)
    p.shape(GOLD, lambda d: d.arc([30, 60, 66, 96], 20, 160, fill=1, width=2), sh=0, hl=0)
    # stack of coins on the palm
    p.hand(60, 108, sk, w=16, h=8)
    for i in range(4):
        p.shape(GOLD, lambda d, i=i: d.ellipse([60, 102 - i * 4, 76, 108 - i * 4], fill=1), sh=1, hl=1)
    p.px(62, 110, GOLD[3]); p.px(63, 110, GOLD[2])


def merchant_f_02(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='red', expr='sly', mouth='smirk', freckles=True, eye=(60, 110, 70))
    torso(p, 'f', PURPLE)
    p.shape(GOLD, lambda d: d.polygon([(36, 63), (60, 63), (64, 70), (48, 76), (32, 70)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=73, half=6)
    for x in (24, 72):
        p.line([(x, 76), (x, 128)], GOLD[2], 2)
    head(p, s)
    p.shape(CRIMS, lambda d: d.polygon([(46, 70), (50, 70), (52, 74), (48, 78), (44, 74)], fill=1), sh=0, hl=1)
    # scales of a trader
    p.line([(60, 84), (60, 104)], GOLD[1], 2)
    p.line([(46, 88), (74, 88)], GOLD[2], 2)
    for x in (46, 74):
        p.line([(x, 88), (x - 4, 100)], GOLD[1]); p.line([(x, 88), (x + 4, 100)], GOLD[1])
        p.shape(GOLD, lambda d, x=x: d.chord([x - 7, 94, x + 7, 106], 0, 180, fill=1), sh=1, hl=1)
    p.hand(54, 104, sk)


def mage_f_03(p):
    sk = SKINS['olive']
    s = dict(g='f', skin='olive', hair='long', hair_c='grey', expr='kind', mouth='smile', old=True,
             hat='pointed', hat_c=FGREEN, eye=(90, 160, 90))
    torso(p, 'f', FGREEN)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    for (x, y) in ((26, 86), (34, 104), (66, 92), (62, 116), (30, 122), (70, 108)):
        p.px(x, y, YELLOW[3]); p.px(x - 1, y, YELLOW[1]); p.px(x + 1, y, YELLOW[1]); p.px(x, y - 1, YELLOW[1]); p.px(x, y + 1, YELLOW[1])
    head(p, s)
    # an owl feather wand and a green glowing orb
    p.hand(40, 108, sk, w=16, h=8)
    p.shape(GREEN, lambda d: d.ellipse([41, 90, 55, 106], fill=1), sh=2, hl=2)
    p.glow(48, 98, 20, (170, 255, 170), 0.5)
    for (x, y) in ((38, 88), (58, 92), (48, 82)):
        p.px(x, y, YELLOW[3])


# ---------------- heroes ----------------
def hero_warrior_m_02(p):
    sk = SKINS['dark']
    s = dict(g='m', skin='dark', hair='bald', hair_c='black', beard='short', expr='stern', mouth='flat', eye=(60, 40, 30))
    torso(p, 'm', MAIL)
    bp = p.mask(lambda d: d.polygon([(26, 70), (70, 70), (68, 112), (48, 122), (28, 112)], fill=1))
    p.layer(bp, STEEL, sh=3, hl=3)
    p.line([(48, 71), (48, 120)], STEEL[3])
    p.shape(STEEL, lambda d: (d.ellipse([8, 60, 38, 90], fill=1), d.ellipse([58, 60, 88, 90], fill=1)), sh=2, hl=2)
    neck(p, 'm', sk)
    head(p, s)
    # axe over the shoulder
    p.shape(WOOD, lambda d: d.line([(66, 92), (80, 30)], fill=1, width=4), sh=1, hl=1)
    p.shape(STEEL, lambda d: d.polygon([(78, 30), (92, 22), (94, 46), (80, 42)], fill=1), sh=2, hl=2)
    p.hand(62, 86, sk)
    round_shield(p, [2, 88, 40, 126], face=RED)


def hero_warrior_f_02(p):
    sk = SKINS['tan']
    s = dict(g='f', skin='tan', hair='long', hair_c='black', expr='stern', mouth='flat', scar=True, eye=(70, 50, 30))
    grip = p.mask(lambda d: d.line([(26, 70), (15, 40)], fill=1, width=4))
    p.layer(grip, LEATH, sh=1, hl=1)
    p.shape(GOLD, lambda d: d.ellipse([10, 32, 19, 41], fill=1), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.polygon([(11, 71), (34, 58), (37, 63), (14, 76)], fill=1), sh=1, hl=1)
    torso(p, 'f', MAIL)
    yy_ring = p.mask(lambda d: d.polygon(TORSO['f'], fill=1)) & ((XX + (YY // 2) % 2) % 2 == 0) & (YY % 2 == 0)
    p.darken(yy_ring & p.shift(p.mask(lambda d: d.polygon(TORSO['f'], fill=1)), 1, 1), 30)
    p.shape(BLUE, lambda d: d.polygon([(40, 74), (56, 74), (58, 128), (38, 128)], fill=1), sh=2, hl=1)
    p.shape(STEEL, lambda d: d.polygon([(48, 84), (53, 92), (48, 102), (43, 92)], fill=1), sh=1, hl=1)
    p.shape(LEATH, lambda d: d.polygon([(34, 64), (62, 64), (60, 72), (48, 76), (36, 72)], fill=1), sh=2, hl=1)
    neck(p, 'f', sk)
    p.shape(LEATH, lambda d: d.ellipse([58, 62, 86, 88], fill=1), sh=3, hl=2)
    head(p, s)


def hero_archer_m_02(p):
    sk = SKINS['light']
    s = dict(g='m', skin='light', hair='short', hair_c='red', beard='stubble', expr='stern', mouth='smirk', freckles=True, eye=(70, 110, 70))
    for i, x in enumerate((14, 19, 24)):
        p.line([(x + 6, 76), (x, 46)], WOOD[2], 1)
        p.shape(WHITE if i != 1 else RED, lambda d, x=x: d.polygon([(x - 2, 40), (x + 2, 52), (x - 3, 50)], fill=1), sh=0, hl=1)
    hood_down(p, BURLAP)
    torso(p, 'm', DLEATH)
    p.shape(LEATH, lambda d: d.ellipse([12, 62, 38, 88], fill=1), sh=2, hl=1)
    neck(p, 'm', sk)
    p.line([(26, 66), (70, 128)], LEATH[2], 3)
    p.line([(14, 108), (82, 108)], LEATH[1], 2)
    head(p, s)
    p.shape(WOOD, lambda d: d.arc([62, 50, 104, 140], 100, 260, fill=1, width=4), sh=0, hl=0)
    p.line([(80, 52), (80, 138)], WHITE[2])
    p.hand(64, 92, sk)


def hero_archer_f_02(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', race='elf', hair='long', hair_c='blond', expr='kind', mouth='flat', hat='hood', hood_c=DGREEN, eye=(80, 150, 200))
    p.shape(WOOD, lambda d: d.arc([62, 20, 106, 140], 280, 80, fill=1, width=4), sh=0, hl=0)
    p.line([(86, 22), (86, 138)], WHITE[2])
    torso(p, 'f', FGREEN)
    p.shape(LEATH, lambda d: (d.ellipse([14, 64, 38, 88], fill=1), d.ellipse([58, 64, 82, 88], fill=1)), sh=2, hl=1)
    neck(p, 'f', sk)
    for y in range(80, 128, 7):
        p.line([(46, y), (50, y + 3)], DLEATH[0]); p.line([(50, y), (46, y + 3)], DLEATH[0])
    p.line([(24, 66), (66, 128)], LEATH[2], 3)
    head(p, s)
    # arrow held ready
    p.line([(20, 120), (40, 76)], WOOD[2], 1)
    p.shape(STEEL, lambda d: d.polygon([(39, 72), (44, 74), (40, 79)], fill=1), sh=0, hl=1)
    p.shape(WHITE, lambda d: d.polygon([(18, 118), (24, 114), (20, 126)], fill=1), sh=0, hl=1)
    p.hand(22, 104, sk)


def hero_mage_m_02(p):
    sk = SKINS['light']
    s = dict(g='m', skin='light', hair='bald', hair_c='silver', beard='long', expr='kind', mouth='flat', old=True,
             hat='pointed', hat_c=BLUE, eye_glow=True)
    staff(p, 76, 18)
    torso(p, 'm', BLUE)
    neck(p, 'm', sk)
    for (x, y) in ((22, 90), (30, 110), (66, 96), (70, 118)):
        p.px(x, y, STEEL[3]); p.px(x - 1, y, STEEL[1]); p.px(x + 1, y, STEEL[1]); p.px(x, y - 1, STEEL[1]); p.px(x, y + 1, STEEL[1])
    head(p, s)
    crystal(p, 78, 14, pal=CYAN, r=5)
    p.hand(72, 84, sk)


def hero_mage_f_02(p):
    sk = SKINS['dark']
    s = dict(g='f', skin='dark', hair='curly_long', hair_c='black', expr='stern', mouth='smirk', eye_glow=True)
    staff(p, 16, 28, pal=GREYR)
    hood_down(p, VIOLET)
    torso(p, 'f', VIOLET)
    p.shape(GREYR, lambda d: d.polygon([(40, 63), (56, 63), (54, 128), (42, 128)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    for (x, y) in ((28, 92), (64, 102), (32, 116)):
        p.line([(x, y), (x + 3, y)], GOLD[3]); p.line([(x + 1, y), (x + 1, y + 4)], GOLD[3])
    head(p, s)
    p.shape(VIOLET, lambda d: d.ellipse([10, 16, 26, 32], fill=1), sh=2, hl=2)
    p.glow(18, 24, 18, (230, 170, 255), 0.6)
    p.hand(12, 84, sk)


def hero_tank_m_02(p):
    sk = SKINS['tan']
    s = dict(g='m', skin='tan', hair='short', hair_c='black', beard='stubble', expr='kind', mouth='flat', scar=True, eye=(60, 50, 40))
    plate(p, 'w')
    p.shape(MAIL, lambda d: d.rectangle([40, 58, 56, 68], fill=1), sh=1, hl=1)
    neck(p, 'w', sk)
    head(p, s)
    km = p.shape(RED, lambda d: d.polygon([(4, 84), (46, 84), (44, 104), (25, 128), (6, 104)], fill=1), sh=3, hl=2)
    p.layer(km & ~p.mask(lambda d: d.polygon([(8, 87), (42, 87), (40, 103), (25, 123), (10, 103)], fill=1)), STEEL, sh=1, hl=1)
    p.line([(8, 88), (40, 116)], YELLOW[2], 5)
    p.shape(YELLOW, lambda d: d.ellipse([19, 94, 31, 106], fill=1), sh=1, hl=1)
    p.hand(44, 94, sk)


def hero_tank_f_02(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', race='dwarf', hair='braid', hair_c='auburn', expr='stern', mouth='smirk', freckles=True, blush=True)
    plate(p, 'w', pal=STEEL)
    p.shape(GOLD, lambda d: (d.ellipse([10, 64, 18, 72], fill=1), d.ellipse([78, 64, 86, 72], fill=1)), sh=0, hl=1)
    neck(p, 'w', sk)
    head(p, s)
    # tower shield, viewer-right
    sm = p.mask(lambda d: (d.rectangle([44, 92, 94, 128], fill=1), d.ellipse([44, 82, 94, 104], fill=1)))
    p.layer(sm, WOOD, sh=3, hl=2)
    p.layer(sm & ~p.mask(lambda d: (d.rectangle([48, 95, 90, 128], fill=1), d.ellipse([48, 86, 90, 106], fill=1))), STEEL, sh=1, hl=1)
    p.shape(STEEL, lambda d: d.rectangle([66, 86, 72, 128], fill=1), sh=1, hl=1)
    p.shape(STEEL, lambda d: d.rectangle([46, 106, 92, 112], fill=1), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.ellipse([64, 104, 74, 114], fill=1), sh=1, hl=1)


CAST2 = {
    'peasant_m_02': peasant_m_02, 'peasant_f_02': peasant_f_02,
    'reveler_m_02': reveler_m_02, 'reveler_f_02': reveler_f_02,
    'herbalist_f_03': herbalist_f_03,
    'merchant_m_02': merchant_m_02, 'merchant_f_02': merchant_f_02,
    'mage_f_03': mage_f_03,
    'hero_warrior_m_02': hero_warrior_m_02, 'hero_warrior_f_02': hero_warrior_f_02,
    'hero_archer_m_02': hero_archer_m_02, 'hero_archer_f_02': hero_archer_f_02,
    'hero_mage_m_02': hero_mage_m_02, 'hero_mage_f_02': hero_mage_f_02,
    'hero_tank_m_02': hero_tank_m_02, 'hero_tank_f_02': hero_tank_f_02,
}

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    for name in (sys.argv[2:] or list(CAST2)):
        p = Portrait()
        CAST2[name](p)
        p.save(os.path.join(out, name + '.png'))
    print('done')
