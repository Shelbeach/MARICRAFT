extends "res://tests/s02_forest.gd"
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var rows:Array=[]
	for id in ["1-3","2-3","3-3"]:
		await test_level(id)
		var a=game.world.player;var b=game.world.boss
		b.set_physics_process(false)
		a.apply_form(2)
		for side in [-1,1]:
			var x:float=game.world.arena.left+40 if side==-1 else game.world.arena.right-40
			a.position=Vector2(x,480);a.velocity=Vector2.ZERO
			a.get_node("Camera").snap_to_player()
			await ticks(240)
			var camera:Camera2D=a.get_node("Camera")
			camera.force_update_scroll()
			var transform:=root.canvas_transform
			var player_screen:Vector2=transform*a.position
			var left_head:Vector2=transform*(b.home-Vector2(156,100))
			var right_head:Vector2=transform*(b.home+Vector2(156,-100))
			var okay:=player_screen.x>=32 and player_screen.x<=928 and left_head.x>=32*camera.zoom.x and right_head.x<=960-32*camera.zoom.x
			check(okay,"arena edge keeps large hero + attack origins visible "+id+" side="+str(side))
			rows.append({"level":id,"side":side,"zoom":camera.zoom.x,"player_x":player_screen.x,"left_origin_x":left_head.x,"right_origin_x":right_head.x,"passed":okay})
	FileAccess.open("res://reports/evidence/camera-repair/arena-edges.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	game.clear_world();await process_frame;await process_frame
	root.get_node("MusicManager").stop_all();root.get_node("SFX").new_world(false)
	quit(1 if failed else 0)
