extends "res://tests/s02_forest.gd"
var destination:="res://reports/evidence/visual-polish/"
var coverage:Array=[]

func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if is_instance_valid(game) and game.page=="pause": game.resume())
	run.call_deferred()

func capture(id:String) -> void:
	game.world.get_node("ForestArt").get_child(1)._process(0)
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
	for level in ["1-1","1-2","1-3"]:
		await test_level(level)
		var world=game.world
		world.player.get_node("Camera").enabled=false
		game.get_node("Interface").hide()
		paused=true
		var segments:Array=[[level,0,int(world.finish_x+128)-960]]
		if world.cave_left>0: segments.append(["grotto",int(world.cave_left),int(world.cave_left+world.cave_width)-960])
		for segment in segments:
			var points:Array[int]=[]
			for x in range(segment[1],segment[2],450): points.append(x)
			if not points.has(segment[2]): points.append(segment[2])
			for x in points:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				var id:String=segment[0]+"-"+str(x)
				await capture(id)
				coverage.append({"id":id,"level":segment[0],"x":x})
			if "--walk" in OS.get_cmdline_user_args():
				var folder:String="res://reports/temp/visual-polish/walk-"+segment[0]+"/"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
				for frame in ceili((segment[2]-segment[1])/10.0)+1:
					var x:float=minf(segment[2],segment[1]+frame*10)
					root.canvas_transform=Transform2D(0,Vector2(-x,0))
					world.get_node("ForestArt").get_child(1)._process(0)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg(folder+"%04d.jpg"%frame,0.94)
		if "--walk" in OS.get_cmdline_user_args():
			for dimensions in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1280,800)]:
				root.size=dimensions
				for i in 3: await process_frame
				root.canvas_transform=Transform2D(0,Vector2(-6400 if level=="1-2" else (-1838 if level=="1-3" else 0),0))
				await capture(level+"-window-"+str(dimensions.x)+"x"+str(dimensions.y))
			root.size=Vector2i(960,540)
		paused=false
	# Each telegraph is shown in the actual level, at an equal warning fraction.
	var boss=game.world.boss
	game.world.player.position=Vector2(2050,480)
	game.world.player.protection=999
	game.world.player.set_physics_process(false)
	root.canvas_transform=Transform2D(0,Vector2(-1838,0))
	for phase in 3:
		boss.position=boss.home
		boss.hp=9-phase*3
		boss.next_water=false
		boss.prepare(game.world.player)
		boss.get_node("Skin").previous_hp=boss.hp
		boss.get_node("Skin").previous_phase=boss.phase()
		boss.get_node("Skin").override_time=0
		if "--clips" in OS.get_cmdline_user_args():
			var folder:="res://reports/temp/visual-polish/boss-%d/"%phase
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			for frame in 140:
				await ticks(1)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(folder+"%04d.jpg"%frame,0.96)
				if frame==roundi(boss.move.warning*60*0.65):
					root.get_texture().get_image().save_png(destination+"boss-warning-%d.png"%phase)
		else:
			await ticks(roundi(boss.move.warning*60*0.65))
			paused=true
			await capture("boss-warning-%d"%phase)
			paused=false
		boss.clear_shots()
	var output:=FileAccess.open(destination+"coverage.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(coverage,"  "))
	print("CAPTURED ",coverage.size()," overlapping camera windows and 3 boss warnings at ",destination)
	quit()
