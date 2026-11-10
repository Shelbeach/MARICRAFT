@tool
extends Node2D
var kind:=""
func _draw() -> void:
	var back=get_parent()
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	if kind=="castle":
		if not back.in_cave(left): back.item("castle",Vector2(540+left*0.88,220),back.forest_color,self)
	elif kind=="landscape":
		if not back.in_cave(left): back.draw_landscape(self,left)
	elif kind=="trees":
		if not back.in_cave(left): back.draw_trees(self,left)
	else: back.draw_props(self,left)

