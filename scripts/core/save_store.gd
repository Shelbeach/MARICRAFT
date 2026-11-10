extends RefCounted
## Two alternating records. A truncated write leaves the preceding record usable.
const VERSION := 3
const ROUTE := ["1-1","1-2","1-3","2-1","2-2","2-3","3-1","3-2","3-3"]
var first_level := "1-1"
var prefix := "user://campaign"
var serial := 0
var notice := ""

func read_profile() -> Dictionary:
	serial = 0
	notice = ""
	var latest := {}
	var damaged := false
	for slot in 2:
		var path := "%s.%d" % [prefix, slot]
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() < 8 or file.get_32() != file.get_length()-4:
			damaged = true
			continue
		file.seek(0)
		var row = file.get_var(false)
		if not row is Dictionary or row.get("version") not in [1,2,VERSION] or not row.get("serial") is int or not row.get("data") is PackedByteArray:
			damaged = true
			continue
		var blob: PackedByteArray = row.data
		if hash(blob) != row.get("checksum"):
			damaged = true
			continue
		var profile = bytes_to_var(blob)
		if row.version == 1 and profile is Dictionary and profile.get("level") == "1-2":
			# S01 carried the finished 1-1 counters into its placeholder screen.
			profile.merge({"coins":0,"lost":0,"level_score":0,"ids":{}},true)
		if row.version<3 and profile is Dictionary: migrate(profile)
		if not valid(profile):
			damaged = true
			continue
		if row.serial > serial:
			serial = row.serial
			latest = profile
	if damaged:
		notice = "Ошибка чтения. Загружена предыдущая запись." if not latest.is_empty() else "Сохранение повреждено или несовместимо. Новая игра заменит его."
	return latest

func migrate(p:Dictionary) -> void:
	# Additive migration only. The existing slot files are neither removed nor renamed.
	var records:Dictionary={}
	var start:Dictionary={"seconds":0.0,"enemies":0}
	if p.get("results") is Dictionary:
		for id in p.results:
			var r=p.results[id]
			if not r is Dictionary: continue
			records[id]={"stars":r.get("stars",0),"score":r.get("score",0)}
			start.seconds+=float(r.get("seconds",0))
			start.enemies+=int(r.get("enemies",0))
	p.merge({"completed":false,"records":records,"attempt":0,"run_start":start,
		"last_level":ROUTE[maxi(0,ROUTE.find(p.get("level","1-1"))-1)],"last_result":{}},false)
	if p.get("status")=="result" and p.get("results") is Dictionary:
		p.last_result=p.results.get(p.last_level,{}).duplicate(true)

func valid_result(result:Variant) -> bool:
	if not result is Dictionary or not result.get("seconds") is float: return false
	for key in ["coins","total","score","stars","enemies","lost"]:
		if not result.get(key) is int or result[key]<0: return false
	return result.stars in [1,2,3] and result.coins<=result.total and result.seconds>=0

func valid(p: Variant) -> bool:
	if not p is Dictionary:
		return false
	for key in ["wallet", "hearts", "purchases", "earned", "spent", "score", "enemies", "lost", "coins", "level_score"]:
		if not p.get(key) is int or p[key] < 0:
			return false
	for key in ["ids", "tutorial", "results", "records","run_start","last_result"]:
		if not p.get(key) is Dictionary:
			return false
	if p.get("hero") not in ["human","ogre"] or p.get("level") not in ROUTE:
		return false
	if p.get("status") not in ["playing","offer","defeat","result","victory","map"] or not p.get("seconds") is float:
		return false
	if not p.get("completed") is bool or not p.get("attempt") is int or p.attempt<0: return false
	if not p.run_start.get("seconds") is float or not p.run_start.get("enemies") is int: return false
	if p.run_start.seconds<0 or p.run_start.seconds>p.seconds or p.run_start.enemies<0 or p.run_start.enemies>p.enemies: return false
	if not p.completed and (p.status in ["victory","map"] or p.attempt>0): return false
	if p.status=="victory" and p.level!="3-3": return false
	var start := ROUTE.find(first_level)
	var completed := ROUTE.size()-start if p.completed else ROUTE.find(p.level)-start
	if completed<0: return false
	if p.results.size()!=completed or (p.status=="result" and completed==0):
		return false
	for index in completed:
		var result = p.results.get(ROUTE[start+index])
		if not valid_result(result): return false
	if p.status in ["result","victory"] and (p.get("last_level") not in ROUTE or not valid_result(p.last_result)): return false
	for id in p.records:
		var record=p.records[id]
		if id not in ROUTE or not record is Dictionary or not record.get("score") is int or record.score<0 or record.get("stars") not in [1,2,3]: return false
	return p.hearts<=3 and ((p.hearts==0)==(p.status in ["offer","defeat"]))

func write_profile(profile: Dictionary) -> bool:
	var next := serial + 1
	var file := FileAccess.open("%s.%d" % [prefix, next % 2], FileAccess.WRITE)
	if file != null:
		var blob := var_to_bytes(profile)
		var ok := file.store_var({"version":VERSION,"serial":next,"checksum":hash(blob),"data":blob})
		file.flush()
		ok = ok and file.get_error() == OK
		file.close()
		if ok:
			serial = next
			notice = ""
			return true
	notice = "Не удалось сохранить прогресс. После закрытия вкладки он может потеряться."
	return false
