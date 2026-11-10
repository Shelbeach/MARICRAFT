extends "res://tests/campaign_polish_forest.gd"
var star_done:={}
var star_results:={}

func stop_star_keys() -> void:
	for k in [KEY_A,KEY_D,KEY_SPACE]: press(k,false)

func star_walk(x:float,jump:=false) -> void:
	stop_star_keys()
	await ticks(8)
	var a=game.world.player
	var air:=false
	for i in 200:
		var dx:float=x-a.position.x
		var axis:=signi(roundi(dx)) if absf(dx)>1.3 and absf(a.velocity.x)<absf(dx)*12 else 0
		press(KEY_A,axis<0);press(KEY_D,axis>0)
		press(KEY_SPACE,jump and i<50)
		await ticks(1)
		if not a.is_on_floor(): air=true
		if a.is_on_floor() and absf(dx)<3 and absf(a.velocity.x)<2 and (not jump or air): break
	stop_star_keys()
	await ticks(8)
	check(absf(a.position.x-x)<15,"reward route reaches "+str(x)+" at "+str(a.position))

func star_chest(name:String) -> void:
	var chest=game.world.get_node(name)
	await star_walk(chest.position.x)
	press(KEY_SPACE,true)
	await ticks(34)
	press(KEY_SPACE,false)
	await ticks(48)
	check(state.claimed(chest.reward_id),"continuous small chest "+chest.reward_id)

func star_practice_ferry() -> void:
	stop_star_keys()
	await star_walk(790)
	var a=game.world.player
	var deck=game.world.get_node("PracticeFerry")
	for i in 320:
		if deck.position.x<916: break
		await ticks(1)
	var boarded:=false
	for i in 100:
		press(KEY_D,a.position.x<deck.position.x-2)
		press(KEY_SPACE,i<48)
		await ticks(1)
		if riding(a,deck): boarded=true;break
	stop_star_keys()
	check(boarded,"small boards diagonal PracticeFerry with real input")
	for i in 280:
		if deck.position.x>1004: break
		press(KEY_D,a.position.x<deck.position.x-5)
		press(KEY_A,a.position.x>deck.position.x+5)
		await ticks(1)
	await star_walk(1140,true)
	check(absf(a.position.y-384)<2,"diagonal ferry leads to static quay")
	await star_chest("Block1196")
	await star_walk(1300)

func route_action(level:String,a) -> void:
	await super.route_action(level,a)
	var key:=""
	if level=="1-1":
		if a.position.x>=520 and not star_done.has("Block544"): key="Block544"
		elif a.position.x>=660 and not star_done.has("mill1"):
			star_done.mill1=true;star_done.Block12880=true
			await star_walk(678)
			await star_walk(776,true)
			await star_walk(904,true)
			await star_walk(1004)
			await star_walk(1120,true)
			await star_walk(1250)
			await star_walk(1350)
			await star_chest("Block12880")
			press(KEY_D,true)
		elif a.position.x>=1250 and not star_done.has("Block12880"): key="Block12880"
		elif a.position.x>=1730 and not star_done.has("mill2"):
			star_done.mill2=true
			await star_walk(1730)
			await star_walk(1824,true)
			await star_walk(2024,true)
			await star_walk(2176,true)
			await star_walk(2320)
			await star_walk(2464,true)
			await star_walk(2528)
			await star_walk(2680)
			press(KEY_D,true)
		elif a.position.x>=4060 and not star_done.has("guard_deck"):
			star_done.guard_deck=true
			await star_walk(4090)
			await star_walk(4212,true)
			await star_walk(4256)
			await star_walk(4384,true)
			await star_walk(4584,true)
			await star_walk(4648)
			await star_walk(4745)
			press(KEY_D,true)
		elif a.position.x>=5800 and not star_done.has("Block9350"):
			star_done["Block9350"]=true
			await star_walk(5884,true)
			await star_walk(5680,true)
			await star_walk(5460,true)
			await star_chest("Block9350")
			await star_walk(5850)
			press(KEY_D,true)
		elif a.position.x>=6220 and not star_done.has("Block6128"): key="Block6128"
	elif level=="1-2":
		if a.position.x>=510 and not star_done.has("Block540"): key="Block540"
		elif a.position.x>=800 and not star_done.has("practice"):
			star_done.practice=true
			await star_practice_ferry()
			press(KEY_D,true)
		elif a.position.x>=3490 and not star_done.has("lookout"):
			star_done.lookout=true
			await star_walk(3494)
			await star_walk(3565,true)
			await star_walk(3684,true)
			await star_walk(3764,true)
			await star_walk(3854,true)
			await star_chest("Block3890")
			await star_walk(4070)
			press(KEY_D,true)
	elif level=="1-3":
		if a.position.x>=780 and not star_done.has("gallery"):
			star_done.gallery=true;star_done.Block1030=true
			await star_walk(782)
			await star_walk(832,true)
			await star_walk(929,true)
			await star_walk(968)
			await star_walk(1170)
			await star_walk(1290)
			await star_chest("Block1030")
			await star_walk(1290)
			press(KEY_D,true)
		elif a.position.x>=1040 and not star_done.has("Block1030"): key="Block1030"
		elif a.position.x>=2350 and game.world.boss.hp==0 and not star_done.has("arena_coins"):
			star_done.arena_coins=true
			await star_walk(2396,true)
			await star_walk(2544,true)
			press(KEY_D,true)
	if not key.is_empty():
		star_done[key]=true
		await star_chest(key)
		press(KEY_D,true)

func cave_detour(a) -> void:
	stop_star_keys()
	await ticks(65)
	press(KEY_S,true);await ticks(3);press(KEY_S,false)
	check(game.world.underground and a.form==0,"small enters grotto normally")
	var held:=0
	for i in 1300:
		if a.position.x>=7525: break
		if a.position.x>=7295 and not star_done.has("cave_cache"):
			star_done.cave_cache=true
			await star_chest("Block7320")
		press(KEY_D,true)
		if held>0:
			held-=1
			if held==0: press(KEY_SPACE,false)
		elif a.is_on_floor() and (a.is_on_wall() or a.position.x>6948 and a.position.x<6990):
			press(KEY_SPACE,true);held=40
		await ticks(1)
	stop_star_keys()
	await ticks(42)
	press(KEY_S,true);await ticks(4);press(KEY_S,false)
	check(not game.world.underground and a.form==0,"small returns from grotto")
	press(KEY_D,true)

func route(level:String,capture:=true) -> void:
	star_done.clear()
	await super.route(level,capture)
	if game.page=="result":
		print("COINS ",level," ",state.p.last_result.coins,"/",state.p.last_result.total," stars=",state.p.last_result.stars)
		check(state.p.last_result.stars==3 and game.world.player.form==0,"small without magic earns three stars "+level)
		star_results[level]=state.p.last_result.duplicate()
		var file:=FileAccess.open("res://reports/evidence/campaign-polish/stars-forest-"+str(state.p.hero)+("-30" if "--30" in OS.get_cmdline_user_args() else "-60")+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(star_results))
