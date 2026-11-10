from pathlib import Path
import json,re,hashlib
from campaign_polish_inventory import nodes
root=Path(__file__).resolve().parents[1]
out=root/'reports/evidence/campaign-polish'
before=json.loads((out/'before.json').read_text(encoding='utf-8'))
checks=[]
def check(ok,name,details=None):
    checks.append({'pass':bool(ok),'name':name,'details':details})
    print('PASS' if ok else 'FAIL',name,details if not ok else '')
matrix={
 'forest':['forest-human-final-60','forest-human-final-30','forest-ogre-final-60','forest-ogre-final-30'],
 'durotar':['durotar-human-final-60','durotar-human-final-30','durotar-ogre-final-60','durotar-ogre-final-30'],
 'molten':['molten-human-final2-60','molten-human-final-30','molten-ogre-final-60','molten-ogre-final2-30']}
for chapter,logs in matrix.items():
    for name in logs:
        log=(out/(name+'.log')).read_text(encoding='utf-8-sig')
        err=(out/(name+'-errors.log')).read_text(encoding='utf-8-sig')
        check(len(re.findall(r'^PASS FINISH ',log,re.M))==9 and 'FAIL' not in log and not err.strip(),name,{'finishes':len(re.findall(r'^PASS FINISH ',log,re.M)),'stderr':err})
changed=[];missing=[]
for path,old in before['hashes'].items():
    p=root/path
    if not p.exists():missing.append(path)
    elif hashlib.sha256(p.read_bytes()).hexdigest()!=old:changed.append(path)
check(not missing,'baseline source files retained',missing)
check(not [p for p in changed if p.startswith('reports/art/')],'P07 source package untouched')
check(not [p for p in changed if p.endswith(('.png','.wav','.ogg','.ttf'))],'accepted raster/audio/font assets untouched')
levels={};all_buried=[];lost_ids=[];new_ids=[];moved_coins=[]
for path in sorted((root/'scenes/levels').glob('*.tscn')):
    if path.stem not in before['layout']:continue
    old=before['layout'][path.stem];cur=nodes(path)
    old_ids={n['reward_id'] for n in old if n.get('reward_id')}
    cur_ids={n['reward_id'] for n in cur if n.get('reward_id')}
    lost_ids.extend(old_ids-cur_ids);new_ids.extend(cur_ids-old_ids)
    def total(rows):return sum(1 if n['type']=='coin' else n.get('amount',0) if n.get('kind')=='coins' else n.get('vein_bonus',0) if n.get('kind')=='fragile' else 0 for n in rows)
    levels[path.stem]={'before_total':total(old),'after_total':total(cur)}
    check(total(old)==total(cur),'coin total stable '+path.stem)
    solid=[(n['position'][0],n['position'][1],*n['size'],n['name']) for n in cur if 'size' in n]
    solid += [(n['position'][0]-16,n['position'][1]-16,32,32,n['name']) for n in cur if n['type']=='block']
    for n in cur:
        if n['type']!='coin':continue
        x,y=n['position']
        for sx,sy,w,h,name in solid:
            if x+14>sx and x-14<sx+w and y+14>sy and y-14<sy+h:all_buried.append([path.stem,n['name'],name])
        prior=next((a for a in old if a['name']==n['name']),None)
        if prior:
            pos=prior['position']
            if isinstance(pos,str):pos=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',pos)))
            if pos!=n['position']:moved_coins.append({'level':path.stem,'id':n['reward_id'],'before':pos,'after':n['position']})
check(not all_buried,'all visible coin extents clear solid terrain and blocks',all_buried)
check(not lost_ids,'all existing reward IDs retained',lost_ids)
final_logs={
 'mechanics-30-verified':'POLISH MECHANICS PASS',
 'mechanics-60-verified':'POLISH MECHANICS PASS',
 'arena-persistence-final':'POLISH PERSISTENCE PASS',
 'damage-checkpoints-final':'MOLTEN MECHANICS PASS',
 'blocks-30-final':'MOLTEN BLOCKS PASS cases=462 chests=96',
 'blocks-60-final':'MOLTEN BLOCKS PASS cases=462 chests=96',
 'ferry-30':'POLISH FERRY PASS','ferry-60':'POLISH FERRY PASS',
 'magic-enemy-30':'ORDINARY MAGIC PASS','magic-enemy-60':'ORDINARY MAGIC PASS',
 'ui-final':'CAMPAIGN POLISH UI PASS',
 'demo-verified':'POLISH DEMO clips recorded',
 'movie-verified':'CAMPAIGN POLISH MOLTEN ROUTES PASS',
 'molten-stars-ogre-30':'CAMPAIGN POLISH MOLTEN ROUTES PASS',
 'stars-forest-verified':'PASS FINISH human 1-3 form=0',
 'stars-forest-ogre-30':'PASS FINISH ogre 1-3 form=0',
 'stars-durotar-verified':'SMALL THREE STARS PASS',
 'stars-durotar-ogre-30':'SMALL THREE STARS PASS',
 'economy-final':'MOLTEN CAMPAIGN PASS',
 'capture-rune-final':'CAPTURED 6 world windows',
 'web-release-final':'MOLTEN WEB PASS release',
 'web-perf30':'MOLTEN WEB PASS debug','web-perf60':'MOLTEN WEB PASS debug',
 'review-final':'CAMPAIGN POLISH REVIEW PASS',
}
for name,marker in final_logs.items():
    path=out/(name+'.log');errpath=out/(name+'-errors.log')
    log=path.read_text(encoding='utf-8-sig') if path.exists() else ''
    err=errpath.read_text(encoding='utf-8-sig') if errpath.exists() else 'missing stderr'
    check(marker in log and 'FAIL' not in log and not err.strip(),name,{'expected':marker,'stderr':err})
star_runs={}
for name in ['stars-forest-verified','stars-forest-ogre-30','stars-durotar-verified','stars-durotar-ogre-30','movie-verified','molten-stars-ogre-30']:
    log=(out/(name+'.log')).read_text(encoding='utf-8-sig')
    stars=re.findall(r'^COINS ([123]-[123]) (\d+)/(\d+) stars=(\d+)',log,re.M)
    star_runs[name]=stars
    check(len(stars)==3 and all(int(s[3])==3 and int(s[1])>=int(s[2])*.8 for s in stars),'three stars in continuous routes '+name)
review_path=out/'review-browser.json'
review=json.loads(review_path.read_text(encoding='utf-8')) if review_path.exists() else {}
check(review.get('success') and len(review.get('allPlayback',[]))==7,'all seven videos play and seek in browser')
check(len(json.loads((out/'after/coverage.json').read_text(encoding='utf-8')))==100,'100 overlapping native camera windows')
release_path=out/'web/release/release.json'
check(release_path.exists() and release_path.stat().st_mtime>=(root/'exports/campaign-polish-release/index.pck').stat().st_mtime,'full Web release test uses latest export')
result={'checks':checks,'route_matrix':matrix,'route_finishes':sum(9 for names in matrix.values() for n in names),'final_logs':final_logs,'continuous_star_runs':star_runs,'changed_existing_files':changed,'new_reward_ids':new_ids,'coins':levels,'moved_coins':moved_coins,'success':all(c['pass'] for c in checks)}
(out/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if result['success'] else 1)
