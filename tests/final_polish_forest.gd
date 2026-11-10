extends "res://tests/s02_form_reachability.gd"
var trace_events:Array=[]
var trace_down:Dictionary={}
var trace_origin:=0
var trace_level:=""
var movie_frames:Dictionary={}
var last_art_frame:=-100
var art_take:=""
var art_movie:=false
var pending_take:=""

func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(resume_test_focus)
	super._initialize()
	RenderingServer.frame_post_draw.connect(save_recorded_frame)

func resume_test_focus() -> void:
	# Desktop focus changes pause the real game. Resume this isolated test only,
	# before its input driver runs, never from a rendering-server callback.
	if is_instance_valid(game) and game.page=="pause":
		game.show_page("play")
		print("HARNESS resumed desktop focus pause")
	if not trace_level.is_empty():
		for code in trace_down:
			if trace_down[code] and not Input.is_physical_key_pressed(code): super.press(code,true)

func save_recorded_frame() -> void:
	if pending_take.is_empty(): return
	var take:=pending_take
	pending_take=""
	var dir:="res://reports/evidence/final-polish/forest/"+("30/" if "--30" in OS.get_cmdline_user_args() else "60/")
	dir+=take+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index:int=movie_frames.get(take,0)
	root.get_texture().get_image().save_png(dir+"%05d.png"%index)
	movie_frames[take]=index+1

func press(code:Key,on:bool) -> void:
	if trace_level!="" and trace_down.get(code,false)!=on:
		trace_down[code]=on
		trace_events.append([Engine.get_physics_frames()-trace_origin,code,on])
	super.press(code,on)

func route(level:String,capture:=true) -> void:
	if damage_run:
		await super.route(level,capture)
		return
	trace_level=level
	trace_origin=Engine.get_physics_frames()
	trace_events.clear()
	trace_down.clear()
	art_movie="--art-movie" in OS.get_cmdline_user_args()
	await super.route(level,capture)
	var dir:="res://reports/evidence/final-polish/forest/"+("30/" if "--30" in OS.get_cmdline_user_args() else "60/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if "--web-traces" in OS.get_cmdline_user_args():
		dir+="web-traces/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file:=FileAccess.open(dir+level+"-"+str(target_form)+"-"+str(state.p.hero)+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"events":trace_events,"ticks":Engine.get_physics_frames()-trace_origin,"form":target_form,"hero":state.p.hero,"result":game.page}))
	trace_level=""
	art_take=""
	file=FileAccess.open(dir+"clips-"+str(state.p.hero)+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(movie_frames))

func frame_capture() -> void:
	if not is_instance_valid(game.world): return
	var a=game.world.player
	if not a.has_node("Skin"): return
	if art_movie and Engine.get_physics_frames()-last_art_frame>=4 and trace_level!="":
		last_art_frame=Engine.get_physics_frames()
		var include:bool=(target_form==0 and a.position.x<600) or (target_form==1 and trace_level=="1-1" and a.position.x>2440 and a.position.x<2830) or (target_form==2 and trace_level=="1-1" and a.position.x<1100) or (target_form==0 and trace_level=="1-2" and (game.world.underground or (a.position.x>1320 and a.position.x<1920))) or (target_form==2 and trace_level=="1-3" and a.position.x>1650)
		if not include: return
		art_take=("boss" if trace_level=="1-3" else "hero")+"-"+str(state.p.hero)
		pending_take=art_take

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp"))
	var args := OS.get_cmdline_user_args()
	before = "--before" in args
	film = "--film" in args
	if film:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/s02fix/clip"))
	var hero := "ogre" if "--ogre" in args else "human"
	state = root.get_node("Campaign")
	state.store.prefix = ProjectSettings.globalize_path("res://reports/temp/final-polish/form-test-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	state.p = {}
	var only:=""
	for arg in args:
		if arg.begins_with("--level="): only=arg.trim_prefix("--level="); state.store.first_level=only
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for form in [0,1,2]:
		if "--small" in args and form!=0 or "--big" in args and form!=1 or "--magic" in args and form!=2: continue
		target_form=form
		game.pages.request_new()
		if game.page=="confirm":
			game.pending.call()
		game.pages.select_hero(hero)
		game.pages.start_campaign()
		if form==2:
			state.start_sandbox()
		game.start_level()
		for level: String in ([only] if not only.is_empty() else ["1-1","1-2","1-3"]):
			await ticks(5)
			var actor=game.world.player
			in_cave_done=false
			struck.clear()
			drank=false
			opened=false
			boundary_shot=false
			still_frames=0
			high_x=actor.position.x
			wanted=form
			if form==1 and level=="1-1":
				wanted=0
			else:
				# Only the starting form is prepared. The rest is keyboard input.
				check(actor.apply_form(form),"starting shape "+level+" "+str(form))
			if not before:
				audit_passages(level,actor)
			await route(level,false)
			if game.page!="result":
				if film: await snapshot("before" if before else "failure")
				break
			check(actor.form==form and (level!="1-1" or form!=1 or drank),"FINISH "+hero+" "+level+" form="+str(form))
			if form==2 and level=="1-3":
				check(rune_seen,"arena rune collected during magic route")
			game.next_map()
			game.start_level()
		if before or failed: break
		game.main_menu()
	if not before and not failed:
		await ticks(2) # Adverse recovery has its own dedicated scenario.
		await tight_growth()
	if film and not before:
		print("VIDEO FRAMES ",sample_count)
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	root.get_node("MusicManager").stop_all()
	OS.delay_msec(120)
	quit(1 if failed else 0)

