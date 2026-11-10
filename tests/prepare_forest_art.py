"""Copy runtime strips and atlases with a reproducible source ledger. Run from project root."""
import json,re,shutil,hashlib
from pathlib import Path
source=Path('reports/art/MARICRAFT_forest_art')
target=Path('assets/forest_art')
files=set()
actors=json.loads((source/'characters/animations.json').read_text(encoding='utf-8'))
env=json.loads((source/'environment/registry.json').read_text(encoding='utf-8'))
gameplay=json.loads((source/'gameplay/registry.json').read_text(encoding='utf-8'))
for actor in actors.values():
    files.add('characters/'+actor['spriteframes'])
    files.update('characters/'+clip['sheet'] for clip in actor['clips'].values())
# Only the strip representation is used. Dependencies of the prepared .tres stay together.
for group in ['items','interactive','effects','ui']:
    for p in (source/'gameplay'/group).iterdir():
        if p.suffix in ['.png','.tres']: files.add(p.relative_to(source).as_posix())
for e in env.values():
    if e.get('anchor') in ['bottom-center','repeat-strip']: files.add('environment/'+e['file'])
files.update(['terrain/forest/forest_atlas_2x.png','environment/atlases/grotto_tiles_2x.png'])
files.update(['characters/animations.json','environment/registry.json','environment/grotto_layout.json','gameplay/registry.json','terrain/forest/atlas.json'])
ledger=[]
for rel in sorted(files):
    src=source/rel; dst=target/rel; dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.exists() and dst.read_bytes()!=src.read_bytes():
        raise RuntimeError('Existing derived file differs: '+rel)
    shutil.copyfile(src,dst)
    ledger.append({'source':str(src).replace('\\','/'),'runtime':str(dst).replace('\\','/'),'bytes':src.stat().st_size,'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
Path('reports/evidence/forest-art/runtime-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')
print(len(files),'files,',sum(x['bytes'] for x in ledger),'bytes, source package unmodified')

