"""Deterministic original petal/heart mark, rendered at 3x and downsampled."""
from PIL import Image, ImageDraw
from pathlib import Path
import json, math
root = Path(__file__).resolve().parents[1] / 'App/Resources/Assets.xcassets'
n = 1024
im = Image.new('RGB', (n, n))
pix = im.load()
for y in range(n):
    for x in range(n):
        t = (x + y) / (2 * n)
        a, b = (255, 250, 252), (220, 198, 255)
        pix[x, y] = tuple(round(a[i] * (1-t) + b[i] * t) for i in range(3))
im = im.resize((n*3, n*3))
d = ImageDraw.Draw(im)
def path(points, fill):
    d.polygon([(round(x*3), round(y*3)) for x, y in points], fill=fill)
def bezier(p0,p1,p2,p3):
    return [tuple((1-t)**3*p0[i]+3*(1-t)**2*t*p1[i]+3*(1-t)*t*t*p2[i]+t**3*p3[i] for i in (0,1)) for t in [j/100 for j in range(101)]]
heart = bezier((512,760),(390,660),(195,520),(240,365))+bezier((240,365),(285,215),(460,245),(512,350))+bezier((512,350),(565,245),(740,215),(785,365))+bezier((785,365),(830,520),(635,660),(512,760))
path(heart, '#F8BBD0')
left=bezier((512,705),(380,610),(345,470),(405,375))+bezier((405,375),(510,425),(555,570),(512,705))
right=bezier((512,705),(510,550),(610,435),(705,425))+bezier((705,425),(710,570),(620,690),(512,705))
path(left, '#FFFAFC'); path(right,'#CBE9FF')
d.line([(340*3,790*3),(684*3,790*3)], fill='#A68BBC', width=8*3)
d.ellipse((740*3,220*3,782*3,262*3), fill='#FFFAFC')
im.resize((n,n), Image.Resampling.LANCZOS).save(root/'AppIcon.appiconset/AppIcon.png')
(root/'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
(root/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
for name, light, dark in [('AccentColor',('0.45','0.28','0.55'),('0.86','0.76','1.0')),('LaunchBackground',('1.0','0.98','0.99'),('0.07','0.06','0.08'))]:
    folder=root/(name+'.colorset'); folder.mkdir(exist_ok=True)
    def color(rgb): return {'color-space':'srgb','components':dict(zip(['red','green','blue','alpha'],[*rgb,'1.0']))}
    (folder/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':color(light)},{'idiom':'universal','appearances':[{'appearance':'luminosity','value':'dark'}],'color':color(dark)}],'info':{'author':'xcode','version':1}},indent=2))
