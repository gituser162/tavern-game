import numpy as np
from PIL import Image, ImageDraw
W,H=96,152
img=np.zeros((H,W,4),np.uint8)
def mask_from(fn):
    m=Image.new('L',(W,H),0); fn(ImageDraw.Draw(m)); return np.array(m)>0
def shift(m,dx,dy):
    o=np.zeros_like(m)
    ys=slice(max(dy,0),H+min(dy,0)); yd=slice(max(-dy,0),H+min(-dy,0))
    xs=slice(max(dx,0),W+min(dx,0)); xd=slice(max(-dx,0),W+min(-dx,0))
    o[ys,xs]=m[yd,xd]; return o
def put(m,c):
    img[m]=list(c)+[255]
def layer(m,pal,outline=True,sh=2,hl=2):
    dark,shad,base,light=pal
    put(m,base)
    if hl: put(m & ~shift(m,hl,hl), light)   # lit from front-left / top
    if sh: put(m & ~shift(m,-sh,-sh) , shad)   # shadow right / bottom
    if outline:
        edge=m & ~(shift(m,1,0)&shift(m,-1,0)&shift(m,0,1)&shift(m,0,-1))
        put(edge,dark)
SKIN=((92,46,34),(176,110,80),(216,158,116),(240,196,150))
HAIR=((40,22,16),(66,40,26),(98,62,38),(134,88,52))
MAIL=((40,42,52),(86,90,102),(128,134,144),(180,186,194))
LEATH=((46,26,16),(88,52,30),(124,78,44),(164,110,64))
STEEL=((40,42,52),(110,116,128),(160,166,176),(214,220,226))
GOLD=((70,44,16),(150,100,36),(204,152,60),(244,206,110))
CLOTH=((40,30,26),(92,40,34),(132,58,44),(170,86,62))

# sword hilt on back, behind viewer-left shoulder
grip=mask_from(lambda d:d.line([(26,92),(15,62)],fill=1,width=4))
layer(grip,LEATH,sh=1,hl=1)
for y in range(64,92,3):  # wrap
    xs=int(15+(y-62)*(11/30)); img[y,xs-1:xs+3,:3]=LEATH[0]
pom=mask_from(lambda d:d.ellipse([10,54,19,63],fill=1)); layer(pom,GOLD,sh=1,hl=1)
guard=mask_from(lambda d:d.polygon([(11,93),(34,80),(37,85),(14,98)],fill=1)); layer(guard,GOLD,sh=1,hl=1)

