"""Arrange real viewport captures; never edits game art or P07 files."""
from pathlib import Path
import sys, json, hashlib
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reports/temp/forest-art/python'))
from PIL import Image, ImageDraw
OUT = ROOT / 'reports/evidence/molten'
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
original = json.loads((OUT/'protected-hashes.json').read_text(encoding='utf-8-sig'))
changed=[]
for file,digest in original.items():
    actual=hashlib.sha256(Path(file).read_bytes()).hexdigest().upper()
    if actual != digest: changed.append(file)
result={'files_checked':len(original),'changed':changed,'success':not changed}
(OUT/'protected-verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
for prefix,interval in [('full',2),('mixed',0.5)]:
    frames=sorted((OUT/'video-frames').glob(prefix+'-*.png'))
    for batch in range(0,len(frames),12):
        sheet=Image.new('RGB',(960,816),'#181d29')
        pen=ImageDraw.Draw(sheet)
        for i,file in enumerate(frames[batch:batch+12]):
            x,y=(i%3)*320,(i//3)*204
            sheet.paste(Image.open(file).convert('RGB').resize((320,180)),(x,y+24))
            pen.text((x+8,y+6),f'{prefix}: {(batch+i+0.5)*interval:.1f}s',fill='white')
        sheet.save(OUT/f'motion-{prefix}-{batch//12+1}.jpg',quality=90)
