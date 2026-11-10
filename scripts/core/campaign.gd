extends Node

signal changed
const Store := preload("res://scripts/core/save_store.gd")
const ROUTE := Store.ROUTE
const NAMES := {"1-1":"Лесная тропа","1-2":"Переправа","1-3":"Дозор вожака","2-1":"Скалистая дорога","2-2":"Заброшенная шахта","2-3":"Восковая плавильня","3-1":"Врата Недр","3-2":"Глубинные кузни","3-3":"Сердце пламени"}
var store := Store.new()
var p: Dictionary = {}
var sandbox := false
var access_ready := false
var access_denied := false
var cheats := {}
var settings := ConfigFile.new()
const OPTIONS := "user://settings.cfg"

func _ready() -> void:
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("new URLSearchParams(location.search).get('expedition') === 'durotar'",true):
			store.first_level="2-1"
			store.prefix="user://durotar-expedition"
		JavaScriptBridge.eval("""
			window.maricraftWriter = 0;
			if (navigator.locks) {
				navigator.locks.request('maricraft-campaign', {ifAvailable:true}, lock => {
					window.maricraftWriter = lock ? 1 : -1;
					if (lock) return new Promise(() => {});
				}).catch(() => { window.maricraftWriter = -1; });
			} else { window.maricraftWriter = 1; }
		""",true)
		while int(JavaScriptBridge.eval("window.maricraftWriter",true)) == 0:
			await get_tree().process_frame
		access_denied = int(JavaScriptBridge.eval("window.maricraftWriter",true)) < 0
	if not access_denied:
		p = store.read_profile()
	access_ready = true
	settings.load(OPTIONS)
	apply_audio()

func save() -> void:
	if not access_denied and not sandbox and not p.is_empty():
		store.write_profile(p)
	changed.emit()

func new_game(hero: String) -> void:
	if hero not in ["human", "ogre"]:
		return
	p = {"hero":hero, "level":store.first_level, "status":"playing", "hearts":3, "wallet":0,
		"purchases":0, "earned":0, "spent":0, "score":0, "enemies":0, "lost":0,
		"coins":0, "level_score":0, "seconds":0.0, "ids":{}, "tutorial":{}, "results":{},
		"completed":false,"records":{},"attempt":0,"last_level":"","last_result":{},"run_start":{"seconds":0.0,"enemies":0}}
	save()

func active() -> bool:
	return not p.is_empty() and p.status == "playing" and NAMES.has(p.level)

func claimed(id: String) -> bool:
	return not p.is_empty() and p.ids.has(id)

func reward(id: String, coins: int, points: int, enemy := false) -> bool:
	if not active() or id.is_empty() or claimed(id):
		return false
	p.ids[id] = true
	p.wallet += coins
	p.earned += coins
	p.coins += coins
	p.score += points
	p.level_score += points
	p.enemies += int(enemy)
	save()
	return true

func learned(action: String) -> void:
	if not p.tutorial.has(action):
		p.tutorial[action] = true
		save()

func lose_heart() -> void:
	if not active() or cheats.get("infinite", false):
		return
	p.hearts -= 1
	p.lost += 1
	if p.hearts == 0:
		p.status = "offer"
	save()

func price() -> int:
	return 100 * (1 + int(p.purchases))

func buy() -> bool:
	if p.is_empty() or p.status != "offer" or p.hearts != 0 or p.wallet < price():
		return false
	var cost := price()
	p.wallet -= cost
	p.spent += cost
	p.purchases += 1
	p.hearts = 1
	p.status = "playing"
	save()
	return true

func abandon() -> void:
	if p.status == "offer":
		p.status = "defeat"
		save()

static func stars(coins: int, total: int, deaths: int) -> int:
	if coins < ceili(total * 0.8):
		return 1
	return 3 if deaths == 0 else 2

func last_level() -> String:
	return p.get("last_level",ROUTE[maxi(0,ROUTE.find(p.level)-1)])

func local_stat(key: String):
	if p.has("run_start"):
		return p[key]-p.run_start.get(key,0)
	var value = p[key]
	for record in p.results.values():
		value -= record[key]
	return value

func finish(total: int) -> bool:
	if not active():
		return false
	var result := {"stars":stars(p.coins,total,p.lost), "coins":p.coins, "total":total,
		"score":p.level_score, "lost":p.lost, "enemies":local_stat("enemies"), "seconds":local_stat("seconds")}
	p.last_level=p.level
	p.last_result=result.duplicate(true)
	var best:Dictionary=p.records.get(p.level,{"stars":0,"score":0})
	p.records[p.level]={"stars":maxi(best.stars,result.stars),"score":maxi(best.score,result.score)}
	var final_victory:bool=not p.completed and p.level=="3-3"
	if not p.completed:
		p.results[p.level]=result
		if not final_victory: p.level=ROUTE[ROUTE.find(p.level)+1]
	if final_victory: p.completed=true
	p.coins = 0
	p.lost = 0
	p.level_score = 0
	p.ids = {}
	p.run_start={"seconds":p.seconds,"enemies":p.enemies}
	p.status = "victory" if final_victory else "result"
	save()
	return true

func leave_result() -> void:
	if p.status in ["result","victory"]:
		p.status = "map" if p.completed else "playing"
		save()

func total_record() -> int:
	var total:=0
	for entry in p.get("records",{}).values(): total+=int(entry.score)
	return total

func start_replay(level:String) -> bool:
	if not p.get("completed",false) or not NAMES.has(level): return false
	p.merge({"level":level,"status":"playing","hearts":3,"coins":0,"lost":0,"level_score":0,"ids":{},
		"attempt":int(p.attempt)+1,"run_start":{"seconds":p.seconds,"enemies":p.enemies}},true)
	save()
	return true

func start_sandbox() -> void:
	if not OS.is_debug_build() or access_denied or sandbox:
		return
	save()
	sandbox = true
	p = p.duplicate(true)
	changed.emit()

func debug_level(level: String) -> void:
	if sandbox and NAMES.has(level):
		new_game(p.get("hero","human"))
		p.level = level
		changed.emit()

func debug_values(coins: int, hearts: int) -> void:
	if sandbox and active():
		p.wallet += coins
		p.hearts = clampi(hearts, 1, 3)
		save()

func end_sandbox() -> void:
	if sandbox:
		sandbox = false
		cheats.clear()
		p = store.read_profile()
		settings = ConfigFile.new()
		settings.load(OPTIONS)
		apply_audio()
		changed.emit()

func volume(bus: String) -> int:
	return clampi(int(settings.get_value("sound", bus, 70 if bus == "Музыка" else 80)),0,100)

func muted(bus: String) -> bool:
	return bool(settings.get_value("mute",bus,false))

func apply_audio() -> void:
	for bus: String in ["Музыка","Эффекты"]:
		# Keep the established Russian settings keys and saved values.
		var bus_name:="Music" if bus=="Музыка" else bus
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx,bus_name)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume(bus)/100.0, 0.0001)))
		AudioServer.set_bus_mute(idx, muted(bus) or volume(bus) == 0)

func store_options(values: Dictionary, mutes: Dictionary) -> void:
	for bus in values:
		settings.set_value("sound",bus,values[bus])
		settings.set_value("mute",bus,mutes[bus])
	apply_audio()
	if not sandbox and settings.save(OPTIONS) != OK:
		store.notice = "Не удалось сохранить настройки."
	changed.emit()
