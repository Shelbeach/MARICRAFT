extends Node2D
## Repeating visual only. Existing level geometry owns collisions.
@export_enum("basalt","obsidian","heated") var stone_type="basalt"
@export var extent := Vector2(512,200)
@export var continuous_origin := Vector2.ZERO
@export var show_top := true
@export var show_sides := true
@export var show_bottom := false
var field:Texture2D
var rim:Texture2D
var edge:Texture2D
var underside:Texture2D
func _ready():
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var folder=get_script().resource_path.get_base_dir()
	field=load(folder+"/"+stone_type+"_field.png")
	rim=load(folder+"/"+stone_type+"_top_repeat.png")
	edge=load(folder+"/wall_edge_repeat.png")
	underside=load(folder+"/underside_repeat.png")
	queue_redraw()
func _draw():
	if not field:return
	draw_texture_rect_region(field,Rect2(Vector2.ZERO,extent),Rect2(continuous_origin*2,extent*2),Color.WHITE,false,false)
	if show_top:
		draw_texture_rect_region(rim,Rect2(0,-2,extent.x,28),Rect2(continuous_origin.x*2,0,extent.x*2,56),Color.WHITE,false,false)
	if show_sides:
		var h=maxf(0,extent.y-18)
		draw_texture_rect_region(edge,Rect2(0,18,20,h),Rect2(0,continuous_origin.y*2,40,h*2),Color.WHITE,false,false)
		draw_set_transform(Vector2(extent.x,0),0,Vector2(-1,1))
		draw_texture_rect_region(edge,Rect2(0,18,20,h),Rect2(0,continuous_origin.y*2,40,h*2),Color.WHITE,false,false)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if show_bottom:
		draw_texture_rect_region(underside,Rect2(0,extent.y-24,extent.x,28),Rect2(continuous_origin.x*2,0,extent.x*2,56),Color.WHITE,false,false)
