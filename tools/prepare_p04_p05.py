"""Copy runtime-only P04/P05 resources; never overwrite divergent accepted files."""
from pathlib import Path
import hashlib,json,shutil,sys
sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'reports/evidence/p04-p05'
DEST.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
baseline=DEST/'baseline-hashes.json'
if not baseline.exists():
    files=list((ROOT/'scripts').rglob('*.gd'))+list((ROOT/'scripts').rglob('*.gdshader'))+list((ROOT/'scenes').rglob('*.tscn'))+[ROOT/'project.godot',ROOT/'assets/forest_art/calibration.json']
    baseline.write_text(json.dumps({str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in files},indent=2),encoding='utf8')
ledger=[]
for package,destination,metadata in [
    ('MARICRAFT_location2_art','location2_art',['environment_registry.json','animations.json','gameplay_registry.json']),
    ('MARICRAFT_ui_art','ui_art',['registry.json'])]:
    source=ROOT/'reports/art'/package
    copies=[]
    for file in (source/'runtime').rglob('*'):
        if not file.is_file() or file.suffix in ['.import','.uid'] or file.name.startswith('.'):continue
        relative=file.relative_to(source/'runtime')
        if 'dependencies' in relative.parts:continue
        if relative.parts[0]=='branding':continue # The real title uses the supplied font.
        copies.append((file,ROOT/'assets'/destination/relative))
    copies += [(source/name,ROOT/'assets'/destination/name) for name in metadata]
    for src,dst in copies:
        if dst.exists() and sha(dst)!=sha(src):raise RuntimeError(f'Refusing divergent overwrite: {dst}')
        dst.parent.mkdir(parents=True,exist_ok=True)
        if not dst.exists():shutil.copyfile(src,dst)
        ledger.append({'source':str(src.relative_to(ROOT)).replace('\\','/'),'runtime':str(dst.relative_to(ROOT)).replace('\\','/'),'sha256':sha(src),'bytes':src.stat().st_size})
    print(destination,len(copies),'files',round(sum(a.stat().st_size for a,b in copies)/1048576,2),'MiB')
(DEST/'runtime-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf8')
print('Baseline hashes and runtime ledger saved; original packages untouched.')
