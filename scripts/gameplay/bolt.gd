extends CharacterBody2D

signal visual_event(kind: String)

var direction := 1
var lifetime := 2.4

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	lifetime -= delta
	var collision := move_and_collide(Vector2(direction*320*delta,0))
	if collision:
		var target := collision.get_collider()
		visual_event.emit("boss" if target.has_method("phase") else ("enemy" if target.has_method("defeat") else "wall"))
		if target.has_method("magic_hit"):
			target.magic_hit()
		elif target.has_method("defeat"):
			target.defeat()
	if not collision and lifetime<=0: visual_event.emit("fade")
	if collision or lifetime <= 0:
		queue_free()

func _draw() -> void:
	if has_meta("forest_skin"): return
	draw_line(Vector2(-7*direction,0),Vector2(6*direction,0),(Color("#8ee987") if Campaign.p.level.begins_with("2-") else Color("#7addff")),6)
	draw_circle(Vector2(5*direction,0),4,Color("#d4ffff"))
