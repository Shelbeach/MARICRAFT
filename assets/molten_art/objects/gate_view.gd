extends Node2D
## Origin: bottom centre. Visual-only; game controller owns collision and open timing.
@export var gate_height=172.0
@export_range(0.0,1.0) var open_progress=0.0:
	set(value):open_progress=clampf(value,0,1);queue_redraw()
var top:Texture2D
var middle:Texture2D
var bottom:Texture2D
func _ready():
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var folder=get_script().resource_path.get_base_dir()
	top=load(folder+"/gate_top.png");middle=load(folder+"/gate_middle_repeat.png");bottom=load(folder+"/gate_bottom.png");queue_redraw()
func _draw():
	if not top:return
	var lower=-gate_height*open_progress
	var y=-gate_height+36.0
	var h=maxf(0,lower-20-y)
	draw_texture_rect_region(middle,Rect2(-9,y,18,h),Rect2(0,0,36,h*2),Color.WHITE,false,false)
	if open_progress<.98:
		draw_texture_rect_region(bottom,Rect2(-27,lower-76.5,54,76.5),Rect2(2,2,108,153))
	draw_texture_rect_region(top,Rect2(-23,-gate_height,46,75),Rect2(2,2,92,150))
