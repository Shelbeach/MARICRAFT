extends Node
## Shared ranged behaviour for fire imps; patrol, stomp and magic rules stay shared.
const SHOT:=preload("res://scenes/objects/imp_projectile.tscn")
const RANGE:=340.0
const MIN_RANGE:=48.0
const WINDUP:=0.65
const INTERVAL:=2.6
enum Mode { PATROL, WINDUP, RECOVER }
var actor
var mode:=Mode.PATROL
var clock:=0.0
var cooldown:=1.5
var shots_fired:=0
var locked_aim:=Vector2.LEFT
var shape:=RectangleShape2D.new()

func _ready() -> void: shape.size=Vector2(12,12)
func muzzle() -> Vector2: return actor.global_position+Vector2(actor.direction*22,-20)
func target() -> Vector2:
	var player=actor.get_parent().player
	return player.global_position-Vector2(0,player.height*0.5)
func can_attack() -> bool:
	var player=actor.get_parent().player
	if player.recovering>0 or not actor.is_on_floor(): return false
	var side:=1.0 if target().x>actor.global_position.x else -1.0
	var launch:Vector2=actor.global_position+Vector2(side*22,-20)
	var distance:=launch.distance_to(target())
	if distance<MIN_RANGE or distance>RANGE or absf(target().y-launch.y)>170: return false
	var viewport:Rect2=actor.get_viewport_rect().grow(-28)
	if not viewport.has_point(actor.get_global_transform_with_canvas().origin-Vector2(0,16)): return false
	if not viewport.has_point(player.get_global_transform_with_canvas().origin-Vector2(0,16)): return false
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform.origin=launch
	query.motion=target()-launch
	query.collision_mask=1
	var space=actor.get_world_2d().direct_space_state
	return space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0]>=1.0

func update_attack(delta:float) -> bool:
	cooldown=maxf(0,cooldown-delta)
	if mode==Mode.PATROL:
		if cooldown<=0 and can_attack():
			mode=Mode.WINDUP
			clock=WINDUP
			actor.direction=1 if target().x>actor.global_position.x else -1
			actor.patrol_turn=0
			locked_aim=(target()-muzzle()).normalized()
		return mode!=Mode.PATROL
	clock-=delta
	if mode==Mode.WINDUP:
		# Acquisition is checked once. A committed warning completes even when
		# the player jumps, retreats or leaves the screen; the locked aim is dodgeable.
		if actor.get_parent().player.recovering>0:
			mode=Mode.PATROL
			cooldown=0.9
			return false
		if clock<=0:
			var shot:=SHOT.instantiate()
			shot.position=muzzle()
			shot.direction=locked_aim
			shot.speed_override=156
			shot.lifetime=2.8
			actor.get_parent().add_child(shot)
			shots_fired+=1
			actor.visual_event.emit("ranged_shoot")
			SFX.play("magic_cast",actor,null,-8)
			mode=Mode.RECOVER
			clock=0.4
			cooldown=INTERVAL
	elif clock<=0: mode=Mode.PATROL
	return true
