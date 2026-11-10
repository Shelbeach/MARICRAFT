extends Node2D
## Explicit, surface-anchored set dressing. No collision shapes or campaign IDs.
const ROOT:="res://assets/faction_art/"
var props:Array=[]

func _ready() -> void:
	name="FactionDecor"
	var level:=get_parent()
	var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"registry.json"))
	var placements:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"placements.json"))
	for entry in placements.get(preload("res://scripts/visual/level_identity.gd").id(level),[]):
		var data:Dictionary=registry[entry.id]
		var kind:String=entry.get("mount","ground")
		var at:=Vector2(entry.x,entry.get("y",0))
		if entry.has("surface"):
			var surface=level.get_node(entry.surface)
			assert(entry.x>=surface.position.x and entry.x<=surface.position.x+surface.size.x,"Faction decoration needs its authored support")
			at.y=surface.position.y+float(entry.get("dy",3))
		var sprite:=Sprite2D.new()
		sprite.name=entry.id
		sprite.texture=load(ROOT+str(data.file).trim_prefix("runtime/"))
		sprite.centered=false
		sprite.offset=-Vector2(data.anchor_px[0],data.anchor_px[1])
		sprite.scale=Vector2.ONE*float(entry.scale)/float(data.density)
		sprite.position=at
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index=-4 if kind in ["wall","beam","canopy"] else -7
		sprite.modulate=Color(0.88,0.88,0.88)
		if kind=="background":
			sprite.modulate=Color(0.56,0.57,0.62)
			sprite.z_index=-25
		elif kind=="distant":
			sprite.modulate=Color(0.76,0.80,0.87)
			sprite.z_index=-26
			sprite.visible=false # Drawn between the canyon's far and middle layers.
		add_child(sprite)
		props.append({"node":sprite,"origin":at,"distant":kind=="distant","parallax":float(entry.get("parallax",1)),"reference":float(entry.get("reference_camera",0))})

func draw_distant(painter:Node2D) -> void:
	for prop in props:
		if not prop.distant: continue
		var sprite:Sprite2D=prop.node
		var rect:=Rect2(sprite.position+sprite.offset*sprite.scale,Vector2(sprite.texture.get_size())*sprite.scale)
		painter.draw_texture_rect(sprite.texture,rect,false,sprite.modulate)

func _process(_delta:float) -> void:
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	for prop in props:
		prop.node.position.x=prop.origin.x+(left-prop.reference)*(1-prop.parallax)
