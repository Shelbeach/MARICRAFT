extends Node2D
## One authoritative gameplay clock; flames never own a damage Area2D.
var object
var library
var frames:SpriteFrames
var was_active:=false
var ended:=false
var lava_material:ShaderMaterial
var vent_frames:SpriteFrames=preload("res://assets/molten_art/effects/boss_eruption/boss_eruption.tres")

func _ready() -> void:
	object=get_parent()
	frames=preload("res://assets/p07_v03/resources/boss_eruption.tres")
	object.tree_exiting.connect(ending)
	z_index=2
	if object.kind=="lava":
		z_index=-6
		var pool:=ColorRect.new()
		pool.position=Vector2(-object.width/2-80,-object.height)
		pool.size=Vector2(object.width+160,200)
		pool.mouse_filter=Control.MOUSE_FILTER_IGNORE
		lava_material=ShaderMaterial.new()
		lava_material.shader=preload("res://scripts/visual/lava_surface.gdshader")
		lava_material.set_shader_parameter("pool",library.resource("layers/lava_pool.png"))
		lava_material.set_shader_parameter("origin_world",object.position+pool.position)
		lava_material.set_shader_parameter("extent",pool.size)
		pool.material=lava_material
		add_child(pool)

func ending() -> void:
	if ended or object.kind=="lava" or not was_active or not object.is_inside_tree() or object.get_parent().is_queued_for_deletion(): return
	ended=true
	var effects=object.get_parent().get_node_or_null("LocationArt/Effects")
	if effects: effects.make("boss_eruption","end",object.global_position,1,Vector2(object.width/66.0,object.height/132.0)*0.5,true)

func _process(_delta:float) -> void:
	if lava_material: lava_material.set_shader_parameter("age",object.age)
	if was_active and not object.active: ending()
	if object.active and not was_active: ended=false
	was_active=object.active
	queue_redraw()

func flame(clip:String,index:int) -> void:
	if not object.one_shot and clip=="active":
		# Restore the original upright flame. The short ignition key is excluded
		# while damage is active; every displayed key fills the whole hot column.
		var key:int=[1,2,1,3][index]
		var top:float=[0,42,58,100][key]
		var source:=Rect2(62,top,196,304-top)
		draw_texture_rect_region(vent_frames.get_frame_texture("active",key),Rect2(-object.width*.72,-object.height-5,object.width*1.44,object.height+10),source)
		return
	# The provided pivot/axis is shared by all keys. Vent size follows its existing
	# gameplay rectangle; the boss's 66x132 zone uses exactly scale 0.5.
	draw_set_transform(Vector2.ZERO,0,Vector2(object.width/66.0,object.height/132.0)*0.5)
	draw_texture(frames.get_frame_texture(clip,index),Vector2(-160,-294))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not object: return
	if object.kind=="lava":
		return
	if not object.one_shot: draw_crater()
	var phase:float=object.age if object.one_shot else fmod(object.age,object.warning+object.duration+object.rest)
	if object.warning_now:
		var fraction:=clampf(phase/object.warning,0,1)
		flame("warning",mini(3,int(fraction*4)))
	elif object.active:
		flame("active",int((phase-object.warning)*12)%4)

func draw_crater() -> void:
	var w:float=object.width/2
	var rim:=PackedVector2Array([Vector2(-w-3,2),Vector2(-w,-5),Vector2(-w*.62,-10),Vector2(-w*.2,-8),Vector2(w*.3,-10),Vector2(w*.84,-6),Vector2(w+3,2)])
	draw_colored_polygon(rim,Color("#211c27"))
	draw_polyline(rim,Color("#bf7955"),2,true)
	var opening:=PackedVector2Array()
	for i in 25:
		var angle:=TAU*i/24
		opening.append(Vector2(cos(angle)*w*.76,-3+sin(angle)*3.5))
	draw_colored_polygon(opening,Color("#7e3424"))
	draw_line(Vector2(-w*.57,-2),Vector2(w*.57,-2),Color("#f2a553") if object.warning_now else Color("#c16b3c"),2,true)
