extends Control
## Fixed display size even though full/lost icons have different source resolutions.
const UI:=preload("res://scripts/ui/forest_ui.gd")
var kind:="hearts"
var filled:=0
var unit:=26.0

func _draw() -> void:
	for i in 3:
		var id:=("heart_full" if i<filled else "heart_lost") if kind=="hearts" else ("star_on" if i<filled else "star_off")
		draw_texture_rect(UI.texture(id),Rect2(i*(unit+4),0,unit,unit),false)
