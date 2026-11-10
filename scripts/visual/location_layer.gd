@tool
extends Node2D
var library
var level
var id:=""
var texture:Texture2D
var data:Dictionary
var source:Rect2
func _ready() -> void:
	if id=="distant": return
	data=library.environment[id]
	texture=library.resource(data.file)
	source=Rect2(Vector2.ZERO,texture.get_size())
	if id=="canyon_far": source=Rect2(200,0,1500,840)
	elif id=="canyon_near": source=Rect2(200,0,1420,500)
	var shader:=ShaderMaterial.new()
	shader.shader=preload("res://scripts/visual/continuous_backdrop.gdshader")
	shader.set_shader_parameter("source_uv",Vector4(source.position.x/texture.get_width(),0,source.size.x/texture.get_width(),1))
	shader.set_shader_parameter("overlap",128.0/source.size.x)
	material=shader
func _process(_delta:float) -> void:
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	visible=not level.mine_main and not (level.cave_left>0 and left>=level.cave_left-1)
	queue_redraw()
func _draw() -> void:
	if id=="distant":
		if level.has_node("FactionDecor"): level.get_node("FactionDecor").draw_distant(self)
		return
	if not texture: return
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	var width:float=get_viewport_rect().size.x/get_viewport().canvas_transform.x.x+40
	var span:float=source.size.x*float(data.world_units[0])/texture.get_width()
	material.set_shader_parameter("cycles",width/span)
	material.set_shader_parameter("phase",left*float(data.parallax[0])/span)
	draw_texture_rect(texture,Rect2(left,float(data.top_world),width,float(data.world_units[1])),false)
	if id=="canyon_sky":
		draw_set_transform(Vector2(left,0),0,Vector2(1,-1))
		draw_texture_rect_region(texture,Rect2(0,0,width,64),Rect2(0,0,texture.get_width(),64*texture.get_height()/float(data.world_units[1])))
		draw_set_transform(Vector2.ZERO)
