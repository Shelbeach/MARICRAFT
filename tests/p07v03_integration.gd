extends SceneTree
const OUT:="res://reports/evidence/p07v03-music/"
var state
var game
var music
var failures:Array=[]
var checks:=0
var events:Array=[]
var shots:=false
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frames(count:int) -> void:
	for i in count: await process_frame
func snap(name:String) -> void:
	if not shots:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"screens/"+name+".png")
func theme(id:String,label:String,settle:=90) -> void:
	await frames(settle)
	var s:Dictionary=music.snapshot()
	check(s.theme==id,label+" theme="+str(s.theme))
	check(s.voices.size()==1 and s.voices[0].playing,label+" one playing voice after fade")
	events.append({"label":label,"state":s})
func run() -> void:
	shots=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"screens"))
	state=root.get_node("Campaign")
	state.start_sandbox()
	state.cheats.shield=true
	music=root.get_node("MusicManager")
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	# UI focus loss may pause during automation; only unpause in gameplay fixtures.
	game.get_node("Interface/Feedback").hide()
	game.show_page("main")
	await theme("menu","main")
	var started:int=music.starts.menu
	for page in ["heroes","map","settings","main"]:
		game.show_page(page)
		await theme("menu",page,4)
	check(music.starts.menu==started,"menu navigation does not restart")
	await snap("menu")
	for id in state.ROUTE:
		state.debug_level(id)
		game.start_level()
		game.world.player.set_physics_process(false)
		if game.world.boss:game.world.boss.set_physics_process(false)
		await theme(music.region_theme(id),id+" before arena")
		if id.begins_with("3-"): await snap(id+"-entry")
		var start_count:Dictionary=music.starts.duplicate()
		game.show_page("pause")
		await frames(50)
		check(music.duck<0.65,id+" pause ducks")
		game.show_page("play")
		await frames(45)
		check(music.starts==start_count,id+" pause resumes same streams")
		var world=game.world
		if world.boss:
			world.player.position=Vector2(world.arena.left-10,480)
			await frames(8)
			check(not world.arena.active and music.current_theme==music.region_theme(id),id+" proximity does not start boss theme")
			world.player.position=Vector2(world.arena.left+110,480)
			await theme("ragnaros" if id=="3-3" else "bosses",id+" real arena activation")
			check(world.arena.active,id+" arena closed")
			if id=="3-3":await rig_check(world)
			world.player.recovering=1.0
			await theme(music.region_theme(id),id+" death/recovery opens entry")
			world.player.position=Vector2(world.arena.left-100,480)
			world.player.recovering=0.0
			await frames(5)
			world.player.position=Vector2(world.arena.left+110,480)
			await theme("ragnaros" if id=="3-3" else "bosses",id+" retry")
			world.boss.take_damage(100)
			if id=="3-3":
				await frames(40)
				check(music.current_theme=="ragnaros","final death holds musical moment")
				await snap("death-start")
				await frames(150)
				await snap("death-end")
			await theme(music.region_theme(id),id+" defeated exit")
		game.clear_world()
		await frames(2)
	game.show_page("victory")
	await theme("menu","final screen after victory hold")
	await snap("final")
	game.show_page("settings")
	await frames(5)
	var fx_db:=AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Эффекты"))
	state.store_options({"Музыка":25,"Эффекты":state.volume("Эффекты")},{"Музыка":false,"Эффекты":state.muted("Эффекты")})
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))-linear_to_db(.25))<.01,"existing music slider controls Music bus")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Эффекты"))==fx_db,"music volume does not change SFX")
	state.store_options({"Музыка":0,"Эффекты":state.volume("Эффекты")},{"Музыка":false,"Эффекты":state.muted("Эффекты")})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"zero volume mutes")
	await snap("settings")
	var report:={"checks":checks,"failures":failures,"events":events,"size":str(root.size),"engine":Engine.get_version_info(),"fps_limit":Engine.max_fps}
	FileAccess.open(OUT+"integration-"+str(root.size.x)+"-"+str(Engine.physics_ticks_per_second)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("P07V03_INTEGRATION ",checks," checks, failures=",failures)
	music.stop_all()
	OS.delay_msec(150)
	quit(0 if failures.is_empty() else 1)

func rig_check(world) -> void:
	var boss=world.boss
	var view=world.get_node("RagnarosPresentation")
	check(view.get_parent()==boss.get_parent(),"rig is physical controller sibling")
	check(boss.hp==12 and boss.has_meta("p07_rig"),"12 HP + prototype hidden")
	check(view.z_index+view.rig.get_node("Front").z_index<world.player.z_index,"hero above weapon")
	world.player.get_node("Camera").enabled=false
	root.canvas_transform=Transform2D(0,Vector2(-1660,0))
	world.player.position=Vector2(1850,480)
	boss.set_physics_process(false)
	for side in [-1,1]:
		boss.position=boss.home+Vector2(side*156,0)
		boss.mode=boss.Mode.OPEN;boss.clock=2.5;boss.hits=0
		await frames(3)
		check(view.global_position==boss.home,"body fixed at home "+str(side))
		check((view.global_position+view.rig.head_bottom).distance_to(boss.global_position)<.01,"OPEN head coincides with 64x64 collision "+str(side))
		var before:Vector2=view.rig.head_bottom
		boss.visual_event.emit("hit")
		await frames(8)
		check(view.rig.head_bottom==before,"hit reaction never moves open head")
		await snap("open-"+str(side))
	# Sample all provided body/hammer states inside the actual campaign world.
	# These are visual fixtures, separate from the continuous input-only fight.
	view.set_process(false)
	for clip in view.rig.Pose.CLIPS:
		for side in [-1,1]:
			view.rig.set_visual(clip,.62,Vector2(side*156,0 if clip in ["open","hit","guarded","death"] else -95),side,"open" if clip=="open" else "raised")
			await frames(2)
			var a:Dictionary=view.rig.attachment_points
			check(absf(a.head_socket.distance_to(a.handle_start)-124)<.01,"handle length "+clip+str(side))
			check(absf(a.front_wrist.distance_to(a.front_grip)-14)<.01,"wrist/grip "+clip+str(side))
			await snap("body-"+clip+"-"+str(side))
	for clip in view.rig.head_frames.get_animation_names():
		view.rig.set_visual("open",.5,Vector2(156,0),1,clip)
		await frames(2)
		await snap("hammer-"+clip)
	view.set_process(true)
	boss.set_physics_process(true)
	world.player.get_node("Camera").enabled=true
