@tool
extends Node2D
const Art=preload("res://scripts/visual/art_library.gd")
var level
var chapter:=""
var markers:Array=[]
var signature:=""
var clock:=0.0
var terrain:Node2D
var scenery:Node2D
var library
var auxiliary:Array[Node]=[]
func _exit_tree() -> void:
	for n in auxiliary:
		if is_instance_valid(n): n.queue_free()
func build() -> void:
	level=get_parent()
	chapter=preload("res://scripts/visual/level_identity.gd").id(level)
	Art.initialize()
	library=preload("res://scripts/visual/molten_library.gd").new() if chapter.begins_with("3") else preload("res://scripts/visual/location_art_library.gd").new()
	refresh()
func state_key() -> String:
	var key:="native-picking-v2"
	for n in level.get_children():
		if n==self or not n is Node2D: continue
		key+=str(n.name)+str(n.position)+str(n.get("size"))+str(n.get("kind"))+str(n.get("construction"))
	return key
func _process(delta:float) -> void:
	if not level: return
	clock+=delta
	if clock<0.2: return
	clock=0
	if state_key()!=signature: refresh()
func frame(n:Node2D,frames:SpriteFrames,clip:String,pivot:Vector2,density:=2.0,factor:=1.0) -> void:
	var sprite:=Sprite2D.new()
	sprite.centered=false
	sprite.texture=frames.get_frame_texture(clip,0)
	sprite.offset=-pivot
	sprite.scale=Vector2.ONE*factor/density
	sprite.position=Vector2.ZERO
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	n.add_child(sprite)
	n.set_meta("_edit_group_",true)
	auxiliary.append(sprite)
	markers.append([n,Rect2(n.position-pivot*factor/density,sprite.texture.get_size()*factor/density)])
func forest_object(n:Node2D,clip:String) -> void:
	var d:Dictionary=Art.objects[clip]
	frame(n,Art.resource("gameplay/"+d.spriteframes),clip,Vector2(d.anchor_world[0],d.anchor_world[1])*2)
func actor(n:Node2D,id:String) -> void:
	var d:Dictionary=Art.actors[id]
	var factor:float=Art.calibration.get(id,{}).get("_scale",1.0)*Art.calibration.get(id,{}).get("idle",{}).get("0",1.0)
	frame(n,Art.resource("characters/"+d.spriteframes),"idle",Vector2(d.pivot_px[0],d.pivot_px[1]),d.density,factor)
func refresh() -> void:
	for n in auxiliary:
		if is_instance_valid(n): n.get_parent().remove_child(n);n.queue_free()
	auxiliary.clear()
	for child in get_children(): remove_child(child);child.queue_free()
	markers.clear()
	if chapter.begins_with("3"):
		var back=preload("res://scripts/visual/molten_backdrop.gd").new()
		back.level=level;back.library=library;back.z_index=-90;add_child(back)
	elif chapter.begins_with("2"):
		var back=preload("res://scripts/visual/location_backdrop.gd").new()
		back.library=library;add_child(back);back.setup(level)
		terrain=preload("res://scripts/visual/location_terrain.gd").new()
		terrain.library=library;terrain.z_index=-5;add_child(terrain);terrain.setup(level)
	else:
		add_child(preload("res://scripts/visual/forest_backdrop.gd").new())
		terrain=preload("res://scripts/visual/forest_terrain.gd").new()
		terrain.z_index=-5;add_child(terrain);terrain.setup(level)
	for n in level.get_children():
		if n==self or not n is Node2D or not n.get_script(): continue
		var role:String=n.get_script().resource_path.get_file().get_basename()
		match role:
			"pickup": forest_object(n,"coin_spin" if n.kind=="coin" else n.kind)
			"forest_player": actor(n,"human_small")
			"murloc","kobold":
				if chapter.begins_with("3"):
					var id:="fire_imp" if role=="murloc" else "obsidian_shell"
					frame(n,load("res://assets/molten_art/characters/"+id+"/"+id+".tres"),"idle",Vector2(80,112) if role=="murloc" else Vector2(96,112))
				elif role=="murloc": actor(n,"murloc")
				else:
					var d:Dictionary=library.actors.kobold
					frame(n,library.resource("characters/kobold/kobold.tres"),"idle",Vector2(d.pivot_px[0],d.pivot_px[1]),d.density)
			"reward_block":
				if chapter.begins_with("3"): molten_item(n,"block_fragile" if n.kind=="fragile" else ("block_strong" if n.kind=="empty" else "block_chest"))
				else: forest_object(n,"fragile" if n.kind=="fragile" else ("solid" if n.kind=="empty" else ("chest_coin" if n.kind=="coins" else "chest_bonus")))
			"test_platform":
				n.queue_redraw()
				markers.append([n,Rect2(n.position,n.size)])
				if chapter.begins_with("3"):
					if n.size.y>28:
						var holder:=Node2D.new();holder.name="__TerrainPreview";n.add_child(holder)
						holder.add_child(preload("res://scripts/visual/molten_surface.gd").new())
						# Holder follows the real platform; removed at the next rebuild.
						holder.set_meta("editor_preview",true)
						auxiliary.append(holder)
					else: deck(n)
			"ferry": deck(n)
			"pipe":
				if chapter.begins_with("3"): molten_item(n,"pipe_"+n.mode)
				else: forest_object(n,"pipe_"+n.mode)
			"spikes":
				if chapter.begins_with("3"): molten_item(n,"spikes")
				else: forest_object(n,"spikes")
			"molten_hazard":
				markers.append([n,Rect2(n.position-Vector2(n.width/2,n.height),Vector2(n.width,n.height))])
	if level.has_node("Scenery"):
		for n in level.get_node("Scenery").get_children():
			if n is Sprite2D: markers.append([n,Rect2(n.position+n.offset*n.scale,n.texture.get_size()*n.scale)])
			elif n is Node2D and n.get_child_count()>0:
				var box:=Rect2()
				for sprite in n.get_children():
					if sprite is Sprite2D:
						var part:=Rect2(n.position+sprite.position+sprite.offset*sprite.scale,sprite.texture.get_size()*sprite.scale)
						box=part if not box.has_area() else box.merge(part)
				markers.append([n,box])
	signature=state_key()
func molten_item(n:Node2D,id:String) -> void:
	var d:Dictionary=library.registry[id]
	var sprite:=Sprite2D.new()
	sprite.texture=library.resource(d.file)
	sprite.centered=false
	sprite.scale=Vector2(d.world_units[0],d.world_units[1])/sprite.texture.get_size()
	sprite.offset=-Vector2(d.anchor_world[0],d.anchor_world[1])/sprite.scale
	sprite.position=Vector2.ZERO
	n.add_child(sprite)
	n.set_meta("_edit_group_",true)
	auxiliary.append(sprite)
	markers.append([n,Rect2(n.position+sprite.offset*sprite.scale,sprite.texture.get_size()*sprite.scale)])
func deck(n:Node2D) -> void:
	if chapter.begins_with("3"):
		var view=preload("deck.gd").new()
		view.library=library;view.object=n;view.position=n.position;add_child(view)
	else: forest_object(n,"ferry_oak")
	markers.append([n,Rect2(n.position-Vector2(64,11),Vector2(128,22))])
func pick(at:Vector2):
	var found=null
	var area:=INF
	for entry in markers:
		var box:Rect2=entry[1]
		if box.grow(3).has_point(at) and box.get_area()<area: found=entry[0];area=box.get_area()
	return found
