extends SceneTree
const IDS=["forest_1_1","forest_1_2","forest_1_3","durotar_2_1","durotar_2_2","durotar_2_3","molten_3_1","molten_3_2","molten_3_3"]
var failed:=false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(Engine.is_editor_hint())
	for id in IDS:
		var path:String="res://scenes/levels/"+id+".tscn"
		var hash_before:=FileAccess.get_sha256(path)
		var source:PackedScene=load(path)
		var level=source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		root.add_child(level)
		var view=load("res://addons/maricraft_levels/preview.gd").new()
		view.name="__LevelPreview"
		level.add_child(view);view.build()
		await process_frame
		await process_frame
		var coin
		for n in level.get_children():
			if n.get("kind")=="coin": coin=n;break
		assert(coin!=null)
		var moved:Vector2=coin.position+Vector2(16,0)
		coin.position=moved
		var packed:=PackedScene.new()
		assert(packed.pack(level)==OK)
		var target:="res://reports/temp/camera-repair/editor-probe.tscn"
		assert(ResourceSaver.save(packed,target)==OK)
		var check:PackedScene=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var content:=FileAccess.get_file_as_string(target)
		var state:=check.get_state()
		var found:=false
		for i in state.get_node_count():
			if str(state.get_node_name(i))!=str(coin.name): continue
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i,j)=="position": found=state.get_node_property_value(i,j)==moved
		var okay:=found and not "__LevelPreview" in content and not "__TerrainPreview" in content and FileAccess.get_sha256(path)==hash_before
		print("PASS " if okay else "FAIL ",id," editor preview + save/reload; source untouched")
		failed=failed or not okay
		level.queue_free()
		await process_frame
		await process_frame
	quit(1 if failed else 0)
