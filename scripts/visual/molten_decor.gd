extends Node2D
var level
var library
var placements:Array=[]
func _ready() -> void:
	# Deliberately authored groups. Bases follow actual level solids.
	match level.chapter_level:
		"3-1": placements=[["broken_arch",110,0.85],["direction_sign",204,0.65],["basalt_column",738,0.8],["molten_ore",990,0.65],["obsidian_crystals",1465,0.65],["dark_iron_furnace",2360,0.65],["iron_support",2850,0.9],["chain_winch",3000,0.7],["fire_lamp",3380,0.9],["broken_arch",3900,0.7],["basalt_column",4370,0.7]]
		"3-2": placements=[["smith_sculpture",120,0.8],["dark_iron_furnace",510,0.75],["iron_support",1640,0.9],["chain_winch",2210,0.6],["dark_iron_furnace",2440,0.7],["smith_sculpture",3195,0.65],["molten_ore",3660,0.75],["dark_iron_furnace",4140,0.75],["fire_lamp",4930,0.8],["direction_sign",5520,0.6],["dark_iron_furnace",6800,0.65],["molten_ore",7190,0.65],["smith_sculpture",7680,0.65],["chain_winch",7820,0.55],["fire_lamp",8170,0.8]]
		"3-3": placements=[["broken_arch",100,0.8],["basalt_column",768,0.7],["fire_lamp",1130,0.8],["arena_obelisk",1510,0.8],["arena_crown_arch",2150,1.0],["arena_obelisk",2760,0.8],["smith_sculpture",3100,0.7]]
	queue_redraw()
	if level.has_node("Scenery"): placements.clear()
func floor_y(x:float) -> float:
	var y:=580.0
	for node in level.get_children():
		if not node.get("size") is Vector2 or node.size.y<30: continue
		if x>=node.position.x and x<node.position.x+node.size.x: y=minf(y,node.position.y)
	return y
func _draw() -> void:
	for data in placements:
		var y:=floor_y(data[1])
		if y>=540: continue
		library.item(self,data[0],Vector2(data[1],y+3),Color(.56,.54,.62),data[2])
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	draw_set_transform(Vector2(left-32,64))
	library.deck(self,1024,false)
	draw_set_transform(Vector2.ZERO)
func _process(_delta:float) -> void: queue_redraw()


