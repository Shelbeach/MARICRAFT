extends CharacterBody2D

signal visual_event(kind: String)
var defeat_clip:="stomp_defeat"

func magic_hit() -> void:
	defeat_clip="magic_defeat"
	defeat()

@export var reward_id := ""
@export var patrol_width := 200.0
@export var ranged := false
var attack_controller
const TURN_SECONDS := 0.18
var patrol_turn := 0.0
var turn_from := 1
var origin := 0.0
var direction := 1
var dead := false
var emerging_from_pipe := false

func _ready() -> void:
	origin = position.x
	if ranged:
		attack_controller=preload("res://scripts/gameplay/imp_attack.gd").new()
		attack_controller.actor=self
		add_child(attack_controller)

func turn_patrol() -> void:
	turn_from=direction
	direction=-direction
	patrol_turn=TURN_SECONDS

func defeat() -> void:
	if dead:
		return
	dead = true
	SFX.play("enemy_pop",self,"death")
	visual_event.emit(defeat_clip)
	Campaign.reward(reward_id,0,100,true)
	queue_free()

func _physics_process(delta: float) -> void:
	if dead or not Campaign.active(): return
	patrol_turn=maxf(0,patrol_turn-delta)
	if emerging_from_pipe:
		velocity.x = direction*118
		velocity.y += 960*delta
		move_and_slide()
		if is_on_wall() and get_wall_normal().x*direction<0 and patrol_turn<=0:
			turn_patrol()
		if is_on_floor() and absf(position.x-origin)>56:
			origin = position.x
			emerging_from_pipe = false
		return
	var attacking:bool=attack_controller.update_attack(delta) if attack_controller else false
	var ahead := Vector2(direction*22,0)
	var ray := PhysicsRayQueryParameters2D.create(global_position+ahead-Vector2(0,5),global_position+ahead+Vector2(0,14),1)
	if not attacking and patrol_turn<=0 and is_on_floor() and ((position.x-origin)*direction>=patrol_width or get_world_2d().direct_space_state.intersect_ray(ray).is_empty()):
		turn_patrol()
	velocity.x = 0 if attacking or patrol_turn>0 else direction*60
	velocity.y = minf(480,velocity.y+960*delta)
	move_and_slide()
	if not attacking and patrol_turn<=0 and is_on_wall() and get_wall_normal().x*direction<0:
		turn_patrol()
	var player = get_tree().get_first_node_in_group("forest_player")
	if not player or player.recovering > 0 or not Campaign.active():
		return
	var dx: float = absf(player.position.x-position.x)
	var feet: float = player.position.y
	if dx < 26 and feet >= position.y-28 and feet-player.height < position.y:
		if player.velocity.y > 0 and player.previous_feet <= position.y-25:
			defeat()
			player.velocity.y = -345
		else:
			player.damage()

func _draw() -> void:
	if has_meta("forest_skin"): return
	draw_colored_polygon(PackedVector2Array([Vector2(-16,0),Vector2(-15,-21),Vector2(-8,-27),Vector2(12,-27),Vector2(17,-12),Vector2(14,0)]),Color("#ed7974"))
	for x in [-10,-2,6]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,-24),Vector2(x-3,-35),Vector2(x+6,-25)]),Color("#ffbc87"))
	draw_rect(Rect2(-8,-20,16,4),Color("#542f41"))
