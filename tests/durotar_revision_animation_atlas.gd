extends SceneTree
const Forest:=preload("res://scripts/visual/art_sprite.gd")
const Local:=preload("res://scripts/visual/location_sprite.gd")
const Art:=preload("res://scripts/visual/art_library.gd")
const Library:=preload("res://scripts/visual/location_art_library.gd")
const OUT:="res://reports/evidence/durotar-revision/animations/"
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Art.initialize()
	var lib:=Library.new()
	var models:Array=Art.actors.keys()+lib.actors.keys()
	var index:Array=[]
	for model in models:
		var data:Dictionary=lib.actors.get(model,Art.actors.get(model,{}))
		var clips:Array=data.clips.keys()
		for start in range(0,clips.size(),5):
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(1920,960)
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var bg:=ColorRect.new()
			bg.color=Color("#26323c")
			bg.size=viewport.size
			viewport.add_child(bg)
			for row in mini(5,clips.size()-start):
				var clip:String=clips[start+row]
				for frame in data.clips[clip].count:
					var origin:=Vector2(frame*240+120,row*192+172)
					var line:=Line2D.new()
					line.points=PackedVector2Array([origin-Vector2(118,0),origin+Vector2(118,0)])
					line.width=1
					line.default_color=Color("#dd927a")
					viewport.add_child(line)
					var item=Local.new() if lib.actors.has(model) else Forest.new()
					if lib.actors.has(model): item.library=lib
					viewport.add_child(item)
					item.set_actor(model)
					item.play(clip)
					item.sprite.pause()
					item.sprite.frame=frame
					item.position=origin
					item.scale=Vector2.ONE*(3.0 if model.ends_with("small") or model=="kobold" else 1.4)
					var label:=Label.new()
					label.text="%s · %s [%d]"%[model,clip,frame]
					label.position=Vector2(frame*240+8,row*192+5)
					label.add_theme_font_size_override("font_size",15)
					viewport.add_child(label)
			await process_frame
			await RenderingServer.frame_post_draw
			var name:String="%s-%d.png"%[model,start/5]
			viewport.get_texture().get_image().save_png(OUT+name)
			index.append({"file":name,"model":model,"clips":clips.slice(start,start+5)})
			viewport.queue_free()
			await process_frame
	FileAccess.open(OUT+"index.json",FileAccess.WRITE).store_string(JSON.stringify(index,"  "))
	print("ALL TEN MODELS / ALL SOURCE CLIPS / ALL FRAMES RENDERED ",index.size()," sheets")
	quit()
