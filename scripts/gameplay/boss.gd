extends StaticBody2D

const Move := preload("res://scripts/gameplay/boss_move.gd")
const SHOT := preload("res://scenes/objects/boss_shot.tscn")
enum Mode { WATCH, WARN, ACT, OPEN, DEAD }
const WATER := 0
const DASH := 1
const LEAP := 2
const MAX_HP := 9

@export var title := "Вожак мурлоков"
@export var reward_id := ""
@export var opening: Move
@export var rush: Move
@export var breaker: Move
@export var roam_limit := 104.0
@onready var home := position
var mode := Mode.WATCH
var move: Move
var hp := 9
var time_left := 0.85
var hurt_lock := 0.0
var block_flash := 0.0
var hits_in_window := 0
var shots_fired := 0
var deflections := 0
var next_water := false
var head_armed := true
var projectile_shape := RectangleShape2D.new()
var alert := false
var clear_lane := false
var aim := Vector2.LEFT
var launch := Vector2.ZERO
var landing := Vector2.ZERO
var face := -1.0

func _ready() -> void:
	var sample:=SHOT.instantiate()
	projectile_shape=sample.get_node("Hitbox").shape.duplicate()
	projectile_shape.size=Vector2(18,18)
	sample.free()

func phase() -> int:
	return 1 if hp>6 else (2 if hp>3 else 3)

func in_arena() -> bool:
	if get_parent().arena: return get_parent().arena.active
	var actor=get_parent().player
	var on_screen:=get_viewport().get_visible_rect().grow(-36).has_point(get_global_transform_with_canvas().origin-Vector2(0,38))
	return absf(actor.position.x-home.x)<420 and on_screen

func magic_open() -> bool:
	return mode==Mode.OPEN and clear_lane and hits_in_window<2 and hurt_lock<=0

func caption() -> String:
	match mode:
		Mode.WARN: return ["Целится","Готовит рывок","Готовит волну"][move.kind]
		Mode.ACT: return ["Выстрел","Рывок","Прыжок"][move.kind]
		Mode.OPEN:
			if magic_open(): return "Атакуйте!"
			if not clear_lane: return "Цель за укрытием"
			if block_flash>0: return "Болт отражён"
			return "Щит восстановлен" if hits_in_window>=2 else "Защита после удара"
	return "Щит поднят"

func reset_health() -> void:
	SFX.stop_id("boss_warning",self)
	hp=9
	mode=Mode.WATCH
	alert=false
	next_water=false
	head_armed=true
	position=home
	time_left=0.85
	hurt_lock=0
	hits_in_window=0
	$Hitbox.set_deferred("disabled",false)
	get_parent().set_gate(true)
	clear_shots()
	queue_redraw()

func clear_shots() -> void:
	for id in ["murloc_water_cast","murloc_dash","murloc_slam"]: SFX.stop_id(id,self)
	for shot in get_tree().get_nodes_in_group("boss_shots"):
		shot.queue_free()

func magic_hit() -> void:
	if magic_open():
		hits_in_window+=1
		take_damage(1)
	elif hp>0:
		deflections+=1
		block_flash=0.21
	queue_redraw()

func take_damage(amount: int) -> void:
	if hp<=0 or not Campaign.active(): return
	var previous_phase:=phase()
	var old_hp:=hp
	hp=maxi(0,hp-amount)
	if hp<old_hp: SFX.play("enemy_pop",self,null,-6)
	hurt_lock=0.58
	if hp==0:
		SFX.stop_id("boss_warning",self)
		mode=Mode.DEAD
		$Hitbox.set_deferred("disabled",true)
		get_parent().set_gate(false)
		Campaign.reward(reward_id,0,10000,true)
		clear_shots()
	elif phase()!=previous_phase:
		# Never skip the next phase's demonstration by firing into an old window.
		mode=Mode.WATCH
		time_left=0.8
		next_water=false
	queue_redraw()

func prepare(actor) -> void:
	move=opening
	if phase()>1 and not next_water:
		move=rush if phase()==2 else breaker
	next_water=not next_water if phase()>1 else false
	face=1.0 if actor.position.x>position.x else -1.0
	launch=position
	landing=Vector2(clampf(launch.x+face*move.travel,home.x-roam_limit,home.x+roam_limit),home.y)
	mode=Mode.WARN
	SFX.play("boss_warning",self)
	time_left=move.warning
	aim=(actor.position-Vector2(0,actor.height/2)-muzzle()).normalized()

func muzzle() -> Vector2:
	return position-Vector2(0,48)

