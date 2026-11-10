extends "res://tests/s04_mechanics.gd"
var record_frame:=0
var capture_step:=0
var visual_states:Dictionary={}

func _initialize() -> void:
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/p04-p05/kobold-motion"))
	run.call_deferred()

func ticks(count:int) -> void:
	for i in count:
		await physics_frame
		if is_instance_valid(game) and game.page=="pause": game.show_page("play")
		capture_step+=1
		if capture_step%2!=0 or not is_instance_valid(game): continue
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		image.save_png("res://reports/temp/p04-p05/kobold-motion/%05d.png"%record_frame)
		record_frame+=1
		for n in game.world.get_children():
			if not n.has_node("Skin") or n.get("wake_in")==null: continue
			var tag:String="kobold-"+n.get_node("Skin").art.last_clip
			if not visual_states.has(tag):
				visual_states[tag]=true
				image.save_png("res://reports/evidence/p04-p05/after/"+tag+".png")

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	await hats()
	print("KOBOLD MOTION frames=",record_frame," clips=",visual_states)
	quit(1 if failed else 0)
