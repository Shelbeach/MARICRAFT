"""Collect assertions from the final runs; do not count obsolete failure logs."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = root / 'reports/evidence/camera-repair'
target = base / 'verification-summary.json'
summary = json.loads(target.read_text(encoding='utf-8'))
summary['native_routes'] = {}
summary['final_ragnaros_routes'] = {}
for pattern, key, expected in [('routes-*.log', 'native_routes', 108), ('ragnaros-*.log', 'final_ragnaros_routes', 12)]:
    for file in sorted(base.glob(pattern)):
        if file.stem.endswith('-errors'):
            continue
        content = file.read_text(encoding='utf-8')
        assert not re.search(r'(^FAIL|SCRIPT ERROR|^ERROR)', content, re.M), file.name
        assert (base / (file.stem + '-errors.log')).stat().st_size == 0, file.name
        summary[key][file.stem] = len(re.findall(r'^PASS FINISH ', content, re.M))
    assert sum(summary[key].values()) == expected, summary[key]

views = [json.loads(p.read_text(encoding='utf-8')) for p in sorted(base.glob('view-*.json'))]
summary['route_camera_bounds'] = {'cases': sum(map(len, views)), 'outside': 0, 'hud_overlap': 0}
for view in views:
    for case in view.values():
        for key in ('outside', 'hud_overlap'):
            summary['route_camera_bounds'][key] += case[key]
assert summary['route_camera_bounds']['cases'] >= 108
assert summary['route_camera_bounds']['outside'] == 0
assert summary['route_camera_bounds']['hud_overlap'] == 0

summary['targeted_tests'] = {}
for name in ['mechanics30', 'mechanics60', 'persistence30', 'persistence60', 'imps30', 'imps60', 'ferry30', 'ferry60', 'arena-edges']:
    content = (base / f'{name}.log').read_text(encoding='utf-8')
    assert not re.search(r'(^FAIL|SCRIPT ERROR|^ERROR)', content, re.M), name
    if name.startswith('imps'):
        cases = json.loads(content.split('IMP REPRO ', 1)[1].strip())
        assert len(cases) == 2 and all(c['fired'] == 20 and c['started'] == 20 and c['cancelled'] == 0 for c in cases), name
    elif name.startswith('ferry'):
        assert 'FERRY EDGES 12 cases; failures=[]' in content, name
    else:
        assert 'PASS' in content, name
    assert (base / f'{name}-errors.log').stat().st_size == 0, name
    summary['targeted_tests'][name] = 'PASS'

summary['web'] = {}
for name in ['release/release', 'perf30/debug-perf30', 'perf60/debug-perf60']:
    result = json.loads((base / f'web/{name}.json').read_text(encoding='utf-8'))
    metrics = result['metrics']
    assert result['errors'] == [] and metrics['final']['completed']
    assert sorted(metrics['boss_attacks']) == [0, 1, 2]
    summary['web'][name] = {'errors': 0, 'final': metrics['final'], 'boss_fps': metrics['boss_performance']['estimated_fps']}

summary['final_import_and_exports'] = {}
for name in ['import-final', 'export-camera-repair', 'export-camera-repair-release', 'export-camera-repair-qa']:
    assert (base / f'{name}-errors.log').stat().st_size == 0, name
    content = (base / f'{name}.log').read_text(encoding='utf-8')
    assert not re.search(r'(SCRIPT ERROR|^ERROR)', content, re.M), name
    summary['final_import_and_exports'][name] = 'PASS'

summary['report'] = json.loads((base / 'report-check.json').read_text(encoding='utf-8'))
summary['desktop_control_used'] = False
target.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(f"PASS: 108 routes, 12 final Ragnaros routes, {summary['route_camera_bounds']['cases']} recorded level/hero/form camera states, targeted tests, Web, import, exports, evidence page.")
