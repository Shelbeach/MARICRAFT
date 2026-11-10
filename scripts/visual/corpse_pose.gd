extends RefCounted
## Feet stay on the real surface. Only the visual branch settles; no hitbox moves.
var floor_y:=0.0
var drop:=0.0
var speed:=0.0
var initialized:=false
func update(actor,art,foot_px:float,pivot_px:float,delta:float) -> void:
	if not initialized:
		initialized=true
		var ray:=PhysicsRayQueryParameters2D.create(actor.global_position-Vector2(0,2),actor.global_position+Vector2(0,640),1)
		var hit:Dictionary=actor.get_world_2d().direct_space_state.intersect_ray(ray)
		floor_y=hit.position.y if not hit.is_empty() else actor.global_position.y
		var clip:=ShaderMaterial.new()
		clip.shader=preload("res://scripts/visual/corpse_ground.gdshader")
		clip.set_shader_parameter("floor_y",floor_y)
		art.sprite.material=clip
	speed+=960*delta
	drop=move_toward(drop,floor_y-actor.global_position.y,speed*delta)
	art.position.y=drop+(pivot_px-foot_px)*art.sprite.scale.y+1
func reset(art) -> void:
	if not initialized: return
	initialized=false
	drop=0; speed=0
	art.position.y=0
	art.sprite.material=null
