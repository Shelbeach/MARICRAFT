extends Camera2D
## World-only framing. HUD remains in its original 960x540 CanvasLayer.
const TRAVEL_ZOOM:=1.25
var look_ahead:=0.0
var framing_arena:=false
func _ready() -> void:
	top_level=true
	snap_to_player()
func snap_to_player() -> void:
	look_ahead=0
	_update_frame(1.0,true)
	reset_smoothing()
func _physics_process(delta:float) -> void:
	_update_frame(delta,false)
func _update_frame(delta:float,snap:bool) -> void:
	var actor=get_parent()
	var level=actor.get_parent()
	var desired_zoom:=TRAVEL_ZOOM
	look_ahead=move_toward(look_ahead,signf(actor.velocity.x)*88 if absf(actor.velocity.x)>8 else 0,130*delta)
	var target:Vector2=actor.global_position+Vector2(look_ahead,-80)
	target.y=clampf(target.y,240,324)
	var boss=level.get_node_or_null("Boss")
	framing_arena=boss!=null and boss.hp>0 and actor.position.x>=level.arena_entry_x-240
	if framing_arena:
		# Hold a single close arena view around the player and attack source. Only
		# long retreats widen it, gradually, rather than tracking each projectile.
		var focus:float=boss.home.x
		var extent:=absf(actor.position.x-focus)+560
		desired_zoom=clampf(960.0/extent,0.85,1.10)
		target.x=(actor.position.x+focus)*0.5
		target.y=296
	var z:=desired_zoom if snap else move_toward(zoom.x,desired_zoom,0.30*delta)
	zoom=Vector2.ONE*z
	global_position=target
