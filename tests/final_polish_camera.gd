extends "res://tests/s02_forest.gd"
var path:="res://reports/evidence/final-polish/camera/"
func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if is_instance_valid(game) and game.page=="pause": game.show_page("play"))
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for id in ["1-1","2-1","3-1"]:
		await test_level(id)
		var a=game.world.player
		a.position=Vector2(350,480)
		a.protection=0
		await ticks(3)
		a.set_physics_process(false)
		var cam=a.get_node("Camera")
		cam.set_physics_process(false)
		for z in [1.0,1.15,1.25,1.35]:
			cam.zoom=Vector2.ONE*z
			cam.global_position=Vector2(440,540-270/z)
			cam.reset_smoothing()
			await ticks(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(path+id+"-"+str(z)+".png")
	root.get_node("MusicManager").stop_all()
	quit()
