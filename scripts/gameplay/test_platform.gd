@tool
extends StaticBody2D

# Only the highlighted deck is solid. The shaded trestles sit behind the path.
@export_enum("plain", "timber", "quay", "masonry", "cave", "redrock", "ore") var construction := "plain":
	set(value):
		construction = value
		queue_redraw()
@export var foundation_y := 480.0
@export var size := Vector2(96, 32):
	set(value):
		size = value
		if is_node_ready():
			_resize()

func _ready() -> void:
	_resize()

func _resize() -> void:
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	$Hitbox.shape = rectangle
	$Hitbox.position = size / 2.0
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint() and get_parent().has_node("__LevelPreview"): return
	if has_meta("forest_skin"): return
	if construction in ["timber", "quay"]:
		draw_trestle()
		return
	if construction in ["redrock","ore"]:
		var rock := Color("#934d40") if construction=="redrock" else Color("#514354")
		draw_rect(Rect2(Vector2.ZERO,size),rock)
		draw_rect(Rect2(0,0,size.x,5),Color("#f1b777") if construction=="redrock" else Color("#ce9b76"))
		for row in range(16,int(size.y),28):
			draw_line(Vector2(0,row),Vector2(size.x,row+2),rock.darkened(0.20),2)
		return
	var masonry := construction in ["masonry","cave"]
	var stone := Color("#556064") if construction=="masonry" else Color("#51566a")
	if construction=="masonry" and position.y+size.y<foundation_y:
		# Recessed piers mark the open archway below its solid lintel.
		for x in [8.0,size.x-14]:
			draw_rect(Rect2(x,size.y,6,foundation_y-position.y-size.y),Color("#405455"))
	draw_rect(Rect2(Vector2.ZERO,size),stone if masonry else Color("#345363"))
	draw_rect(Rect2(0,0,size.x,4),Color("#b4bba8") if masonry else Color("#75cbb6"))
	if masonry:
		for row in ceili(size.y/24.0):
			var y := row*24.0
			for x in range(24+32*(row%2),int(size.x),64):
				draw_line(Vector2(x,y+4),Vector2(x,minf(y+24,size.y)),stone.darkened(0.22),2)
			if y>0: draw_line(Vector2(0,y),Vector2(size.x,y),stone.darkened(0.22),2)

func draw_trestle() -> void:
	var depth := foundation_y-position.y
	var bays := maxi(1,roundi(size.x/112.0))
	var inset := minf(12,size.x/5)
	var back := Color("#415654")
	var brace := Color("#49615b")
	if depth>size.y:
		for i in bays+1:
			var x := lerpf(inset,size.x-inset,float(i)/bays)
			draw_rect(Rect2(x-4,size.y,8,depth-size.y),back)
			var knee := minf(28,(depth-size.y)*0.65)
			if i<bays: draw_line(Vector2(x,size.y+knee),Vector2(x+knee,size.y),brace,4)
			if i>0: draw_line(Vector2(x,size.y+knee),Vector2(x-knee,size.y),brace,4)
	var beam := Color("#78634f") if construction=="timber" else Color("#555f60")
	draw_rect(Rect2(Vector2.ZERO,size),beam)
	draw_rect(Rect2(0,0,size.x,4),Color("#ddbd85") if construction=="timber" else Color("#9ac9c0"))
	draw_rect(Rect2(0,size.y-4,size.x,4),beam.darkened(0.22))
	for x in range(24,int(size.x),32):
		draw_line(Vector2(x,4),Vector2(x,mini(10,int(size.y)-1)),beam.darkened(0.3),2)
