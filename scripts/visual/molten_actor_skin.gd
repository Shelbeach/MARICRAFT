extends Node2D
var actor
var art
var model:String
var last_direction:=1.0
var turn_age:=1.0
var charge

func _ready() -> void:
	actor=get_parent()
	model="obsidian_shell" if actor.get_script().resource_path.ends_with("kobold.gd") else "fire_imp"
	art=load("res://assets/molten_art/characters/"+model+"/"+model+".tscn").instantiate()
	add_child(art)
	last_direction=actor.direction
	actor.visual_event.connect(on_event)
	if model=="fire_imp" and actor.ranged:
		charge=load("res://assets/molten_art/effects/boss_projectile/boss_projectile.tscn").instantiate()
		charge.scale=Vector2.ONE*0.22
		add_child(charge)

func effects(): return actor.get_parent().get_node("LocationArt/Effects")

func on_event(event:String) -> void:
	if event in ["stomp_defeat","magic_defeat","death","hat_collision"]:
		effects().actor_ending(model,"shell_collision" if event=="hat_collision" else event,actor.global_position,actor.direction)

func _process(delta:float) -> void:
	art.face_right(actor.direction>0)
	if model=="fire_imp":
		if charge:
			var attack=actor.attack_controller
			last_direction=actor.direction
			art.rotation=0
			art.position=Vector2.ZERO
			charge.visible=attack.mode==attack.Mode.WINDUP
			charge.position=Vector2(actor.direction*22,-20)
			charge.face_right(actor.direction>0)
			if charge.visible:
				charge.sample("warning",1.0-attack.clock/attack.WINDUP)
				art.play("idle")
				art.rotation=actor.direction*-0.07*sin((1.0-attack.clock/attack.WINDUP)*PI*0.5)
				return
			if attack.mode==attack.Mode.RECOVER:
				art.play("idle")
				art.position.x=-actor.direction*3.0*sin(attack.clock/0.4*PI)
				return
		if last_direction!=actor.direction: turn_age=0
		last_direction=actor.direction
		turn_age+=delta
		# The imp does not pause in physics: turn faces the NEW velocity immediately.
		if actor.emerging_from_pipe: art.play("pipe_emerge")
		elif actor.patrol_turn>0:
			var progress:float=1.0-actor.patrol_turn/actor.TURN_SECONDS
			art.face_right((actor.turn_from if progress<0.5 else actor.direction)>0)
			art.sample("turn",progress)
		else: art.play("patrol" if absf(actor.velocity.x)>1 else "idle")
		return
	if actor.state==actor.State.ROLLING:
		art.play("rolling")
	elif actor.state==actor.State.HIDDEN:
		var age:float=5-actor.wake_in
		if age<0.1875: art.sample("stomp",age/0.1875)
		elif age<0.4375: art.sample("hide",(age-0.1875)/0.25)
		elif actor.wake_in<=0.35: art.sample("wake",1-actor.wake_in/0.35)
		else: art.play("hidden")
	elif actor.patrol_turn>0:
		var progress:float=1-actor.patrol_turn/actor.TURN_SECONDS
		art.face_right((actor.turn_from if progress<0.5 else actor.direction)>0)
		art.sample("turn",progress)
	else:
		art.play("patrol" if absf(actor.velocity.x)>1 else "idle")
		art.sprite.speed_scale=absf(actor.velocity.x)/54 if absf(actor.velocity.x)>1 else 1.0
