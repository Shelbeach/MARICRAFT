extends Node2D
const ActorSkin:=preload("res://scripts/visual/actor_skin.gd")
const ObjectSkin:=preload("res://scripts/visual/object_skin.gd")
const Terrain:=preload("res://scripts/visual/forest_terrain.gd")
const Backdrop:=preload("res://scripts/visual/forest_backdrop.gd")
const Effects:=preload("res://scripts/visual/forest_effects.gd")
const Sprite:=preload("res://scripts/visual/art_sprite.gd")
var level
var checkpoint:=Sprite.new()
var gate:Node2D
var gate_opened:=false

func _ready() -> void:
	level=get_parent()
	var effects:=Effects.new()
	effects.name="Effects"
	effects.z_index=4
	add_child(effects)
	var back:=Backdrop.new()
	add_child(back)
	var terrain:=Terrain.new()
	terrain.z_index=-5
	add_child(terrain)
	terrain.setup(level)
	for object in level.get_children(): attach(object)
	level.child_entered_tree.connect(func(node): attach.call_deferred(node))
	checkpoint.position=Vector2(level.checkpoint_x,480)
	checkpoint.z_index=-2
	add_child(checkpoint)
	checkpoint.play("checkpoint_off")
	level.checkpoint_reached.connect(func(): checkpoint.play("checkpoint_on"))
	var finish:=Sprite.new()
	add_child(finish)
	finish.position=Vector2(level.finish_x,480)
	finish.z_index=-2
	finish.play("finish")
	if level.boss and not level.arena:
		gate=Sprite.new()
		add_child(gate)
		gate.position=Vector2(level.get_node("Gate").position.x,480)
		gate.play("gate_closed")

func attach(object: Node) -> void:
	if not is_instance_valid(object) or object.is_queued_for_deletion() or not object.is_inside_tree() or object.has_meta("forest_skin") or object.get_script()==null: return
	var script:String=object.get_script().resource_path.get_file().get_basename()
	var skin:Node2D
	if script in ["forest_player","murloc","boss"]:
		skin=ActorSkin.new()
	elif script in ["pickup","reward_block","bolt","boss_shot","pipe","ferry","spikes"]:
		skin=ObjectSkin.new()
	elif script!="test_platform": return
	object.set_meta("forest_skin",true)
	object.queue_redraw()
	if skin:
		skin.name="Skin"
		object.add_child(skin)

func _process(_delta: float) -> void:
	if gate and level.boss.hp<=0 and not gate_opened:
		gate_opened=true
		gate.play("gate_unlock")
		$Effects.spawn("gate_sparks",gate.global_position-Vector2(0,60))
		gate.sprite.animation_finished.connect(func(): gate.play("gate_open"),CONNECT_ONE_SHOT)

