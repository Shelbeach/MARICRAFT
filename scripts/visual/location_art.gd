extends Node2D
const Library:=preload("res://scripts/visual/location_art_library.gd")
const Sprite:=preload("res://scripts/visual/location_sprite.gd")
var library:=Library.new()
var level
var backdrop
var checkpoint:=Sprite.new()
var gate
var gate_opened:=false

func _ready() -> void:
	level=get_parent()
	var effects:=preload("res://scripts/visual/location_effects.gd").new()
	effects.library=library
	effects.name="Effects"
	effects.z_index=4
	add_child(effects)
	backdrop=preload("res://scripts/visual/location_backdrop.gd").new()
	backdrop.library=library
	add_child(backdrop)
	backdrop.setup(level)
	var terrain:=preload("res://scripts/visual/location_terrain.gd").new()
	terrain.name="Terrain"
	terrain.library=library
	terrain.z_index=-5
	add_child(terrain)
	terrain.setup(level)
	for object in level.get_children(): attach(object)
	level.child_entered_tree.connect(func(node): attach.call_deferred(node))
	checkpoint.library=library
	checkpoint.position=Vector2(level.checkpoint_x,481)
	checkpoint.z_index=-2
	add_child(checkpoint)
	checkpoint.play("checkpoint_inactive")
	level.checkpoint_reached.connect(func(): checkpoint.play("checkpoint"))
	var finish:=Sprite.new()
	finish.library=library
	finish.position=Vector2(level.finish_x,481)
	finish.z_index=-2
	add_child(finish)
	finish.play("finish")
	if level.boss and not level.arena:
		gate=Sprite.new()
		gate.library=library
		gate.position=Vector2(level.get_node("Gate").position.x,480)
		add_child(gate)
		gate.play("gate_closed")

func attach(object:Node) -> void:
	if not is_instance_valid(object) or object.is_queued_for_deletion() or not object.is_inside_tree() or object.has_meta("forest_skin") or object.has_meta("location2_skin") or object.get_script()==null: return
	var role:String=object.get_script().resource_path.get_file().get_basename()
	var skin:Node2D
	match role:
		"forest_player","murloc": skin=preload("res://scripts/visual/actor_skin.gd").new()
		"pickup","reward_block": skin=preload("res://scripts/visual/object_skin.gd").new()
		"kobold","candle_foreman": skin=preload("res://scripts/visual/location_actor_skin.gd").new()
		"mine_strike": skin=preload("res://scripts/visual/mine_strike_skin.gd").new()
		"bolt","pipe","ferry","spikes": skin=preload("res://scripts/visual/location_object_skin.gd").new()
		"test_platform": pass
		_: return
	object.set_meta("forest_skin",true)
	object.set_meta("location2_skin",true)
	object.queue_redraw()
	if skin:
		if skin.get("library")!=null or role in ["kobold","candle_foreman","mine_strike","bolt","pipe","ferry","spikes"]: skin.library=library
		skin.name="Skin"
		object.add_child(skin)

func redraw_backdrop() -> void: backdrop._process(0)

func _process(_delta:float) -> void:
	if gate and level.boss.hp<=0 and not gate_opened:
		gate_opened=true
		gate.play("gate_opening")
	elif gate and level.boss.hp>0 and gate_opened:
		gate_opened=false
		gate.play("gate_closed")
