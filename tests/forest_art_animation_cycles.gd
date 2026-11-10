extends SceneTree
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func run() -> void:
	root.get_node("Campaign").start_sandbox()
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	var bench=load("res://scripts/debug/animation_bench.gd").new()
	layer.add_child(bench)
	var directory:="res://reports/temp/forest-art/animation-cycles/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var index:=0
	var chapters:Array=[]
	for actor in bench.models.size():
		bench.select_model(actor)
		var id:String=bench.models[actor]
		for clip in (["run"] if actor<6 else (["patrol"] if id=="murloc" else ["dash","leap"])):
			var sf:SpriteFrames=bench.corrected.sprite.sprite_frames
			var count:=ceili(sf.get_frame_count(clip)/sf.get_animation_speed(clip)*60)+2
			chapters.append({"actor":id,"clip":clip,"seconds":index/30.0})
			for direction in [1,-1]:
				bench.select_clip(bench.clips.find(clip))
				bench.speed=0.5
				bench.zoom=2
				bench.direction=direction
				for frame in count:
					for tick in 2: await physics_frame
					await RenderingServer.frame_post_draw
					var im:=root.get_texture().get_image()
					im.save_jpg(directory+"%05d.jpg"%index,0.98)
					if direction==1 and frame==10:
						im.save_png("res://reports/evidence/forest-art/cycle-"+id+"-"+clip+".png")
					index+=1
	var file:=FileAccess.open("res://reports/evidence/forest-art/animation-chapters.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":30,"frames":index,"chapters":chapters},"  "))
	print("ANIMATION CYCLES frames=",index," chapters=",chapters)
	quit()

