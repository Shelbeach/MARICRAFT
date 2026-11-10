extends "res://tests/final_polish_mechanics.gd"
var rows:Array=[]

func menu_checks() -> void:
	game.clear_world()
	state.p={}
	game.show_page("main")
	check(game.screen.get_node("LevelSelect").disabled,"level selection visible and locked without profile")
	game.pages.choose_levels()
	check(game.page=="main","locked callback cannot enter selection")
	state.store.first_level="1-1"
	state.new_game("human")
	game.main_menu()
	check(game.screen.get_node("LevelSelect").disabled,"level selection locked before victory")
	check(not state.start_replay("3-3"),"state layer rejects early replay")
	for id in state.ROUTE:
		check(state.p.level==id,"normal campaign order "+id)
		state.finish(10)
		if id!="3-3": state.leave_result()
	state.p=state.store.read_profile()
	check(state.store.valid(state.p) and state.p.completed,"victory unlock persists in real save")
	game.main_menu()
	check(not game.screen.get_node("LevelSelect").disabled,"level selection enabled after reload")
	game.pages.choose_levels()
	check(game.page=="map","new button opens existing nine-level map")
	var bank:int=state.p.wallet
	game.map_selected="2-2"
	game.pages.launch_selected()
	check(game.page=="play" and state.p.level=="2-2" and state.p.hearts==3 and state.p.wallet==bank,"selection starts ordinary replay and preserves bank")
	game.main_menu()
	state.new_game("human")
	game.main_menu()
	check(game.screen.get_node("LevelSelect").disabled,"new campaign locks selection again")

func rune_checks() -> void:
	for hero in ["human","ogre"]:
		for form in [0,1]:
			state.store.first_level="3-3"
			state.new_game(hero)
			game.start_level()
			await ticks(6)
			var w=game.world;var a=w.player
			w.boss.set_physics_process(false)
			a.position=Vector2(1810,480);a.velocity=Vector2.ZERO
			a.apply_form(form)
			await ticks(6)
			check(w.arena.active and a.is_on_floor() and not state.claimed("3-3/LastRune"),"rune optional while standing inside locked arena %s/%d"%[hero,form])
			var score:int=state.p.score
			await move_key(KEY_SPACE,12)
			await ticks(45)
			check(a.form==2 and state.claimed("3-3/LastRune") and state.p.hearts==3,"short floor jump collects rune %s/%d"%[hero,form])
			check(state.p.score==score+1000 and not state.reward("3-3/LastRune",0,1000),"rune award remains unique")

func projectile_checks() -> void:
	await fresh("3-3")
	var w=game.world
	w.boss.set_physics_process(false)
	w.player.protection=999
	for direction in [-1,1]:
		w.boss.projectile(Vector2(2250,472),Vector2(direction,0),true)
		await ticks(2)
		var shot=get_nodes_in_group("molten_attacks").filter(func(n):return n.get("wave")==true).back()
		shot.set_physics_process(false)
		await process_frame
		check(shot.get_node("Hitbox").shape.size==Vector2(12,12),"wave damage area unchanged "+str(direction))
		check(shot.get_node("Skin").art.scale==Vector2(.48,.48),"wave art enlarged threefold "+str(direction))
		check(shot.get_node("Skin").art.mirror.scale.x==direction,"wave faces its travel direction")
		shot.queue_free()
		await ticks(2)
	var imp=load("res://scenes/objects/imp_projectile.tscn").instantiate()
	w.add_child(imp)
	check(imp.get_node("Hitbox").shape.size==Vector2(12,12) and not imp.is_in_group("molten_attacks"),"imp projectile keeps independent collision and lifetime")
	imp.queue_free()

func imp_checks() -> void:
	for id in ["3-1","3-2","3-3"]:
		await fresh(id)
		var w=game.world;var a=w.player
		if w.boss: w.boss.set_physics_process(false)
		a.protection=999
		if id=="3-2":
			a.position=Vector2(3810,480)
			await ticks(90)
			check(w.get_node("DangerVent").triggered,"danger pipe spawns its actual enemy")
		var imps=w.get_children().filter(func(n):return n.get_script()==load("res://scripts/gameplay/murloc.gd"))
		check(imps.size()==({"3-1":2,"3-2":3,"3-3":1}[id]),"all fire imps enumerated "+id)
		for imp in imps:
			check(imp.ranged and imp.attack_controller!=null,"ranged enabled: "+imp.reward_id)
			if not imp.ranged: continue
			var attack=imp.attack_controller
			a.set_physics_process(false)
			attack.mode=attack.Mode.PATROL
			attack.clock=0
			var started:=0;var cancelled:=0
			var fired_before:int=attack.shots_fired
			for trial in 20:
				attack.cooldown=0
				# The spawned guard patrols beside a 40px higher bank. Do not put
				# the synthetic target inside that bank or inside the pipe.
				var offset:=120.0
				var side:=-1
				var acquired:=false
				for wait_frame in 180:
					if imp.reward_id=="3-2/DangerGuard":
						offset=90
						side=1 if imp.position.x<3800 else -1
					a.position=imp.position+Vector2(side*offset,0)
					a.get_node("Camera").snap_to_player()
					await ticks(1)
					if attack.mode==attack.Mode.WINDUP: acquired=true;break
				if not acquired:
					check(false,"visible target acquired: "+imp.reward_id)
					continue
				started+=1
				var previous:int=attack.mode
				for frame in 70:
					a.position=imp.position+Vector2(side*offset,-140 if frame>6 and frame<34 else 0)
					a.velocity=Vector2.ZERO
					a.get_node("Camera").snap_to_player()
					await ticks(1)
					if previous==attack.Mode.WINDUP and attack.mode==attack.Mode.PATROL: cancelled+=1
					previous=attack.mode
			var fired:int=attack.shots_fired-fired_before
			rows.append({"id":imp.reward_id,"started":started,"fired":fired,"cancelled":cancelled})
			check(fired==20 and started==20 and cancelled==0,"20 complete shots despite target jump: "+imp.reward_id)
			a.set_physics_process(true)
			imp.set_physics_process(false)

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/arena-polish/profile-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	await menu_checks()
	await rune_checks()
	await projectile_checks()
	await imp_checks()
	var tag:="30" if "--30" in OS.get_cmdline_user_args() else "60"
	FileAccess.open("res://reports/evidence/arena-polish/imps-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("MusicManager").stop_all()
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("ARENA POLISH CHECKS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
