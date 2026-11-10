extends "res://tests/s02_forest.gd"
var destination:="res://reports/evidence/p04-p05/"
var coverage:Array=[]
var resume_focus:=true
var level_ids:Array=["2-1","2-2","2-3"]

func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if resume_focus and is_instance_valid(game) and game.page=="pause": game.show_page("play"))
	run.call_deferred()

func redraw() -> void:
	if game.world.has_node("FactionDecor"): game.world.get_node("FactionDecor")._process(0)
	if game.world.has_node("ForestArt"): game.world.get_node("ForestArt").get_child(1)._process(0)
	if game.world.has_node("LocationArt"): game.world.get_node("LocationArt").redraw_backdrop()

func snap(id:String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+id+".png")

func run() -> void:
	destination+=("before/" if "--before" in OS.get_cmdline_user_args() else "after/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	for id in level_ids:
		await test_level(id)
		game.world.player.get_node("Camera").enabled=false
		root.canvas_transform=Transform2D.IDENTITY
		await snap("hud-"+id)
		game.get_node("Interface").hide()
		paused=true
		var segments:Array=[[id,0,int(game.world.finish_x+128)-960]]
		if game.world.cave_left>0: segments.append([id+"-mine",int(game.world.cave_left),int(game.world.cave_left+game.world.cave_width)-960])
		for segment in segments:
			var points:Array[int]=[]
			for x in range(segment[1],segment[2],450): points.append(x)
			if not points.has(segment[2]): points.append(segment[2])
			for x in points:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				redraw()
				var name:String=segment[0]+"-"+str(x)
				await snap(name)
				coverage.append({"id":name,"level":segment[0],"x":x})
		paused=false
		game.get_node("Interface").show()
	# Baseline UI uses real campaign callbacks and an isolated valid test profile.
	resume_focus=false
	for page in ["main","heroes","map","settings","pause","future","occupied"]:
		game.show_page(page)
		await snap("ui-"+page)
	game.cancel_page="pause"
	game.pending=game.start_level
	game.show_page("confirm","Вернуться к старту? Потраченные сердца и полученные награды сохранятся.")
	await snap("ui-confirm")
	var file:=FileAccess.open(destination+"coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(coverage,"  "))
	print("CAPTURED ",coverage.size()," world windows, 3 HUDs and 8 UI screens at ",destination)
	quit()
