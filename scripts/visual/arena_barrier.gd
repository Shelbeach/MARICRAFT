extends Node2D
## Existing painted gate pieces, repeated vertically at their authored density.
var chapter:=1
var closed:=true
var progress:=0.0
var texture:Texture2D
var molten
func _ready() -> void:
	z_index=5
	if chapter==3:
		molten=preload("res://assets/molten_art/objects/gate_view.tscn").instantiate()
		molten.gate_height=510
		add_child(molten)
	elif chapter==1:
		texture=load("res://assets/forest_art/gameplay/interactive/gate_closed.png")
	else:
		var lib=preload("res://scripts/visual/location_art_library.gd").new()
		texture=lib.resource(lib.objects.gate_closed.file)
	queue_redraw()
func _process(delta:float) -> void:
	progress=move_toward(progress,0.0 if closed else 1.0,delta*2.5)
	if molten: molten.open_progress=progress
	queue_redraw()
func _draw() -> void:
	if not texture: return
	var sz:=Vector2(texture.get_size())
	var bottom:=-510*progress
	var y:=-510.0
	while y<bottom:
		var h:=minf(48,bottom-y)
		draw_texture_rect_region(texture,Rect2(-10,y,20,h),Rect2(0,sz.y*0.35,sz.x,sz.y*0.30*h/48))
		y+=h
	if progress<0.99:
		draw_texture_rect_region(texture,Rect2(-13,bottom-28,26,30),Rect2(0,sz.y*0.72,sz.x,sz.y*0.28))
