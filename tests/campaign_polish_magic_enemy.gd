extends "res://tests/campaign_polish_mechanics.gd"
## Rapid input at instant-removal ordinary targets, not invulnerable boss fixtures.
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	root.get_node("SFX").played.connect(func(id,_details):
		if id=="magic_cast": sound_ticks.append(Engine.get_physics_frames()))
	for kind in ["murloc","kobold"]:
		await fresh("1-1" if kind=="murloc" else "2-1")
		var a=game.world.player
		a.apply_form(2)
		a.facing=1
		a.visual_event.connect(func(event):
			if event=="shoot": cast_ticks.append(Engine.get_physics_frames()))
		cast_ticks.clear();sound_ticks.clear()
		var enemy
		var spawned:=0
		var prior:int=state.p.enemies
		for i in 240:
			if not is_instance_valid(enemy):
				enemy=load("res://scenes/enemies/"+kind+".tscn").instantiate()
				enemy.position=a.position+Vector2(40,0)
				enemy.reward_id=state.p.level+"/magic_fixture_"+str(spawned)
				game.world.add_child(enemy)
				enemy.set_physics_process(false)
				spawned+=1
			press(KEY_E,i%2==0)
			await ticks(1)
		press(KEY_E,false)
		check(cast_ticks.size()==7 and sound_ticks.size()==7,"ordinary "+kind+" accepts seven casts and sounds in four seconds")
		for i in range(1,cast_ticks.size()): check(cast_ticks[i]-cast_ticks[i-1]>=36,"instant enemy removal cannot bypass cooldown")
		check(state.p.enemies-prior==7 and state.p.hearts==3 and a.form==2,"seven ordinary hits give exactly seven rewards, no extra damage "+kind)
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("ORDINARY MAGIC ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
