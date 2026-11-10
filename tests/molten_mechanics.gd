extends "res://tests/s02_forest.gd"

func fresh(id:String) -> void:
	state.store.first_level=id
	state.new_game("human")
	game.start_level()
	await ticks(8)

func check_death(caption:String,at:Vector2,fall:=false) -> void:
	var a=game.world.player
	a.apply_form(0)
	a.protection=0
	a.position=at
	a.velocity=Vector2.ZERO
	var before:int=state.p.hearts
	if fall: a.damage(true)
	await ticks(5)
	check(state.p.hearts==before-1 and a.recovering>0,caption+" loses exactly one heart")
	# Repeated contacts during the same death cannot debit again.
	a.damage(true)
	check(state.p.hearts==before-1,caption+" duplicate contact rejected")
	await ticks(75)
	check(a.position.distance_to(Vector2(game.world.checkpoint_x,480))<8 and a.protection>0,caption+" safe checkpoint respawn")

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/molten/mechanics-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for id in ["3-1","3-2","3-3"]:
		await fresh(id)
		game.world.player.position=Vector2(game.world.checkpoint_x,475)
		await ticks(10)
		check(game.world.checkpoint and state.p.hearts==3,"checkpoint activates without healing "+id)
		state.reward(id+"/fixture_coin",1,10)
		var bank:int=state.p.wallet
		await check_death(id+" pit",Vector2(500,620),true)
		check(state.claimed(id+"/fixture_coin") and state.p.wallet>=bank and not state.reward(id+"/fixture_coin",1,10),"death keeps claimed ID and bank "+id)
	await fresh("3-2")
	game.world.player.position=Vector2(2290,475)
	await ticks(8)
	await check_death("spikes",Vector2(4180,479))
	await check_death("lava",Vector2(800,520))
	await fresh("3-1")
	game.world.player.position=Vector2(game.world.checkpoint_x,475)
	await ticks(8)
	var enemy=game.world.get_node("BasaltGuard")
	await check_death("ordinary enemy",enemy.position-Vector2(12,0))
	await fresh("3-2")
	game.world.player.position=Vector2(2290,475)
	await ticks(8)
	game.world.warp(Vector2(6680,475))
	check(game.world.underground,"room camera enters")
	game.world.warp(Vector2(2680,475))
	await check_death("after returning from room",Vector2(2680,475),true)
	check(not game.world.underground,"death returns camera to main route")
	await fresh("3-1")
	var a=game.world.player
	var vent=game.world.get_node("FirstVent")
	a.position=Vector2(650,480)
	a.set_physics_process(false)
	vent.age=0
	await ticks(30)
	check(state.p.hearts==3 and vent.warning_now and not vent.active,"vent warning is harmless")
	var age:float=vent.age
	paused=true
	await ticks(30)
	check(is_equal_approx(vent.age,age),"pause freezes hazard warning")
	paused=false
	await ticks(38)
	check(vent.active and state.p.hearts==2,"vent starts damage with visible active phase")
	await ticks(15)
	check(state.p.hearts==2,"one activation cannot double debit dying hero")
	a.set_physics_process(true)
	await fresh("3-3")
	a=game.world.player
	a.position=Vector2(1442,480)
	await ticks(100)
	check(game.world.boss.mode==game.world.boss.Mode.WATCH and not game.world.boss.engaged and get_nodes_in_group("molten_attacks").is_empty(),"boss waits until his silhouette is in view")
	var b=game.world.boss
	a=game.world.player
	a.position=Vector2(1180,475)
	await ticks(10)
	b.hp=6
	a.position=Vector2(1860,480)
	b.step=1
	b.prepare(a)
	await ticks(4)
	check(b.attack==b.Attack.ERUPTION and get_nodes_in_group("molten_attacks").size()==1,"phase two locks one visible eruption")
	var strike=get_nodes_in_group("molten_attacks")[0]
	var before_clock:float=b.clock
	var before_age:float=strike.age
	paused=true
	await ticks(20)
	check(is_equal_approx(b.clock,before_clock) and is_equal_approx(strike.age,before_age),"boss and warning pause together")
	paused=false
	await ticks(65)
	check(state.p.hearts==2 and b.hp==6,"boss eruption costs one heart and keeps boss HP")
	await ticks(80)
	check(a.position.distance_to(Vector2(1180,480))<8 and b.hp==6 and get_nodes_in_group("molten_attacks").is_empty(),"respawn clears attacks, retains HP, no duplicate boss")
	b.hp=3
	a.position=Vector2(1860,480)
	b.step=0
	b.prepare(a)
	await ticks(3)
	check(b.marks.size()==2 and absf(b.marks[0]-b.marks[1])>=150,"final phase has two separate readable vents")
	b.take_damage(3)
	var points:int=state.p.score
	b.take_damage(3)
	await ticks(125)
	check(b.hp==0 and state.p.score==points and state.claimed("3-3/ragnaros"),"boss death rewards once")
	check(get_nodes_in_group("molten_attacks").is_empty() and b.death_age==2.0,"death ends animation at its ground anchor; no surviving attacks")
	check(game.world.get_node("Gate/Hitbox").disabled,"boss death opens physical gate")
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("MOLTEN MECHANICS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
