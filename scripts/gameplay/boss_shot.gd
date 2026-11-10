extends CharacterBody2D

signal visual_event(kind: String)

var direction := Vector2.LEFT
var wave := false
var lifetime := 4.0
var speed_override := 0.0

func _ready() -> void:
	if not wave:
		$Hitbox.shape=$Hitbox.shape.duplicate()
		$Hitbox.shape.size=Vector2(18,18)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	lifetime -= delta
	var speed:=speed_override if speed_override>0 else (230.0 if wave else 216.0)
	var hit := move_and_collide(direction*speed*delta)
	if hit and hit.get_collider().is_in_group("forest_player"):
		hit.get_collider().damage()
	if hit: visual_event.emit("water_hit")
	if hit or lifetime<=0:
		queue_free()

func _draw() -> void:
	if has_meta("forest_skin"): return
	if wave:
		draw_colored_polygon(PackedVector2Array([Vector2(-10,7),Vector2(-5,-2),Vector2(2,-10),Vector2(10,7)]),Color("#89e5ec"))
		return
	draw_circle(Vector2.ZERO,8,Color("#ffbf83"))
	draw_circle(Vector2.ZERO,4,Color("#ef7366"))
