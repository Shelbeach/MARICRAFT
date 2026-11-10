# Historical one-time bootstrap; the finished sources contain later verified fixes.
raise SystemExit("Одноразовый генератор завершён. Не запускать поверх текущих сцен/тестов; см. docs/CAMPAIGN_POLISH_REPORT.md")
"""Explicit, reviewable scene corrections. IDs/counts of rewards are preserved."""
import json
import re
from pathlib import Path
from campaign_polish_inventory import ROOT, OUT, nodes

changes=[]
def edit(level, name, **props):
    path=ROOT/'scenes/levels'/f'{level}.tscn'
    text=path.read_text(encoding='utf-8')
    pattern=r'(\[node name="'+re.escape(name)+r'"[^\n]*\]\n)(.*?)(?=\n\[|\Z)'
    match=re.search(pattern,text,re.S)
    assert match, (level,name)
    body=match[2]
    for key,value in props.items():
        encoded='Vector2(%s, %s)'%tuple(value) if isinstance(value,(list,tuple)) else json.dumps(value,ensure_ascii=False)
        old=re.search(r'^'+key+r' = (.*)$',body,re.M)
        if old and old[1]==encoded: continue
        changes.append([level,name,key,old[1] if old else None,encoded])
        if old: body=body[:old.start()]+key+' = '+encoded+body[old.end():]
        else: body=body.rstrip()+'\n'+key+' = '+encoded+'\n'
    text=text[:match.start(2)]+body+text[match.end(2):]
    path.write_text(text,encoding='utf-8')

edit('molten_3_1','UpperApproach',position=[1552,440],size=[104,140])
edit('molten_3_2','TowerStep',position=[1330,440],size=[180,140])
edit('molten_3_2','DangerVent',position=[3860,480],emerge_direction=-1,enemy_patrol_width=140)
edit('forest_1_2','PracticeFerry',travel=[116,-28])
for name in ['LandingQuay','LastLanding']: edit('forest_1_2',name,construction='plain')
edit('forest_1_3','ArchL',position=[496,248],size=[48,32])
edit('forest_1_3','ArchR',position=[576,248],size=[64,32])
edit('forest_1_3','Shelf1950Y400',position=[1912,424],size=[112,16])
edit('forest_1_3','Shelf2340Y420',position=[2340,424],size=[112,16])
edit('forest_1_3','Shelf2480Y369',position=[2500,480],size=[92,64])
edit('forest_1_3','Forest',arena_entry_x=1810)
edit('forest_1_3','ArenaRune',position=[1870,370])
edit('durotar_2_3','Durotar',arena_entry_x=2780)
edit('durotar_2_3','LastRune',position=[2850,366])
edit('durotar_2_3','Sentry',position=[1735,478],patrol_width=50)
edit('molten_3_3','MoltenCore',arena_entry_x=1740)
edit('molten_3_3','Boss',arena_start=1740,engage_x=1788)
edit('molten_3_3','LastRune',position=[1820,366])
for i in range(3): edit('durotar_2_2',f'GalleryBridge{i}',position=[2992+i*32,264])

for level,name,x in [('molten_3_1','ForgeCaster',2500),('molten_3_2','FoundryCaster',2280)]:
    path=ROOT/'scenes/levels'/f'{level}.tscn'
    text=path.read_text(encoding='utf-8')
    if f'[node name="{name}"' not in text:
        chapter='3-1' if level.endswith('1') else '3-2'
        text+=f'\n[node name="{name}" parent="." instance=ExtResource("murloc")]\nposition = Vector2({x}, 478)\nreward_id = "{chapter}/{name}"\npatrol_width = 70\nranged = true\n'
        path.write_text(text,encoding='utf-8')
        changes.append([level,name,'new ranged enemy',x])

# Include blocks as solids; put an intersecting coin above the actual surface.
# Never add/remove a coin or alter its reward ID.
for path in (ROOT/'scenes/levels').glob('*.tscn'):
    if path.stem=='test_field': continue
    rows=nodes(path)
    solids=[]
    for row in rows:
        if 'size' in row: solids.append((*row['position'],*row['size']))
        elif row['type']=='block':
            x,y=row['position'];solids.append((x-16,y-16,32,32))
    for coin in [r for r in rows if r['type']=='coin']:
        x,y=coin['position']; original=y
        for _ in range(8):
            overlaps=[sy for sx,sy,w,h in solids if x+12>sx and x-12<sx+w and y+14>sy and y-14<sy+h]
            if not overlaps: break
            y=min(overlaps)-36
        if y!=original: edit(path.stem,coin['name'],position=[x,y])

placements=ROOT/'assets/faction_art/placements.json'
data=json.loads(placements.read_text(encoding='utf-8'))
for level in ['1-1','1-2','1-3']:
    data[level]=[p for p in data[level] if p['id'] not in ['alliance_standard','alliance_wall_banner']]
placements.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Keep the Horde sign, and remove the redundant tool/sign clusters in scene data.
for level,banned in [('durotar_2_1',{'sign'}),('durotar_2_3',{'tools'})]:
    path=ROOT/'scenes/levels'/f'{level}.tscn'
    text=path.read_text(encoding='utf-8')
    match=re.search(r'^scenery = (.*)$',text,re.M)
    scenery=json.loads(match[1])
    scenery=[p for p in scenery if p['id'] not in banned]
    text=text[:match.start(1)]+json.dumps(scenery,ensure_ascii=False)+text[match.end(1):]
    path.write_text(text,encoding='utf-8')

(OUT/'layout-changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(changes,ensure_ascii=False,indent=2))
