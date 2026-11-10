extends StaticBody2D
signal visual_event(kind:String)
const Hazard:=preload("res://scripts/gameplay/molten_hazard.gd")
const Shot:=preload("res://scenes/objects/molten_projectile.tscn")
const MAX_HP := 12
enum Mode { WATCH, WARN, STRIKE, OPEN, DEAD }
enum Attack { FIREBALL, HAMMER, ERUPTION }
@export var reward_id := "3-3/ragnaros"
@export var title := "Рагнарос"
@export var arena_start := 1440.0
@export var engage_x := 1760.0
@onready var home := position
var hp := MAX_HP
var mode := Mode.WATCH
var clock := 0.9
var step := 0
var attack_phase := 1
var attack := Attack.FIREBALL
var marks:Array[float]=[]
var aim := Vector2.LEFT
var hits := 0
var hit_lock := 0.0
var head_armed := true
var engaged := false
var death_age := 0.0
var burst_count:=0
var watch_duration:=0.9

func open_duration() -> float: return 2.2-(attack_phase-1)*0.15
func strike_duration() -> float: return 0.80 if attack==Attack.ERUPTION else 0.65

func phase() -> int: return 1 if hp>8 else (2 if hp>4 else 3)
func in_arena() -> bool:
	if get_parent().arena: return get_parent().arena.active
	return get_parent().player.position.x>=arena_start
func caption() -> String:
	if mode==Mode.DEAD: return "Огонь погас · выход открыт"
	if mode==Mode.OPEN: return "Молот застрял · прыгните на головку!" if hits==0 else "Отойдите · молот поднимается"
	if mode in [Mode.WARN,Mode.STRIKE]: return ["Огненный шар · смените высоту","Удар молота · перепрыгните волну","Лава поднимается · выйдите из метки"][attack]
	return "Следите за молотом"

func clear_attacks() -> void:
	for node in get_tree().get_nodes_in_group("molten_attacks"):
		node.set_physics_process(false)
		node.queue_free()
	marks.clear()
	SFX.stop_id("boss_warning",self)
	for id in ["magic_cast","foreman_pickaxe_strike","foreman_wax_burst"]: SFX.stop_id(id,self)

func reset_cycle() -> void:
	clear_attacks()
	engaged=false
	mode=Mode.WATCH
	clock=0.9
	watch_duration=clock
	burst_count=0
	hits=0
	head_armed=true
	hit_lock=0
	position=home
	$Hitbox.set_deferred("disabled",true)

func reset_health() -> void:
	hp=MAX_HP
	step=0
	death_age=0
	reset_cycle()
	get_parent().set_gate(true)
	queue_redraw()

func prepare(actor) -> void:
	# Fired projectiles finish their flight across a combination; a new windup
	# must not erase a ball before it reaches the player's side of the arena.
	marks.clear()
	SFX.stop_id("boss_warning",self)
	engaged=true
	step+=1
	burst_count+=1
	attack_phase=phase()
	# A complete cycle in every phase: learning -> combination -> two locked vents.
	var sequence:Array=[Attack.FIREBALL,Attack.HAMMER,Attack.ERUPTION]
	if attack_phase==2: sequence=[Attack.HAMMER,Attack.ERUPTION,Attack.FIREBALL]
	elif attack_phase==3: sequence=[Attack.ERUPTION,Attack.FIREBALL,Attack.HAMMER]
	attack=sequence[(step-1)%sequence.size()]
	position=Vector2(home.x+(-156 if actor.position.x<home.x else 156),home.y)
	aim=(actor.position-Vector2(0,actor.height*0.5)-(home-Vector2(0,100))).normalized()
	mode=Mode.WARN
	clock=1.05 if attack==Attack.ERUPTION else 0.95
	SFX.play("boss_warning",self)
	if attack==Attack.ERUPTION:
		marks.append(clampf(actor.position.x,arena_start+65,get_parent().finish_x-200))
		if attack_phase==3: marks.append(clampf(actor.position.x+(158 if actor.position.x<home.x else -158),arena_start+65,get_parent().finish_x-200))
		for x in marks:
			var vent:=Hazard.new()
			vent.kind="eruption"
			vent.width=66
			vent.height=132
			vent.warning=clock
			vent.duration=0.75
			vent.one_shot=true
			vent.position=Vector2(x,home.y)
			get_parent().add_child(vent)

func projectile(at:Vector2,heading:Vector2,wave:=false) -> void:
	var shot:=Shot.instantiate()
	shot.position=at
	shot.direction=heading
	shot.wave=wave
	shot.lifetime=4.8
	get_parent().add_child(shot)

func execute() -> void:
	mode=Mode.STRIKE
	clock=strike_duration()
	SFX.play(["magic_cast","foreman_pickaxe_strike","foreman_wax_burst"][attack],self,null,-3)
	if attack==Attack.FIREBALL: projectile(home-Vector2(0,100),aim)
	elif attack==Attack.HAMMER:
		projectile(position-Vector2(44,8),Vector2.LEFT,true)
		projectile(position+Vector2(44,-8),Vector2.RIGHT,true)
	visual_event.emit("attack")

func magic_hit() -> void:
	if mode==Mode.OPEN and hits<2 and hit_lock<=0 and in_arena():
		hits+=1
		take_damage(1)
	elif hp>0: visual_event.emit("deflect")

