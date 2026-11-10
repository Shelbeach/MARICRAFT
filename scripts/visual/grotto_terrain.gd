@tool
extends Node2D
var tiles:Array=[]
var atlas:Texture2D
func _draw() -> void:
	for tile in tiles:
		draw_texture_rect_region(atlas,tile[0],tile[1],Color(1 if tile[3] else 0,float(tile[4])/7.0,1,1))
