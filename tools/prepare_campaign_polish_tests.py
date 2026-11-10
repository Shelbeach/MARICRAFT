# Historical one-time bootstrap; the finished sources contain later verified fixes.
raise SystemExit("Одноразовый генератор завершён. Не запускать поверх текущих сцен/тестов; см. docs/CAMPAIGN_POLISH_REPORT.md")
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(p): return (root / p).read_text(encoding='utf-8-sig')
def write(p, s): (root / p).write_text(s, encoding='utf-8')

# The same input drivers, with isolated evidence and current campaign exits.
forest = read('tests/forest_art_routes.gd')
forest = forest.replace('res://reports/temp/forest-art/', 'res://reports/evidence/campaign-polish/forest/')
base = read('tests/s02_form_reachability.gd')
run = base[base.index('func run()'):base.index('func audit_passages')]
run = run.replace('for form in ([1] if before else [0,1,2]):', '''for form in [0,1,2]:
		if "--small" in args and form!=0 or "--big" in args and form!=1 or "--magic" in args and form!=2: continue''')
run = run.replace('res://reports/temp/form-test-', 'res://reports/temp/campaign-polish/form-test-')
run = run.replace('await damage_recovery_route()', 'await ticks(2) # Adverse recovery has its own dedicated scenario.')
forest += '\n' + run
forest = forest.replace('var dir:="res://reports/evidence/campaign-polish/forest/"\n', '''var dir:="res://reports/evidence/campaign-polish/forest/"+("30/" if "--30" in OS.get_cmdline_user_args() else "60/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
''')
write('tests/campaign_polish_forest.gd', forest)

s = read('tests/s04_routes.gd')
s = s.replace('res://reports/evidence/s04/', 'res://reports/evidence/campaign-polish/durotar/')
s = s.replace('res://reports/temp/s04/', 'res://reports/temp/campaign-polish/')
s = s.replace('await approach(2640,[490,1060,2150])', 'await approach(2850,[490,1060,2150])')
s = s.replace('game.page=="future"', 'game.page=="play"')
s = s.replace('var trace:=FileAccess.open(TMP+clip4+"-"+hero+".json",FileAccess.WRITE)', '''var dir:=OUTPUT4+("30/" if "--30" in args else "60/")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var trace:=FileAccess.open(dir+clip4+"-"+hero+".json",FileAccess.WRITE)''')
s += '''
func _initialize() -> void:
	root.unfocusable=true
	super._initialize()
'''
write('tests/campaign_polish_durotar.gd', s)

s = read('tests/campaign_polish_molten.gd')
s = s.replace('var file:=FileAccess.open("res://reports/evidence/campaign-polish/route-%s-%s-%d-%s.json"', '''var dir:="res://reports/evidence/campaign-polish/molten/"+("30/" if "--30" in args else "60/")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var file:=FileAccess.open(dir+"route-%s-%s-%d-%s.json"''')
write('tests/campaign_polish_molten.gd', s)

export = read('tools/export_p07.ps1').replace('p07', 'campaign-polish').replace('reports/temp/molten', 'reports/temp/campaign-polish')
write('tools/export_campaign_polish.ps1', export)
