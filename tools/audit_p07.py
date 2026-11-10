"""Verify preserved assets, geometry, source delivery and presentation-only hooks."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/evidence/p07'
SOURCE=ROOT/'reports/art/MARICRAFT_P07_molten_core'
baseline=json.loads((OUT/'baseline.json').read_text(encoding='utf-8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
changed=[p for p,h in baseline['protected'].items() if sha((ROOT/p).read_bytes())!=h]
source_changed=[p for p,h in baseline['package'].items() if sha((SOURCE/p).read_bytes())!=h]
allowed=['scripts/gameplay/molten_hazard.gd','scripts/gameplay/molten_projectile.gd','scripts/gameplay/ragnaros.gd']
semantic={}
for name in allowed:
    value=(ROOT/name).read_text(encoding='utf-8-sig')
    value=value.replace('\tif has_meta("forest_skin"): return\n','')
    value=value.replace(' and not has_meta("p07_warnings")','')
    expected=baseline['protected'][name]
    semantic[name]=expected in [sha(value.encode()),sha(value.replace('\n','\r\n').encode())]
original_images=[]
for target in (ROOT/'assets/molten_art').rglob('*.png'):
    source=SOURCE/'runtime'/target.relative_to(ROOT/'assets/molten_art')
    original_images.append({'file':str(target.relative_to(ROOT)), 'unchanged':sha(target.read_bytes())==sha(source.read_bytes())})
logs={}
for log in OUT.glob('*.log'):
    if log.stem=='routes-60' or log.name.endswith('-errors.log') or any(tag in log.name for tag in ['first','fixed','import','export','editor','capture','web-']):continue
    s=log.read_text(encoding='utf-8-sig',errors='replace')
    errors=log.with_name(log.stem+'-errors.log')
    stderr=errors.read_text(encoding='utf-8-sig',errors='replace') if errors.exists() else ''
    logs[log.stem]={'pass':'PASS' in s and 'FAIL' not in s,'clean_stderr':not stderr.strip(),'finish_count':s.count('PASS FINISH ')}
sizes={p.name:p.stat().st_size for p in (ROOT/'exports/p07-release').glob('*') if p.is_file()}
result={'source_files_checked':len(baseline['package']),'source_changed':source_changed,'preexisting_files_checked':len(baseline['protected']),'changed':changed,'unexpected_changes':[p for p in changed if p not in allowed],'gameplay_restores_original_hash_after_removing_only_visual_hooks':semantic,'pngs':original_images,'tests':logs,'baseline_web_bytes':baseline['web_bytes'],'p07_web_bytes':sizes}
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['pngs','tests','baseline_web_bytes','p07_web_bytes']},ensure_ascii=True))
print('PNG unchanged:',all(x['unchanged'] for x in original_images),'logs:',len(logs),'web delta bytes:',sum(sizes.values())-sum(baseline['web_bytes'].values()))
