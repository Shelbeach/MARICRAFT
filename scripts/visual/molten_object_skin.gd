extends Node2D
var object
var role:=""
var library
var art
var trail_clock:=0.0
var ending_spawned:=false
var shot_scale:=0.42
const WAVE_SCALE:=0.48
func effects(): return object.get_parent().get_node("LocationArt/Effects")
func _ready() -> void:
	object=get_parent()
	role=object.get_script().resource_path.get_file().get_basename()
	if role=="imp_projectile": role="molten_projectile"
	elif role=="molten_projectile": shot_scale=0.672
	if object.has_signal("visual_event"): object.visual_event.connect(on_event)
	if role=="test_platform":
		z_index=-5
		if object.size.y>28: add_child(preload("res://scripts/visual/molten_surface.gd").new())
	elif role=="ferry":
		art=preload("res://assets/p07_v03/visual/ferry.tscn").instantiate()
		add_child(art)
	elif role in ["bolt","molten_projectile"]:
		var family:String="hero_bolt" if role=="bolt" else ("boss_wave" if object.wave else "boss_projectile")
		art=library.resource("effects/"+family+"/"+family+".tscn").instantiate()
		add_child(art)
		art.play("flight" if role=="bolt" else "active")
		if role=="molten_projectile":
			# Larger flame and wake; the existing 12x12 damage core is unchanged.
			art.scale=Vector2.ONE*(WAVE_SCALE if object.wave else shot_scale)
			# Anchor the bright core, rather than the decorative tail.
			art.sprite.offset=-Vector2(230,168) if object.wave else -Vector2(145,80)
			if object.wave:
				art.face_right(object.direction.x>=0)
				art.position.y=6
			else: art.rotation=object.direction.angle()
		object.tree_exiting.connect(projectile_end)
	queue_redraw()
func on_event(event:String) -> void:
	match role:
		"reward_block":
			if event=="break": effects().spawn("block_shards",object.global_position)
			elif event=="open": effects().spawn("chest_reward",object.global_position)
			elif event=="eject": effects().spawn("potion_eject",object.global_position+Vector2(0,-16))
		"bolt":
			ending_spawned=true
			if event in ["enemy","boss"]: effects().make("hero_impacts",event+"_hit",object.global_position,object.direction,Vector2.ONE,true)
			else: effects().make("hero_bolt","fade",object.global_position,object.direction,Vector2.ONE,true)
		"spikes": effects().spawn("spike_contact",object.global_position-Vector2(0,12))
		"pipe": effects().spawn("pipe_"+event,object.global_position-Vector2(0,48))
		"molten_projectile": projectile_end()
func projectile_end() -> void:
	if ending_spawned or not object.is_inside_tree() or not is_instance_valid(object.get_parent()) or object.get_parent().is_queued_for_deletion(): return
	ending_spawned=true
	if role=="molten_projectile":
		var ending=effects().make("boss_wave" if object.wave else "boss_projectile","end",object.global_position,signf(object.direction.x),Vector2.ONE*(WAVE_SCALE if object.wave else shot_scale),true)
		if object.wave and ending:
			ending.sprite.offset=-Vector2(230,168)
			ending.position.y+=6
func _process(delta:float) -> void:
	if role=="bolt":
		art.face_right(object.direction>0)
		trail_clock+=delta
		if trail_clock>=0.10:
			trail_clock=0
			effects().make("hero_bolt","trail",object.global_position-Vector2(8*object.direction,0),object.direction,Vector2.ONE,true)
	if role=="reward_block": position.y=-sin(object.bump/0.18*PI)*4 if object.bump>0 else 0.0
	if role in ["reward_block","pipe","ferry"]: queue_redraw()
func _draw() -> void:
	if not object: return
	match role:
		"test_platform":
			if object.size.y>28: return
			for x in [12.0,object.size.x-12]:
				library.chain(self,Vector2(x,80-object.position.y),object.position.y-80,Color(.6,.57,.62))
				library.item(self,"wall_anchor",Vector2(x,80-object.position.y),Color(.65,.62,.65),0.35)
			library.deck(self,object.size.x,object.get_parent().chapter_level!="3-2")
		"ferry":
			for x in [-52,52]:
				library.chain(self,Vector2(x,80-object.position.y),object.position.y-80,Color(.72,.7,.75))
				library.item(self,"wall_anchor",Vector2(x,80-object.position.y),Color(.7,.68,.7),0.35)
		"pipe": library.cropped(self,"pipe_"+object.mode,Rect2(-40,-48,80,50),Color(.65,.65,.65) if object.mode=="ambush" and object.triggered else Color.WHITE)
		"spikes": library.cropped(self,"spikes",Rect2(-23,-18,46,20))
		"reward_block":
			var id:="block_chest"
			if object.kind=="fragile": id="block_fragile"
			elif object.kind=="empty": id="block_empty" if object.spent else "block_strong"
			elif object.spent: id="block_used"
			library.item(self,id,Vector2.ZERO)

