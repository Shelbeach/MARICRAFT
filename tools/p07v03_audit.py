"""Read-only source protection/import audit. Writes only its evidence report."""
import hashlib, json, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'reports/evidence/p07v03-music'
baseline=json.loads((base/'before.json').read_text(encoding='utf8'))
allowed={
 'project.godot','export_presets.cfg','scripts/core/campaign.gd',
 'scripts/core/game_flow.gd','scripts/debug/web_observer.gd',
 'scripts/gameplay/ragnaros.gd','scripts/visual/molten_art.gd',
 'scripts/visual/molten_object_skin.gd','scripts/visual/molten_hazard_skin.gd',
 'scripts/visual/molten_effects.gd','scripts/visual/molten_surface.gd',
 'scripts/visual/molten_backdrop.gd','scripts/visual/molten_boss_warning.gd'
}
changed=[]; missing=[]; unchanged=[]
for name,old in baseline.items():
    p=Path(name) if Path(name).is_absolute() else root/name
    if not p.exists():missing.append(name)
    elif hashlib.sha256(p.read_bytes()).hexdigest()!=old:changed.append(name)
    else:unchanged.append(name)
unexpected=sorted(set(changed)-allowed)
pngs=list((root/'assets/p07_v03').rglob('*.png'))
imports=[]
for p in pngs:
    imp=p.with_suffix('.png.import')
    s=imp.read_text(encoding='utf8') if imp.exists() else ''
    if 'compress/mode=0' not in s or 'mipmaps/generate=false' not in s:imports.append(str(p.relative_to(root)))
adapted=[];copied=[];missing_runtime=[]
for p in (root/'reports/art/MARICRAFT_P07_v03_fixes/runtime').rglob('*'):
    if not p.is_file() or p.suffix in ['.uid','.import']:continue
    rel=p.relative_to(root/'reports/art/MARICRAFT_P07_v03_fixes/runtime')
    target=root/'assets/p07_v03'/rel
    if not target.exists():missing_runtime.append(str(rel))
    elif target.read_bytes()!=p.read_bytes():adapted.append(str(rel))
    else:copied.append(str(rel))
new_runtime=[str(p.relative_to(root)).replace('\\','/') for folder in ['scripts','scenes','assets'] for p in (root/folder).rglob('*') if p.is_file() and p.suffix not in ['.uid','.import'] and str(p.relative_to(root)).replace('\\','/') not in baseline]
exports={}
for folder in ['p07v03-music','p07v03-music-release']:
    exports[folder]={p.name:p.stat().st_size for p in (root/'exports'/folder).glob('*') if p.is_file()}
report={
 'baseline_files':len(baseline),'unchanged':len(unchanged),'changed_existing':changed,
 'missing':missing,'unexpected_changes':unexpected,'new_runtime_files':new_runtime,
 'level_scenes_unchanged':all(p in unchanged for p in baseline if p.startswith('scenes/')),
 'accepted_assets_unchanged':all(p in unchanged for p in baseline if p.startswith('assets/')),
 'source_packs_unchanged':all(p in unchanged for p in baseline if p.startswith('reports/art/')),
 'original_mp3_unchanged':all(p in unchanged for p in baseline if p.endswith('.mp3') and p.startswith('C:')),
 'forest_scripts_unchanged':all('scripts/visual/'+p in unchanged for p in ['forest_backdrop.gd','forest_terrain.gd']),
 'runtime_exact_copies':len(copied),'runtime_adapted':adapted,'runtime_missing':missing_runtime,
 'new_pngs':len(pngs),'png_import_issues':imports,
 'music_bytes':sum(p.stat().st_size for p in (root/'assets/audio/music').glob('*.ogg')),
 'exports':exports,
 'passed':not(missing or unexpected or imports or missing_runtime)
}
(base/'protection-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in report.items() if k not in ['new_runtime_files','exports']},ensure_ascii=False,indent=2))
if not report['passed']:raise SystemExit(1)
