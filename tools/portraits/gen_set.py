"""Pixel-art portrait set for the tavern game (96x128, transparent PNG).
Same drawing approach as the approved trial hero_warrior_m_01.png.
Usage: python3 gen_set.py OUT_DIR"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw

W, H = 96, 128
YY, XX = np.mgrid[0:H, 0:W]

# ---------- palettes: (outline, shadow, base, light) ----------
SKINS = {
    'light': ((96, 50, 40), (196, 132, 104), (234, 184, 150), (250, 214, 186)),
    'mid':   ((92, 46, 34), (176, 110, 80), (216, 158, 116), (240, 196, 150)),
    'tan':   ((80, 40, 26), (150, 92, 60), (192, 132, 90), (220, 166, 118)),
    'dark':  ((46, 24, 18), (92, 54, 36), (126, 78, 52), (160, 106, 72)),
    'olive': ((74, 44, 28), (156, 112, 72), (198, 150, 102), (224, 182, 130)),
}
HAIRS = {
    'brown':  ((40, 22, 16), (66, 40, 26), (98, 62, 38), (134, 88, 52)),
    'black':  ((18, 14, 18), (34, 28, 34), (54, 46, 54), (86, 76, 88)),
    'blond':  ((88, 60, 24), (170, 128, 58), (214, 176, 92), (240, 214, 140)),
    'red':    ((70, 22, 12), (140, 50, 24), (186, 78, 38), (224, 120, 64)),
    'auburn': ((52, 20, 14), (96, 40, 26), (132, 60, 36), (170, 92, 56)),
    'grey':   ((60, 58, 62), (126, 124, 130), (168, 166, 170), (210, 208, 212)),
    'silver': ((90, 96, 120), (170, 178, 200), (212, 218, 236), (244, 246, 255)),
}
def P(*c):
    return tuple(c)
LINEN  = ((84, 66, 46), (170, 150, 116), (206, 188, 150), (232, 218, 186))
WHITE  = ((96, 88, 84), (196, 190, 180), (232, 228, 218), (250, 248, 242))
LEATH  = ((46, 26, 16), (88, 52, 30), (124, 78, 44), (164, 110, 64))
DLEATH = ((30, 18, 12), (58, 36, 22), (84, 54, 32), (116, 78, 46))
BURLAP = ((70, 52, 30), (138, 108, 66), (172, 140, 90), (202, 174, 122))
STRAW  = ((96, 70, 22), (178, 140, 58), (218, 182, 86), (244, 220, 132))
STEEL  = ((40, 42, 52), (110, 116, 128), (160, 166, 176), (214, 220, 226))
MAIL   = ((40, 42, 52), (86, 90, 102), (128, 134, 144), (180, 186, 194))
GOLD   = ((70, 44, 16), (150, 100, 36), (204, 152, 60), (244, 206, 110))
WOOD   = ((50, 30, 16), (100, 62, 32), (138, 90, 48), (176, 124, 72))
RED    = ((50, 18, 16), (112, 34, 30), (156, 50, 40), (196, 84, 62))
CRIMS  = ((44, 10, 18), (110, 20, 34), (150, 32, 46), (192, 64, 72))
GREEN  = ((22, 40, 22), (52, 86, 44), (76, 118, 60), (112, 154, 84))
FGREEN = ((16, 34, 26), (36, 70, 50), (52, 98, 66), (84, 134, 92))
DGREEN = ((14, 30, 24), (28, 58, 44), (40, 82, 60), (66, 112, 82))
YELLOW = ((90, 64, 10), (180, 140, 30), (222, 184, 54), (248, 222, 110))
PURPLE = ((34, 16, 42), (74, 34, 86), (104, 52, 118), (140, 86, 154))
VIOLET = ((40, 20, 60), (90, 50, 130), (122, 76, 170), (162, 120, 206))
BLUE   = ((16, 20, 52), (34, 46, 110), (50, 68, 150), (84, 108, 192))
GREYR  = ((30, 30, 36), (62, 62, 72), (88, 88, 100), (124, 124, 138))
SHAWL  = ((52, 36, 30), (110, 76, 60), (146, 104, 82), (182, 140, 112))
FUR    = ((64, 42, 26), (140, 104, 70), (182, 146, 104), (220, 192, 150))
STONE  = ((44, 44, 48), (100, 98, 102), (138, 136, 138), (178, 176, 176))
RBROWN = ((40, 20, 14), (92, 40, 28), (124, 60, 40), (160, 90, 60))
CYAN   = ((20, 60, 90), (60, 160, 200), (120, 220, 240), (220, 252, 255))
FLAME  = ((120, 30, 10), (220, 90, 20), (250, 160, 40), (255, 236, 140))
PINK   = ((110, 40, 60), (200, 90, 120), (236, 140, 164), (252, 196, 210))


class Portrait:
    def __init__(self):
        self.img = np.zeros((H, W, 4), np.uint8)

    @staticmethod
    def mask(fn):
        m = Image.new('L', (W, H), 0)
        fn(ImageDraw.Draw(m))
        return np.array(m) > 0

    @staticmethod
    def shift(m, dx, dy):
        o = np.zeros_like(m)
        ys = slice(max(dy, 0), H + min(dy, 0)); yd = slice(max(-dy, 0), H + min(-dy, 0))
        xs = slice(max(dx, 0), W + min(dx, 0)); xd = slice(max(-dx, 0), W + min(-dx, 0))
        o[ys, xs] = m[yd, xd]
        return o

    def put(self, m, c):
        self.img[m] = list(c[:3]) + [255]

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.img[y, x] = list(c[:3]) + [255]

    def edge(self, m):
        s = self.shift
        return m & ~(s(m, 1, 0) & s(m, -1, 0) & s(m, 0, 1) & s(m, 0, -1))

    def layer(self, m, pal, sh=2, hl=2, outline=True):
        dark, shad, base, light = pal
        self.put(m, base)
        if hl:
            self.put(m & ~self.shift(m, hl, hl), light)
        if sh:
            self.put(m & ~self.shift(m, -sh, -sh), shad)
        if outline:
            self.put(self.edge(m), dark)
        return m

    def shape(self, pal, fn, **kw):
        return self.layer(self.mask(fn), pal, **kw)

    def line(self, pts, c, width=1):
        m = self.mask(lambda d: d.line(pts, fill=1, width=width))
        self.put(m, c)

    def darken(self, m, amt):
        sel = m & (self.img[:, :, 3] > 0)
        self.img[sel, :3] = np.clip(self.img[sel, :3].astype(int) - amt, 0, 255)

    def glow(self, cx, cy, r, color, strength=0.6):
        d = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2)
        f = np.clip(1 - d / r, 0, 1) * strength
        f = np.round(f * 3) / 3  # banded, stays pixel-art
        sel = (self.img[:, :, 3] > 0) & (f > 0)
        c = np.array(color, float)
        self.img[sel, :3] = (self.img[sel, :3] * (1 - f[sel, None]) + c * f[sel, None]).astype(np.uint8)

    def hand(self, x, y, skin, w=9, h=7):
        m = self.shape(skin, lambda d: d.ellipse([x, y, x + w, y + h], fill=1), sh=1, hl=1)
        for i in range(1, 3):
            self.px(x + i * w // 3, y + h // 2, skin[1])
        return m

    def outline_all(self):
        a = self.img[:, :, 3] > 0
        s = self.shift
        out = ~a & (s(a, 1, 0) | s(a, -1, 0) | s(a, 0, 1) | s(a, 0, -1))
        self.img[out] = [30, 18, 14, 255]

    def save(self, path):
        self.outline_all()
        Image.fromarray(self.img).save(path)


# ---------- body ----------
TORSO = {
    'm': [(12, 140), (14, 80), (22, 68), (38, 61), (58, 61), (74, 68), (82, 80), (84, 140)],
    'f': [(18, 140), (20, 82), (27, 70), (40, 63), (56, 63), (69, 70), (76, 82), (78, 140)],
    'w': [(4, 140), (6, 78), (16, 66), (36, 60), (60, 60), (80, 66), (90, 78), (92, 140)],
}
NECK = {'m': [41, 52, 55, 66], 'f': [43, 52, 53, 66], 'w': [40, 52, 56, 64]}


def torso(p, build, pal, sh=4, hl=3):
    return p.shape(pal, lambda d: d.polygon(TORSO[build], fill=1), sh=sh, hl=hl)


def neck(p, build, skin):
    m = p.shape(skin, lambda d: d.rectangle(NECK[build], fill=1), sh=3, hl=0)
    p.put(m & (YY >= 54) & (YY <= 56), skin[1])
    return m


def vneck(p, skin, top=61, depth=72, half=6):
    p.shape(skin, lambda d: d.polygon([(48 - half, top), (48 + half, top), (48, depth)], fill=1), sh=1, hl=0)


def hood_down(p, pal):
    p.shape(pal, lambda d: d.ellipse([28, 54, 68, 72], fill=1), sh=2, hl=1)


# ---------- head ----------
def head(p, s):
    g = s['g']
    skin = SKINS[s['skin']]
    hair = HAIRS[s.get('hair_c', 'brown')]
    style = s.get('hair', 'short')
    hw = s.get('hat')
    race = s.get('race', 'human')

    # behind the head: hood, long hair
    if hw == 'hood':
        hc = s['hood_c']
        p.shape(hc, lambda d: (d.ellipse([27, 10, 69, 64], fill=1),
                               d.polygon([(24, 58), (72, 58), (76, 74), (20, 74)], fill=1)), sh=3, hl=2)
        p.shape(hc[:1] + (hc[0], hc[1], hc[1]), lambda d: d.ellipse([33, 18, 63, 64], fill=1), sh=0, hl=0)
    if style in ('long', 'curly_long'):
        # behind the shoulders: only where nothing is drawn yet (or above the shoulder line)
        free = (p.img[:, :, 3] == 0) | (YY < 62)
        hm = p.mask(lambda d: (d.ellipse([30, 14, 66, 50], fill=1),
                               d.polygon([(30, 32), (66, 32), (69, 78), (60, 82), (48, 66), (36, 82), (27, 78)], fill=1)))
        p.layer(hm & free, hair, sh=2, hl=1)
        for x in (33, 36, 60, 63):
            p.put(p.mask(lambda d, x=x: d.line([(x, 46), (x + (1 if x < 48 else -1), 76)], fill=1)) & hm & free, hair[1])

    # ears
    if race == 'elf':
        p.shape(skin, lambda d: (d.polygon([(38, 38), (27, 26), (36, 50)], fill=1),
                                 d.polygon([(58, 38), (69, 26), (60, 50)], fill=1)), sh=1, hl=1)
    else:
        p.shape(skin, lambda d: (d.ellipse([32, 37, 38, 49], fill=1), d.ellipse([58, 37, 64, 49], fill=1)), sh=1, hl=1)

    # face
    if g == 'f':
        fm = p.mask(lambda d: (d.ellipse([36, 22, 60, 52], fill=1),
                               d.polygon([(37, 41), (59, 41), (57, 55), (51, 61), (45, 61), (39, 55)], fill=1)))
    elif race == 'dwarf':
        fm = p.mask(lambda d: (d.ellipse([34, 22, 62, 52], fill=1),
                               d.polygon([(34, 41), (62, 41), (60, 56), (52, 62), (44, 62), (36, 56)], fill=1)))
    else:
        fm = p.mask(lambda d: (d.ellipse([35, 21, 61, 53], fill=1),
                               d.polygon([(36, 41), (60, 41), (58, 56), (52, 62), (44, 62), (38, 56)], fill=1)))
    p.layer(fm, skin, sh=3, hl=2)

    # beard
    beard = s.get('beard')
    if beard == 'stubble':
        st = fm & (YY >= 50) & ((XX + YY) % 2 == 0) & p.shift(fm, 0, -1)
        st &= ~((YY >= 53) & (YY <= 55) & (XX >= 44) & (XX <= 52))
        p.put(st, skin[1])
    elif beard in ('short', 'long', 'braided'):
        if beard == 'short':
            bm = p.mask(lambda d: d.polygon([(37, 46), (40, 51), (56, 51), (59, 46), (58, 57), (52, 64), (44, 64), (38, 57)], fill=1))
        else:
            bm = p.mask(lambda d: d.polygon([(35, 44), (39, 50), (57, 50), (61, 44), (62, 62), (56, 84), (48, 92), (40, 84), (34, 62)], fill=1))
        bm &= ~p.mask(lambda d: d.ellipse([43, 52, 53, 57], fill=1))
        p.layer(bm, hair, sh=2, hl=1)
        if beard in ('long', 'braided'):
            for y in range(60, 90, 4):
                p.line([(44, y), (52, y + 2)], hair[1])
        if beard == 'braided':
            for y in (78, 86):
                p.shape(GOLD, lambda d: d.rectangle([45, y, 51, y + 2], fill=1), sh=0, hl=0)
        # moustache
        p.shape(hair, lambda d: d.polygon([(42, 51), (48, 49), (54, 51), (55, 54), (48, 52), (41, 54)], fill=1), sh=1, hl=0)

    # hair on top
    if style != 'bald' and hw not in ('hood', 'scarf'):
        cap = p.mask(lambda d: d.ellipse([33, 15, 63, 41], fill=1))
        if style == 'spiky':
            cap |= p.mask(lambda d: d.polygon([(36, 21), (38, 11), (42, 18), (46, 10), (50, 17), (55, 11), (56, 18), (61, 15), (60, 25)], fill=1))
        if style in ('curly', 'curly_long'):
            for (cx, cy) in ((36, 22), (42, 16), (49, 14), (56, 16), (61, 22), (34, 30), (63, 30), (33, 38), (63, 38)):
                cap |= p.mask(lambda d, cx=cx, cy=cy: d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=1))
        if style == 'bun':
            cap |= p.mask(lambda d: d.ellipse([41, 6, 55, 19], fill=1))
        cap &= (YY < 30) | (XX < 37) | (XX > 59)
        side = 47 if (g == 'f' or style in ('short_f',)) else 43
        cap &= YY < side
        cap &= ~((XX >= 37) & (XX <= 59) & (YY >= 29))
        if style in ('spiky', 'short', 'short_f', 'curly', 'curly_long', 'long', 'braid', 'bun', 'ponytail'):
            if style in ('long', 'braid', 'bun', 'ponytail', 'short_f'):
                fr = p.mask(lambda d: d.polygon([(37, 29), (46, 25), (58, 28), (59, 33), (50, 30), (40, 34)], fill=1))
            else:
                fr = p.mask(lambda d: d.polygon([(38, 29), (42, 25), (46, 31), (50, 25), (54, 30), (58, 26), (59, 31), (38, 32)], fill=1))
            cap |= fr
        cap &= ~((YY >= 33) & (XX > 36) & (XX < 60))
        p.layer(cap, hair, sh=2, hl=2)
        for (x, y) in ((41, 19), (47, 16), (53, 18), (44, 23), (51, 22)):
            if cap[y, x]:
                p.px(x, y, hair[3])
    elif style == 'bald' and hw is None:
        p.shape(hair, lambda d: (d.ellipse([33, 30, 38, 42], fill=1), d.ellipse([58, 30, 63, 42], fill=1)), sh=1, hl=1)
        p.px(42, 26, skin[3]); p.px(43, 25, skin[3]); p.px(44, 25, skin[3])

    if style == 'braid':
        for i, (bx, by) in enumerate([(60, 42), (61, 49), (62, 56), (63, 63), (63, 70), (62, 77)]):
            p.shape(hair, lambda d, bx=bx, by=by: d.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=1), sh=1, hl=1)
        p.shape(LEATH, lambda d: d.rectangle([59, 81, 64, 83], fill=1), sh=0, hl=0)
        p.shape(hair, lambda d: d.polygon([(59, 84), (64, 84), (66, 90), (57, 90)], fill=1), sh=1, hl=0)

    # brows
    expr = s.get('expr', 'kind')
    bc = hair[0] if s.get('hair_c') not in ('grey', 'silver') else hair[1]
    if expr == 'stern':
        L = [(39, 36), (40, 36), (41, 36), (42, 37), (43, 37), (44, 38)]
    elif expr == 'happy':
        L = [(39, 36), (40, 35), (41, 35), (42, 35), (43, 35), (44, 36)]
    elif expr == 'sly':
        L = [(39, 35), (40, 35), (41, 35), (42, 36), (43, 36), (44, 37)]
    else:
        L = [(39, 37), (40, 36), (41, 36), (42, 36), (43, 36), (44, 36)]
    for (x, y) in L:
        p.px(x, y, bc)
        rx = 96 - x
        ry = y if expr != 'sly' else y - 1 - (x - 39) // 3
        if expr == 'sly':
            ry = 36 - (1 if x < 42 else 0)
        p.px(rx, ry, bc)
        if g == 'm' or race == 'dwarf':
            p.px(x, y - 1, bc); p.px(rx, ry - 1, bc)

    # eyes
    eye_c = s.get('eye', (52, 70, 92))
    for ex in (40, 52):
        for x in range(ex, ex + 5):
            p.px(x, 40, skin[0])
        for x in range(ex, ex + 5):
            p.px(x, 41, (236, 228, 214))
        p.px(ex + 2, 41, eye_c); p.px(ex + 3, 41, eye_c)
        p.px(ex + 2, 41, tuple(int(c * 0.5) for c in eye_c))
        for x in range(ex + 1, ex + 4):
            p.px(x, 42, skin[1])
        if g == 'f':
            p.px(ex - 1 if ex == 40 else ex + 5, 39, skin[0])
    if s.get('eye_glow'):
        for ex in (40, 52):
            p.px(ex + 2, 41, CYAN[3]); p.px(ex + 3, 41, CYAN[2])

    # nose
    nl = 49 if race != 'dwarf' else 50
    for y in range(42, nl):
        p.px(49, y, skin[1])
    p.px(46, nl - 1, skin[1]); p.px(47, nl - 1, skin[1]); p.px(48, nl - 1, skin[1])
    p.px(46, nl, skin[0]); p.px(49, nl, skin[0])
    for y in range(43, 47):
        p.px(47, y, skin[3])
    if race == 'dwarf':
        p.shape(skin, lambda d: d.ellipse([44, 43, 52, 51], fill=1), sh=1, hl=1)
    if s.get('red_nose'):
        for (x, y) in ((47, 47), (48, 47), (48, 48), (47, 48), (46, 48)):
            p.px(x, y, (204, 92, 84))

    # mouth
    mouth = s.get('mouth', 'flat')
    if beard not in ('short', 'long', 'braided'):
        if g == 'f':
            lip = (178, 86, 88); lipl = (206, 118, 112)
            if mouth in ('smile', 'grin'):
                for x in range(46, 51):
                    p.px(x, 54, lip)
                p.px(45, 53, lip); p.px(51, 53, lip)
                if mouth == 'grin':
                    for x in range(46, 51):
                        p.px(x, 55, (240, 236, 228))
                    for x in range(47, 50):
                        p.px(x, 56, lip)
                else:
                    for x in range(47, 50):
                        p.px(x, 55, lipl)
            elif mouth == 'smirk':
                for x in range(45, 51):
                    p.px(x, 54, lip)
                p.px(51, 53, lip)
                for x in range(46, 50):
                    p.px(x, 55, lipl)
            else:
                for x in range(46, 51):
                    p.px(x, 54, lip)
                for x in range(47, 50):
                    p.px(x, 55, lipl)
        else:
            if mouth == 'grin':
                for x in range(44, 53):
                    p.px(x, 53, skin[0])
                for x in range(45, 52):
                    p.px(x, 54, (240, 236, 228))
                for x in range(45, 52):
                    p.px(x, 55, (110, 40, 36))
                for x in range(46, 51):
                    p.px(x, 56, skin[0])
                p.px(43, 52, skin[0]); p.px(53, 52, skin[0])
            elif mouth == 'smile':
                for x in range(45, 52):
                    p.px(x, 54, skin[0])
                p.px(44, 53, skin[0]); p.px(52, 53, skin[0])
                for x in range(46, 51):
                    p.px(x, 55, skin[1])
            elif mouth == 'smirk':
                for x in range(44, 52):
                    p.px(x, 54, skin[0])
                p.px(52, 53, skin[0])
            else:
                for x in range(44, 53):
                    p.px(x, 54, skin[0])
                for x in range(46, 51):
                    p.px(x, 55, skin[1])
    elif mouth in ('smile', 'grin'):
        for x in range(45, 52):
            p.px(x, 55, (110, 40, 36))

    # cheeks, age, freckles, scar
    if s.get('blush'):
        for (x, y) in ((41, 46), (42, 46), (54, 46), (55, 46), (41, 47), (55, 47)):
            p.px(x, y, (226, 130, 120))
    if s.get('old'):
        for x in range(41, 45):
            p.px(x, 43, skin[1])
        for x in range(53, 57):
            p.px(x, 43, skin[1])
        p.line([(44, 50), (43, 54)], skin[1]); p.line([(54, 50), (55, 54)], skin[1])
        p.px(38, 40, skin[1]); p.px(58, 40, skin[1])
    if s.get('freckles'):
        for (x, y) in ((40, 45), (42, 46), (44, 45), (52, 45), (54, 46), (56, 45), (43, 44), (53, 44)):
            p.px(x, y, skin[1])
    if s.get('scar'):
        for (x, y) in [(38, 42), (39, 44), (40, 45), (41, 47), (42, 48)]:
            p.px(x, y, (228, 150, 140)); p.px(x + 1, y, (150, 78, 70))

    # headwear in front
    if hw == 'straw':
        p.shape(STRAW, lambda d: d.ellipse([35, 6, 61, 30], fill=1), sh=2, hl=2)
        p.shape(RED, lambda d: d.rectangle([36, 22, 60, 25], fill=1), sh=1, hl=0)
        p.shape(STRAW, lambda d: d.ellipse([20, 24, 76, 34], fill=1), sh=2, hl=1)
        for x in range(24, 74, 3):
            p.px(x, 29, STRAW[1])
    elif hw == 'scarf':
        sc = s['scarf_c']
        m = p.mask(lambda d: d.ellipse([32, 13, 64, 47], fill=1)) & ~p.mask(lambda d: d.ellipse([37, 27, 59, 70], fill=1))
        m |= p.mask(lambda d: d.polygon([(33, 34), (37, 34), (39, 52), (34, 50)], fill=1))
        m |= p.mask(lambda d: d.polygon([(63, 34), (59, 34), (57, 52), (62, 50)], fill=1))
        p.layer(m, sc, sh=2, hl=2)
        p.shape(sc, lambda d: (d.ellipse([60, 40, 68, 47], fill=1), d.polygon([(63, 46), (70, 58), (64, 58)], fill=1)), sh=1, hl=1)
        for (x, y) in ((40, 20), (46, 17), (52, 18), (57, 22), (36, 30), (60, 30)):
            p.px(x, y, sc[3])
        # a little fringe showing
        p.shape(hair, lambda d: d.polygon([(38, 30), (48, 27), (58, 30), (58, 33), (38, 33)], fill=1), sh=1, hl=1)
    elif hw == 'hood':
        hc = s['hood_c']
        rim = p.mask(lambda d: d.ellipse([29, 11, 67, 50], fill=1)) & ~p.mask(lambda d: d.ellipse([36, 23, 60, 64], fill=1))
        p.layer(rim, hc, sh=2, hl=2)
        # hair peeking under the hood
        p.shape(hair, lambda d: d.polygon([(37, 30), (46, 25), (59, 29), (59, 33), (50, 30), (38, 34)], fill=1), sh=1, hl=1)
    elif hw == 'pointed':
        hc = s['hat_c']
        p.shape(hc, lambda d: d.polygon([(35, 26), (61, 26), (57, 14), (52, 4), (44, -2), (36, 0), (45, 6), (40, 16)], fill=1), sh=2, hl=2)
        p.shape(hc, lambda d: d.ellipse([22, 22, 74, 32], fill=1), sh=2, hl=1)
        p.shape(GOLD if s.get('hat_band', 'gold') == 'gold' else STEEL, lambda d: d.rectangle([37, 21, 59, 24], fill=1), sh=0, hl=0)
        for (x, y) in ((46, 12), (52, 17), (42, 5)):
            p.px(x, y, YELLOW[3]); p.px(x + 1, y, YELLOW[2]); p.px(x, y + 1, YELLOW[2])
    elif hw == 'wreath':
        for i, x in enumerate(range(35, 62, 3)):
            y = int(25 - 7 * math.sin((x - 35) / 26 * math.pi)) + 2
            p.shape(GREEN, lambda d, x=x, y=y: d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=1), sh=0, hl=1)
        for (x, y, c) in ((38, 22, PINK), (47, 17, YELLOW), (56, 21, PINK), (42, 19, WHITE), (52, 18, WHITE)):
            p.px(x, y, c[2]); p.px(x + 1, y, c[3]); p.px(x, y + 1, c[1])


# ---------- the cast ----------
def peasant_m(p):
    s = dict(g='m', skin='tan', hair='short', hair_c='brown', beard='stubble', expr='kind', mouth='smile', hat='straw')
    torso(p, 'm', LINEN)
    vest = p.mask(lambda d: d.polygon(TORSO['m'], fill=1)) & ((XX < 40) | (XX > 56)) & (YY > 66)
    p.layer(vest, LEATH, sh=2, hl=1)
    neck(p, 'm', SKINS['tan'])
    vneck(p, SKINS['tan'], top=61, depth=74, half=7)
    p.shape(LINEN, lambda d: d.polygon([(38, 60), (44, 60), (47, 72), (40, 66)], fill=1), sh=0, hl=1)
    p.shape(LINEN, lambda d: d.polygon([(58, 60), (52, 60), (49, 72), (56, 66)], fill=1), sh=0, hl=1)
    p.line([(14, 112), (82, 112)], LEATH[1], 2)
    head(p, s)
    # sack on the shoulder
    p.shape(BURLAP, lambda d: d.polygon([(62, 52), (72, 44), (88, 50), (94, 66), (90, 84), (74, 88), (62, 78)], fill=1), sh=3, hl=2)
    p.shape(BURLAP, lambda d: d.polygon([(60, 54), (54, 42), (62, 40), (66, 48)], fill=1), sh=1, hl=1)
    p.line([(58, 50), (66, 47)], LEATH[0], 2)
    for (a, b) in (((72, 54), (80, 66)), ((84, 56), (86, 74)), ((70, 70), (78, 82))):
        p.line([a, b], BURLAP[1])
    p.hand(60, 70, SKINS['tan'])


def peasant_f(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='blond', expr='kind', mouth='smile', hat='scarf', scarf_c=RED, blush=True)
    torso(p, 'f', RBROWN)
    p.shape(WHITE, lambda d: d.polygon([(40, 62), (56, 62), (55, 70), (41, 70)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=69, half=5)
    p.shape(WHITE, lambda d: d.polygon([(34, 82), (62, 82), (66, 128), (30, 128)], fill=1), sh=2, hl=1)
    p.line([(36, 82), (42, 66)], WHITE[1], 2); p.line([(60, 82), (54, 66)], WHITE[1], 2)
    head(p, s)
    # basket of eggs
    p.shape(WOOD, lambda d: d.arc([28, 84, 66, 120], 180, 360, fill=1, width=3), sh=0, hl=0)
    bm = p.shape(STRAW, lambda d: d.polygon([(24, 104), (70, 104), (64, 128), (30, 128)], fill=1), sh=2, hl=1)
    for y in range(107, 128, 3):
        p.put(bm & (YY == y) & (XX % 2 == 0), STRAW[1])
    for (ex, ey) in ((32, 97), (40, 95), (48, 96), (56, 95), (36, 100), (52, 100)):
        p.shape(WHITE, lambda d, ex=ex, ey=ey: d.ellipse([ex, ey, ex + 7, ey + 8], fill=1), sh=1, hl=1)
    p.shape(STRAW, lambda d: d.rectangle([24, 103, 70, 106], fill=1), sh=1, hl=1)
    p.hand(18, 100, sk); p.hand(68, 100, sk)


def reveler_m(p):
    sk = SKINS['mid']
    s = dict(g='m', skin='mid', hair='curly', hair_c='black', beard='stubble', expr='happy', mouth='grin', red_nose=True, blush=True)
    torso(p, 'm', GREEN)
    p.shape(WHITE, lambda d: d.polygon([(38, 61), (58, 61), (54, 100), (42, 100)], fill=1), sh=2, hl=1)
    neck(p, 'm', sk)
    vneck(p, sk, top=61, depth=80, half=8)
    for y in range(70, 128, 8):
        p.shape(YELLOW, lambda d, y=y: d.rectangle([34, y, 37, y + 3], fill=1), sh=0, hl=0)
    p.line([(37, 61), (40, 128)], YELLOW[2], 2); p.line([(59, 61), (56, 128)], YELLOW[2], 2)
    head(p, s)
    # raised arm with a mug
    p.shape(GREEN, lambda d: d.polygon([(68, 70), (84, 74), (86, 128), (72, 128)], fill=1), sh=2, hl=1)
    p.hand(66, 60, sk, w=12, h=10)
    p.shape(WOOD, lambda d: d.ellipse([78, 44, 88, 58], fill=1), sh=1, hl=0)
    p.shape(WOOD, lambda d: d.rectangle([64, 38, 80, 64], fill=1), sh=2, hl=2)
    for y in (42, 58):
        p.line([(64, y), (80, y)], STEEL[1], 2)
    p.shape(WHITE, lambda d: (d.ellipse([62, 32, 82, 42], fill=1), d.ellipse([60, 34, 66, 46], fill=1)), sh=1, hl=1)
    p.hand(64, 56, sk, w=12, h=8)


def reveler_f(p):
    sk = SKINS['olive']
    s = dict(g='f', skin='olive', hair='curly_long', hair_c='auburn', expr='happy', mouth='grin', blush=True)
    torso(p, 'f', RED)
    p.shape(WHITE, lambda d: (d.ellipse([16, 62, 36, 86], fill=1), d.ellipse([60, 62, 80, 86], fill=1)), sh=2, hl=2)
    neck(p, 'f', sk)
    p.shape(sk, lambda d: d.polygon([(36, 63), (60, 63), (56, 76), (40, 76)], fill=1), sh=1, hl=0)
    p.shape(WHITE, lambda d: d.polygon([(36, 74), (60, 74), (58, 78), (38, 78)], fill=1), sh=0, hl=0)
    for y in range(82, 124, 6):
        p.line([(44, y), (52, y + 4)], YELLOW[2]); p.line([(52, y), (44, y + 4)], YELLOW[2])
    head(p, s)
    # goblet raised
    p.hand(14, 68, sk, w=10, h=9)
    p.shape(GOLD, lambda d: d.polygon([(10, 46), (28, 46), (25, 58), (13, 58)], fill=1), sh=1, hl=2)
    p.shape(CRIMS, lambda d: d.rectangle([12, 46, 26, 49], fill=1), sh=0, hl=0)
    p.shape(GOLD, lambda d: d.rectangle([17, 58, 21, 68], fill=1), sh=1, hl=0)
    p.shape(RED, lambda d: d.polygon([(10, 76), (28, 74), (34, 128), (12, 128)], fill=1), sh=2, hl=1)


def herbalist_f_01(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='brown', expr='kind', mouth='smile', hat='wreath', eye=(60, 110, 60))
    hood_down(p, FGREEN)
    torso(p, 'f', FGREEN)
    p.shape(LINEN, lambda d: d.polygon([(40, 63), (56, 63), (52, 128), (44, 128)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    p.shape(GOLD, lambda d: d.ellipse([45, 70, 51, 75], fill=1), sh=0, hl=1)
    p.line([(68, 70), (30, 128)], LEATH[2], 3)
    head(p, s)
    # bundle of herbs
    for i, (x0, c) in enumerate(((22, GREEN), (26, FGREEN), (30, GREEN), (24, YELLOW), (28, PINK))):
        p.line([(x0 + 8, 120), (x0 - 2, 78 + i * 2)], GREEN[1], 1)
        p.shape(c, lambda d, x0=x0, i=i: d.ellipse([x0 - 6, 72 + i * 2, x0 + 1, 80 + i * 2], fill=1), sh=1, hl=1)
    p.shape(LEATH, lambda d: d.rectangle([28, 104, 36, 107], fill=1), sh=0, hl=0)
    p.hand(26, 106, sk)


def herbalist_f_02(p):
    sk = SKINS['mid']
    s = dict(g='f', skin='mid', hair='braid', hair_c='grey', expr='kind', mouth='smile', old=True, eye=(80, 70, 50))
    torso(p, 'f', GREYR)
    neck(p, 'f', sk)
    p.shape(SHAWL, lambda d: d.polygon([(18, 76), (40, 62), (56, 62), (78, 76), (66, 100), (48, 116), (30, 100)], fill=1), sh=2, hl=2)
    for x in range(30, 66, 3):
        y = 100 + int(16 * (1 - abs(x - 48) / 18))
        p.px(x, min(y, 127), SHAWL[0])
    p.shape(SHAWL, lambda d: d.polygon([(40, 62), (56, 62), (48, 74)], fill=1), sh=0, hl=0)
    vneck(p, sk, top=63, depth=70, half=4)
    head(p, s)
    # mortar with herbs
    p.shape(WOOD, lambda d: d.line([(56, 92), (70, 74)], fill=1, width=4), sh=1, hl=1)
    p.shape(STONE, lambda d: (d.ellipse([28, 96, 68, 108], fill=1), d.polygon([(30, 102), (66, 102), (60, 124), (36, 124)], fill=1)), sh=3, hl=2)
    p.shape(STONE, lambda d: d.rectangle([38, 122, 58, 128], fill=1), sh=1, hl=0)
    p.shape(GREEN, lambda d: d.ellipse([33, 97, 63, 104], fill=1), sh=1, hl=1)
    p.hand(24, 104, sk); p.hand(64, 104, sk)


def merchant_m(p):
    sk = SKINS['light']
    s = dict(g='m', skin='light', hair='short', hair_c='black', beard='short', expr='sly', mouth='smile', eye=(70, 56, 40))
    p.shape(PURPLE, lambda d: d.polygon([(8, 140), (12, 84), (22, 68), (38, 61), (58, 61), (74, 68), (84, 84), (88, 140)], fill=1), sh=4, hl=3)
    p.shape(GOLD, lambda d: d.rectangle([46, 84, 50, 128], fill=1), sh=0, hl=1)
    for y in range(90, 128, 9):
        p.shape(GOLD, lambda d, y=y: d.ellipse([46, y, 50, y + 4], fill=1), sh=0, hl=1)
    neck(p, 'm', sk)
    p.shape(FUR, lambda d: d.ellipse([24, 56, 72, 84], fill=1), sh=3, hl=2)
    fm = p.mask(lambda d: d.ellipse([24, 56, 72, 84], fill=1))
    p.put(fm & ((XX + YY * 3) % 5 == 0) & p.shift(fm, 1, 1) & p.shift(fm, -1, -1), FUR[1])
    p.shape(sk, lambda d: d.ellipse([38, 56, 58, 72], fill=1), sh=2, hl=0)
    head(p, s)
    p.shape(GOLD, lambda d: d.arc([34, 60, 62, 90], 20, 160, fill=1, width=2), sh=0, hl=0)
    # coin purse
    p.shape(LEATH, lambda d: d.ellipse([60, 96, 82, 120], fill=1), sh=2, hl=2)
    p.shape(LEATH, lambda d: d.polygon([(64, 98), (78, 98), (74, 92), (68, 92)], fill=1), sh=1, hl=1)
    for (x, y) in ((66, 90), (72, 88)):
        p.shape(GOLD, lambda d, x=x, y=y: d.ellipse([x, y, x + 6, y + 4], fill=1), sh=0, hl=1)
    p.hand(56, 104, sk, w=10, h=8)
    p.px(60, 106, GOLD[3]); p.px(61, 106, GOLD[2])


def merchant_f(p):
    sk = SKINS['dark']
    s = dict(g='f', skin='dark', hair='bun', hair_c='black', expr='sly', mouth='smirk', eye=(60, 40, 30))
    torso(p, 'f', DGREEN)
    p.shape(WHITE, lambda d: d.polygon([(36, 63), (60, 63), (64, 70), (48, 76), (32, 70)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=73, half=6)
    for i in range(9):
        a = math.pi * (0.15 + 0.7 * i / 8)
        x = int(48 - 10 * math.cos(a)); y = int(62 + 9 * math.sin(a))
        p.px(x, y, WHITE[3]); p.px(x + 1, y, WHITE[1])
    for x in (22, 74):
        p.shape(GOLD, lambda d, x=x: d.rectangle([x - 1, 70, x + 1, 128], fill=1), sh=0, hl=0)
    head(p, s)
    p.px(35, 48, GOLD[3]); p.px(35, 49, GOLD[2]); p.px(61, 48, GOLD[3]); p.px(61, 49, GOLD[2])
    # ledger
    p.shape(WHITE, lambda d: d.polygon([(20, 96), (52, 92), (54, 122), (22, 126)], fill=1), sh=1, hl=0)
    p.shape(CRIMS, lambda d: d.polygon([(18, 98), (50, 94), (52, 124), (20, 128)], fill=1), sh=2, hl=2)
    for (x, y) in ((19, 99), (48, 95), (50, 121), (21, 125)):
        p.shape(GOLD, lambda d, x=x, y=y: d.rectangle([x, y, x + 2, y + 2], fill=1), sh=0, hl=0)
    p.shape(GOLD, lambda d: d.ellipse([30, 106, 40, 114], fill=1), sh=0, hl=1)
    p.hand(46, 104, sk)


def mage_f_01(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='long', hair_c='black', expr='kind', mouth='smile', hat='pointed', hat_c=BLUE, eye=(70, 120, 200))
    torso(p, 'f', BLUE)
    p.shape(STEEL, lambda d: d.polygon([(40, 63), (56, 63), (48, 74)], fill=1), sh=0, hl=0)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    m = p.mask(lambda d: d.polygon(TORSO['f'], fill=1))
    for (x, y) in ((26, 86), (34, 100), (66, 90), (60, 110), (30, 118), (70, 122), (44, 92)):
        p.px(x, y, STEEL[3]); p.px(x - 1, y, STEEL[1]); p.px(x + 1, y, STEEL[1]); p.px(x, y - 1, STEEL[1]); p.px(x, y + 1, STEEL[1])
    head(p, s)
    # crystal in palm
    p.hand(40, 108, sk, w=16, h=8)
    p.shape(CYAN, lambda d: d.polygon([(48, 86), (54, 96), (48, 108), (42, 96)], fill=1), sh=2, hl=2)
    p.glow(48, 96, 22, (150, 220, 255), 0.5)
    for (x, y) in ((38, 88), (58, 92), (46, 80), (56, 82)):
        p.px(x, y, CYAN[3])


def mage_f_02(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', race='elf', hair='long', hair_c='silver', expr='kind', mouth='flat', eye=(140, 90, 200))
    # staff behind the shoulder
    p.shape(WOOD, lambda d: d.rectangle([72, 30, 75, 128], fill=1), sh=1, hl=1)
    torso(p, 'f', VIOLET)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    p.line([(40, 63), (36, 128)], GOLD[2], 2); p.line([(56, 63), (60, 128)], GOLD[2], 2)
    for (x, y) in ((28, 90), (64, 100), (30, 112), (66, 120)):
        p.line([(x, y), (x + 3, y)], GOLD[3]); p.line([(x + 1, y), (x + 1, y + 4)], GOLD[3]); p.px(x + 3, y + 3, GOLD[3])
    head(p, s)
    p.shape(VIOLET, lambda d: d.ellipse([66, 20, 82, 36], fill=1), sh=2, hl=2)
    p.glow(74, 28, 16, (220, 180, 255), 0.6)
    p.px(72, 25, WHITE[3]); p.px(73, 25, WHITE[3])
    p.hand(68, 88, sk)


def hero_warrior_f(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='braid', hair_c='red', expr='stern', mouth='smirk', freckles=True, eye=(60, 110, 70))
    torso(p, 'f', MAIL)
    bp = p.mask(lambda d: d.polygon([(28, 72), (68, 72), (66, 110), (48, 120), (30, 110)], fill=1))
    p.layer(bp, STEEL, sh=3, hl=3)
    p.line([(48, 73), (48, 118)], STEEL[3])
    p.shape(STEEL, lambda d: (d.ellipse([12, 62, 38, 88], fill=1), d.ellipse([58, 62, 84, 88], fill=1)), sh=2, hl=2)
    neck(p, 'f', sk)
    head(p, s)
    # sword hilt over the shoulder
    p.shape(LEATH, lambda d: d.line([(72, 66), (80, 40)], fill=1, width=4), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.polygon([(64, 64), (84, 70), (83, 74), (62, 68)], fill=1), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.ellipse([77, 32, 85, 40], fill=1), sh=1, hl=1)
    # round shield
    p.shape(WOOD, lambda d: d.ellipse([2, 86, 42, 126], fill=1), sh=3, hl=2)
    for x in range(8, 40, 6):
        p.line([(x, 88), (x, 124)], WOOD[1])
    p.layer(p.mask(lambda d: d.ellipse([2, 86, 42, 126], fill=1)) & ~p.mask(lambda d: d.ellipse([6, 90, 38, 122], fill=1)), STEEL, sh=1, hl=1)
    p.shape(STEEL, lambda d: d.ellipse([16, 100, 28, 112], fill=1), sh=1, hl=2)


def hero_archer_m(p):
    sk = SKINS['olive']
    s = dict(g='m', skin='olive', race='elf', hair='long', hair_c='blond', expr='stern', mouth='flat', hat='hood', hood_c=FGREEN, eye=(70, 130, 80))
    # bow behind, viewer-left
    p.shape(WOOD, lambda d: d.arc([-10, 20, 34, 140], 100, 260, fill=1, width=4), sh=0, hl=0)
    p.line([(10, 22), (10, 138)], WHITE[2])
    # quiver feathers behind viewer-right shoulder
    for i, x in enumerate((66, 71, 76)):
        p.line([(x, 70), (x + 4, 46)], WOOD[2], 1)
        p.shape(RED if i != 1 else WHITE, lambda d, x=x: d.polygon([(x + 2, 52), (x + 6, 40), (x + 7, 48)], fill=1), sh=0, hl=1)
    torso(p, 'm', LEATH)
    p.shape(FGREEN, lambda d: (d.ellipse([10, 62, 36, 88], fill=1), d.ellipse([60, 62, 86, 88], fill=1)), sh=2, hl=1)
    neck(p, 'm', sk)
    for y in range(78, 128, 7):
        p.line([(46, y), (50, y + 3)], DLEATH[0]); p.line([(50, y), (46, y + 3)], DLEATH[0])
    p.line([(72, 66), (28, 128)], DLEATH[2], 3)
    head(p, s)


def hero_archer_f(p):
    sk = SKINS['mid']
    s = dict(g='f', skin='mid', hair='long', hair_c='black', expr='stern', mouth='flat', freckles=True, eye=(90, 70, 40))
    for i, x in enumerate((14, 19, 24)):
        p.line([(x + 6, 76), (x, 46)], WOOD[2], 1)
        p.shape(WHITE if i != 1 else GREEN, lambda d, x=x: d.polygon([(x - 2, 40), (x + 2, 52), (x - 3, 50)], fill=1), sh=0, hl=1)
    hood_down(p, DLEATH)
    torso(p, 'f', LEATH)
    p.shape(DLEATH, lambda d: d.ellipse([14, 64, 38, 88], fill=1), sh=2, hl=1)
    for (x, y) in ((22, 70), (30, 72), (20, 78)):
        p.px(x, y, STEEL[3])
    neck(p, 'f', sk)
    p.line([(26, 68), (68, 128)], DLEATH[2], 3)
    p.line([(26, 108), (70, 108)], DLEATH[1], 2)
    head(p, s)
    # bow held in front, viewer-right
    p.shape(WOOD, lambda d: d.arc([62, 52, 104, 140], 100, 260, fill=1, width=4), sh=0, hl=0)
    p.line([(80, 54), (80, 138)], WHITE[2])
    p.hand(64, 94, sk)


def hero_mage_m(p):
    sk = SKINS['dark']
    s = dict(g='m', skin='dark', hair='short', hair_c='black', beard='short', expr='stern', mouth='flat', eye_glow=True)
    p.shape(WOOD, lambda d: d.rectangle([16, 20, 20, 128], fill=1), sh=1, hl=1)
    hood_down(p, GREYR)
    torso(p, 'm', GREYR)
    p.shape(GREYR, lambda d: d.polygon([(38, 61), (58, 61), (56, 128), (40, 128)], fill=1), sh=1, hl=1)
    neck(p, 'm', sk)
    p.line([(36, 61), (40, 128)], STEEL[2], 1); p.line([(60, 61), (56, 128)], STEEL[2], 1)
    p.line([(20, 108), (76, 108)], LEATH[2], 3)
    head(p, s)
    p.shape(CYAN, lambda d: d.polygon([(18, 4), (25, 14), (18, 26), (11, 14)], fill=1), sh=2, hl=2)
    p.shape(GOLD, lambda d: d.polygon([(12, 24), (24, 24), (21, 30), (15, 30)], fill=1), sh=0, hl=1)
    p.glow(18, 14, 18, (150, 220, 255), 0.55)
    p.hand(12, 80, sk)


def hero_mage_f(p):
    sk = SKINS['light']
    s = dict(g='f', skin='light', hair='short_f', hair_c='blond', expr='stern', mouth='smirk', eye=(80, 120, 160))
    hood_down(p, CRIMS)
    torso(p, 'f', CRIMS)
    p.shape(GREYR, lambda d: d.polygon([(40, 63), (56, 63), (54, 128), (42, 128)], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    vneck(p, sk, top=63, depth=72, half=5)
    p.shape(GOLD, lambda d: d.ellipse([38, 66, 44, 72], fill=1), sh=0, hl=1)
    p.shape(GOLD, lambda d: d.ellipse([52, 66, 58, 72], fill=1), sh=0, hl=1)
    p.line([(41, 69), (55, 69)], GOLD[1])
    head(p, s)
    # spellbook under arm, viewer-left
    p.shape(RBROWN, lambda d: d.polygon([(10, 96), (34, 92), (36, 122), (12, 126)], fill=1), sh=2, hl=2)
    p.shape(GOLD, lambda d: d.ellipse([18, 104, 28, 114], fill=1), sh=0, hl=1)
    # flame above the palm
    p.hand(62, 104, sk, w=14, h=7)
    p.shape(FLAME, lambda d: d.polygon([(63, 104), (76, 104), (78, 94), (73, 86), (72, 76), (67, 88), (64, 84), (61, 94)], fill=1), sh=2, hl=2)
    p.shape(YELLOW, lambda d: d.polygon([(66, 103), (73, 103), (73, 96), (70, 90), (67, 97)], fill=1), sh=0, hl=1, outline=False)
    p.glow(69, 94, 20, (255, 170, 80), 0.45)


def hero_tank_m(p):
    sk = SKINS['mid']
    s = dict(g='m', skin='mid', race='dwarf', hair='bald', hair_c='red', beard='braided', expr='stern', mouth='flat')
    torso(p, 'w', STEEL)
    p.shape(STEEL, lambda d: (d.ellipse([0, 58, 34, 92], fill=1), d.ellipse([62, 58, 96, 92], fill=1)), sh=3, hl=2)
    for x0 in (6, 68):
        p.line([(x0, 72), (x0 + 22, 72)], STEEL[0]); p.line([(x0 + 2, 80), (x0 + 20, 80)], STEEL[0])
    neck(p, 'w', sk)
    head(p, s)
    # tower shield, viewer-left
    p.shape(WOOD, lambda d: (d.rectangle([2, 92, 52, 128], fill=1), d.ellipse([2, 82, 52, 104], fill=1)), sh=3, hl=2)
    sm = p.mask(lambda d: (d.rectangle([2, 92, 52, 128], fill=1), d.ellipse([2, 82, 52, 104], fill=1)))
    p.layer(sm & ~p.mask(lambda d: (d.rectangle([6, 95, 48, 128], fill=1), d.ellipse([6, 86, 48, 106], fill=1))), STEEL, sh=1, hl=1)
    p.shape(STEEL, lambda d: d.rectangle([24, 86, 30, 128], fill=1), sh=1, hl=1)
    p.shape(STEEL, lambda d: d.rectangle([4, 106, 50, 112], fill=1), sh=1, hl=1)
    p.shape(GOLD, lambda d: d.ellipse([22, 104, 32, 114], fill=1), sh=1, hl=1)


def hero_tank_f(p):
    sk = SKINS['tan']
    s = dict(g='f', skin='tan', hair='short_f', hair_c='black', expr='kind', mouth='flat', eye=(70, 50, 30))
    torso(p, 'w', STEEL)
    p.shape(STEEL, lambda d: (d.ellipse([0, 58, 34, 92], fill=1), d.ellipse([62, 58, 96, 92], fill=1)), sh=3, hl=2)
    for x0 in (6, 68):
        p.line([(x0, 72), (x0 + 22, 72)], STEEL[0])
    p.line([(48, 72), (48, 128)], STEEL[3])
    p.shape(MAIL, lambda d: d.rectangle([40, 58, 56, 68], fill=1), sh=1, hl=1)
    neck(p, 'f', sk)
    head(p, s)
    # kite shield, viewer-right
    km = p.shape(BLUE, lambda d: d.polygon([(50, 84), (92, 84), (90, 104), (71, 128), (52, 104)], fill=1), sh=3, hl=2)
    p.layer(km & ~p.mask(lambda d: d.polygon([(54, 87), (88, 87), (86, 103), (71, 123), (56, 103)], fill=1)), GOLD, sh=1, hl=1)
    p.shape(GOLD, lambda d: d.polygon([(71, 92), (76, 100), (71, 112), (66, 100)], fill=1), sh=1, hl=1)
    p.hand(46, 94, sk)


CAST = {
    'peasant_m_01': peasant_m, 'peasant_f_01': peasant_f,
    'reveler_m_01': reveler_m, 'reveler_f_01': reveler_f,
    'herbalist_f_01': herbalist_f_01, 'herbalist_f_02': herbalist_f_02,
    'merchant_m_01': merchant_m, 'merchant_f_01': merchant_f,
    'mage_f_01': mage_f_01, 'mage_f_02': mage_f_02,
    'hero_warrior_f_01': hero_warrior_f,
    'hero_archer_m_01': hero_archer_m, 'hero_archer_f_01': hero_archer_f,
    'hero_mage_m_01': hero_mage_m, 'hero_mage_f_01': hero_mage_f,
    'hero_tank_m_01': hero_tank_m, 'hero_tank_f_01': hero_tank_f,
}

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    only = sys.argv[2:] or list(CAST)
    for name in only:
        p = Portrait()
        CAST[name](p)
        p.save(os.path.join(out, name + '.png'))
    print('done', len(only))
