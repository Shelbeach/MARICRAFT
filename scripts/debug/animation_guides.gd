extends Node2D
var bench
func _draw() -> void:
	if not is_instance_valid(bench): return
	for x in [245,715]:
		draw_line(Vector2(x-205,441),Vector2(x+205,441),Color("#90ada7"),1)
		draw_rect(Rect2(Vector2(x,441)-Vector2(bench.body_size.x/2,bench.body_size.y)*bench.zoom,bench.body_size*bench.zoom),Color("#68e5d4"),false,1)
		draw_line(Vector2(x-7,441),Vector2(x+7,441),Color("#ffd381"),2)
		draw_line(Vector2(x,434),Vector2(x,448),Color("#ffd381"),2)

