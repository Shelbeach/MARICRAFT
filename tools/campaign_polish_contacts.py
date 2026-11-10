from pathlib import Path
import sys,json
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw
out=root/'reports/evidence/campaign-polish'
(out/'contacts').mkdir(exist_ok=True)
rows=json.loads((out/'after/coverage.json').read_text())
for level in dict.fromkeys(r['level'] for r in rows):
    group=[r for r in rows if r['level']==level]
    for page in range(0,len(group),6):
        chunk=group[page:page+6]
        sheet=Image.new('RGB',(960,292*((len(chunk)+1)//2)), '#17232b')
        draw=ImageDraw.Draw(sheet)
        for i,r in enumerate(chunk):
            im=Image.open(out/'after'/f"{r['id']}.png").convert('RGB').resize((480,270))
            x=(i%2)*480;y=(i//2)*292
            draw.text((x+8,y+4),r['id'],fill='white')
            sheet.paste(im,(x,y+22))
        sheet.save(out/'contacts'/f'{level}-{page//6}.jpg',quality=94)
for name in ['ui-main','ui-map','1-3-0','2-1-4468','2-2-2700','3-1-450','3-1-1350','3-2-900','3-2-3600']:
    sheet=Image.new('RGB',(960,1124),'#17232b');d=ImageDraw.Draw(sheet)
    for i,version in enumerate(['before','after']):
        d.text((12,i*562+5),version.upper()+' - '+name,fill='white')
        sheet.paste(Image.open(out/version/(name+'.png')).convert('RGB'),(0,i*562+22))
    sheet.save(out/'contacts'/('compare-'+name+'.jpg'),quality=95)
print('Contact sheets and 9 comparisons created from native screenshots.')
