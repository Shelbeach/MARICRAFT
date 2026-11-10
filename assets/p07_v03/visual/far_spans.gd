extends Node2D
# Optional standalone background helper. No game-state writes.
@export var original_span:Texture2D
@export var added_span:Texture2D
@export var parallax:=0.12
@export var span_world:=Vector2(2160,540)
@export var phase_origin:=0.0
var camera_left:=0.0
func set_camera_left(value:float)->void:camera_left=value;queue_redraw()
func _draw()->void:
	if not original_span or not added_span:return
	var shift:=fposmod(phase_origin+camera_left*parallax,span_world.x*2)
	for i in range(-2,4):
		var tex:=original_span if posmod(i,2)==0 else added_span
		draw_texture_rect(tex,Rect2(camera_left-shift+i*span_world.x,0,span_world.x,span_world.y),false)
