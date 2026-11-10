from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
for p in (root/'scenes/levels').glob('*_[123]_[123].tscn'):
    s=p.read_text(encoding='utf8')
    lines=re.findall(r'^\[ext_resource [^\n]+\]\n',s,re.M)
    s=re.sub(r'^\[ext_resource [^\n]+\]\n','',s,flags=re.M)
    at=s.index('\n')+1
    s=s[:at]+'\n'+''.join(lines)+s[at:]
    p.write_text(s,encoding='utf8')
print('External resources precede subresources in all nine scenes.')
