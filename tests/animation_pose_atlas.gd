extends SceneTree
const Art:=preload("res://scripts/visual/art_library.gd")
const Sprite:=preload("res://scripts/visual/art_sprite.gd")
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func run() -> void:
	Art.initialize()
	for model in Art.actors:
		var clips:Array=Art.actors[model].clips.keys()
		for start in range(0,clips.size(),5):
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(1984,1050)
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var background:=ColorRect.new()
			background.color=Color("#19272e")
			background.size=viewport.size
			viewport.add_child(background)
			for row in mini(5,clips.size()-start):
				var clip:String=clips[start+row]
				for frame in Art.actors[model].clips[clip].count:
					var origin:=Vector2(frame*248+124,row*210+185)
					var line:=Line2D.new()
					line.add_point(origin+Vector2(-120,0))
					line.add_point(origin+Vector2(120,0))
					line.default_color=Color("#64858b")
					line.width=1
					viewport.add_child(line)
					var item:=Sprite.new()
					viewport.add_child(item)
					item.set_actor(model)
					item.play(clip)
					item.sprite.pause()
					item.sprite.frame=frame
					item.position=origin
					item.scale=Vector2.ONE*(4 if model.ends_with("small") else 2)
					var label:=Label.new()
					label.position=Vector2(frame*248+8,row*210+5)
					label.text="%s [%d]"%[clip,frame]
					viewport.add_child(label)
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://reports/evidence/animation-fix/corrected-%s-%d.png"%[model,start/5])
			viewport.queue_free()
			await process_frame
	print("POSE ATLAS all 8 models / all clips / all frames rendered")
	quit()
