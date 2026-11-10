extends Node2D
const Sprite := preload("res://scripts/visual/art_sprite.gd")
var art := Sprite.new()
var aura := Sprite.new()
var dust_time:=0.0
var actor
var level
var role := ""
var last_ground := true
var override_clip := ""
var override_time := 0.0
var previous_hp := 9
var previous_phase := 1
var previous_mode := -1
var flash := false
var previous_direction := 1
var turn_from := 1
var corpse:=preload("res://scripts/visual/corpse_pose.gd").new()
var frame_delta:=0.0

func _ready() -> void:
	process_physics_priority=1
	actor=get_parent()
	level=actor.get_parent()
	role=actor.get_script().resource_path.get_file().get_basename()
	add_child(art)
	add_child(aura)
	aura.visible=false
	if actor.has_signal("visual_event"): actor.visual_event.connect(on_event)
	if role=="forest_player":
		form_model()
	elif role=="murloc":
		art.set_actor("murloc")
		previous_direction=actor.direction
	else:
		art.set_actor("chief")
		previous_hp=actor.hp
		previous_phase=actor.phase()
		add_child(preload("res://scripts/visual/boss_telegraph.gd").new())

func _physics_process(_delta:float) -> void:
	if role=="murloc": art.face(actor.direction)

func effect(name: String,offset:=Vector2.ZERO) -> void:
	effects().spawn(name,actor.global_position+offset)

func effects():
	return level.get_node("LocationArt/Effects" if level.has_meta("location2_art") else "ForestArt/Effects")

func form_model() -> void:
	var form_name:String=["small","large","magic"][actor.form]
	art.set_actor(Campaign.p.hero+"_"+form_name)

func on_event(kind: String) -> void:
	match kind:
		"shoot":
			override_clip="cast"
			override_time=0.27
			art.play("cast",0.27,true)
		"grow","magic":
			form_model()
			effect("growth" if kind=="grow" else "magic_form",Vector2(0,-actor.height/2))
		"hurt":
			form_model()
			override_clip="hurt"
			override_time=0.25
			effect("form_loss",Vector2(0,-26))
			effect("damage",Vector2(0,-16))
		"head":
			if override_time<=0:
				override_clip="head_hit"
				override_time=0.16
			effect("head_bump",Vector2(0,-actor.height))
		"death":
			effects().actor_ending(art.model,"death",actor.global_position,actor.facing)
		"respawn":
			form_model()
			effect("respawn",Vector2(0,-24))
		"stomp_defeat","magic_defeat":
			effects().actor_ending("murloc",kind,actor.global_position,actor.direction)
			effect("enemy_fade",Vector2(0,-14))

func _process(delta: float) -> void:
	frame_delta=delta
	override_time=maxf(0,override_time-delta)
	dust_time+=delta
	match role:
		"forest_player": update_player()
		"murloc": update_murloc()
		"boss": update_boss()

func update_player() -> void:
	form_model()
	art.face(actor.facing)
	var grounded:bool=actor.is_on_floor()
	var running:bool=absf(actor.velocity.x)>8
	# A planted landing pose cannot move along the floor or mask a new jump.
	if override_clip=="land" and (running or not grounded): override_time=0
	if grounded and not last_ground:
		effect("land_dust")
		if not running and override_time<=0:
			override_clip="land"
			override_time=0.16
	var clip:="idle"
	if running: clip="run"
	if not grounded: clip="jump" if actor.velocity.y<0 else "fall"
	if override_time>0: clip=override_clip
	if Campaign.p.status=="result": clip="victory"
	var was:String=art.sprite.animation
	art.play(clip,{"cast":0.27,"land":0.16,"hurt":0.25,"head_hit":0.16}.get(clip,0.0))
	if clip=="run": art.play_locomotion(clip,actor.velocity.x)
	if clip=="run" and dust_time>0.17:
		dust_time=0
		effect("run_dust",Vector2(-actor.facing*8,0))
	if clip=="jump" and was!="jump": art.sprite.frame=1
	last_ground=grounded

func update_murloc() -> void:
	var clip:="patrol"
	if actor.emerging_from_pipe:
		clip="pipe_emerge"
	previous_direction=actor.direction
	art.face(actor.direction)
	art.play(clip)
	if clip=="patrol": art.play_locomotion(clip,actor.velocity.x)

func update_boss() -> void:
	var phase:int=actor.phase()
	if actor.hp>previous_hp:
		previous_hp=actor.hp
		previous_phase=phase
		override_time=0
	if actor.hp<previous_hp:
		override_clip="death" if actor.hp==0 else ("phase" if phase!=previous_phase else "hit")
		override_time=1.2 if actor.hp==0 else 0.24
		effect("boss_victory" if actor.hp==0 else ("boss_phase" if phase!=previous_phase else "boss_hit"),Vector2(0,-38))
		previous_hp=actor.hp
		previous_phase=phase
	if actor.block_flash>0 and not flash:
		override_clip="deflect"
		override_time=0.18
		effect("boss_deflect",Vector2(0,-40))
	flash=actor.block_flash>0
	var clip:="idle"
	var duration:=0.0
	match actor.mode:
		actor.Mode.WARN:
			clip=["water_warning","dash_warning","leap_warning"][actor.move.kind]
			duration=actor.move.warning
		actor.Mode.ACT:
			clip=["water_release","dash","leap"][actor.move.kind]
			duration=actor.move.execution
		actor.Mode.OPEN:
			clip="open"
			if previous_mode==actor.Mode.ACT and actor.move.kind==actor.LEAP:
				effect("boss_slam")
				override_clip="slam"
				override_time=0.22
		actor.Mode.DEAD: clip="death"
	if override_time>0: clip=override_clip
	art.face(actor.face)
	art.play(clip,duration if override_time<=0 else 0)
	if actor.mode==actor.Mode.DEAD:
		corpse.update(actor,art,234,234,frame_delta)
		queue_redraw()
	else: corpse.reset(art)
	if actor.mode==actor.Mode.ACT and actor.move.kind==actor.DASH and dust_time>0.10:
		dust_time=0
		effect("boss_dash_trail",Vector2(-actor.face*32,-10))
	previous_mode=actor.mode
	aura.visible=actor.hp>0
	if aura.visible:
		aura.position=Vector2(0,-94) if actor.magic_open() else Vector2(0,-40)
		aura.play("boss_open" if actor.magic_open() else "boss_shield")

func _draw() -> void:
	if role!="boss" or actor.hp>0 or not corpse.initialized: return
	var contour:=PackedVector2Array()
	for i in 25:
		var angle:=TAU*i/24
		contour.append(Vector2(cos(angle)*38,corpse.floor_y-actor.global_position.y+1+sin(angle)*3))
	draw_colored_polygon(contour,Color(0.05,0.08,0.06,0.4))
