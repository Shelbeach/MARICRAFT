"""One-time hash inventory only. Does not copy or restore project files."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'reports/evidence/p07v03-music'
out.mkdir(parents=True,exist_ok=True)
target=out/'before.json'
if target.exists(): raise SystemExit('Baseline already exists; not replacing it.')
files=[]
for folder in ['scripts','scenes','assets']:
    files += [p for p in (root/folder).rglob('*') if p.is_file() and p.suffix not in ['.uid','.import']]
files += [root/'project.godot',root/'export_presets.cfg']
data={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
for folder in ['reports/art/MARICRAFT_P07_v03_fixes/runtime','reports/art/MARICRAFT_P07_molten_core/runtime']:
    for p in (root/folder).rglob('*'):
        if p.is_file() and p.suffix not in ['.uid','.import']:data[str(p.relative_to(root)).replace('\\','/')]=hashlib.sha256(p.read_bytes()).hexdigest()
for i in range(1,7):
    p=Path.home()/'Downloads'/f'{i}.mp3'
    data[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
target.write_text(json.dumps(data,indent=2),encoding='utf8')
print(len(data),'baseline hashes')
