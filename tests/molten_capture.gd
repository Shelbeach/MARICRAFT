extends "res://tests/p04_p05_capture.gd"

func redraw() -> void:
	if game.world.has_node("LocationArt"):
		game.world.get_node("LocationArt").queue_redraw()
		game.world.get_node("LocationArt").get_child(1)._process(0)

func run() -> void:
	destination="res://reports/evidence/molten/windows/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	for id in ["3-1","3-2","3-3"]:
		await test_level(id)
		game.world.player.get_node("Camera").enabled=false
		root.canvas_transform=Transform2D.IDENTITY
		await snap("hud-"+id)
		game.get_node("Interface").hide()
		paused=true
		var segments:Array=[[id,0,int(game.world.finish_x+128)-960]]
		if game.world.cave_left>0: segments.append([id+"-room",int(game.world.cave_left),int(game.world.cave_left+game.world.cave_width)-960])
		for segment in segments:
			var points:Array[int]=[]
			for x in range(segment[1],segment[2],600): points.append(x)
			points.append(segment[2])
			for x in points:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				redraw()
				var name:String=segment[0]+"-"+str(x)
				await snap(name)
				coverage.append({"id":name,"level":segment[0],"x":x})
		paused=false
		game.get_node("Interface").show()
	var file:=FileAccess.open(destination+"coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(coverage,"  "))
	game.clear_world()
	await process_frame
	await process_frame
	print("MOLTEN CAPTURE ",coverage.size()," windows")
	quit()
