"""Install selected P07 runtime resources, never modify the delivered package."""
from pathlib import Path
import hashlib, json, shutil, re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'reports/art/MARICRAFT_P07_molten_core'
TARGET = ROOT / 'assets/molten_art'
EVIDENCE = ROOT / 'reports/evidence/p07'
EVIDENCE.mkdir(parents=True, exist_ok=True)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

if not (EVIDENCE/'baseline.json').exists():
    protected = list((ROOT/'assets').rglob('*')) + list((ROOT/'scenes').rglob('*.tscn'))
    protected += list((ROOT/'scripts/gameplay').glob('*.gd'))
    baseline = {str(p.relative_to(ROOT)).replace('\\','/'): digest(p) for p in protected if p.is_file() and p.suffix not in ['.import','.uid']}
    package = {str(p.relative_to(SOURCE)).replace('\\','/'): digest(p) for p in SOURCE.rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix not in ['.import','.uid']}
    sizes = {p.name: p.stat().st_size for p in (ROOT/'exports/molten-release').glob('*') if p.is_file()}
    (EVIDENCE/'baseline.json').write_text(json.dumps({'protected':baseline,'package':package,'web_bytes':sizes},indent=2),encoding='utf-8')

# Reading the complete catalogs here also verifies that every shipped entry exists.
for name in ['registry.json','animations.json','source_calibration.json','integration_contracts.json','current_game_contract.json','map_contract.json']:
    json.loads((SOURCE/name).read_text(encoding='utf-8'))
catalog = (SOURCE/'FULL_IMAGE_CATALOG.txt').read_text(encoding='utf-8')
handoff = (SOURCE/'ART_HANDOFF.txt').read_text(encoding='utf-8')
review = (SOURCE/'review/index.html').read_text(encoding='utf-8')
assert 'world_map_base' in catalog and 'sanctum_far' in handoff and 'videos' in review
TARGET.mkdir(parents=True,exist_ok=True)
copied=[]
for src in (SOURCE/'runtime').rglob('*'):
    rel=src.relative_to(SOURCE/'runtime')
    if not src.is_file() or src.suffix in ['.import','.uid'] or 'shared_ui' in rel.parts: continue
    # Whole Ragnaros sheets cannot drive a separate moving hammer (see ART_FEEDBACK).
    if rel.parts[:2] in [('characters','ragnaros'),('effects','boss_falling')]: continue
    if rel.name=='maricraft_p06.theme.tres': continue
    dst=TARGET/rel
    dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.exists(): continue  # Do not overwrite game-side integration adjustments on rerun.
    if src.suffix in ['.gd','.tscn','.tres','.gdshader']:
        content=src.read_text(encoding='utf-8')
        content=content.replace('base+"/maricraft_p06.theme.tres"','"res://assets/faction_art/maricraft_p06.theme.tres"')
        content=content.replace('base+"/shared_ui/', '"res://assets/ui_art/')
        dst.write_text(content,encoding='utf-8')
    else: shutil.copyfile(src,dst)
    copied.append(str(rel).replace('\\','/'))
for name in ['registry.json','animations.json','source_calibration.json']:
    if not (TARGET/name).exists(): shutil.copyfile(SOURCE/name,TARGET/name)
(EVIDENCE/'installation.json').write_text(json.dumps({'source':str(SOURCE),'target':str(TARGET),'files':copied,'omitted':['whole ragnaros: needs split rig','boss_falling: no gameplay attack','shared_ui: reuse P05/P06','masters/demo/review/web']},indent=2),encoding='utf-8')
print(f'P07 installed {len(copied)} resources; protected baseline saved.')
