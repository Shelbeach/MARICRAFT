extends Node2D
const Library:=preload("res://scripts/visual/molten_library.gd")
var library:=Library.new()
var level
var gate
func _ready() -> void:
	level=get_parent()
	var effects:=preload("res://scripts/visual/molten_effects.gd").new()
	effects.library=preload("res://scripts/visual/location_art_library.gd").new()
	effects.name="Effects"
	effects.z_index=4
	add_child(effects)
	var backdrop:=preload("res://scripts/visual/molten_backdrop.gd").new()
	backdrop.level=level
	backdrop.library=library
	backdrop.z_index=-90
	add_child(backdrop)
	var decor:=preload("res://scripts/visual/molten_decor.gd").new()
	decor.level=level
	decor.library=library
	decor.z_index=-8
	add_child(decor)
	if level.boss:
		var presentation:=preload("res://assets/p07_v03/visual/controller_adapter.tscn").instantiate()
		presentation.name="RagnarosPresentation"
		presentation.z_index=-3
		# Sibling of the moving physical head; body stays anchored to home.
		level.add_child(presentation)
		presentation.bind_controller(level.boss)
		level.boss.set_meta("p07_rig",true)
		level.boss.queue_redraw()
		if not level.arena:
			gate=library.resource("objects/gate_view.tscn").instantiate()
			gate.gate_height=480
			gate.position=Vector2(level.get_node("Gate").position.x,480)
			add_child(gate)
		var warning:=preload("res://scripts/visual/molten_boss_warning.gd").new()
		warning.boss=level.boss
		warning.library=library
		warning.z_index=5
		add_child(warning)
	for object in level.get_children(): attach(object)
	level.child_entered_tree.connect(func(node): attach.call_deferred(node))
	z_index=-2
func attach(object:Node) -> void:
	if not is_instance_valid(object) or object.is_queued_for_deletion() or not object.is_inside_tree() or not object.get_script() or object.has_meta("forest_skin"): return
	var role:String=object.get_script().resource_path.get_file().get_basename()
	var skin:Node2D
	match role:
		"forest_player": skin=preload("res://scripts/visual/actor_skin.gd").new()
		"murloc","kobold": skin=preload("res://scripts/visual/molten_actor_skin.gd").new()
		"pickup": skin=preload("res://scripts/visual/object_skin.gd").new()
		"molten_hazard": skin=preload("res://scripts/visual/molten_hazard_skin.gd").new(); skin.library=library
		"test_platform","ferry","pipe","spikes","bolt","reward_block","molten_projectile","imp_projectile":
			skin=preload("res://scripts/visual/molten_object_skin.gd").new()
			skin.library=library
		_: return
	object.set_meta("forest_skin",true)
	object.set_meta("location2_skin",true)
	object.queue_redraw()
	skin.name="Skin"
	object.add_child(skin)
func _process(delta:float) -> void:
	if gate: gate.open_progress=move_toward(gate.open_progress,1.0 if level.boss.hp<=0 else 0.0,delta*2)
	queue_redraw()
func _draw() -> void:
	if not level: return
	if level.boss: library.item(self,"arena_dais",Vector2(level.boss.home.x,600))
	library.item(self,"checkpoint_on" if level.checkpoint else "checkpoint_off",Vector2(level.checkpoint_x,482))
	library.item(self,"finish_on" if not level.boss or level.boss.hp<=0 else "finish_off",Vector2(level.finish_x,482))
	var rows:Dictionary={}
	for node in level.get_children():
		if node.has_method("hit_below"):
			var key:=roundi(node.position.y)
			if not rows.has(key): rows[key]=[]
			rows[key].append(node.position.x)
	for y in rows:
		rows[y].sort()
		var xs:Array=rows[y]
		for i in xs.size():
			if i==0 or xs[i]-xs[i-1]>34: library.chain(self,Vector2(xs[i]-11,80),maxf(0,y-96),Color(.6,.56,.6))
			if i==xs.size()-1 or xs[i+1]-xs[i]>34: library.chain(self,Vector2(xs[i]+11,80),maxf(0,y-96),Color(.6,.56,.6))

