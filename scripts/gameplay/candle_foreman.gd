extends StaticBody2D
signal visual_event(kind:String)

const Strike := preload("res://scripts/gameplay/mine_strike.gd")
const MAX_HP := 9
enum Mode { WATCH, WARN, STRIKE, OPEN, DEAD }
@export var reward_id := "2-3/foreman"
@export var title := "Главарь кобольдов"
@export var arena_start := 1430.0
@onready var home := position
var hp := 9
var mode := Mode.WATCH
var clock := 0.55
var step := 0
var target_x := 0.0
var marks: Array[float] = []
var hits := 0
var hit_lock := 0.0
var head_armed := true
var attack_phase := 1
var engaged := false
var burst_count:=0

func phase() -> int:
	return 1 if hp>6 else (2 if hp>3 else 3)

func in_arena() -> bool:
	if get_parent().arena: return get_parent().arena.active
	return get_parent().player.position.x >= arena_start

func caption() -> String:
	if mode==Mode.OPEN:
		return "Кирка застряла · атакуйте!" if hits<2 else "Главарь прикрывается"
	if mode in [Mode.WARN,Mode.STRIKE]:
		return ["Перепрыгните разлом","Выйдите из воска","Два обвала · смените место"][attack_phase-1]
	return "Поднимает кирку"

func clear_marks() -> void:
	for id in ["foreman_pickaxe_strike","foreman_wax_burst","foreman_rockfall"]: SFX.stop_id(id)
	for strike in get_tree().get_nodes_in_group("mine_strikes"): strike.queue_free()
	marks.clear()

func reset_cycle() -> void:
	SFX.stop_id("boss_warning",self)
	clear_marks()
	mode=Mode.WATCH
	clock=0.55
	burst_count=0
	hits=0
	head_armed=true

func reset_health() -> void:
	hp=9
	step=0
	position=home
	reset_cycle()
	$Hitbox.set_deferred("disabled",false)
	get_parent().set_gate(true)
	queue_redraw()

func mark(x: float,kind: int,w: float,warn: float,active: float) -> void:
	var strike:=Strike.new()
	strike.kind=kind
	strike.warning=warn
	strike.duration=active
	strike.half_width=w
	# A fissure belongs to the surface under the target, including raised plinths.
	# Lock this floor height at warning time; jumping away remains a fair response.
	var actor=get_parent().player
	var ray:=PhysicsRayQueryParameters2D.create(Vector2(x,minf(actor.position.y-2,home.y-2)),Vector2(x,home.y+90),1)
	var floor_hit:=get_world_2d().direct_space_state.intersect_ray(ray)
	strike.position=Vector2(x,floor_hit.position.y if not floor_hit.is_empty() else home.y)
	get_parent().add_child(strike)
	strike.add_to_group("mine_strikes")
	marks.append(x)

func prepare(actor) -> void:
	clear_marks()
	step+=1
	burst_count+=1
	attack_phase=phase()
	mode=Mode.WARN
	SFX.play("boss_warning",self)
	clock=[0.90,0.96,1.04][attack_phase-1]
	var x:float=actor.position.x
	# Close the distance on the side chosen by the player; counterattack requires
	# repositioning instead of repeating jumps at one permanently safe coordinate.
	target_x=home.x+(-140 if x<home.x else 140)
	match attack_phase:
		1: mark(x,Strike.Kind.FISSURE,48,clock,0.36)
		2:
			mark(x,Strike.Kind.WAX,43,clock,0.70)
			# Two locked vents leave a readable corridor; unchanged width/time per vent.
			var inward:=1.0 if x<home.x else -1.0
			mark(clampf(x+inward*160,arena_start+64,get_parent().finish_x-180),Strike.Kind.WAX,43,clock,0.70)
		3:
			mark(x,Strike.Kind.ROCK,40,clock,0.36)
			# A second, offset fall has its own visible countdown. Both are locked.
			var inward:=1.0 if x<home.x else -1.0
			mark(x+inward*160,Strike.Kind.ROCK,36,clock+0.45,0.40)

func magic_hit() -> void:
	if mode==Mode.OPEN and hits<2 and hit_lock<=0 and in_arena():
		hits+=1
		take_damage(1)
	elif hp>0:
		visual_event.emit("deflect")

