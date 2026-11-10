from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'tests/p07_web.mjs').read_text(encoding='utf-8-sig')
s=s.replace("const stage = 'p07';", "const stage = 'campaign-polish';").replace('const port = 18792;', 'const port = 18796;')
s=s.replace("reports/evidence/p07/web/", "reports/evidence/campaign-polish/web/")
s=s.replace('reports/temp/molten', 'reports/temp/campaign-polish')
s=s.replace('p.x>b.arena_start+180', 'p.x>b.arena_start+120')
s=s.replace('async function controls(s,axis,leap){await hold', '''async function controls(s,axis,leap){
 for(const shot of s.enemy_shots||[])if((s.player.x-shot.x)*shot.dx>0&&Math.abs(s.player.x-shot.x)<110&&shot.y>s.player.y-(s.player.form?64:32)-16&&shot.y<s.player.y+8)leap=true;
 await hold''')
(root/'tests/campaign_polish_web.mjs').write_text(s,encoding='utf-8')
