extends Area2D

signal visual_event(kind: String)

@export_enum("coin","potion","rune") var kind := "coin"
@export var reward_id := ""

var falling := false
var fall_speed := -135.0

func _ready() -> void:
	if Campaign.claimed(reward_id):
		queue_free()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if falling:
		fall_speed = minf(fall_speed + 660.0*delta,360.0)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = $Hitbox.shape
		query.transform = $Hitbox.global_transform
		query.motion = Vector2(0,fall_speed*delta)
		query.collision_mask = 1
		var travel := get_world_2d().direct_space_state.cast_motion(query)
		position += query.motion*travel[0]
		if travel[0] < 1.0:
			falling = fall_speed < 0
			fall_speed = 0
	for actor in get_overlapping_bodies():
		if not actor.is_in_group("forest_player") or actor.recovering > 0 or not Campaign.active():
			continue
		if kind != "coin" and not actor.apply_form(maxi(actor.form, 2 if kind == "rune" else 1)):
			continue
		visual_event.emit("pickup")
		if kind=="rune" and get_parent().get("arena"):
			get_parent().arena.request_activation()
		if Campaign.reward(reward_id, 1 if kind == "coin" else 0, 10 if kind == "coin" else 1000):
			SFX.play("coin_pickup" if kind=="coin" else "powerup_pickup",self,reward_id)
		queue_free()
		return

func _draw() -> void:
	if has_meta("forest_skin"): return
	if kind == "coin":
		draw_circle(Vector2.ZERO,10,Color("#8b591f"))
		draw_circle(Vector2(0,-1),8,Color("#ffcd5f"))
		draw_line(Vector2(0,-5),Vector2(0,4),Color("#976a28"),2)
	elif kind == "potion":
		draw_circle(Vector2(0,3),12,Color("#7fe1a8"))
		draw_rect(Rect2(-5,-14,10,12),Color("#edf5d9"))
		draw_line(Vector2(-5,4),Vector2(5,4),Color("#225b4e"),3)
		draw_line(Vector2(0,-1),Vector2(0,9),Color("#225b4e"),3)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-16),Vector2(12,0),Vector2(0,16),Vector2(-12,0)]),Color("#83dfff"))
		draw_line(Vector2(-3,5),Vector2(3,-5),Color("#235777"),3)
