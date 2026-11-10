"""Inspection-only contact sheets. Never changes source/runtime images."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw,ImageFont
REG=ROOT/'assets/forest_art/characters'
DATA=json.loads((REG/'animations.json').read_text())
OUT=ROOT/'reports/evidence/animation-fix'
OUT.mkdir(parents=True,exist_ok=True)
FONT=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
def main():
 for model,a in DATA.items():
  clips=list(a['clips'])
  for part in range(0,len(clips),5):
   cell_w,cell_h=(248,210) if model!='chief' else (340,270)
   im=Image.new('RGB',(cell_w*8,cell_h*min(5,len(clips)-part)),(25,39,46));d=ImageDraw.Draw(im)
   for row,name in enumerate(clips[part:part+5]):
    c=a['clips'][name];w,h=c['frame_px'];sheet=Image.open(REG/c['sheet']).convert('RGBA')
    for f in range(c['count']):
     x=f*cell_w+cell_w//2;y=row*cell_h+cell_h-25
     d.line((x-cell_w//2+4,y,x+cell_w//2-4,y),fill='#6a8790')
     d.line((x,y-4,x,y+4),fill='#f6ca77')
     d.text((f*cell_w+8,row*cell_h+5),f'{name} [{f}]',font=FONT,fill='white')
     frame=sheet.crop((f*w,0,(f+1)*w,h))
     im.paste(frame,(x-a['pivot_px'][0],y-a['pivot_px'][1]),frame)
   im.save(OUT/f'source-{model}-{part//5}.png')
 print('Inspection sheets:',OUT)
if __name__=='__main__':main()
