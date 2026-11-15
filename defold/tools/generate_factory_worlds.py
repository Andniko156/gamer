"""Generate source-native pixel assets for the four steampunk arenas."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
A = Path(__file__).resolve().parents[1] / 'art'

def tile(name, bg, plate, seam, shine, axis, scenery=None):
    im=Image.new('RGBA',(384,384),bg); d=ImageDraw.Draw(im)
    if axis=='vertical':
        for x0 in (0,350):
            if scenery=='forest':
                for y in range(22,384,58):
                    x=x0+16+(y//58%2)*8
                    d.rectangle((x-3,y,x+3,y+38),fill='#26383b')
                    d.polygon([(x-17,y+11),(x,y-15),(x+17,y+11)],fill='#41605b')
                    d.polygon([(x-14,y+24),(x,y+1),(x+14,y+24)],fill='#304d4c')
            elif scenery=='bridge':
                d.rectangle((x0,0,x0+34,383),fill='#23333a')
                for y in range(18,384,64):
                    d.line((x0,y,x0+34,y+30),fill='#91836a',width=4)
                    d.line((x0+34,y,x0,y+30),fill='#91836a',width=4)
                    d.rectangle((x0+6,y+8,x0+11,y+13),fill='#d7a866')
            elif scenery=='city':
                for y in range(0,384,95):
                    x=x0+(y//95%2)*8
                    d.rectangle((x,y+11,x+30,y+92),fill='#303c43')
                    d.rectangle((x+5,y+20,x+23,y+24),fill='#d5a25e')
                    d.rectangle((x+5,y+39,x+23,y+43),fill='#bd8050')
                    d.rectangle((x+23,y+2,x+27,y+18),fill='#54616a')
        d.rectangle((35,0,348,383),fill=plate)
        for x in (37,46,338,347): d.line((x,0,x,383),fill=seam,width=3)
        for y in range(0,384,48):
            d.line((51,y,333,y),fill=seam,width=2)
            for x in (64,128,192,256,320):
                d.rectangle((x,y+4,x+3,y+7),fill=shine)
        for y in (24,120,216,312):
            d.rectangle((56,y,79,y+8),fill=shine)
            d.rectangle((305,y,328,y+8),fill=shine)
            d.line((96,y+12,290,y+12),fill=seam,width=2)
        for y in (80,272):
            d.rectangle((20,y-18,35,y+18),fill=seam)
            d.rectangle((349,y-18,364,y+18),fill=seam)
    else:
        d.rectangle((0,0,383,383),fill='#15243b')
        for x in range(12,384,62):
            d.rectangle((x,10,x+3,13),fill='#9daeb0')
            d.rectangle((x+28,368,x+30,370),fill='#8797ad')
        for y in (4,365):
            for x in (20,154,300):
                d.rectangle((x,y+10,x+34,y+19),fill='#34445d')
                d.rectangle((x+7,y+1,x+26,y+11),fill='#576376')
                d.rectangle((x+13,y-5,x+20,y+2),fill='#aa946b')
        d.rectangle((0,28,383,355),fill=plate)
        for y in (30,39,345,354): d.line((0,y,383,y),fill=seam,width=3)
        for x in range(0,384,48):
            d.line((x,50,x,335),fill=seam,width=2)
            for y in (64,128,192,256,320): d.rectangle((x+3,y,x+6,y+3),fill=shine)
        for x in (24,120,216,312):
            d.rectangle((x,54,x+8,78),fill=shine)
            d.rectangle((x,306,x+8,330),fill=shine)
        for x in (82,274):
            d.ellipse((x-12,175,x+12,199),outline=shine,width=3)
            d.ellipse((x-4,183,x+4,191),fill=seam)
    im.save(A/name)

tile('arena_express.png','#172023','#485157','#20292d','#bd8a48','vertical')
for scene in ('forest','bridge','city'):
    tile(f'arena_express_{scene}.png','#172023','#485157','#20292d','#bd8a48','vertical',scene)
tile('arena_bastion.png','#172a44','#4d4542','#27252b','#c59a55','horizontal')
(A/'arena_express.atlas').write_text(''.join(f'images {{ image: "/art/arena_express_{scene}.png" }}\n' for scene in ('forest','bridge','city'))+'margin: 2\nextrude_borders: 2\n')
(A/'arena_bastion.atlas').write_text('images { image: "/art/arena_bastion.png" }\nmargin: 2\nextrude_borders: 2\n')

palettes=[('#557b78','#91d4c0','#d0a555'),('#5b4b48','#d1a06d','#e7bd73'),('#394750','#b07854','#dfb063'),('#394a61','#aab9c4','#eac575')]
for arena,(dark,metal,light) in enumerate(palettes,1):
    for kind in range(1,11):
        im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
        # Each silhouette is native pixel geometry at a common 64 px canvas and foot pivot (32,55).
        if kind==1: # gear, bird, rat, watchman depending on arena
            d.ellipse((19,23,45,49),fill=dark,outline=light,width=3)
            for a in range(0,360,45):
                x=32+int(16*math.cos(math.radians(a)));y=36+int(16*math.sin(math.radians(a)))
                d.rectangle((x-3,y-3,x+3,y+3),fill=metal)
            d.ellipse((28,32,36,40),fill=light)
        elif kind==2: # paired tool arms / fast hound
            d.rectangle((17,24,47,49),fill=metal,outline=dark,width=3)
            d.polygon([(12,29),(19,33),(17,43),(9,39)],fill=light)
            d.polygon([(52,29),(45,33),(47,43),(55,39)],fill=light)
            for x in (21,40): d.rectangle((x,49,x+4,57),fill=dark)
            d.rectangle((27,31,36,34),fill=light)
        elif kind==3: # long legged walker
            d.ellipse((17,19,47,43),fill=metal,outline=dark,width=3)
            for x in (13,22,40,50):
                d.line((x,38,x+(x-32)//4,54),fill=light,width=4)
            d.rectangle((26,25,38,30),fill=light)
        elif kind==4: # ranged turret / signalman
            d.rectangle((17,27,47,51),fill=dark,outline=light,width=3)
            d.rectangle((26,13,38,31),fill=metal,outline=dark,width=2)
            d.rectangle((37,17,57,23),fill=light)
            d.rectangle((21,49,44,55),fill=metal)
        elif kind==5: # boiler / bombardier
            d.ellipse((14,16,50,54),fill=metal,outline=dark,width=4)
            d.rectangle((25,7,37,18),fill=dark)
            d.rectangle((21,33,43,42),fill=light)
            for x in (9,50): d.rectangle((x,37,x+6,49),fill=dark)
        elif kind==6: # large boss, crown, segmented armor
            d.polygon([(6,22),(18,10),(32,17),(46,10),(58,22),(53,53),(11,53)],fill=dark,outline=light)
            d.rectangle((13,23,51,46),fill=metal,outline=dark,width=4)
            for x in (17,27,37): d.rectangle((x,26,x+7,35),fill=light)
            d.ellipse((25,38,39,52),fill=light,outline=dark,width=3)
            d.rectangle((12,52,23,59),fill=dark);d.rectangle((41,52,52,59),fill=dark)
        elif kind==7: # support drone / guard
            d.ellipse((15,21,49,47),fill=dark,outline=light,width=3)
            d.ellipse((24,28,40,42),fill=metal)
            d.rectangle((4,30,17,38),fill=light);d.rectangle((47,30,60,38),fill=light)
            d.rectangle((29,13,35,23),fill=light)
        elif kind==8: # clock/control
            d.ellipse((16,17,48,51),fill=metal,outline=light,width=4)
            d.ellipse((23,24,41,42),fill=dark)
            d.line((32,33,32,25),fill=light,width=3);d.line((32,33,39,36),fill=light,width=3)
            d.rectangle((22,50,42,56),fill=dark)
        elif kind==9: # elite heavy, magnetron
            d.polygon([(10,24),(20,15),(44,15),(54,24),(49,51),(15,51)],fill=dark,outline=light)
            d.rectangle((19,24,45,43),fill=metal,outline=dark,width=3)
            d.rectangle((25,29,39,37),fill=light)
            d.rectangle((9,42,16,53),fill=metal);d.rectangle((48,42,55,53),fill=metal)
        else: # rare human engineer/commander
            d.ellipse((25,11,39,25),fill='#e2ad7d',outline=dark,width=2)
            d.rectangle((21,22,43,43),fill=metal,outline=dark,width=3)
            d.rectangle((16,28,22,43),fill=light);d.rectangle((42,28,48,43),fill=light)
            d.rectangle((25,42,30,55),fill=dark);d.rectangle((35,42,40,55),fill=dark)
            d.rectangle((23,11,41,15),fill=dark)
        im.save(A/f'enemy_{arena}_{kind}.png')

for idx,color,shape in [(19,'#6bd7fb','rail'),(20,'#e9b36d','pendulum'),(21,'#64df8f','acid'),
                        (22,'#49dfff','coil'),(23,'#d4a667','clock'),(24,'#65dd8e','heart')]:
    im=Image.new('RGBA',(40,40));d=ImageDraw.Draw(im)
    d.rounded_rectangle((3,3,36,36),radius=5,fill='#25313a',outline='#a67b4d',width=2)
    if shape=='rail':
        d.rectangle((7,18,32,23),fill=color);d.rectangle((21,13,31,27),fill='#bd914e')
    elif shape=='pendulum':
        d.line((20,8,20,27),fill=color,width=3);d.ellipse((11,24,29,34),fill=color)
    elif shape=='acid':
        d.polygon([(14,8),(26,8),(23,18),(29,29),(24,33),(16,33),(11,29),(17,18)],fill=color)
    elif shape=='coil':
        for y in (13,19,25): d.arc((9,y-5,31,y+7),0,180,fill=color,width=3)
    elif shape=='clock':
        d.ellipse((10,9,30,30),outline=color,width=3);d.line((20,19,20,12),fill=color,width=2);d.line((20,19,26,22),fill=color,width=2)
    else:
        d.polygon([(20,32),(9,20),(10,13),(16,10),(20,14),(24,10),(30,13),(31,20)],fill=color)
    im.save(A/f'item_{idx}.png')

sprites=A/'sprites.atlas'
base=sprites.read_text().split('images { image: "/art/enemy_1_1.png" }')[0]
sprites.write_text(base)
with sprites.open('a') as f:
    for arena in range(1,5):
        for kind in range(1,11): f.write(f'images {{ image: "/art/enemy_{arena}_{kind}.png" }}\n')
    for idx in (19,20,21,22,23,24): f.write(f'images {{ image: "/art/item_{idx}.png" }}\n')
