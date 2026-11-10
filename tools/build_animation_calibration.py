"""Rebuild runtime transforms only. The accepted painted sheets stay untouched.

Pose proportions were reviewed at a fixed feet origin. A painted pose has one
target height across clips; crouching is not stretched to standing height.
The original pack rounded each cel's height, so compensate in source pixels.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / 'assets/forest_art/calibration.json'
REGISTRY = json.loads((ROOT / 'assets/forest_art/characters/animations.json').read_text(encoding='utf8'))
SOURCE = {
    'idle': [1]*6,
    'run': [.95,.90,.94,.94,.95,.90,.94,.94],
    'jump': [.76,.92,1], 'fall': [.96]*4,
    'land': [.72,.80,.94,1], 'hurt': [.95,.91,.84,1],
    'head_hit': [.93,1,.94,.93], 'death': [1,.70,.39,.37],
    'victory': [.81,.98,1,1.02,1], 'cast': [.95,.95,.97,.97,1],
}
# References are per painted pose, not per animation. Magic uses the same body.
HUMAN = {'idle': .94, 'actions:0': .76, 'actions:1': .92,
         'actions:2': .94, 'actions:3': .72, 'actions:4': .96,
         'actions:5': .95, 'actions:6': .96, 'actions:7': .97, 'actions:8': .39}
OGRE = {'idle': .98, 'actions:0': .72, 'actions:1': .92,
        'actions:2': .94, 'actions:3': .70, 'actions:4': .94,
        'actions:5': .95, 'actions:6': .96, 'actions:7': .98, 'actions:8': .40}
RUN = {'human': [.99,.99,.98,.95,.99,.99,.96,.94],
       'ogre': [.98,.99,.96,.94,.97,.99,.94,.90]}

def build():
    old = json.loads(FILE.read_text(encoding='utf8'))
    out = {'_version': 2}
    for model, actor in REGISTRY.items():
        if model in ('murloc', 'chief'):
            out[model] = old[model]
            continue
        hero = model.split('_')[0]
        refs = HUMAN if hero == 'human' else OGRE
        height = actor['height_world_with_crest']*2
        profile = {'_scale': 1.0, '_stride': 52 if model.endswith('small') else 104}
        for clip, info in actor['clips'].items():
            values = {}
            for i, key in enumerate(info['painted_keys']):
                target = RUN[hero][i] if clip == 'run' else refs[key]
                values[str(i)] = round(round(height*target) / round(height*SOURCE[clip][i]), 6)
            profile[clip] = values
        out[model] = profile
    out['murloc']['_scale'] = 1.4
    out['murloc']['_stride'] = 64
    # Reused reaction and emergence poses keep the same anatomy too.
    for clip, ratios, target in [
        ('hit', [1,.93], [1,1]),
        ('pipe_emerge', [.74,.88,1,1], [.94,.88,1,1]),
        ('stomp_defeat', [.88,.47,.32], [1,.47,.32]),
        ('magic_defeat', [1.02,.82,.34], [1.02,1,.34]),
    ]:
        out['murloc'][clip] = {str(i): round(round(62*t)/round(62*r),6)
                                 for i,(r,t) in enumerate(zip(ratios,target))}
    FILE.write_text(json.dumps(out, indent=2)+'\n', encoding='utf8')
    print('Updated runtime calibration; no source images written.')

if __name__ == '__main__':
    build()
