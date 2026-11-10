@tool
extends Node2D
var level
var library
var far_spans:Node2D
func _ready() -> void:
	far_spans=preload("res://scripts/visual/molten_far_spans.gd").new()
	var id:="forge_far" if level.chapter_level=="3-2" else "core_far"
	far_spans.original_span=library.resource("layers/"+id+".png")
	far_spans.added_span=load("res://assets/p07_v03/layers/"+id+"_b.png")
	far_spans.parallax=0.15 if level.chapter_level=="3-2" else 0.12
	# At these slow parallax rates an origin of zero never exposes span B during
	# the main route. Place the matched A/B join within the campaign camera sweep.
	far_spans.phase_origin=1440.0
	# Draw A/B below mid/unique sanctuary, above the solid background.
	far_spans.show_behind_parent=true
	add_child(far_spans)
func _process(_delta:float) -> void: queue_redraw()
func layer(id:String,left:float,size:Vector2,y:float,parallax:float,tint:=Color.WHITE) -> void:
	var texture:Texture2D=library.resource("layers/"+id+".png")
	var phase:=fposmod(left*parallax,size.x)
	for i in range(-1,3): draw_texture_rect(texture,Rect2(left-phase+i*size.x,y,size.x,size.y),false,tint)
func _draw() -> void:
	if not level: return
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	if far_spans: far_spans.set_camera_left(left)
	var forge:bool=level.chapter_level=="3-2"
	layer("forge_mid" if forge else "core_mid",left,Vector2(1680,420),120,0.42 if forge else 0.36,Color(.66,.67,.73,1))
	if level.chapter_level=="3-3":
		# Unique panorama, bounded drift. No repeated sanctuaries.
		var blend:=smoothstep(1060,1540,left)
		if blend>0:
			var drift:=clampf((left-1660)*0.08,-50,50)
			var sanctuary:Texture2D=library.resource("layers/sanctum_far.png")
			# Cover the actual world-space viewport, including the wider boss zoom.
			# Keep the panorama's aspect ratio and spare room for bounded drift.
			var visible:=get_viewport_rect().size/get_viewport().canvas_transform.get_scale()
			var factor:=maxf(1.0,maxf((visible.x+160.0)/1080.0,visible.y/540.0))
			var extent:=Vector2(1080,540)*factor
			var origin:=Vector2(left+(visible.x-extent.x)*0.5-drift,540-extent.y)
			draw_texture_rect(sanctuary,Rect2(origin,extent),false,Color(1,1,1,blend))
			draw_set_transform(origin,0,Vector2(1,-1))
			draw_texture_rect_region(sanctuary,Rect2(0,0,extent.x,64),Rect2(0,0,sanctuary.get_width(),64.0*sanctuary.get_height()/extent.y),Color(1,1,1,blend))
			draw_set_transform(Vector2.ZERO)
	if level.chapter_level=="3-1": layer("core_near",left,Vector2(720,180),526,1.08,Color(.6,.6,.65,.5))

