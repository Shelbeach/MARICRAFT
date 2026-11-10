extends SceneTree
var bench
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Campaign").start_sandbox()
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	bench=load("res://scripts/debug/animation_bench.gd").new()
	layer.add_child(bench)
	var index:=0
	var directory:="res://reports/temp/forest-art/bench/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for actor in range(bench.models.size()):
		bench.select_model(actor)
		var selected:Array=["idle","run","jump","fall","land","cast","hurt","death"] if actor<6 else (["patrol","turn","pipe_emerge","stomp_defeat","magic_defeat"] if bench.models[actor]=="murloc" else ["idle","water_warning","water_release","dash_warning","dash","leap_warning","leap","slam","open","hit","deflect","phase","death"])
		for clip in selected:
			if not bench.clips.has(clip): continue
			bench.select_clip(bench.clips.find(clip))
			bench.speed=0.5
			bench.zoom=2
			for frame in 30:
				if frame==15: bench.direction=-1
				for tick in 2: await physics_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory+"%05d.png"%index)
				index+=1
			bench.direction=1
		bench.select_clip(maxi(0,bench.clips.find("run")))
		bench.zoom=1
		for tick in 2: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/evidence/forest-art/bench-"+str(bench.models[actor])+".png")
	print("BENCH frames=",index," models=",bench.models)
	quit()

