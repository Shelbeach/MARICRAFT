extends SceneTree
func _initialize() -> void:
	var merged:SpriteFrames=load("res://assets/location2_art/effects/effects.tres").duplicate(true)
	var incoming:SpriteFrames=load("res://assets/faction_art/effects/mine_effects.tres")
	for clip in incoming.get_animation_names():
		if merged.has_animation(clip): merged.remove_animation(clip)
		merged.add_animation(clip)
		merged.set_animation_loop(clip,incoming.get_animation_loop(clip))
		merged.set_animation_speed(clip,incoming.get_animation_speed(clip))
		for i in incoming.get_frame_count(clip): merged.add_frame(clip,incoming.get_frame_texture(clip,i),incoming.get_frame_duration(clip,i))
	var result:=ResourceSaver.save(merged,"res://assets/faction_art/effects/effects.tres")
	print("Merged P06 mine effects, retained total clips: ",merged.get_animation_names().size()," status=",result)
	quit(result)
