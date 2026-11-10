extends Node2D
const Art:=preload("res://scripts/visual/art_library.gd")

func _draw() -> void:
	var pipe=get_parent().object
	var cave:bool=get_parent().level.cave_left>0 and pipe.position.x>=get_parent().level.cave_left
	if cave:
		# Small rocks bury the alpha-padded foot without creating a new obstacle.
		var texture:Texture2D=Art.resource("environment/decor/stones.png")
		for x in [-29,18]: draw_texture_rect(texture,Rect2(x,-4,19,11),false,Color("#99aaa4"))
	else:
		var texture:Texture2D=Art.resource("environment/decor/grass.png")
		for x in [-36,-18,10,27]:
			draw_texture_rect(texture,Rect2(x,-5,12,11),false,Color("#b5c982"))