# torso (chainmail)
torso=mask_from(lambda d:d.polygon([(12,151),(14,104),(22,92),(38,85),(58,85),(74,92),(82,104),(84,151)],fill=1))
layer(torso,MAIL,sh=4,hl=3)
yy,xx=np.mgrid[0:H,0:W]
ring=torso & ((xx+ (yy//2)%2)%2==0) & (yy%2==0)
inner=torso & shift(torso,1,0)&shift(torso,-1,0)&shift(torso,0,1)
img[ring&inner,:3]=np.clip(img[ring&inner,:3].astype(int)-34,0,255)
# red tabard strip center
tab=mask_from(lambda d:d.polygon([(40,96),(56,96),(58,151),(38,151)],fill=1)) & torso
layer(tab,CLOTH,sh=2,hl=1)
emb=mask_from(lambda d:d.polygon([(48,104),(53,110),(48,118),(43,110)],fill=1)); layer(emb,GOLD,sh=1,hl=1)
# gambeson collar
col=mask_from(lambda d:d.polygon([(34,86),(62,86),(60,94),(48,99),(36,94)],fill=1)); layer(col,LEATH,sh=2,hl=1)
# neck
neck=mask_from(lambda d:d.rectangle([41,76,55,90],fill=1))
layer(neck,SKIN,sh=3,hl=0)
img[(yy>=79)&(yy<=81)&neck,:3]=SKIN[1]
layer(mask_from(lambda d:d.polygon([(34,86),(62,86),(60,94),(48,99),(36,94)],fill=1)) & ~mask_from(lambda d:d.polygon([(41,86),(55,86),(48,93)],fill=1)),LEATH,sh=2,hl=1)
# pauldron + strap
strap=mask_from(lambda d:d.polygon([(66,92),(72,98),(30,151),(20,151)],fill=1)) & torso
layer(strap,LEATH,sh=1,hl=1)
buck=mask_from(lambda d:d.rectangle([40,111,45,116],fill=1)); layer(buck,GOLD,sh=1,hl=0)
paul=mask_from(lambda d:(d.ellipse([58,84,90,112],fill=1)))
paul&= ~mask_from(lambda d:d.rectangle([0,104,95,151],fill=1)) | mask_from(lambda d:d.ellipse([58,84,90,112],fill=1))&(yy<108)
layer(paul,LEATH,sh=3,hl=2)
for y0 in (93,100):
    band=paul&(yy==y0); img[band,:3]=LEATH[0]
for (rx,ry) in ((66,89),(74,88),(82,91),(64,96),(72,95),(80,97)):
    if paul[ry,rx]: img[ry,rx,:3]=STEEL[3]; img[ry+1,rx,:3]=STEEL[1]

body=img.copy(); img[:]=0
# ears
ears=mask_from(lambda d:(d.ellipse([32,52,38,64],fill=1),d.ellipse([58,52,64,64],fill=1)))
layer(ears,SKIN,sh=1,hl=1)
# head
head=mask_from(lambda d:(d.ellipse([35,36,61,68],fill=1),d.polygon([(36,56),(60,56),(58,71),(52,77),(44,77),(38,71)],fill=1)))
layer(head,SKIN,sh=3,hl=2)
# stubble dither on jaw
stub=head&(yy>=65)&((xx+yy)%2==0)&shift(head,0,-1)
stub&=~((yy>=68)&(yy<=70)&(xx>=44)&(xx<=52))
img[stub,:3]=(150,104,78)
# hair
hair=mask_from(lambda d:(d.ellipse([33,30,63,56],fill=1),
    d.polygon([(36,36),(38,26),(42,33),(46,25),(50,32),(55,26),(56,33),(61,30),(60,40)],fill=1)))
hair&=((yy<45)|(xx<37)|(xx>59))&(yy<58)
hair&=~((xx>=37)&(xx<=59)&(yy>=44))
fr=mask_from(lambda d:d.polygon([(38,44),(42,40),(46,46),(50,40),(54,45),(58,41),(59,46),(38,47)],fill=1))
hair=(hair|fr)&~((yy>=47)&(xx>36)&(xx<60))
layer(hair,HAIR,sh=2,hl=2)
for (x,y) in ((41,34),(47,31),(53,33),(44,38),(51,37)):
    img[y,x,:3]=HAIR[3]
# brows (angled, determined)
for x,y in ((39,51),(40,51),(41,51),(42,52),(43,52),(44,53)) + ((52,53),(53,52),(54,52),(55,51),(56,51),(57,51)):
    img[y,x,:3]=HAIR[0]; img[y-1,x,:3]=HAIR[1] if x not in (44,52) else img[y-1,x,:3]
# eyes
for ex in (40,52):
    img[55,ex:ex+5,:3]=SKIN[0]
    img[56,ex:ex+5,:3]=(236,228,214)
    img[56,ex+2:ex+4,:3]=(52,70,92); img[56,ex+2,:3]=(28,32,44)
    img[57,ex+1:ex+4,:3]=SKIN[1]
# nose
for y in range(57,64): img[y,49,:3]=SKIN[1]
img[63,46:49,:3]=SKIN[1]; img[64,46,:3]=SKIN[0]; img[64,49,:3]=SKIN[0]
img[58:62,47,:3]=SKIN[3]
# mouth
img[69,44:53,:3]=SKIN[0]; img[69,44,:3]=SKIN[1]; img[68,52,:3]=SKIN[0]
img[70,46:51,:3]=SKIN[1]
# scar across viewer-left cheek
for i,(x,y) in enumerate([(38,57),(39,59),(40,60),(41,62),(42,63),(43,65),(44,66)]):
    img[y,x,:3]=(228,150,140); img[y,x+1,:3]=(150,78,70)
OY=9
hd=np.zeros_like(img); hd[OY:]=img[:H-OY]
img[:]=body; a=hd[:,:,3]>0; img[a]=hd[a]
# outer outline
alpha=img[:,:,3]>0
out=~alpha & (shift(alpha,1,0)|shift(alpha,-1,0)|shift(alpha,0,1)|shift(alpha,0,-1))
img[out]=[30,18,14,255]
img=img[24:]; H=128
Image.fromarray(img).save('hero_warrior_m_01.png')
# preview: x5 on tavern-like bg
big=Image.fromarray(img).resize((W*5,H*5),Image.NEAREST)
bg=Image.new('RGBA',big.size,(52,34,22,255)); bg.alpha_composite(big); bg.convert('RGB').save('preview.png')
