from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1]
sha=lambda data:hashlib.sha256(data).hexdigest()
ledger=json.loads((r/'reports/evidence/forest-art/runtime-ledger.json').read_text(encoding='utf-8-sig'))
sources=[v['source'] for v in ledger if sha((r/v['source']).read_bytes())!=v['sha256']]
runtime=[v['runtime'] for v in ledger if sha((r/v['runtime']).read_bytes())!=v['sha256']]
baseline=json.loads((r/'reports/evidence/forest-art/baseline-hashes.json').read_text(encoding='utf-8-sig'))
changed=[]
scene_checks={}
for f,digest in baseline.items():
 p=r/f
 if sha(p.read_bytes())==digest: continue
 changed.append(f)
 if f.startswith('scenes'):
  s=p.read_text(encoding='utf-8-sig').replace('forest_art = true\n','')
  variants=[]
  for eol in ['\n','\r\n']:
   for end in ['',eol,eol+eol]:
    text=s.strip().replace('\n',eol)+end
    variants.extend([text.encode(),b'\xef\xbb\xbf'+text.encode()])
  scene_checks[f]=any(sha(v)==digest for v in variants)
exports={}
for build in ['s04-release','forest-art-release','forest-art']:
 files={p.name:p.stat().st_size for p in (r/'exports'/build).iterdir() if p.is_file()}
 exports[build]={'files':files,'bytes':sum(files.values())}
out={'source_count':len(ledger),'source_changes':sources,'runtime_copy_changes':runtime,'baseline_changed_paths':changed,'only_art_flag_in_changed_scenes':scene_checks,'exports':exports}
(r/'reports/evidence/forest-art/integrity.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(out,ensure_ascii=False,indent=2))
assert not sources
assert not runtime
assert all(scene_checks.values())

