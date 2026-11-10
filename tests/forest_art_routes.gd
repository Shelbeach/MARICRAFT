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
	var dir:="res://reports/temp/forest-art/"+take+"/"
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
	var dir:="res://reports/temp/forest-art/"
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
