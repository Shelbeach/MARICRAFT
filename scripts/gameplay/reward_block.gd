extends StaticBody2D

signal visual_event(kind: String)

const POTION := preload("res://scenes/objects/potion.tscn")
const RUNE := preload("res://scenes/objects/rune.tscn")
@export_enum("coins","potion","rune","fragile","empty") var kind := "coins"
@export var reward_id := ""
@export var amount := 10
@export_range(0,20) var vein_bonus := 0
var spent := false
var bump := 0.0

func _ready() -> void:
	spent = kind not in ["fragile","empty"] and Campaign.claimed(reward_id)
	if spent and kind in ["potion","rune"] and not Campaign.claimed(reward_id+"/item"):
		drop_item.call_deferred()

func drop_item() -> void:
	visual_event.emit("eject")
	var item := (RUNE if kind == "rune" else POTION).instantiate()
	item.reward_id = reward_id+"/item"
	item.position = position + release_offset(item.get_node("Hitbox").shape)
	item.falling = true
	get_parent().add_child(item)

func release_offset(shape: Shape2D) -> Vector2:
	# Eject beside the lid, over a verified landing. The underside is a
	# fallback for recessed chests: the opener already reached that space.
	var space := get_world_2d().direct_space_state
	for dx in [38.0,-38.0]:
		var mouth := global_position + Vector2(dx,-12)
		var clearance := PhysicsShapeQueryParameters2D.new()
		clearance.shape = shape
		clearance.transform.origin = mouth
		clearance.collision_mask = 1
		var floor_ray := PhysicsRayQueryParameters2D.create(mouth,mouth+Vector2(0,260),1)
		if space.intersect_shape(clearance,1).is_empty() and not space.intersect_ray(floor_ray).is_empty():
			return Vector2(dx,-12)
	return Vector2(0,32)

func hit_below(player) -> void:
	if spent or not Campaign.active():
		return
	if kind in ["fragile","empty"]:
		if player.form > 0:
			spent = true
			if kind == "fragile":
				Campaign.reward(reward_id,vein_bonus,50+10*vein_bonus)
			visual_event.emit("break")
			SFX.play("block_break",self,reward_id)
			queue_free()
		return
	spent = true
	bump = 0.18
	visual_event.emit("open")
	var coins := amount if kind == "coins" else 0
	if Campaign.reward(reward_id,coins,coins*10): SFX.play("chest_open",self,reward_id)
	if kind != "coins":
		drop_item.call_deferred()
	queue_redraw()

func _process(delta: float) -> void:
	if bump > 0:
		bump = maxf(0,bump-delta)
		queue_redraw()

func _draw() -> void:
	if has_meta("forest_skin"): return
	var rect := Rect2(-16,-16 - sin(bump/0.18*PI)*4,32,32)
	var tint := Color("#697885") if spent else Color("#e5a654")
	if kind in ["fragile","empty"]:
		draw_rect(rect,Color("#bd8c77"))
		draw_polyline(PackedVector2Array([Vector2(-3,-15),Vector2(3,-5),Vector2(-3,2),Vector2(4,14)]),Color("#613f40"),2)
		if vein_bonus>0:
			draw_line(Vector2(5,-8),Vector2(10,-12),Color("#e5bd80"),3)
		return
	draw_rect(rect,tint)
	draw_rect(rect,Color("#614836"),false,2)
	draw_line(rect.position+Vector2(2,10),rect.position+Vector2(30,10),Color("#725139"),3)
	if not spent:
		draw_rect(Rect2(-4,rect.position.y+9,8,11),Color("#ffe9a6") if kind=="coins" else Color("#85efb4"))
