extends "res://tests/s02_forest.gd"
var rows:={}
func _initialize() -> void: run.call_deferred()
func entry(texture:Texture2D,at:Vector2,extent:Vector2,pivot:Vector2,tint:Color,id:String) -> Dictionary:
	return {"texture":texture.resource_path,"position":[at.x,at.y],"scale":[extent.x/texture.get_width(),extent.y/texture.get_height()],"offset":[-pivot.x*texture.get_width()/extent.x,-pivot.y*texture.get_height()/extent.y],"tint":[tint.r,tint.g,tint.b,tint.a],"id":id}
func forest_item(back,id:String,at:Vector2,tint:Color) -> Dictionary:
	var d:Dictionary=back.Art.environment[id]
	var size:=Vector2(d.world[0],d.world[1])
	return entry(back.Art.resource("environment/"+d.file),at,size,Vector2(size.x/2,size.y),tint,id)
func run() -> void:
	state=root.get_node("Campaign");state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn");await scene_changed;game=current_scene
	for id in ["1-1","1-2","1-3","2-1","2-2","2-3","3-1","3-2","3-3"]:
		await test_level(id)
		rows[id]=[]
		var w=game.world
		if id.begins_with("1"):
			var back=w.get_node("ForestArt").get_child(1)
			for prop in back.props:
				if prop[0] in ["post","stone_post"]: continue
				rows[id].append(forest_item(back,prop[0],prop[1],Color.WHITE))
			for foot in back.trees:
				var tree:={"id":"Oak","position":[foot.x,foot.y],"children":[]}
				tree.children.append(forest_item(back,"oak_trunk",Vector2.ZERO,Color("#a2b8a0")))
				tree.children.append(forest_item(back,"oak_crown",Vector2(2,-204),Color("#a7bc9c")))
				tree.children.append(forest_item(back,"oak_bough",Vector2(35,-174),Color("#a7bc9c")))
				rows[id].append(tree)
		elif id.begins_with("2"):
			var back=w.get_node("LocationArt").backdrop
			for prop in back.props:
				var d:Dictionary=back.library.environment[prop[0]]
				var mine:bool=w.mine_main or (w.cave_left>0 and prop[1].x>=w.cave_left)
				var tint:=Color(.77,.80,.83) if mine else Color(.90,.88,.84)
				if prop[0]=="arena_kiln": tint=Color(.60,.61,.65)
				rows[id].append(entry(back.library.resource(d.file),prop[1],Vector2(d.world_units[0],d.world_units[1]),Vector2(d.anchor_world[0],d.anchor_world[1]),tint,prop[0]))
		else:
			var decor=w.get_node("LocationArt").get_child(2)
			for p in decor.placements:
				var y:float=decor.floor_y(p[1])
				if y>=540: continue
				var d:Dictionary=decor.library.registry[p[0]]
				rows[id].append(entry(decor.library.resource(d.file),Vector2(p[1],y+3),Vector2(d.world_units[0],d.world_units[1])*p[2],Vector2(d.anchor_world[0],d.anchor_world[1])*p[2],Color(.56,.54,.62),p[0]))
	var f:=FileAccess.open("res://reports/temp/final-polish/scenery.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"  "))
	print("SCENERY EXPORTED ",rows.size())
	root.get_node("MusicManager").stop_all();quit()
