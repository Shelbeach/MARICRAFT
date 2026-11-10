extends "res://tests/s02_forest.gd"
func run() -> void:
	root.unfocusable=true
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for level in ["1-1","1-2","1-3"]:
		await test_level(level)
		var world=game.world
		world.player.get_node("Camera").enabled=false
		paused=true
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(int(world.finish_x+128),540)
		viewport.world_2d=World2D.new()
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		game.remove_child(world)
		viewport.add_child(world)
		for frame in 3: await process_frame
		world.get_node("ForestArt").get_child(1)._process(0)
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png("res://reports/evidence/forest-art/strip-"+level+".png")==OK,"single viewport panorama "+level+" "+str(viewport.size))
		if world.cave_left>0:
			viewport.size=Vector2i(world.cave_width,540)
			viewport.canvas_transform=Transform2D(0,Vector2(-world.cave_left,0))
			world.get_node("ForestArt").get_child(1)._process(0)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png("res://reports/evidence/forest-art/strip-mine.png")==OK,"single viewport panorama grotto")
		viewport.remove_child(world)
		game.add_child(world)
		viewport.queue_free()
		paused=false
	quit(1 if failed else 0)

