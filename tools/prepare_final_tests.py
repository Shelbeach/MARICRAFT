from pathlib import Path
root=Path(__file__).resolve().parents[1]
for source,dest in [('campaign_polish_forest','final_polish_forest'),('campaign_polish_durotar','final_polish_durotar'),('p07v03_routes','final_polish_molten'),('p07v03_mechanics','final_polish_mechanics'),('p07v03_ferry','final_polish_ferry'),('p07v03_persistence','final_polish_persistence')]:
    text=(root/f'tests/{source}.gd').read_text(encoding='utf8')
    text=text.replace('reports/evidence/p07v03-music/','reports/evidence/final-polish/').replace('reports/temp/p07v03-music/','reports/temp/final-polish/').replace('reports/evidence/campaign-polish/','reports/evidence/final-polish/').replace('reports/temp/campaign-polish/','reports/temp/final-polish/')
    (root/f'tests/{dest}.gd').write_text(text,encoding='utf8')
print('Final verification harnesses prepared.')
