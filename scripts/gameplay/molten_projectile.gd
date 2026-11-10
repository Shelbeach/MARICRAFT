extends "res://scripts/gameplay/boss_shot.gd"

func _ready() -> void:
	super._ready()
	add_to_group("molten_attacks")

func _draw() -> void:
	if has_meta("forest_skin"): return
	# Hitbox is the existing 12x12 projectile; corona is a non-damaging soft tail.
	var tail:=-direction.normalized()*18
	draw_line(Vector2.ZERO,tail,Color(0.96,0.35,0.12,0.45),9)
	if wave:
		draw_colored_polygon(PackedVector2Array([Vector2(-6,6),Vector2(0,-6),Vector2(6,6)]),Color("#ffd27e"))
	else:
		draw_circle(Vector2.ZERO,6,Color("#ffb14e"))
		draw_circle(Vector2.ZERO,3,Color("#fff3b8"))
