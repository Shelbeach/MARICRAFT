@tool
extends Node2D
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

## Supplied continuous UV surface, with exposed-edge culling for adjacent solids.
var left_start:=18.0
var right_start:=18.0
var field_panel:ColorRect
var neighbours:Array[Rect2]=[]

func _ready() -> void:
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	edge=load("res://assets/molten_art/terrain/wall_edge_repeat.png")
	underside=load("res://assets/molten_art/terrain/underside_repeat.png")
	var body=get_parent().get_parent()
	continuous_origin=body.position
	extent=body.size
	show_bottom=body.position.y+body.size.y<540
	var chapter:String=body.get_parent().chapter_level
	stone_type="obsidian" if chapter=="3-3" else "basalt"
	field=load("res://assets/molten_art/terrain/"+stone_type+"_field.png")
	rim=load("res://assets/molten_art/terrain/"+stone_type+"_top_repeat.png")
	for other in body.get_parent().get_children():
		if other==body or not other.get("size") is Vector2: continue
		neighbours.append(Rect2(other.position-body.position,other.size))
		if other.position.y+other.size.y<body.position.y+18: continue
		if absf(other.position.x+other.size.x-body.position.x)<0.1: left_start=maxf(left_start,other.position.y-body.position.y)
		if absf(body.position.x+body.size.x-other.position.x)<0.1: right_start=maxf(right_start,other.position.y-body.position.y)
		if other.position.y<=body.position.y:
			if absf(other.position.x+other.size.x-body.position.x)<0.1: left_start=extent.y
			if absf(body.position.x+body.size.x-other.position.x)<0.1: right_start=extent.y
	field_panel=ColorRect.new()
	field_panel.size=extent
	field_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	field_panel.show_behind_parent=true
	var transition:=ShaderMaterial.new()
	transition.shader=preload("res://scripts/visual/molten_field_variants.gdshader")
	transition.set_shader_parameter("origin_world",continuous_origin)
	transition.set_shader_parameter("size_world",extent)
	transition.set_shader_parameter("stone_a",field)
	transition.set_shader_parameter("stone_a_variant",load("res://assets/p07_v03/terrain/"+stone_type+"_field_b.png"))
	transition.set_shader_parameter("stone_b",load("res://assets/molten_art/terrain/heated_field.png"))
	transition.set_shader_parameter("stone_b_variant",load("res://assets/p07_v03/terrain/heated_field_b.png"))
	transition.set_shader_parameter("transition_enabled",chapter=="3-2")
	transition.set_shader_parameter("boundary_world_x",2250.0 if body.position.x<6600 else 7380.0)
	field_panel.material=transition
	add_child(field_panel)
	queue_redraw()

func exposed(axis:int,start:float,end:float,probe:float) -> Array[Vector2]:
	var cuts:Array[float]=[start,end]
	for rect in neighbours:
		for edge in [rect.position[axis],rect.end[axis]]:
			if edge>start and edge<end and not cuts.has(edge): cuts.append(edge)
	cuts.sort()
	var spans:Array[Vector2]=[]
	for i in cuts.size()-1:
		var middle:float=(cuts[i]+cuts[i+1])/2
		var at:=Vector2(middle,probe) if axis==0 else Vector2(probe,middle)
		var hidden:=false
		for rect in neighbours:
			if rect.has_point(at): hidden=true;break
		if not hidden: spans.append(Vector2(cuts[i],cuts[i+1]))
	return spans

func _draw() -> void:
	if not field: return
	if not field_panel: draw_texture_rect_region(field,Rect2(Vector2.ZERO,extent),Rect2(continuous_origin*2,extent*2),Color.WHITE,false,false)
	if show_top:
		for span in exposed(0,0,extent.x,-0.1):
			draw_texture_rect_region(rim,Rect2(span.x,-2,span.y-span.x,28),Rect2((continuous_origin.x+span.x)*2,0,(span.y-span.x)*2,56),Color.WHITE,false,false)
	for side in 2:
		if side==1: draw_set_transform(Vector2(extent.x,0),0,Vector2(-1,1))
		for span in exposed(1,18,extent.y,-0.1 if side==0 else extent.x+0.1):
			draw_texture_rect_region(edge,Rect2(0,span.x,20,span.y-span.x),Rect2(0,(continuous_origin.y+span.x)*2,40,(span.y-span.x)*2),Color.WHITE,false,false)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if show_bottom:
		for span in exposed(0,0,extent.x,extent.y+0.1):
			draw_texture_rect_region(underside,Rect2(span.x,extent.y-24,span.y-span.x,28),Rect2((continuous_origin.x+span.x)*2,0,(span.y-span.x)*2,56),Color.WHITE,false,false)
