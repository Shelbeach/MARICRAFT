"""Arrange real viewport captures; never edits game art or P07 files."""
from pathlib import Path
import sys, json, hashlib
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reports/temp/forest-art/python'))
from PIL import Image, ImageDraw
OUT = ROOT / 'reports/evidence/p07'
coverage = json.loads((OUT / 'windows/coverage.json').read_text(encoding='utf-8'))
for level in ['3-1','3-2','3-2-room','3-3']:
    entries = sorted((c for c in coverage if c['level']==level), key=lambda c:c['x'])
    start = entries[0]['x']
    panorama = Image.new('RGB',(entries[-1]['x']-start+960,540))
    sheet = Image.new('RGB',(960, ((len(entries)+1)//2)*294), '#181d29')
    pen = ImageDraw.Draw(sheet)
    for i,entry in enumerate(entries):
        frame = Image.open(OUT / 'windows' / (entry['id']+'.png')).convert('RGB')
        panorama.paste(frame, (entry['x']-start,0))
        x,y=(i%2)*480,(i//2)*294
        sheet.paste(frame.resize((480,270)),(x,y+24))
        pen.text((x+8,y+6),entry['id'],fill='white')
    panorama.save(OUT / ('panorama-'+level+'.png'))
    sheet.save(OUT / ('contact-'+level+'.png'))