func fire(origin: Vector2, bearing: Vector2, wave:=false) -> void:
	var shot:=SHOT.instantiate()
	shot.position=origin
	shot.direction=bearing
	shot.wave=wave
	get_parent().add_child(shot)
	if not wave: SFX.play("murloc_water_cast",self)
	shots_fired+=1

func act(delta: float) -> void:
	time_left=maxf(0,time_left-delta)
	var t:=1.0-time_left/move.execution
	position=launch.lerp(landing,t)
	position.y-=move.arc_height*4*t*(1-t)
	if time_left>0: return
	if move.kind==LEAP:
		SFX.play("murloc_slam",self)
		for direction in [Vector2.LEFT,Vector2.RIGHT]:
			fire(position+Vector2(0,-10),direction,true)
	mode=Mode.OPEN
	time_left=move.recovery
	hits_in_window=0

func contact(actor) -> void:
	var dx:float=actor.position.x-position.x
	if absf(dx)>52: head_armed=true
	if absf(dx)>=42 or actor.position.y<position.y-76 or actor.position.y-actor.height>=position.y: return
	if actor.velocity.y>0 and actor.previous_feet<=position.y-73:
		if head_armed and magic_open():
			take_damage(3)
			hits_in_window=2
		head_armed=false
		actor.position.y=position.y-77
		var away:= -1 if dx<=0 else 1
		actor.velocity=Vector2(away*200,-420)
		actor.rebound_time=0.28
	else:
		actor.damage()

func _physics_process(delta: float) -> void:
	if hp<=0 or not Campaign.active(): return
	var actor=get_parent().player
	hurt_lock=maxf(0,hurt_lock-delta)
	block_flash=maxf(0,block_flash-delta)
	if not in_arena() or actor.recovering>0:
		if alert:
			alert=false
			clear_shots()
			position=home
			mode=Mode.WATCH
			next_water=false
			head_armed=true
			time_left=0.85
			queue_redraw()
		return
	alert=true
	var sight:=PhysicsShapeQueryParameters2D.new()
	sight.shape=projectile_shape
	sight.transform.origin=muzzle()
	sight.motion=actor.position-Vector2(0,actor.height/2)-muzzle()
	sight.collision_mask=1
	clear_lane=get_world_2d().direct_space_state.cast_motion(sight)[0]>=1.0
	time_left-=delta if mode!=Mode.ACT else 0.0
	match mode:
		Mode.WATCH:
			var patrol_x:=clampf(actor.position.x,home.x-30,home.x+30)
			position.x=move_toward(position.x,patrol_x,26*delta)
			if time_left<=0: prepare(actor)
		Mode.WARN:
			if move.kind==WATER and time_left>0.24:
				aim=(actor.position-Vector2(0,actor.height/2)-muzzle()).normalized()
			if time_left<=0:
				mode=Mode.ACT
				time_left=move.execution
				if move.kind==WATER: fire(muzzle(),aim)
				elif move.kind==DASH: SFX.play("murloc_dash",self)
		Mode.ACT: act(delta)
		Mode.OPEN:
			if time_left<=0:
				mode=Mode.WATCH
				time_left=0.65
	contact(actor)
	queue_redraw()

func _draw() -> void:
	if has_meta("forest_skin"): return
	if hp==0:
		draw_rect(Rect2(-29,-9,58,9),Color("#697675"))
		return
	var open:=magic_open()
	var tint:=Color("#d99168") if open else Color("#638ca5")
	var crouch:=7.0 if mode==Mode.WARN else 0.0
	draw_rect(Rect2(-30,-76+crouch,60,76-crouch),tint)
	for x in [-27,-7,13]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,-76+crouch),Vector2(x-3,-89+crouch),Vector2(x+13,-76+crouch)]),Color("#f3b989"))
	draw_rect(Rect2(-23,-56+crouch,46,8),Color("#4b3942"))
	if not open:
		draw_arc(Vector2(0,-40),48,0,TAU,48,Color.WHITE if block_flash>0 else Color("#96dcf2"),4,true)
	else:
		draw_line(Vector2(-15,-91),Vector2(15,-91),Color("#ffdc80"),4)
	if mode==Mode.WARN:
		var ink:=Color("#ffce7c")
		if move.kind==WATER:
			draw_dashed_line(Vector2(0,-48),Vector2(0,-48)+aim*135,ink,3,9)
		else:
			draw_line(Vector2.ZERO,landing-position,ink,4)
			draw_arc(landing-position,19,PI,TAU,16,ink,3)
			if move.kind==LEAP: draw_arc(landing-position,30,PI,TAU,20,ink,2)
	draw_rect(Rect2(-32,-104,64,5),Color("#402e38"))
	draw_rect(Rect2(-32,-104,64*hp/9.0,5),Color("#ffc785"))
