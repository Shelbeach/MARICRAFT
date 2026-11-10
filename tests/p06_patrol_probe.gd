extends "res://tests/p04_p05_capture.gd"

var records:Array=[]
var stage:="before"

func run() -> void:
	print("PROBE starting")
	stage="after" if "--after" in OS.get_cmdline_user_args() else "before"
	destination="res://reports/evidence/p06/"+stage+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	print("PROBE scene ready")
	for id in ["2-1","2-2","2-3"]:
		await test_level(id)
		print("PROBE level ",id)
		game.world.player.get_node("Camera").enabled=false
		game.world.player.set_physics_process(false)
		game.world.player.position=Vector2(-1000,-1000)
		game.get_node("Interface").hide()
		var patrols:Array=[]
		for node in game.world.get_children():
			if node.get_script() and node.get_script().resource_path.ends_with("/kobold.gd"):
				patrols.append(node)
		for frame in 720:
			await physics_frame
			for node in patrols:
				records.append({"level":id,"name":str(node.name),"tick":frame,"x":node.position.x,"y":node.position.y,"dir":node.direction,"vx":node.velocity.x,"face":node.get_node("Skin").art.scale.x,"turn":node.patrol_turn})
			if id=="2-3":
				root.canvas_transform=Transform2D(0,Vector2(-570 if frame<360 else -1530,0))
				redraw()
				if frame%6==0 and "--frames" in OS.get_cmdline_user_args(): await snap("patrol-%04d"%(frame/6))
		if id=="2-2":
			for x in [3040,7350]:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				redraw()
				await snap("spikes-"+str(x))
	var file:=FileAccess.open(destination+"patrol-"+("30" if "--fps30" in OS.get_cmdline_user_args() else "60")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	print("PATROL_PROBE ",stage," ",records.size()," samples")
	quit()
