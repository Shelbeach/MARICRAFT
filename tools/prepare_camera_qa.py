"""Stage only test harness dependencies; never copy game scripts or assets."""
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
target=root/'qa/camera_repair'
target.mkdir(parents=True,exist_ok=True)
pending=['camera_repair_entry.tscn','camera_repair_entry.gd','camera_repair_web.gd']
seen=set()
while pending:
    name=pending.pop()
    if name in seen: continue
    seen.add(name)
    source=(root/'tests'/name).read_text(encoding='utf-8')
    pending.extend(re.findall(r'res://tests/([^"\s]+\.(?:gd|tscn))',source))
    (target/name).write_text(source.replace('res://tests/','res://qa/camera_repair/'),encoding='utf-8')
print('Staged QA dependencies:',len(seen))
