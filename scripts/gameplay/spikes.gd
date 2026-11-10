extends Area2D
signal visual_event(kind:String)

func _physics_process(_delta: float) -> void:
	for actor in get_overlapping_bodies():
		if actor.is_in_group("forest_player"):
			var was:bool=actor.protection<=0 and actor.recovering<=0 and not Campaign.cheats.get("shield",false)
			actor.damage()
			if was: visual_event.emit("contact")

func _draw() -> void:
	if has_meta("forest_skin"): return
	for x in [-24,-8,8]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+8,-22),Vector2(x+16,0)]),Color("#ff9e87"))
