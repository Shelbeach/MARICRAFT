@tool
extends Node2D
var object
var library
func _draw() -> void:
	var is_ferry:bool=object.get("travel")!=null
	var width:float=128 if is_ferry else object.size.x
	var offset:float=-64 if is_ferry else 0
	for x in [offset+12,offset+width-12]:
		library.chain(self,Vector2(x,80-object.position.y),object.position.y-80,Color(.6,.57,.62))
		library.item(self,"wall_anchor",Vector2(x,80-object.position.y),Color(.65,.62,.65),0.35)
	draw_set_transform(Vector2(offset,0))
	library.deck(self,width,object.get_parent().chapter_level!="3-2")
