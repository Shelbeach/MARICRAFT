extends "res://scripts/gameplay/forest_level.gd"

@export var forts := PackedFloat32Array()
@export var mine_mouths := PackedFloat32Array()
@export var mine_main := false
@export var scenery: Array[Dictionary] = []
const IRON := Color("#49404b")
const TIMBER := Color("#694845")

func _ready() -> void:
	set_meta("location2_art",true)
	super._ready()
	var art:=preload("res://scripts/visual/location_art.gd").new()
	art.name="LocationArt"
	add_child(art)

func draw_forest_backdrop(width: float) -> void:
	draw_rect(Rect2(0,0,width,540),Color("#ba8171"))
	draw_circle(Vector2(702,156),48,Color("#dfa88a"))
	for i in ceili(width/460)+1:
		var x:=float(i*460)
		var y:=181.0+31*sin(i*1.8)
		var rim:=PackedVector2Array([Vector2(x-90,540),Vector2(x-35,y+135),Vector2(x+34,y+105),Vector2(x+59,y),Vector2(x+166,y-9),Vector2(x+204,y+68),Vector2(x+277,y+77),Vector2(x+318,y+158),Vector2(x+486,440),Vector2(x+520,540)])
		draw_colored_polygon(rim,Color("#a8685e"))
		draw_line(Vector2(x+65,y+13),Vector2(x+164,y+6),Color("#bc7c68"),5)
	for i in ceili(width/370)+1:
		var x:=i*370.0+90
		var at:=Vector2(x,473)
		draw_line(at,at+Vector2(-7,-37),Color("#79665a"),5)
		draw_line(at+Vector2(-4,-18),at+Vector2(11,-29),Color("#79665a"),4)
	# Eroded foreground shelves frame the ravines below the playable top edges.
	for i in ceili(width/830):
		var x:=i*830.0+220
		draw_colored_polygon(PackedVector2Array([Vector2(x-190,540),Vector2(x-95,378),Vector2(x+3,358),Vector2(x+49,321),Vector2(x+147,316),Vector2(x+231,421),Vector2(x+394,540)]),Color("#995b50"))
		draw_line(Vector2(x+54,334),Vector2(x+146,328),Color("#ad705a"),5)
	for x in forts:
		for i in 7:
			var post:=x+i*15
			draw_colored_polygon(PackedVector2Array([Vector2(post,480),Vector2(post-3,365),Vector2(post+3,350-8*(i%3)),Vector2(post+9,364),Vector2(post+10,480)]),TIMBER)
		draw_line(Vector2(x-8,392),Vector2(x+108,385),Color("#806052"),7)
		draw_line(Vector2(x+12,345),Vector2(x+90,345),IRON,4)
		draw_colored_polygon(PackedVector2Array([Vector2(x+14,345),Vector2(x+88,345),Vector2(x+72,374),Vector2(x+46,362)]),Color("#924b46"))
	for x in mine_mouths:
		draw_rect(Rect2(x-79,303,158,177),IRON)
		draw_support(x,300,480)
		draw_cart(x+50,473)

	if boss:
		# The forge is roofed; hanging braces explain where the marked rockfalls come from.
		var left:float=boss.arena_start
		var right:float=finish_x-76
		draw_rect(Rect2(left,0,right-left,132),Color("#4c3940"))
		for i in ceili((right-left)/120):
			var x:=left+i*120
			draw_colored_polygon(PackedVector2Array([Vector2(x,132),Vector2(x+30,157+12*(i%3)),Vector2(x+65,143),Vector2(x+120,164),Vector2(x+120,127),Vector2(x,127)]),Color("#6d4946"))
		for post in [left+35,right-36]:
			draw_line(Vector2(post,150),Vector2(post,478),TIMBER,12)
			draw_line(Vector2(post-27,145),Vector2(post,183),TIMBER,8)

func draw_support(x: float,y: float,bottom: float) -> void:
	for side: int in [-1,1]:
		draw_line(Vector2(x+side*76,bottom),Vector2(x+side*65,y),TIMBER,12)
		draw_line(Vector2(x+side*65,y+38),Vector2(x+side*37,y+2),Color("#896450"),6)
	draw_line(Vector2(x-84,y),Vector2(x+84,y),Color("#a5795f"),12)
	draw_rect(Rect2(x-56,y-15,6,11),Color("#d6b58b"))
	draw_circle(Vector2(x-53,y-18),3,Color("#ffc875"))

func draw_cart(x: float,y: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x-27,y-25),Vector2(x+26,y-25),Vector2(x+19,y-7),Vector2(x-20,y-7)]),Color("#746273"))
	for dx in [-14,14]: draw_circle(Vector2(x+dx,y-3),5,IRON)
	draw_line(Vector2(x+5,y-24),Vector2(x+19,y-52),Color("#ba9470"),4)
	draw_line(Vector2(x+8,y-52),Vector2(x+31,y-47),Color("#92909a"),4)

func draw_cave() -> void:
	draw_rect(Rect2(cave_left,0,cave_width,540),Color("#302b38"))
	for i in ceili(cave_width/148):
		var x:=cave_left+i*148
		draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+148,0),Vector2(x+148,171),Vector2(x+92,185+13*(i%3)),Vector2(x+39,157),Vector2(x,169)]),Color("#443949"))
	for i in ceili(cave_width/255):
		var x:=cave_left+100+i*255
		draw_support(x,225+(i%3)*9,489)
		for j in 4:
			var ore:=Vector2(x+90+14*j,362-10*j+7*(j%2))
			draw_line(ore,ore+Vector2(8,-11),Color("#957962"),5)
		if i%2==0: draw_cart(x+19,475)
	draw_line(Vector2(cave_left,478),Vector2(cave_left+cave_width,478),Color("#776573"),3)
