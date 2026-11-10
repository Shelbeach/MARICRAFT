extends SceneTree
const IDS=["forest_1_1","forest_1_2","forest_1_3","durotar_2_1","durotar_2_2","durotar_2_3","molten_3_1","molten_3_2","molten_3_3"]
func _initialize() -> void: run.call_deferred()
func canonical(value):
	if value is Resource: return {"resource":value.resource_path,"type":value.get_class()}
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is PackedVector2Array:
		var result:Array=[]
		for v in value: result.append([v.x,v.y])
		return result
	return value
func inventory() -> Dictionary:
	var result:={}
	for id in IDS:
		var scene:PackedScene=ResourceLoader.load("res://scenes/levels/"+id+".tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var data:=scene.get_state()
		var nodes:={}
		for i in data.get_node_count():
			var path:=str(data.get_node_path(i))
			if path=="./Scenery" or path.begins_with("./Scenery/"): continue
			var record:={"type":data.get_node_type(i),"instance":data.get_node_instance(i).resource_path if data.get_node_instance(i) else "","properties":{}}
			for j in data.get_node_property_count(i):
				var key:=str(data.get_node_property_name(i,j))
				if key.begins_with("metadata/_edit"): continue
				record.properties[key]=canonical(data.get_node_property_value(i,j))
			nodes[path]=record
		result[id]=nodes
	return result
func run() -> void:
	var current:=inventory()
	# Run the historical inventory in a separate process with --main-pack.
	# This keeps old and current script/resource caches completely independent.
	if "--accepted" in OS.get_cmdline_user_args():
		FileAccess.open("D:/Projects/MARICRAFT/reports/evidence/camera-repair/scene-accepted.json",FileAccess.WRITE).store_string(JSON.stringify(current,"  "))
		print("ACCEPTED PCK INVENTORY: 9 scenes")
		quit();return
	var accepted:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/evidence/camera-repair/scene-accepted.json"))
	var differences:Array=[]
	for id in IDS:
		for node in accepted[id]:
			if node=="./Scenery" or node.begins_with("./Scenery/"):continue
			if not current[id].has(node): differences.append({"level":id,"node":node,"kind":"removed"})
			elif JSON.stringify(accepted[id][node])!=JSON.stringify(current[id][node]): differences.append({"level":id,"node":node,"kind":"changed","accepted":accepted[id][node],"current":current[id][node]})
		for node in current[id]:
			if not accepted[id].has(node): differences.append({"level":id,"node":node,"kind":"added"})
	var file:=FileAccess.open("D:/Projects/MARICRAFT/reports/evidence/camera-repair/scene-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"accepted":accepted,"current":current,"differences":differences},"  "))
	print("SCENE AUDIT: ",differences.size()," differences; details saved to scene-audit.json")
	root.get_node("MusicManager").stop_all()
	quit()
