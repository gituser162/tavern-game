"""Pixel-art ale keg lying on a little cradle, 26x16, standing on the counter (same palette/light as the background:
lit from the upper left). Run: python3 gen_keg.py <project>/assets/objects/keg.png [level]
level (the "Пивний погріб" upgrade): 0 = plain keg (keg.png), 1 = brass hoops and tap (keg_2.png),
2 = brass hoops, a third hoop and the griffin's red-gold crest painted on the staves (keg_3.png)."""
import sys
from PIL import Image

LEVEL = int(sys.argv[2]) if len(sys.argv) > 2 else 0
W, H = 26, 16
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
p = im.load()


def c(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


OUT = c("1a0f0a")
WOOD = [c("a07448"), c("8a6038"), c("6a4426"), c("553420"), c("3e2616")]   # light -> dark
SEAM = c("4a2e1c")
END = [c("b08458"), c("9a7248"), c("7a5634")]
HOOP = [c("8a8a94"), c("6a6a72"), c("4a4a52")]
BRASS = [c("f0d070"), c("c8a040"), c("8a6a22")]
STAND = [c("6e4e30"), c("5a3a22"), c("3e2616")]


def put(x, y, col):
    if 0 <= x < W and 0 <= y < H:
        p[x, y] = col


# body: rows 1..11, rounded ends; shade by row (light on top)
rows = {1: (7, 22), 2: (6, 23), 3: (6, 23), 4: (6, 23), 5: (6, 23), 6: (6, 23), 7: (6, 23), 8: (6, 23), 9: (6, 23), 10: (6, 23), 11: (7, 22)}
shade = {1: 0, 2: 0, 3: 1, 4: 1, 5: 2, 6: 2, 7: 2, 8: 3, 9: 3, 10: 4, 11: 4}
for y, (x0, x1) in rows.items():
    for x in range(x0, x1 + 1):
        put(x, y, WOOD[shade[y]])
# stave seams (broken lines)
for y in (4, 8):
    for x in range(7, 23):
        if (x + y) % 7 != 0:
            put(x, y, SEAM)
if LEVEL >= 1:
    HOOP = BRASS
# iron hoops
for x in ((9, 14, 19) if LEVEL >= 2 else (9, 19)):
    for y in range(1, 12):
        put(x, y, HOOP[0] if y <= 3 else (HOOP[1] if y <= 8 else HOOP[2]))
if LEVEL >= 2:
    # the griffin crest: a small red shield with a gold dot between the hoops
    for y in range(4, 9):
        for x in range(11, 14 if y < 7 else 13):
            put(x, y, c("a82a2a") if x > 10 + (y - 6) else c("a82a2a"))
    put(12, 9, c("8a1e1e"))
    put(12, 5, BRASS[0]); put(12, 6, BRASS[1]); put(11, 5, BRASS[1])
# end face (towards the left, a bit lighter = end grain) with its own hoop
for y in range(2, 11):
    put(4, y, END[1] if 3 <= y <= 9 else END[2])
    put(5, y, END[0] if y <= 6 else END[1])
put(4, 4, END[0]); put(5, 9, END[2])
for y in range(2, 11):
    put(3, y, HOOP[1] if y < 8 else HOOP[2])
# tap: brass pipe out of the end face, spout pointing down, little wooden handle on top
put(2, 7, BRASS[1]); put(1, 7, BRASS[0]); put(0, 7, BRASS[1])
put(0, 8, BRASS[2]); put(0, 9, BRASS[2])
put(1, 6, SEAM); put(1, 5, STAND[0])
# cradle: two little trestles under the keg
for x0 in (8, 18):
    for x in range(x0, x0 + 4):
        put(x, 12, STAND[0] if x < x0 + 2 else STAND[1])
    for y in (13, 14):
        put(x0, y, STAND[1]); put(x0 + 3, y, STAND[2])
# outline
a = [[p[x, y][3] > 0 for x in range(W)] for y in range(H)]
for y in range(H):
    for x in range(W):
        if a[y][x]:
            continue
        if any(0 <= x + dx < W and 0 <= y + dy < H and a[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            p[x, y] = OUT
im.save(sys.argv[1])
print("saved", sys.argv[1])
