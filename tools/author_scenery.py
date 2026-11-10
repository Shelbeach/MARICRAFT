"""One-time migration of the existing live set dressing to real scene nodes."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'reports/temp/final-polish/scenery.json').read_text(encoding='utf8'))
def vec(v): return 'Vector2('+', '.join(f'{x:.6g}' for x in v)+')'
for level,rows in data.items():
    region={'1':'forest','2':'durotar','3':'molten'}[level[0]]
    path=ROOT/f'scenes/levels/{region}_{level.replace("-","_")}.tscn'
    text=path.read_text(encoding='utf8')
    if '[node name="Scenery"' in text: continue
    resources={};parts=['\n[node name="Scenery" type="Node2D" parent="."]\nz_index = -8\n']
    def add(row,parent,index):
        name=f'{row["id"]}_{index:02}'
        if 'children' in row:
            parts.append(f'\n[node name="{name}" type="Node2D" parent="{parent}"]\nposition = {vec(row["position"])}\nmetadata/_edit_group_ = true\n')
            for i,child in enumerate(row['children']): add(child,parent+'/'+name,i)
            return
        src=row['texture']
        rid=resources.setdefault(src,'decor_'+str(len(resources)))
        color=', '.join(f'{x:.6g}' for x in row['tint'])
        parts.append(f'\n[node name="{name}" type="Sprite2D" parent="{parent}"]\nposition = {vec(row["position"])}\nscale = {vec(row["scale"])}\ntexture = ExtResource("{rid}")\ncentered = false\noffset = {vec(row["offset"])}\nmodulate = Color({color})\ntexture_filter = 2\n')
        if level.startswith('1') and row['id'].startswith('oak_'):
            resources.setdefault('res://scripts/visual/tree_depth.gdshader','decor_tree_shader')
            parts[-1]+='material = SubResource("TreeDepth")\n'
    for i,row in enumerate(rows): add(row,'Scenery',i)
    ext='\n'.join(f'[ext_resource type="{"Shader" if src.endswith(".gdshader") else "Texture2D"}" path="{src}" id="{rid}"]' for src,rid in resources.items())+'\n\n'
    if 'res://scripts/visual/tree_depth.gdshader' in resources:
        ext+='[sub_resource type="ShaderMaterial" id="TreeDepth"]\nshader = ExtResource("decor_tree_shader")\n\n'
    at=text.index('[sub_resource ') if '[sub_resource ' in text else text.index('[node ')
    text=text[:at]+ext+text[at:]+''.join(parts)
    path.write_text(text,encoding='utf8')
    print(level,len(rows),'editable scenery objects')