func take_damage(amount: int) -> void:
	if hp<=0 or not Campaign.active(): return
	var old_phase:=phase()
	var old_hp:=hp
	hp=maxi(0,hp-amount)
	if hp<old_hp: SFX.play("enemy_pop",self,null,-6)
	hit_lock=0.38
	if hp==0:
		SFX.stop_id("boss_warning",self)
		clear_marks()
		mode=Mode.DEAD
		$Hitbox.set_deferred("disabled",true)
		get_parent().set_gate(false)
		Campaign.reward(reward_id,0,10000,true)
	elif old_phase!=phase():
		clear_marks()
		burst_count=0
		mode=Mode.WATCH
		clock=0.55
	visual_event.emit("death" if hp==0 else ("phase" if old_phase!=phase() else "hit"))
	queue_redraw()

func contact(actor) -> void:
	var dx:float=actor.position.x-position.x
	if absf(dx)>52: head_armed=true
	if absf(dx)>=43 or actor.position.y<position.y-70 or actor.position.y-actor.height>=position.y: return
	if actor.velocity.y>0 and actor.previous_feet<=position.y-65:
		if head_armed and mode==Mode.OPEN and hits==0:
			hits=2
			take_damage(3)
		head_armed=false
		actor.position.y=position.y-71
		actor.velocity=Vector2(-202 if dx<=0 else 202,-410)
		actor.rebound_time=0.30
	else:
		actor.damage()

func _physics_process(delta: float) -> void:
	if hp<=0 or not Campaign.active(): return
	var actor=get_parent().player
	if not in_arena() or actor.recovering>0:
		if engaged:
			engaged=false
			reset_cycle()
			position=home
			queue_redraw()
		return
	engaged=true
	hit_lock=maxf(0,hit_lock-delta)
	clock-=delta
	match mode:
		Mode.WATCH:
			if clock<=0: prepare(actor)
		Mode.WARN:
			position.x=move_toward(position.x,target_x,132*delta)
			if clock<=0:
				mode=Mode.STRIKE
				clock=[0.40,0.76,0.90][attack_phase-1]
		Mode.STRIKE:
			if clock<=0:
				if burst_count<(1 if attack_phase==1 else 2):
					mode=Mode.WATCH
					clock=0.24
					return
				mode=Mode.OPEN
				hits=0
				clock=[1.95,1.85,1.80][attack_phase-1]
		Mode.OPEN:
			if clock<=0 or (hits>=2 and hit_lock<=0):
				mode=Mode.WATCH
				clock=0.24
				burst_count=0
	contact(actor)
	queue_redraw()

func _draw() -> void:
	if has_meta("location2_skin"): return
	if hp<=0:
		draw_rect(Rect2(-30,-8,60,8),Color("#847060"))
		return
	var open:=mode==Mode.OPEN and hits<2
	var coat:=Color("#ba8360") if open else Color("#81615b")
	draw_colored_polygon(PackedVector2Array([Vector2(-32,0),Vector2(-36,-41),Vector2(-20,-66),Vector2(20,-65),Vector2(36,-40),Vector2(30,0)]),coat)
	draw_rect(Rect2(-32,-24,64,10),Color("#483944"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18,-59),Vector2(-42,-43),Vector2(-13,-42)]),Color("#dba17a"))
	draw_rect(Rect2(-24,-56,8,4),Color("#ffe1a7"))
	draw_line(Vector2(-28,-64),Vector2(25,-64),Color("#e6bc80"),7)
	for i in 3:
		var y:float=[-78,-84,-74][i]
		var x:=i*13-16
		draw_rect(Rect2(x,y,8,-63-y),Color("#f5ce91"))
		draw_circle(Vector2(x+4,y-4),4,Color("#ff9947"))
	var tip:=Vector2(44,-4) if open else Vector2(25,-95)
	draw_line(Vector2(16,-32),tip,Color("#d5ad77"),6)
	draw_line(tip-Vector2(16,3),tip+Vector2(14,5),Color("#b8bec1"),7)
	if open: draw_arc(Vector2(0,-38),42,PI,TAU,20,Color("#8be5be"),3)

