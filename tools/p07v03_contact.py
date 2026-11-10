from pathlib import Path
import sys,json
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw
base=root/'reports/evidence/p07v03-music'
dest=base/'contact';dest.mkdir(exist_ok=True)
groups={}
for level in ['3-1','3-2','3-3']:
    groups[level]=sorted((base/'after').glob(level+'-*.png'))
groups['body']=sorted((base/'screens').glob('body-*.png'))
groups['hammer']=sorted((base/'screens').glob('hammer-*.png'))
for group,files in groups.items():
    for page in range((len(files)+7)//8):
        subset=files[page*8:page*8+8]
        sheet=Image.new('RGB',(1280,384*((len(subset)+1)//2)),(19,23,31));d=ImageDraw.Draw(sheet)
        for i,p in enumerate(subset):
            im=Image.open(p).convert('RGB');im.thumbnail((640,360))
            x=(i%2)*640;y=(i//2)*384
            sheet.paste(im,(x,y+24));d.text((x+8,y+5),p.stem,fill='white')
        sheet.save(dest/f'{group}-{page}.jpg',quality=90)
        print(dest/f'{group}-{page}.jpg')
