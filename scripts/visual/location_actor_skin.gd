extends Node2D
const Sprite:=preload("res://scripts/visual/location_sprite.gd")
var library
var actor
var art:=Sprite.new()
var role:=""
var previous_direction:=1.0
var turn_from:=1.0
var turn_time:=0.0
var override_time:=0.0
var override_clip:=""
var previous_mode:=-1
var last_x:=0.0
var engaged:=false
var dust_time:=0.0
var death_floor:=0.0
var death_face:=1.0
var corpse:=preload("res://scripts/visual/corpse_pose.gd").new()
var frame_delta:=0.0

func _ready() -> void:
	process_physics_priority=1
	actor=get_parent()
	role=actor.get_script().resource_path.get_file().get_basename()
	art.library=library
	add_child(art)
	art.set_actor("kobold" if role=="kobold" else "foreman")
	actor.visual_event.connect(on_event)
	last_x=actor.position.x
	if role=="kobold": previous_direction=actor.direction

func effects(): return actor.get_parent().get_node("LocationArt/Effects")

func on_event(event:String) -> void:
	if role=="kobold":
		if event=="hat_collision":
			effects().spawn("enemy_disappear",actor.global_position)
		if event=="death":
			effects().actor_ending("kobold","death",actor.global_position,actor.direction)
			effects().spawn("enemy_disappear",actor.global_position)
		return
	if event=="death":
		death_face=art.scale.x
		var ray:=PhysicsRayQueryParameters2D.create(actor.global_position+Vector2(0,-2),actor.global_position+Vector2(0,160),1)
		var ground:Dictionary=actor.get_world_2d().direct_space_state.intersect_ray(ray)
		death_floor=ground.position.y-actor.global_position.y if not ground.is_empty() else 0.0
	override_clip={"phase":"phase","death":"death","hit":"hit","deflect":"deflect"}.get(event,"")
	override_time={"phase":0.55,"death":0.8,"hit":0.38,"deflect":0.16}.get(event,0.0)
	if not override_clip.is_empty():
		art.play(override_clip,override_time,true)
		effects().spawn("foreman_"+event,actor.global_position)

func _process(delta:float) -> void:
	frame_delta=delta
	override_time=maxf(0,override_time-delta)
	if role=="kobold": update_kobold(delta)
	else:
		update_foreman()
		queue_redraw()

func _draw() -> void:
	if role!="candle_foreman" or actor.mode!=actor.Mode.DEAD: return
	# Contact shadow is fixed to the floor, independent of the ending pose or camera.
	var shadow:=PackedVector2Array()
	for i in 25:
		var angle:=TAU*i/24.0
		shadow.append(Vector2(cos(angle)*49+death_face*5,death_floor+1+sin(angle)*3))
	draw_colored_polygon(shadow,Color(0.08,0.045,0.03,0.38))

func _physics_process(_delta:float) -> void:
	if role=="kobold" and actor.patrol_turn<=0: art.face(actor.direction)

func update_kobold(delta:float) -> void:
	if actor.state==actor.State.ROLLING:
		turn_time=0
		art.face(actor.direction)
		art.play("rolling")
		dust_time+=delta
		if dust_time>0.11:
			dust_time=0
			effects().spawn("dust",actor.global_position+Vector2(-actor.direction*15,1))
		return
	if actor.state==actor.State.HIDDEN:
		turn_time=0
		art.face(actor.direction)
		var age:float=5.0-actor.wake_in
		if age<0.1875: art.sample("stomp",age/0.1875)
		elif age<0.4375: art.sample("hide",(age-0.1875)/0.25)
		elif actor.wake_in<=0.35: art.sample("wake",1.0-actor.wake_in/0.35)
		else: art.play("hidden")
		return
	# The short turn is stationary. Reflect at the frontal pose, then walk forward.
	if actor.patrol_turn>0:
		var progress:float=1.0-actor.patrol_turn/actor.TURN_SECONDS
		art.face(actor.turn_from if progress<0.5 else actor.direction)
		art.sample("turn",progress)
		return
	previous_direction=actor.direction
	art.face(actor.direction)
	art.play("patrol" if absf(actor.velocity.x)>1 else "idle")
	if art.last_clip=="patrol": art.sprite.speed_scale=absf(actor.velocity.x)/54.0

func update_foreman() -> void:
	if actor.mode==actor.Mode.DEAD:
		art.face(death_face)
		art.play("death")
		# The source's final pose rests on the pickaxe at y=279 (pivot=278).
		# Ground the visible body, not a stale position of the moving visual branch.
		var sole:float=[278,278,278,267,267,267][mini(5,art.sprite.frame)]
		corpse.update(actor,art,sole,278,frame_delta)
		previous_mode=actor.mode
		return
	corpse.reset(art)
	art.position.y=0
	if actor.hp==9 and previous_mode==actor.Mode.DEAD: override_time=0
	if actor.engaged and not engaged and actor.mode==actor.Mode.WATCH and override_time<=0:
		override_clip="alert"
		override_time=minf(0.5,maxf(0.01,actor.clock))
		art.play("alert",override_time,true)
	engaged=actor.engaged
	var player=actor.get_parent().player
	var direction:float=signf(player.position.x-actor.position.x)
	if actor.mode==actor.Mode.WARN: direction=signf(actor.target_x-actor.position.x) if absf(actor.target_x-actor.position.x)>1 else direction
	art.face(direction)
	var attack:String=["fissure","wax","rock"][actor.attack_phase-1]
	var clip:="idle"
	var duration:=0.0
	match actor.mode:
		actor.Mode.WARN:
			clip="move" if absf(actor.position.x-last_x)>0.1 and actor.clock>0.27 else attack+"_prepare"
			duration=0.0 if clip=="move" else maxf(actor.clock,0.05)
		actor.Mode.STRIKE:
			clip=attack+"_strike"
			duration=[0.4,0.76,0.9][actor.attack_phase-1]
		actor.Mode.OPEN:
			clip="guarded" if actor.hits>=2 else ("open" if actor.hits>0 else attack+"_recover")
		actor.Mode.DEAD: clip="death"
	if override_time>0: clip=override_clip
	art.play(clip,duration if override_time<=0 else 0)
	if clip=="move": art.sprite.speed_scale=132.0/78.0
	last_x=actor.position.x
	previous_mode=actor.mode
