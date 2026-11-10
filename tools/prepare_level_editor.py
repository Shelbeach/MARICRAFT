"""Enable presentation-only scripts in editor; gameplay scripts remain inert."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
for name in ['art_library','forest_backdrop','backdrop_layer','forest_terrain','grotto_terrain','location_art_library','location_backdrop','location_terrain','molten_library','molten_backdrop']:
    p=ROOT/f'scripts/visual/{name}.gd'
    s=p.read_text(encoding='utf8')
    if not s.startswith('@tool'): p.write_text('@tool\n'+s,encoding='utf8')
for name in ['forest_backdrop','faction_decor']:
    p=ROOT/f'scripts/visual/{name}.gd';s=p.read_text(encoding='utf8')
    s=s.replace('Campaign.p.level','preload("res://scripts/visual/level_identity.gd").id(level)')
    p.write_text(s,encoding='utf8')
p=ROOT/'scripts/visual/location_terrain.gd';s=p.read_text(encoding='utf8')
s=s.replace('level.boss','level.get_node_or_null("Boss")')
s=s.replace('node.origin.x','node.position.x if Engine.is_editor_hint() else node.origin.x')
# Keep operator precedence explicit for mooring computations.
s=s.replace('node.position.x if Engine.is_editor_hint() else node.origin.x','(node.position.x if Engine.is_editor_hint() else node.origin.x)')
p.write_text(s,encoding='utf8')
p=ROOT/'scripts/visual/location_backdrop.gd';s=p.read_text(encoding='utf8').replace('level.boss','level.get_node_or_null("Boss")');p.write_text(s,encoding='utf8')
p=ROOT/'scripts/visual/molten_far_spans.gd'
if not p.exists(): p.write_text('@tool\n'+(ROOT/'assets/p07_v03/visual/far_spans.gd').read_text(encoding='utf8'),encoding='utf8')
p=ROOT/'scripts/visual/molten_backdrop.gd';s=p.read_text(encoding='utf8').replace('res://assets/p07_v03/visual/far_spans.gd','res://scripts/visual/molten_far_spans.gd');p.write_text(s,encoding='utf8')
p=ROOT/'scripts/visual/molten_surface.gd';s=p.read_text(encoding='utf8')
base=(ROOT/'assets/molten_art/terrain/surface.gd').read_text(encoding='utf8')
fields=base[base.index('@export_enum'):base.index('func _ready')]
if not s.startswith('@tool'): s=s.replace('extends "res://assets/molten_art/terrain/surface.gd"','@tool\nextends Node2D\n'+fields)
p.write_text(s,encoding='utf8')
print('Presentation scripts enabled; no gameplay @tool execution.')
