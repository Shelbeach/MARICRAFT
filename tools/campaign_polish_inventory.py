"""Read authored level geometry and record the pre-edit state (no project copies)."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/evidence/campaign-polish'
OUT.mkdir(parents=True, exist_ok=True)

def nodes(path):
    text = path.read_text(encoding='utf-8')
    result = []
    for match in re.finditer(r'\[node name="([^"]+)"([^\n]*)\]\n([^\[]*)', text):
        name, header, body = match.groups()
        if 'parent="."' not in header:
            continue
        row = {'name': name}
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', header)
        row['type'] = inst[1] if inst else 'node'
        for key, value in re.findall(r'^(\w+) = (.*)$', body, re.M):
            vec = re.fullmatch(r'Vector2\(([^,]+),\s*([^)]+)\)', value)
            if vec:
                row[key] = [float(vec[1]), float(vec[2])]
            else:
                try: row[key] = json.loads(value)
                except ValueError: row[key] = value
        result.append(row)
    return result

if __name__ == '__main__':
    data = {}
    for path in sorted((ROOT/'scenes/levels').glob('*.tscn')):
        if path.stem == 'test_field': continue
        data[path.stem] = nodes(path)
    (OUT/'layout.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    baseline = OUT/'before.json'
    if not baseline.exists():
        paths = [p for folder in ['scripts', 'scenes', 'assets', 'reports/art/MARICRAFT_P07_molten_core/runtime']
                 for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.uid', '.import']]
        hashes = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
        baseline.write_text(json.dumps({'hashes': hashes, 'layout': data}, ensure_ascii=False, indent=2), encoding='utf-8')
    for name, rows in data.items():
        print('\n'+name)
        for row in rows:
            if row['type'] in ['coin', 'block']: continue
            print(json.dumps(row, ensure_ascii=False))
        solids = [r for r in rows if 'size' in r]
        buried = []
        for coin in [r for r in rows if r['type'] == 'coin']:
            x, y = coin['position']
            for solid in solids:
                sx, sy = solid['position']; w, h = solid['size']
                if x+10 > sx and x-10 < sx+w and y+10 > sy and y-10 < sy+h:
                    buried.append([coin['name'], coin['position'], solid['name']])
        print('BURIED', json.dumps(buried))
