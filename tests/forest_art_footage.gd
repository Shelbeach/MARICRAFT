extends "res://tests/forest_art_routes.gd"
var take:=""
var ferry_section:=false
func frame_capture() -> void:
	if take.is_empty() or not is_instance_valid(game.world): return
	if Engine.get_physics_frames()-last_art_frame<4: return
	last_art_frame=Engine.get_physics_frames()
	if ferry_section:
		var a=game.world.player
		if not (game.world.underground or a.position.x<500 or (a.position.x>1320 and a.position.x<1920)): return
	pending_take=take

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/forest-art/film-profile-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		state.new_game(hero)
		game.start_level()
		await ticks(5)
		trace_level="fixture"
		take="review-hero-"+hero
		press(KEY_D,true)
		await ticks(90)
		press(KEY_SPACE,true)
		await ticks(34)
		press(KEY_SPACE,false)
		await ticks(45)
		press(KEY_D,false)
		press(KEY_A,true)
		await ticks(45)
		press(KEY_A,false)
		await ticks(20)
		# Start the next recorded episode at the existing growth chest.
		# The item is released and collected by ordinary input, not granted.
		await place_player(2608)
		press(KEY_SPACE,true)
		await ticks(32)
		press(KEY_SPACE,false)
		await ticks(34)
		press(KEY_D,true)
		await ticks(42)
		press(KEY_D,false)
		await ticks(18)
		check(game.world.player.form==1,"recorded real growth "+hero)
		# The river episode is a full keyboard traversal from its real start.
		state.new_game(hero)
		state.p.level="1-2"
		game.start_level()
		await ticks(5)
		target_form=0
		wanted=0
		in_cave_done=false
		opened=false
		drank=false
		struck.clear()
		still_frames=0
		high_x=0
		ferry_section=true
		await route("1-2",false)
		ferry_section=false
		check(game.page=="result","recorded ferry and grotto "+hero)
		game.next_map()
		game.start_level()
		await ticks(5)
		trace_level="fixture"
		await place_player(1688)
		press(KEY_SPACE,true)
		await ticks(32)
		press(KEY_SPACE,false)
		await ticks(34)
		check(game.world.player.form==2,"recorded real rune "+hero)
		press(KEY_D,true)
		var held:=0
		for frame in 300:
			await ticks(1)
			var entering=game.world.player
			if entering.position.x>=1804: break
			if held>0:
				held-=1
				if held==0: press(KEY_SPACE,false)
			elif entering.is_on_floor() and entering.is_on_wall():
				press(KEY_SPACE,true)
				held=40
		press(KEY_D,false)
		press(KEY_SPACE,false)
		check(game.world.player.position.x>=1804,"recorded stepped arena entry "+hero)
		take="review-boss-"+hero
		var a=game.world.player
		var boss=game.world.boss
		var pilot:=preload("res://tests/boss_pilot.gd").new()
		for frame in 4200:
			await ticks(1)
			if boss.hp==0: break
			pilot.tick(self,a,boss,true)
		pilot.release(self)
		check(boss.hp==0 and a.form==2,"recorded three-phase magic victory "+hero)
		press(KEY_D,true)
		for frame in 500:
			await ticks(1)
			if game.page=="result": break
		press(KEY_D,false)
		await ticks(30)
		check(game.page=="result","recorded gate and result "+hero)
		take=""
		pending_take=""
		trace_level=""
		game.main_menu()
	var file:=FileAccess.open("res://reports/evidence/forest-art/review-clips.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(movie_frames,"  "))
	print("REVIEW CLIPS ",movie_frames)
	quit(1 if failed else 0)
