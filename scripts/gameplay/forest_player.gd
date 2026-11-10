extends CharacterBody2D

signal form_changed
signal visual_event(kind: String)
const BOLT := preload("res://scenes/objects/bolt.tscn")
const SPEED := 160.0
const GRAVITY := 960.0
const JUMP := 490.0
const SHOT_COOLDOWN := 0.60
const FORM_NAMES := ["Малая", "Большая", "Магическая"]
var form := 0
var facing := 1
var protection := 0.0
var recovering := 0.0
var rebound_time := 0.0
var previous_feet := 0.0
var height := 32.0
var spawn_point := Vector2(96, 475)
var shot_cooldown := 0.0

func _ready() -> void:
	apply_form(0)
	$Camera.reset_smoothing()

func apply_form(value: int) -> bool:
	var new_height := 32.0 if value == 0 else 64.0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24,new_height)
	if new_height > height:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = rect
		query.transform.origin = global_position - Vector2(0,new_height/2 + 0.5)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
			return false
	var old_form:=form
	height = new_height
	form = value
	$Hitbox.shape = rect
	$Hitbox.position.y = -height/2
	queue_redraw()
	form_changed.emit()
	if value>old_form: visual_event.emit("magic" if value==2 else "grow")
	return true

func respawn() -> void:
	apply_form(0)
	global_position = spawn_point
	rebound_time = 0
	shot_cooldown = 0
	velocity = Vector2.ZERO
	recovering = 0
	protection = 2
	visible = true
	visual_event.emit("respawn")
	$Camera.reset_smoothing()

func damage(fall := false, forced := false) -> void:
	if recovering > 0 or not Campaign.active():
		return
	if not forced and not fall and (protection > 0 or Campaign.cheats.get("shield",false)):
		return
	if not forced and not fall and form > 0:
		apply_form(0)
		visual_event.emit("hurt")
		SFX.play("player_hurt",self)
		protection = 2
		return
	visual_event.emit("death")
	recovering = 1.05
	visible = false
	velocity = Vector2.ZERO
	var hearts_before:int=Campaign.p.hearts
	Campaign.lose_heart()
	if Campaign.p.hearts<hearts_before: SFX.play("player_death",self)

func shoot() -> void:
	if not Campaign.active() or recovering>0 or form != 2 or shot_cooldown>0 or get_tree().get_nodes_in_group("bolts").size() >= 2:
		return
	# Reserve the attack before adding the projectile: an immediate collision must
	# never release this timer, nor replay sound/animation for a rejected input.
	shot_cooldown = SHOT_COOLDOWN
	var bolt := BOLT.instantiate()
	bolt.direction = facing
	bolt.position = position + Vector2(10*facing,-height*0.42)
	get_parent().add_child(bolt)
	visual_event.emit("shoot")
	SFX.play("magic_cast",self)
	Campaign.learned("shoot")

func _physics_process(delta: float) -> void:
	if not Campaign.active():
		return
	shot_cooldown=maxf(0,shot_cooldown-delta)
	if recovering > 0:
		recovering -= delta
		if recovering <= 0:
			respawn()
		return
	protection = maxf(0,protection-delta)
	modulate.a = 0.48 if protection > 0 and int(protection*10)%2 == 1 else 1.0
	previous_feet = global_position.y
	var axis := Input.get_axis("move_left","move_right")
	var speed := SPEED * float(Campaign.cheats.get("speed",1.0))
	if rebound_time > 0:
		rebound_time -= delta
	else:
		velocity.x = move_toward(velocity.x,axis*speed,(1250 if axis else 1600)*delta)
	if axis:
		facing = 1 if axis > 0 else -1
		queue_redraw()
	if Campaign.cheats.get("fly",false):
		velocity.y = Input.get_axis("ui_up","ui_down")*speed
	else:
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = -JUMP
			SFX.play("player_jump",self)
			Campaign.learned("jump")
		if not Input.is_action_pressed("jump") and velocity.y < -310 and rebound_time <= 0:
			velocity.y = -310
		velocity.y = minf(480,velocity.y + GRAVITY*delta)
	if Input.is_action_just_pressed("shoot"):
		shoot()
	var before := position.x
	move_and_slide()
	if axis and absf(position.x-before)>0.1 and not Campaign.p.tutorial.has("move"):
		Campaign.learned("move")
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_normal().y > 0.8 and hit.get_collider().has_method("hit_below"):
			hit.get_collider().hit_below(self)
			visual_event.emit("head")
	if position.y > 610:
		damage(true)

func _draw() -> void:
	if has_meta("forest_skin"): return
	var ogre: bool = Campaign.p.get("hero","human") == "ogre"
	var body := Color("#9acf78") if ogre else Color("#ffc36a")
	draw_rect(Rect2(-12,-height,24,height),body)
	draw_rect(Rect2(-12,-height*0.50,24,5),Color("#654c86") if ogre else Color("#316778"))
	draw_rect(Rect2(4*facing-2,-height+8,4,4),Color("#20343e"))
	if ogre:
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-height+16),Vector2(-6,-height+20),Vector2(-6,-height+12)]),Color.WHITE)
	if form == 2:
		draw_rect(Rect2(-12,-height,24,5),Color("#65e5ff"))