func take_damage(amount:int) -> void:
	if hp<=0 or not Campaign.active(): return
	var old_phase:=phase()
	hp=maxi(0,hp-amount)
	hit_lock=0.48
	SFX.play("enemy_pop",self,null,-6)
	if hp==0:
		clear_attacks()
		mode=Mode.DEAD
		death_age=0
		$Hitbox.set_deferred("disabled",true)
		get_parent().set_gate(false)
		Campaign.reward(reward_id,0,10000,true)
	elif old_phase!=phase():
		clear_attacks()
		step=0
		burst_count=0
		mode=Mode.WATCH
		clock=0.55
		watch_duration=clock
		$Hitbox.set_deferred("disabled",true)
	visual_event.emit("death" if hp==0 else "hit")

func contact(actor) -> void:
	var dx:float=actor.position.x-position.x
	if absf(dx)>52: head_armed=true
	if mode!=Mode.OPEN or absf(dx)>=43 or actor.position.y<position.y-64 or actor.position.y-actor.height>=position.y: return
	if actor.velocity.y>0 and actor.previous_feet<=position.y-59:
		if head_armed and hits==0 and hit_lock<=0:
			hits=2
			take_damage(3)
		head_armed=false
		actor.position.y=position.y-65
		actor.velocity=Vector2(-190 if dx<=0 else 190,-375)
		actor.rebound_time=0.28
	else: actor.damage()

func _physics_process(delta:float) -> void:
	if hp<=0:
		death_age=minf(2.0,death_age+delta)
		queue_redraw()
		return
	if not Campaign.active(): return
	var actor=get_parent().player
	if not in_arena() or actor.recovering>0:
		if engaged:
			engaged=false
			reset_cycle()
		return
	# The player first sees the complete silhouette inside the 960-wide camera.
	# Once engaged, the wider arena remains available for dodging and retreat.
	if not engaged and actor.position.x<engage_x: return
	engaged=true
	hit_lock=maxf(0,hit_lock-delta)
	clock-=delta
	match mode:
		Mode.WATCH:
			if clock<=0: prepare(actor)
		Mode.WARN:
			if clock<=0: execute()
		Mode.STRIKE:
			if clock<=0:
				if burst_count<attack_phase:
					mode=Mode.WATCH
					clock=0.18
					watch_duration=clock
					return
				mode=Mode.OPEN
				clock=open_duration()
				hits=0
				head_armed=true
				$Hitbox.set_deferred("disabled",false)
		Mode.OPEN:
			if clock<=0 or (hits>=2 and hit_lock<=0):
				mode=Mode.WATCH
				clock=0.24
				watch_duration=clock
				burst_count=0
				$Hitbox.set_deferred("disabled",true)
	contact(actor)
	queue_redraw()

func _draw() -> void:
	if has_meta("p07_rig"): return
	# P07 will replace this local silhouette, retaining home/hammer anchors and clock.
	var centre:=home-position if is_node_ready() else Vector2.ZERO
	var fade:=1.0-death_age/2.0 if hp<=0 else 1.0
	var top:=-220.0*fade
	var shell:=PackedVector2Array([centre+Vector2(-90,0),centre+Vector2(-66,top*0.55),centre+Vector2(-92,top*0.7),centre+Vector2(-45,top*0.75),centre+Vector2(-30,top),centre+Vector2(9,top*0.9),centre+Vector2(38,top*1.02),centre+Vector2(60,top*0.68),centre+Vector2(90,top*0.62),centre+Vector2(65,top*0.35),centre+Vector2(92,0)])
	draw_colored_polygon(shell,Color("#b94324"))
	if fade>0.05:
		draw_colored_polygon(PackedVector2Array([centre+Vector2(-52,0),centre+Vector2(-34,top*0.55),centre+Vector2(-16,top*0.79),centre+Vector2(13,top*0.7),centre+Vector2(44,top*0.5),centre+Vector2(52,0)]),Color("#ffab42"))
		draw_line(centre+Vector2(-24,top*0.71),centre+Vector2(-8,top*0.69),Color("#fff2b3"),5)
		draw_line(centre+Vector2(8,top*0.69),centre+Vector2(24,top*0.71),Color("#fff2b3"),5)
	var down:=mode in [Mode.STRIKE,Mode.OPEN,Mode.DEAD]
	var hammer_y:=0.0 if down else -95.0
	draw_line(centre+Vector2(0,-100*fade),Vector2(0,hammer_y-35),Color("#573f37"),12)
	draw_rect(Rect2(-32,hammer_y-64,64,64),Color("#282b36"))
	draw_rect(Rect2(-32,hammer_y-64,64,10),Color("#ffe1a0") if mode==Mode.OPEN and hits==0 else Color("#ad7253"))
	draw_rect(Rect2(-25,hammer_y-49,50,34),Color("#94775c"))
	if mode==Mode.WARN and attack==Attack.FIREBALL and not has_meta("p07_warnings"):
		var origin:=centre-Vector2(0,100)
		draw_circle(origin,10,Color("#ffdf8a"))
		draw_line(origin+aim*14,origin+aim*85,Color(1.0,0.78,0.45,0.6),3)
	if mode==Mode.WARN and attack==Attack.HAMMER and not has_meta("p07_warnings"):
		for direction in [-1,1]:
			for i in 4:
				var x:float=direction*(54+i*24)
				draw_colored_polygon(PackedVector2Array([Vector2(x-direction*5,-3),Vector2(x+direction*7,-8),Vector2(x-direction*5,-13)]),Color("#f5c17f"))
