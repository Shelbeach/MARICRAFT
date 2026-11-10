extends CharacterBody2D
signal visual_event(kind:String)

enum State { PATROL, HIDDEN, ROLLING }
@export var reward_id := ""
@export var patrol_width := 64.0
var state := State.PATROL
var direction := 1
var wake_in := 0.0
var dead := false
var kick_clear := false
var kicker:Node2D
var kick_age := 0.0
const TURN_SECONDS := 0.25
var patrol_turn := 0.0
var turn_from := 1
@onready var origin := position.x

func turn_patrol() -> void:
	turn_from=direction
	direction=-direction
	patrol_turn=TURN_SECONDS

func set_height(h: float) -> void:
	$Hitbox.shape.size.y = h
	$Hitbox.position.y = -h/2
	queue_redraw()

func defeat() -> void:
	if dead: return
	dead = true
	SFX.play("enemy_pop",self,"death")
	visual_event.emit("death" if state==State.PATROL else "hat_collision")
	Campaign.reward(reward_id,0,100,true)
	queue_free()

func magic_hit() -> void:
	if state != State.ROLLING: defeat()

func push_hat(actor) -> void:
	if dead or state!=State.HIDDEN: return
	SFX.play("hat_kick",self)
	state = State.ROLLING
	direction = 1 if actor.position.x < position.x else -1
	kicker=actor
	kick_age=0.0
	kick_clear=false
	Campaign.reward(reward_id,0,100,true)
	queue_redraw()

func retire_hat() -> void:
	# Mark synchronously: other hats in this physics tick must see a consumed object.
	if dead: return
	dead=true
	visual_event.emit("hat_collision")
	$Hitbox.set_deferred("disabled",true)
	queue_free()

func _physics_process(delta: float) -> void:
	if dead or not Campaign.active(): return
	if state == State.HIDDEN:
		wake_in -= delta
		if wake_in <= 0:
			state = State.PATROL
			origin = position.x
			set_height(32)
	patrol_turn=maxf(0,patrol_turn-delta)
	if state == State.PATROL and is_on_floor() and patrol_turn<=0:
		var tip := global_position + Vector2(direction*21,-5)
		var floor_ray := PhysicsRayQueryParameters2D.create(tip,tip+Vector2.DOWN*22,1)
		if (position.x-origin)*direction >= patrol_width or get_world_2d().direct_space_state.intersect_ray(floor_ray).is_empty():
			turn_patrol()
	velocity.x = direction * [54,0,256][state]
	if state==State.PATROL and patrol_turn>0: velocity.x=0
	velocity.y = minf(480,velocity.y+960*delta)
	move_and_slide()
	# Only the wall actually opposing this move can turn us. An endpoint/edge
	# decision and a stale wall contact must never cancel each other in one tick.
	if is_on_wall() and get_wall_normal().x*direction<0:
		if state==State.PATROL and patrol_turn<=0: turn_patrol()
		elif state==State.ROLLING: direction=-direction
	if position.y>620:
		queue_free()
		return
	if state == State.ROLLING:
		kick_age+=delta
		strike_enemies()
		return
	var actor = get_parent().player
	var h: float = $Hitbox.shape.size.y
	if actor.recovering>0 or absf(actor.position.x-position.x)>=27 or actor.position.y<position.y-h or actor.position.y-actor.height>=position.y:
		return
	if actor.velocity.y>0 and actor.previous_feet<=position.y-h+5:
		actor.velocity.y = -345
		if state == State.PATROL:
			state = State.HIDDEN
			SFX.play("enemy_pop",self)
			wake_in = 5.0
			# The wick rises to 27 px and catches a horizontal bolt from the tall hero.
			set_height(27)
	elif state == State.HIDDEN:
		push_hat(actor)
	else:
		actor.damage()

func strike_enemies() -> void:
	var actor=get_parent().player
	var overlaps:bool=absf(actor.position.x-position.x)<27 and actor.position.y>position.y-27 and actor.position.y-actor.height<position.y
	if not overlaps: kick_clear=true
	# The initial push is not itself a hit. Once separated, even the kicker is at risk.
	if overlaps and (kick_clear or kick_age>0.12 or actor!=kicker):
		actor.damage()
		retire_hat()
		return
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = $Hitbox.shape
	q.transform = $Hitbox.global_transform
	q.collision_mask = 4
	q.exclude = [get_rid()]
	var contacts:=get_world_2d().direct_space_state.intersect_shape(q)
	contacts.sort_custom(func(a,b): return absf(a.collider.position.x-position.x)<absf(b.collider.position.x-position.x))
	for hit in contacts:
		var enemy = hit.collider
		if enemy.is_queued_for_deletion() or enemy.get("dead")==true: continue
		if enemy.has_method("phase"):
			retire_hat()
			return
		if enemy.has_method("retire_hat") and enemy.state == State.ROLLING:
			SFX.play("enemy_pop",self,"hat_collision")
			enemy.retire_hat()
			retire_hat()
			return
		if enemy.has_method("defeat"):
			enemy.defeat()
			retire_hat()
			return

func _draw() -> void:
	if has_meta("location2_skin"): return
	var crown := -26 if state==State.PATROL else -10
	if state==State.PATROL:
		draw_circle(Vector2(0,-14),14,Color("#aa7d6b"))
		draw_colored_polygon(PackedVector2Array([Vector2(direction*9,-22),Vector2(direction*22,-10),Vector2(direction*8,-10)]),Color("#dfaa82"))
		draw_rect(Rect2(-12,-9,24,5),Color("#59414a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18,crown+8),Vector2(-12,crown-4),Vector2(8,crown-6),Vector2(18,crown+8)]),Color("#d09553"))
	draw_line(Vector2(-18,crown+8),Vector2(18,crown+8),Color("#523b3e"),3)
	draw_rect(Rect2(-4,crown-12,6,10),Color("#f1d5a3"))
	draw_circle(Vector2(0,crown-15),3,Color("#ffb344"))
