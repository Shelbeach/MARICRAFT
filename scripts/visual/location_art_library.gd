@tool
extends RefCounted
## Per-level resource ownership: terrain from a previous scene is not pinned globally.
const ROOT:="res://assets/location2_art/"
const P06:="res://assets/faction_art/"
var environment:Dictionary
var actors:Dictionary
var objects:Dictionary
var resources:Dictionary={}

func _init() -> void:
	environment=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"environment_registry.json"))
	actors=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"animations.json"))
	objects=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"gameplay_registry.json"))
	var additions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(P06+"animations.json"))
	for clip in additions:
		if clip=="rolling": continue
		objects[clip]=additions[clip]
		objects[clip].file=P06+str(additions[clip].file).trim_prefix("runtime/")
		objects[clip].world_units=additions[clip].world_canvas
		objects[clip].frames_resource=P06+"effects/effects.tres"

func resource(path:String):
	path=path.trim_prefix("runtime/")
	if path=="characters/kobold/kobold.tres": path=P06+"characters/kobold.tres"
	if path=="effects/effects.tres": path=P06+"effects/effects.tres"
	if not resources.has(path): resources[path]=load(path if path.begins_with("res://") else ROOT+path)
	return resources[path]

func item(painter:Node2D,id:String,at:Vector2,tint:=Color.WHITE) -> void:
	var data:Dictionary=environment.get(id,objects.get(id,{}))
	var size:=Vector2(data.world_units[0],data.world_units[1])
	var pivot:=Vector2(data.anchor_world[0],data.anchor_world[1])
	painter.draw_texture_rect(resource(data.file),Rect2(at-pivot,size),false,tint)

func rectangle(painter:Node2D,id:String,rect:Rect2,tint:=Color.WHITE) -> void:
	var data:Dictionary=environment.get(id,objects.get(id,{}))
	painter.draw_texture_rect(resource(data.file),rect,false,tint)
