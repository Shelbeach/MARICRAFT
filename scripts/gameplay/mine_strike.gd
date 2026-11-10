extends Node2D
## Positions are locked when the warning appears. Light and damage use the same width.
enum Kind { FISSURE, WAX, ROCK }
var kind := Kind.FISSURE
var half_width := 46.0
var warning := 0.88
var duration := 0.42
var age := 0.0
var activated := false
var hit_player := false

func _physics_process(delta: float) -> void:
	age += delta
	if age >= warning + duration:
		queue_free()
		return
	if age >= warning:
		if not activated:
			activated=true
			SFX.play(["foreman_pickaxe_strike","foreman_wax_burst","foreman_rockfall"][kind],self,"activate")
		var actor = get_parent().player
		var shape: CollisionShape2D = actor.get_node("Hitbox")
		var bounds: Rect2 = shape.shape.get_rect()
		bounds.position += shape.global_position
		if not hit_player and danger().intersects(bounds):
			hit_player=true
			actor.damage()
	queue_redraw()

func danger() -> Rect2:
	var h: float = [30,158,296][kind]
	return Rect2(global_position-Vector2(half_width,h),Vector2(half_width*2,h))

func _draw() -> void:
	if has_meta("location2_skin"): return
	var ink: Color = [Color("#ffd57f"),Color("#ffac68"),Color("#fed5aa")][kind]
	var w := half_width
	draw_line(Vector2(-w,-2),Vector2(w,-2),ink,5)
	if age < warning:
		var rise := clampf(age/warning,0,1)
		for side: int in [-1,1]:
			draw_line(Vector2(side*w,-4),Vector2(side*w,-17),ink,3)
		draw_line(Vector2(-w,-8),Vector2(-w+2*w*rise,-8),Color.WHITE,2)
		if kind==Kind.ROCK:
			draw_dashed_line(Vector2(0,-258),Vector2(0,-20),ink,2,9)
			draw_circle(Vector2(0,-258+rise*38),10,ink)
		elif kind==Kind.WAX:
			draw_arc(Vector2(0,-5),15+rise*9,PI,TAU,16,ink,3)
		return
	var rect:=danger()
	rect.position-=global_position
	draw_rect(rect,Color(ink,0.33))
	for i in 4:
		var x := -w+2*w*(i+0.5)/4
		var h := rect.size.y
		draw_colored_polygon(PackedVector2Array([Vector2(x-8,0),Vector2(x-4,-h*0.72),Vector2(x+6,-h),Vector2(x+10,0)]),ink)

