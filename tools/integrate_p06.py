"""Copy only P06 runtime additions; keep source packs and P04/P05 images intact."""
from pathlib import Path
import hashlib, json, re, shutil, wave

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'reports/art/MARICRAFT_P06_factions_art'
OUT = ROOT / 'assets/faction_art'
EVIDENCE = ROOT / 'reports/evidence/p06'
EVIDENCE.mkdir(parents=True, exist_ok=True)

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

protected = [ROOT/'scripts/visual/forest_backdrop.gd', ROOT/'scripts/visual/forest_terrain.gd']
protected += list((ROOT/'assets/location2_art').rglob('*.png'))
protected += list((ROOT/'assets/ui_art').rglob('*.png'))
protected += [p for root in [SRC, ROOT/'reports/audio/MARICRAFT_audio_v2'] for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix not in ['.import','.uid']]
snapshot = EVIDENCE/'protected-hashes.json'
if not snapshot.exists(): write(snapshot, {p.relative_to(ROOT).as_posix():digest(p) for p in protected})
registry, animations = read(SRC/'registry.json'), read(SRC/'animations.json')
copied = []
def copy(relative):
    source = SRC/'runtime'/relative
    target = OUT/relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    copied.append({'source':source.relative_to(ROOT).as_posix(),'runtime':target.relative_to(ROOT).as_posix(),'sha256':digest(target),'bytes':target.stat().st_size})

for data in [*registry.values(), *animations.values()]: copy(data['file'].removeprefix('runtime/'))
copy('ui/selection_light.gdshader')
copy('effects/mine_effects.tres')
# The nine unchanged kobold sheets resolve to the existing P04 textures, never copies.
frames=(SRC/'runtime/characters/kobold/kobold.tres').read_text(encoding='utf-8')
frames=re.sub(r'path="([^"/]+\.png)"',r'path="res://assets/location2_art/characters/kobold/\1"',frames)
frames=frames.replace('path="../rolling.png"','path="rolling.png"')
(OUT/'characters/kobold.tres').write_text(frames,encoding='utf-8')
theme=(SRC/'runtime/maricraft_p06.theme.tres').read_text(encoding='utf-8').replace('path="shared_ui/','path="res://assets/ui_art/')
(OUT/'maricraft_p06.theme.tres').write_text(theme,encoding='utf-8')
write(OUT/'registry.json',registry)
write(OUT/'animations.json',animations)

audio_source=ROOT/'reports/audio/MARICRAFT_audio_v2'
audio_target=ROOT/'assets/audio/sfx'
manifest=read(audio_target/'manifest.json')
audited=[]
for entry in read(audio_source/'audio_manifest.json')['events']:
    source=audio_source/entry['path']
    assert digest(source)==entry['sha256'], source
    with wave.open(str(source)) as wav:
        assert (wav.getnchannels(),wav.getsampwidth(),wav.getframerate())==(1,2,48000)
        assert abs(wav.getnframes()/48000-entry['duration_seconds'])<.002
    target=audio_target/source.name
    shutil.copyfile(source,target)
    audited.append({'id':entry['id'],'sha256':digest(target),'duration':entry['duration_seconds']})
    # All jump variations share one logical limiter/event; choose a stream after admission.
    if not entry['id'].startswith('player_jump_'):
        manifest[entry['id']]={'file':source.name,'volume_db':entry['volume_db'],'pitch':entry['pitch'],'voices':entry['voices'],'interval':entry['minimum_interval_ms']/1000,'priority':65}
manifest['player_jump']['variants']=['player_jump.wav','player_jump_02.wav','player_jump_03.wav']
manifest['player_jump']['pitch']=[1,1]
write(audio_target/'manifest.json',manifest)
shutil.copyfile(audio_source/'CREDITS.txt',audio_target/'CREDITS-v2.txt')
write(EVIDENCE/'runtime-import.json',{'copied':copied,'audio':audited,'reuse':'P04 nine kobold sheets; P05 all theme components and fonts; no masters/demo/review resources'})
print('P06 import:',len(copied),'runtime files;',len(audited),'verified PCM WAV files')
