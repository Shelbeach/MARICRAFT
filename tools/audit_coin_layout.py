"""Read authored TSCN positions without running gameplay or touching rewards."""
import json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def vector(text,key,default=None):
    m=re.search(r'^'+key+r' = Vector2\(([^)]+)\)',text,re.M)
    return tuple(map(float,m[1].split(','))) if m else default
def nodes(path):
    text=path.read_text(encoding='utf8')
    resources=dict((rid,src) for src,rid in re.findall(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]',text))
    result=[]
    for block in re.split(r'(?=\[node )',text)[1:]:
        name=re.search(r'name="([^"]+)"',block)[1]
        ref=re.search(r'instance=ExtResource\("([^"]+)"\)',block)
        source=resources.get(ref[1],'') if ref else ''
        result.append(dict(name=name,block=block,source=source,pos=vector(block,'position',(0,0)),size=vector(block,'size')))
    return result
def audit():
    findings=[]; counts={}
    for path in sorted((ROOT/'scenes/levels').glob('*_[123]_[123].tscn')):
        items=nodes(path)
        coins=[n for n in items if n['source'].endswith('/coin.tscn')]
        counts[path.stem]=len(coins)
        solids=[]
        for n in items:
            x,y=n['pos']; size=n['size']
            if size and 'platform' in n['source']: solids.append((n['name'],x,y,*size))
            elif 'reward_block.tscn' in n['source']: solids.append((n['name'],x-16,y-16,32,32))
            elif '/pipe.tscn' in n['source']: solids.append((n['name'],x-32,y-48,64,48))
        for i,c in enumerate(coins):
            x,y=c['pos']
            for d in coins[i+1:]:
                if (x-d['pos'][0])**2+(y-d['pos'][1])**2<30**2:
                    findings.append(dict(level=path.stem,coin=c['name'],issue='spacing',other=d['name'],at=c['pos'],other_at=d['pos']))
            for name,sx,sy,sw,sh in solids:
                dx=max(sx-x,0,x-sx-sw);dy=max(sy-y,0,y-sy-sh)
                if dx*dx+dy*dy<15**2:
                    findings.append(dict(level=path.stem,coin=c['name'],issue='solid_clearance',other=name,at=c['pos'],solid=[sx,sy,sw,sh]))
    return dict(counts=counts,findings=findings)
if __name__=='__main__':
    data=audit()
    (ROOT/'reports/evidence/final-polish/coin-layout.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    print(json.dumps(data,indent=2))
